"""Training, held-out evaluation, baselines, and rollout for SciTransformers."""

from std.math import sqrt, pow, exp, sin
from std.time import perf_counter
from hyperforge.autodiff.tape import Tape
from hyperforge.scit.task import (
    TaskSpec,
    sample_task,
    frame,
    persistence_prediction,
    mean_prediction,
    fit_linear_baseline,
    linear_prediction,
    mse,
)
from hyperforge.scit.model import SciTransformer, init_model, predict, forward_tape

comptime LEARNING_RATE = 0.01
comptime BETA1 = 0.9
comptime BETA2 = 0.999
comptime ADAM_EPS = 1e-8
comptime ROLLOUT_STEPS = 5


struct SciOutcome(Copyable, Movable):
    var problem: String
    var seed: UInt64
    var epochs: Int
    var initial_loss: Float64
    var final_loss: Float64
    var model_mse: Float64
    var persistence_mse: Float64
    var mean_mse: Float64
    var linear_mse: Float64
    var rollout_drift: Float64
    var state: String
    var detail: String
    var runtime_seconds: Float64

    def __init__(
        out self,
        problem: String,
        seed: UInt64,
        epochs: Int,
        initial_loss: Float64,
        final_loss: Float64,
        model_mse: Float64,
        persistence_mse: Float64,
        mean_mse: Float64,
        linear_mse: Float64,
        rollout_drift: Float64,
        state: String,
        detail: String,
        runtime_seconds: Float64,
    ):
        self.problem = problem
        self.seed = seed
        self.epochs = epochs
        self.initial_loss = initial_loss
        self.final_loss = final_loss
        self.model_mse = model_mse
        self.persistence_mse = persistence_mse
        self.mean_mse = mean_mse
        self.linear_mse = linear_mse
        self.rollout_drift = rollout_drift
        self.state = state
        self.detail = detail
        self.runtime_seconds = runtime_seconds


def train_inputs(spec: TaskSpec, index: Int) raises -> Tuple[List[List[Float64]], List[Float64]]:
    var sample = sample_task(spec, index, True)
    return (sample[0]^, sample[1]^)


def loss_for(
    mut tape: Tape, predictions: List[Int], targets: List[Float64]
) raises -> Int:
    var total = tape.constant(0.0)
    for i in range(len(predictions)):
        var delta = tape.sub(predictions[i], tape.constant(targets[i]))
        total = tape.add(total, tape.mul(delta, delta))
    return tape.scale(total, 1.0 / Float64(len(predictions)))


def rollout_drift(
    model: SciTransformer, spec: TaskSpec, phase: Float64
) raises -> Float64:
    """Iterative multi-step rollout against the analytic reference."""
    var history = List[List[Float64]]()
    history.append(frame(spec, phase, 0.0))
    history.append(frame(spec, phase, 1.0))
    var worst = Float64(0.0)
    for step in range(ROLLOUT_STEPS):
        var predicted = predict(model, spec, history)
        history.append(predicted.copy())
        if len(history) > spec.history:
            _ = history.pop(0)
        var truth = frame(spec, phase, Float64(2 + step))
        var error = mse(predicted, truth)
        if error > worst:
            worst = error
    return worst


def train_and_evaluate(
    spec: TaskSpec, seed: UInt64, epochs: Int, learning_rate: Float64 = LEARNING_RATE
) raises -> Tuple[SciTransformer, SciOutcome]:
    if epochs < 1:
        raise Error("epochs must be positive")
    var model = init_model(seed, spec.grid_points)
    var parameters = len(model.parameters)
    var momentum = List[Float64]()
    var velocity = List[Float64]()
    for _ in range(parameters):
        momentum.append(0.0)
        velocity.append(0.0)

    var started = perf_counter()
    var initial_loss = Float64(0.0)
    var current_loss = Float64(0.0)
    var rejected = False

    for epoch in range(epochs):
        current_loss = 0.0
        for sample_index in range(spec.train_count):
            var sample = sample_task(spec, sample_index, True)
            var inputs = sample[0].copy()
            var target = sample[1].copy()
            var tape = Tape()
            var predictions = forward_training(tape, model, spec, inputs)
            var loss_node = loss_for(tape, predictions, target)
            current_loss += tape.value(loss_node)
            tape.backward(loss_node)
            for p in range(parameters):
                var gradient = tape.accumulated(p)
                if gradient != gradient:
                    rejected = True
            if rejected:
                break
            var progress = Float64(epoch * spec.train_count + sample_index + 1)
            var correction1 = 1.0 - pow(BETA1, progress)
            var correction2 = 1.0 - pow(BETA2, progress)
            for p in range(parameters):
                var gradient = tape.accumulated(p)
                momentum[p] = BETA1 * momentum[p] + (1.0 - BETA1) * gradient
                velocity[p] = BETA2 * velocity[p] + (1.0 - BETA2) * gradient * gradient
                var mhat = momentum[p] / correction1
                var vhat = velocity[p] / correction2
                model.parameters[p] -= learning_rate * mhat / (sqrt(vhat) + ADAM_EPS)
        current_loss /= Float64(spec.train_count)
        if epoch == 0:
            initial_loss = current_loss
        if rejected:
            break

    var elapsed = perf_counter() - started

    var train_inputs_list = List[List[List[Float64]]]()
    var train_targets = List[List[Float64]]()
    for i in range(spec.train_count):
        var sample = sample_task(spec, i, True)
        train_inputs_list.append(sample[0].copy())
        train_targets.append(sample[1].copy())
    var mean_baseline = mean_prediction(train_targets, spec.grid_points)
    var linear_coefficients = fit_linear_baseline(
        train_inputs_list, train_targets, spec.grid_points
    )

    var model_total = Float64(0.0)
    var persistence_total = Float64(0.0)
    var mean_total = Float64(0.0)
    var linear_total = Float64(0.0)
    for i in range(spec.test_count):
        var sample = sample_task(spec, i, False)
        var inputs = sample[0].copy()
        var target = sample[1].copy()
        var prediction = predict(model, spec, inputs)
        model_total += mse(prediction, target)
        persistence_total += mse(persistence_prediction(inputs), target)
        mean_total += mse(mean_baseline, target)
        linear_total += mse(linear_prediction(linear_coefficients, inputs), target)
    var divisor = Float64(spec.test_count)
    var model_mse = model_total / divisor
    var persistence_mse = persistence_total / divisor
    var mean_mse = mean_total / divisor
    var linear_mse = linear_total / divisor

    var first_held = sample_task(spec, 0, False)
    var phase = first_held[2]
    var drift = rollout_drift(model, spec, phase)

    var state = String("POOR_FIT")
    var detail = String("model did not beat both non-transformer baselines")
    if rejected:
        state = "DIVERGED"
        detail = "non-finite gradient; training rejected"
    elif current_loss < initial_loss and model_mse < persistence_mse and model_mse < mean_mse:
        state = "CONVERGED"
        detail = "loss decreased and held-out error beat persistence and mean baselines"

    return (
        model^,
        SciOutcome(
            spec.name, seed, epochs, initial_loss, current_loss, model_mse,
            persistence_mse, mean_mse, linear_mse, drift, state, detail, elapsed,
        ),
    )


def forward_training(
    mut tape: Tape, model: SciTransformer, spec: TaskSpec, inputs: List[List[Float64]]
) raises -> List[Int]:
    # Thin wrapper so the training loop and inference share one forward path.
    return forward_tape(tape, model, spec, inputs)
