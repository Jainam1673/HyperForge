"""Transparent synthetic scientific sequence benchmark.

Task: predict the next frame of a decaying spatial mode

    u(x, t; phase) = sin(2*pi*x + phase) * exp(-lambda*t)

on a fixed 1D grid from the previous two frames. The generator is analytic and
explicitly labeled synthetic; it is a correctness fixture, not experimental
data. Held-out samples use different phases from training samples.
"""

from std.math import exp, sin, cos, pi
from hyperforge.core.rng import SplitMix64, derive_seed

comptime TASK_SCHEMA = "hyperforge-scit-task-v1"
comptime TASK_NAME = "decaying_mode_1d"


struct TaskSpec(Copyable, Movable):
    var name: String
    var grid_points: Int
    var history: Int
    var decay: Float64
    var train_count: Int
    var test_count: Int
    var seed: UInt64

    def __init__(
        out self,
        name: String,
        grid_points: Int,
        history: Int,
        decay: Float64,
        train_count: Int,
        test_count: Int,
        seed: UInt64,
    ):
        self.name = name
        self.grid_points = grid_points
        self.history = history
        self.decay = decay
        self.train_count = train_count
        self.test_count = test_count
        self.seed = seed


def default_task(seed: UInt64) raises -> TaskSpec:
    return TaskSpec(TASK_NAME, 8, 2, 0.35, 24, 8, seed)


def grid_x(spec: TaskSpec, index: Int) raises -> Float64:
    return Float64(index) / Float64(spec.grid_points - 1)


def frame(spec: TaskSpec, phase: Float64, time: Float64) raises -> List[Float64]:
    var values = List[Float64]()
    for i in range(spec.grid_points):
        var x = grid_x(spec, i)
        values.append(sin(2.0 * pi * x + phase) * exp(-spec.decay * time))
    return values^


def sample_task(spec: TaskSpec, index: Int, training: Bool) raises -> Tuple[List[List[Float64]], List[Float64], Float64]:
    var namespace = String("train-phase")
    if not training:
        namespace = "test-phase"
    var rng = SplitMix64(derive_seed(spec.seed, namespace, UInt64(index)))
    var phase = Float64(Int(rng.next_below(UInt64(1000)))) / 1000.0 * 2.0 * pi
    var inputs = List[List[Float64]]()
    for k in range(spec.history):
        inputs.append(frame(spec, phase, Float64(k)))
    var target = frame(spec, phase, Float64(spec.history))
    return (inputs^, target^, phase)


def coordinate_encoding(spec: TaskSpec, cell: Int, time_step: Int) raises -> List[Float64]:
    """Deterministic absolute coordinate encoding for (x, time)."""
    var x = grid_x(spec, cell)
    var out = List[Float64]()
    out.append(sin(2.0 * pi * x))
    out.append(cos(2.0 * pi * x))
    out.append(sin(pi * Float64(time_step) / Float64(spec.history + 1)))
    out.append(cos(pi * Float64(time_step) / Float64(spec.history + 1)))
    return out^


def persistence_prediction(inputs: List[List[Float64]]) raises -> List[Float64]:
    return inputs[len(inputs) - 1].copy()


def mean_prediction(targets: List[List[Float64]], width: Int) raises -> List[Float64]:
    var out = List[Float64]()
    for j in range(width):
        var total = Float64(0.0)
        for target in targets:
            total += target[j]
        out.append(total / Float64(len(targets)))
    return out^


def fit_linear_baseline(
    inputs: List[List[List[Float64]]], targets: List[List[Float64]], width: Int
) raises -> List[Float64]:
    """Per-cell least-squares scale from last frame to target."""
    var coefficients = List[Float64]()
    for j in range(width):
        var numerator = Float64(0.0)
        var denominator = Float64(0.0)
        for i in range(len(inputs)):
            var last = inputs[i][len(inputs[i]) - 1][j]
            numerator += last * targets[i][j]
            denominator += last * last
        if denominator == 0.0:
            coefficients.append(0.0)
        else:
            coefficients.append(numerator / denominator)
    return coefficients^


def linear_prediction(
    coefficients: List[Float64], inputs: List[List[Float64]]
) raises -> List[Float64]:
    var out = List[Float64]()
    var last = inputs[len(inputs) - 1].copy()
    for j in range(len(coefficients)):
        out.append(coefficients[j] * last[j])
    return out^


def mse(prediction: List[Float64], target: List[Float64]) raises -> Float64:
    if len(prediction) != len(target):
        raise Error("mse length mismatch")
    var total = Float64(0.0)
    for i in range(len(prediction)):
        var delta = prediction[i] - target[i]
        total += delta * delta
    return total / Float64(len(prediction))
