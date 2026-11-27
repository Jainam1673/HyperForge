"""Training and measurement for AutoTransformers candidates.

Training here reuses the verified SciTransformers task/autodiff substrate; it is
not implied by any MAX inference support. No serving path is used.
"""

from std.math import sqrt, pow
from std.time import perf_counter
from hyperforge.autodiff.tape import Tape
from hyperforge.scit.task import TaskSpec, sample_task, target_at
from hyperforge.autotrans.model import (
    TransformerModel,
    TransformerConfig,
    forward_tape,
    predict,
)

comptime BETA1 = 0.9
comptime BETA2 = 0.999
comptime ADAM_EPS = 1e-8


def range_indices(count: Int, offset: Int = 0) raises -> List[Int]:
    var out = List[Int]()
    for i in range(count):
        out.append(offset + i)
    return out^


def evaluate(
    model: TransformerModel, spec: TaskSpec, indices: List[Int], training: Bool
) raises -> Tuple[Float64, Float64]:
    var total_squared = Float64(0.0)
    var total_absolute = Float64(0.0)
    var n = 0
    for index in indices:
        var sample = sample_task(spec, index, training)
        var inputs = sample[0].copy()
        var target = sample[1].copy()
        var prediction = predict(model, spec, inputs)
        for j in range(len(prediction)):
            var delta = prediction[j] - target[j]
            total_squared += delta * delta
            if delta < 0.0:
                delta = -delta
            total_absolute += delta
            n += 1
    return (total_squared / Float64(n), total_absolute / Float64(n))


def train(
    mut model: TransformerModel,
    spec: TaskSpec,
    train_indices: List[Int],
    epochs: Int,
    learning_rate: Float64,
) raises -> List[Float64]:
    if epochs < 1:
        raise Error("epochs must be positive")
    var losses = List[Float64]()
    var total = len(model.parameters)
    var momentum = List[Float64]()
    var velocity = List[Float64]()
    for _ in range(total):
        momentum.append(0.0)
        velocity.append(0.0)

    for epoch in range(epochs):
        var epoch_loss = Float64(0.0)
        for sample_index in train_indices:
            var sample = sample_task(spec, sample_index, True)
            var inputs = sample[0].copy()
            var target = sample[1].copy()
            var tape = Tape()
            var predictions = forward_tape(tape, model, spec, inputs)
            var loss_node = tape.constant(0.0)
            for j in range(len(predictions)):
                var delta = tape.sub(predictions[j], tape.constant(target[j]))
                loss_node = tape.add(loss_node, tape.mul(delta, delta))
            loss_node = tape.scale(loss_node, 1.0 / Float64(len(predictions)))
            var loss_value = tape.value(loss_node)
            if loss_value != loss_value:
                raise Error("non-finite transformer loss")
            epoch_loss += loss_value
            tape.backward(loss_node)
            var step = Float64(epoch * len(train_indices) + sample_index + 1)
            var correction1 = 1.0 - pow(BETA1, step)
            var correction2 = 1.0 - pow(BETA2, step)
            for p in range(total):
                var gradient = tape.accumulated(p)
                momentum[p] = BETA1 * momentum[p] + (1.0 - BETA1) * gradient
                velocity[p] = BETA2 * velocity[p] + (1.0 - BETA2) * gradient * gradient
                model.parameters[p] -= learning_rate * (
                    momentum[p] / correction1 / (sqrt(velocity[p] / correction2) + ADAM_EPS)
                )
        losses.append(epoch_loss / Float64(len(train_indices)))
    return losses^


def median(values: List[Float64]) raises -> Float64:
    var sorted_values = List[Float64]()
    for value in values:
        var inserted = False
        for i in range(len(sorted_values)):
            if value < sorted_values[i]:
                sorted_values.insert(i, value)
                inserted = True
                break
        if not inserted:
            sorted_values.append(value)
    return sorted_values[(len(sorted_values) - 1) // 2]


def inference_latency(
    model: TransformerModel, spec: TaskSpec, sample_index: Int, repetitions: Int
) raises -> Float64:
    var sample = sample_task(spec, sample_index, False)
    var inputs = sample[0].copy()
    _ = predict(model, spec, inputs)  # warm-up
    var times = List[Float64]()
    for _ in range(repetitions):
        var started = perf_counter()
        _ = predict(model, spec, inputs)
        times.append(perf_counter() - started)
    return median(times)
