"""Mini-batch training with validation-only early stopping and checkpoints."""

from std.math import sqrt, pow
from std.time import perf_counter
from hyperforge.autodiff.tape import Tape
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.autodl.task import AutoDLTask
from hyperforge.autodl.model import (
    ArchCandidate,
    MLP,
    init_model,
    forward_tape,
    predict,
)

comptime BETA1 = 0.9
comptime BETA2 = 0.999
comptime ADAM_EPS = 1e-8
comptime LOSS_EPS = 1e-6


struct TrainResult(Copyable, Movable):
    var candidate_id: String
    var epochs_run: Int
    var initial_loss: Float64
    var final_train_loss: Float64
    var validation_loss: Float64
    var test_loss: Float64
    var test_accuracy: Float64
    var parameters_changed: Bool
    var max_parameter_delta: Float64
    var state: String
    var detail: String
    var runtime_seconds: Float64

    def __init__(
        out self,
        candidate_id: String,
        epochs_run: Int,
        initial_loss: Float64,
        final_train_loss: Float64,
        validation_loss: Float64,
        test_loss: Float64,
        test_accuracy: Float64,
        parameters_changed: Bool,
        max_parameter_delta: Float64,
        state: String,
        detail: String,
        runtime_seconds: Float64,
    ):
        self.candidate_id = candidate_id
        self.epochs_run = epochs_run
        self.initial_loss = initial_loss
        self.final_train_loss = final_train_loss
        self.validation_loss = validation_loss
        self.test_loss = test_loss
        self.test_accuracy = test_accuracy
        self.parameters_changed = parameters_changed
        self.max_parameter_delta = max_parameter_delta
        self.state = state
        self.detail = detail
        self.runtime_seconds = runtime_seconds


def bce_loss(mut tape: Tape, node: Int, label: Int) raises -> Int:
    var clipped = tape.add(tape.scale(node, 1.0 - 2.0 * LOSS_EPS), tape.constant(LOSS_EPS))
    var right = tape.sub(tape.constant(1.0), clipped)
    var term = tape.add(
        tape.mul(tape.constant(Float64(label)), tape.log(clipped)),
        tape.mul(tape.constant(Float64(1 - label)), tape.log(right)),
    )
    return tape.scale(term, -1.0)


def evaluate_indices(
    model: MLP, task: AutoDLTask, indices: List[Int]
) raises -> Tuple[Float64, Float64]:
    var total_loss = Float64(0.0)
    var correct = 0
    for index in indices:
        var features = task.features[index].copy()
        var probability = predict(model, features)
        var clipped = probability
        if clipped < LOSS_EPS:
            clipped = LOSS_EPS
        if clipped > 1.0 - LOSS_EPS:
            clipped = 1.0 - LOSS_EPS
        var label = Float64(task.labels[index])
        total_loss -= label * __log(clipped) + (1.0 - label) * __log(1.0 - clipped)
        var predicted_label = 1 if probability >= 0.5 else 0
        if predicted_label == task.labels[index]:
            correct += 1
    return (
        total_loss / Float64(len(indices)),
        Float64(correct) / Float64(len(indices)),
    )


def __log(value: Float64) raises -> Float64:
    from std.math import log
    return log(value)


def train_model(
    candidate: ArchCandidate,
    task: AutoDLTask,
    max_epochs: Int,
    patience: Int,
) raises -> Tuple[MLP, TrainResult]:
    if max_epochs < 1 or patience < 1:
        raise Error("epochs and patience must be positive")
    var model = init_model(candidate)
    var initial_parameters = model.parameters.copy()
    var parameter_total = len(model.parameters)
    var momentum = List[Float64]()
    var velocity = List[Float64]()
    for _ in range(parameter_total):
        momentum.append(0.0)
        velocity.append(0.0)

    var started = perf_counter()
    var best_validation = Float64(1e300)
    var epochs_without_improvement = 0
    var epochs_run = 0
    var initial_loss = Float64(0.0)
    var final_train_loss = Float64(0.0)
    var rejected = False

    for epoch in range(max_epochs):
        var shuffle_rng = SplitMix64(
            derive_seed(candidate.seed, "autodl-batch", UInt64(epoch))
        )
        var order = List[Int]()
        for index in task.train:
            order.append(index)
        for i in range(len(order) - 1, 0, -1):
            var j = Int(shuffle_rng.next_below(UInt64(i + 1)))
            var tmp = order[i]
            order[i] = order[j]
            order[j] = tmp

        var epoch_loss = Float64(0.0)
        var batches = 0
        var start = 0
        while start < len(order):
            var end = start + candidate.batch_size
            if end > len(order):
                end = len(order)
            var tape = Tape()
            var total = tape.constant(0.0)
            for position in range(start, end):
                var sample_index = order[position]
                var output = forward_tape(tape, model, task.features[sample_index])
                total = tape.add(total, bce_loss(tape, output, task.labels[sample_index]))
            var batch_size = Float64(end - start)
            var loss_node = tape.scale(total, 1.0 / batch_size)
            var loss_value = tape.value(loss_node)
            if loss_value != loss_value:
                rejected = True
                break
            tape.backward(loss_node)
            var non_finite = False
            for p in range(parameter_total):
                if tape.accumulated(p) != tape.accumulated(p):
                    non_finite = True
                    break
            if non_finite:
                rejected = True
                break
            var step = Float64(epoch * len(order) + end)
            var correction1 = 1.0 - pow(BETA1, step)
            var correction2 = 1.0 - pow(BETA2, step)
            for p in range(parameter_total):
                var gradient = tape.accumulated(p)
                momentum[p] = BETA1 * momentum[p] + (1.0 - BETA1) * gradient
                velocity[p] = BETA2 * velocity[p] + (1.0 - BETA2) * gradient * gradient
                var mhat = momentum[p] / correction1
                var vhat = velocity[p] / correction2
                model.parameters[p] -= candidate.learning_rate * mhat / (sqrt(vhat) + ADAM_EPS)
            epoch_loss += loss_value * batch_size
            batches += 1
            start = end

        if rejected:
            break
        epoch_loss /= Float64(len(order))
        epochs_run = epoch + 1
        if epoch == 0:
            initial_loss = epoch_loss
        final_train_loss = epoch_loss
        var validation = evaluate_indices(model, task, task.validation)
        if validation[0] < best_validation - 1e-6:
            best_validation = validation[0]
            epochs_without_improvement = 0
        else:
            epochs_without_improvement += 1
        if epochs_without_improvement >= patience:
            break

    var max_delta = Float64(0.0)
    for i in range(parameter_total):
        var delta = model.parameters[i] - initial_parameters[i]
        if delta < 0.0:
            delta = -delta
        if delta > max_delta:
            max_delta = delta
    var changed = max_delta > Float64(0.0)

    var state = String("TRAINED")
    var detail = String("validation early stopping or full epoch budget")
    if rejected:
        state = "DIVERGED"
        detail = "non-finite loss or gradient"
    elif not changed:
        state = "UNCHANGED"
        detail = "parameters did not update; training not accepted"

    return (
        model^,
        TrainResult(
            candidate.id, epochs_run, initial_loss, final_train_loss, best_validation,
            Float64(0.0), Float64(0.0), changed, max_delta, state, detail,
            perf_counter() - started,
        ),
    )
