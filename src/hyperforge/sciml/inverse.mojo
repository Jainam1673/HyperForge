"""Inverse parameter identification with conventional and hybrid baselines."""

from std.math import sqrt, sin, pi
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.sciml.problem import (
    ScientificProblem,
    exact_solution,
    finite_difference_solution,
)

comptime SEARCH_STEPS = 200
comptime REFINE_STEPS = 40
comptime NOISE_SIGMA = 0.01
comptime REPEAT_SEEDS = 5


struct SciMLOutcome(Copyable, Movable):
    var problem: String
    var seed: UInt64
    var observations: Int
    var train_count: Int
    var heldout_count: Int
    var estimated_parameter: Float64
    var parameter_error: Float64
    var parameter_std: Float64
    var inverse_exact_l2: Float64
    var hybrid_exact_l2: Float64
    var constant_exact_l2: Float64
    var finite_difference_l2: Float64
    var detail: String

    def __init__(
        out self,
        problem: String,
        seed: UInt64,
        observations: Int,
        train_count: Int,
        heldout_count: Int,
        estimated_parameter: Float64,
        parameter_error: Float64,
        parameter_std: Float64,
        inverse_exact_l2: Float64,
        hybrid_exact_l2: Float64,
        constant_exact_l2: Float64,
        finite_difference_l2: Float64,
        detail: String,
    ):
        self.problem = problem
        self.seed = seed
        self.observations = observations
        self.train_count = train_count
        self.heldout_count = heldout_count
        self.estimated_parameter = estimated_parameter
        self.parameter_error = parameter_error
        self.parameter_std = parameter_std
        self.inverse_exact_l2 = inverse_exact_l2
        self.hybrid_exact_l2 = hybrid_exact_l2
        self.constant_exact_l2 = constant_exact_l2
        self.finite_difference_l2 = finite_difference_l2
        self.detail = detail


def observation_points(problem: ScientificProblem, count: Int) raises -> List[Float64]:
    var points = List[Float64]()
    var stride = problem.evaluation_points // count
    if stride < 1:
        stride = 1
    for i in range(count):
        var index = (i * stride) % problem.evaluation_points + 1
        points.append(Float64(index) / Float64(problem.evaluation_points + 1))
    return points^


def observations_with_noise(
    problem: ScientificProblem, points: List[Float64], seed: UInt64
) raises -> List[Float64]:
    var rng = SplitMix64(derive_seed(seed, "sciml-noise", UInt64(0)))
    var observed = List[Float64]()
    for x in points:
        var noise = (Float64(Int(rng.next_below(UInt64(2001))) - 1000) / 1000.0) * NOISE_SIGMA
        observed.append(exact_solution(x, problem.true_parameter) + noise)
    return observed^


def sse(
    problem: ScientificProblem,
    points: List[Float64],
    observed: List[Float64],
    indices: List[Int],
    parameter: Float64,
) raises -> Float64:
    var predicted = finite_difference_solution(problem, parameter, points)
    var total = Float64(0.0)
    for index in indices:
        var delta = predicted[index] - observed[index]
        total += delta * delta
    return total


def estimate_parameter(
    problem: ScientificProblem,
    points: List[Float64],
    observed: List[Float64],
    indices: List[Int],
) raises -> Float64:
    var best = problem.parameter_lower
    var best_score = Float64(1e300)
    for step in range(SEARCH_STEPS + 1):
        var parameter = problem.parameter_lower
            + (problem.parameter_upper - problem.parameter_lower)
            * Float64(step) / Float64(SEARCH_STEPS)
        var score = sse(problem, points, observed, indices, parameter)
        if score < best_score:
            best_score = score
            best = parameter
    var span = (problem.parameter_upper - problem.parameter_lower) / Float64(SEARCH_STEPS)
    for step in range(REFINE_STEPS):
        var candidate = best + span * (Float64(step) - Float64(REFINE_STEPS) / 2.0) / Float64(REFINE_STEPS)
        if candidate < problem.parameter_lower:
            candidate = problem.parameter_lower
        if candidate > problem.parameter_upper:
            candidate = problem.parameter_upper
        var score = sse(problem, points, observed, indices, candidate)
        if score < best_score:
            best_score = score
            best = candidate
    return best


def mean_ratio_baseline(
    problem: ScientificProblem, points: List[Float64], observed: List[Float64], indices: List[Int]
) raises -> Float64:
    var total = Float64(0.0)
    for index in indices:
        var basis = sin(pi * points[index]) / (pi * pi)
        total += observed[index] / basis
    return total / Float64(len(indices))


def l2_error(predictions: List[Float64], targets: List[Float64]) raises -> Float64:
    var total = Float64(0.0)
    for i in range(len(predictions)):
        var delta = predictions[i] - targets[i]
        total += delta * delta
    return sqrt(total / Float64(len(predictions)))


def root_mean_square(values: List[Float64]) raises -> Float64:
    var total = Float64(0.0)
    for value in values:
        total += value * value
    return sqrt(total / Float64(len(values)))


def mean_of(values: List[Float64]) raises -> Float64:
    var total = Float64(0.0)
    for value in values:
        total += value
    return total / Float64(len(values))


def run_experiment(problem: ScientificProblem, seed: UInt64) raises -> SciMLOutcome:
    var points = observation_points(problem, 12)
    var observed = observations_with_noise(problem, points, seed)
    var train = List[Int]()
    var heldout = List[Int]()
    for i in range(len(points)):
        if i < 7:
            train.append(i)
        else:
            heldout.append(i)

    var parameter = estimate_parameter(problem, points, observed, train)
    var ratio = mean_ratio_baseline(problem, points, observed, train)

    # Physics + data hybrid: FD solver at the estimated parameter with a
    # least-squares scalar correction fitted on training observations only.
    var physics = finite_difference_solution(problem, parameter, points)
    var numerator = Float64(0.0)
    var denominator = Float64(0.0)
    for index in train:
        numerator += physics[index] * observed[index]
        denominator += physics[index] * physics[index]
    var correction = numerator / denominator
    var constant_prediction = Float64(0.0)
    for index in train:
        constant_prediction += observed[index]
    constant_prediction /= Float64(len(train))

    var inverse_predictions = List[Float64]()
    var hybrid_predictions = List[Float64]()
    var constant_predictions = List[Float64]()
    var exact_values = List[Float64]()
    for index in heldout:
        inverse_predictions.append(physics[index])
        hybrid_predictions.append(correction * physics[index])
        constant_predictions.append(constant_prediction)
        exact_values.append(exact_solution(points[index], problem.true_parameter))

    var repeats = List[Float64]()
    for i in range(REPEAT_SEEDS):
        var noisy = observations_with_noise(problem, points, seed + UInt64(i * 17 + 1))
        repeats.append(estimate_parameter(problem, points, noisy, train))
    var repeat_mean = mean_of(repeats)
    var variance = Float64(0.0)
    for value in repeats:
        var delta = value - repeat_mean
        variance += delta * delta
    var deviation = sqrt(variance / Float64(len(repeats) - 1))

    var fd_reference = finite_difference_solution(problem, problem.true_parameter, points)
    var fd_errors = List[Float64]()
    for index in heldout:
        fd_errors.append(fd_reference[index] - exact_values[len(fd_errors)])

    return SciMLOutcome(
        problem.name, seed, len(points), len(train), len(heldout), parameter,
        abs2(parameter - problem.true_parameter), deviation,
        l2_error(inverse_predictions, exact_values),
        l2_error(hybrid_predictions, exact_values),
        l2_error(constant_predictions, exact_values),
        root_mean_square(fd_errors),
        "inverse via finite-difference operator; hybrid correction fitted on train only",
    )


def abs2(value: Float64) raises -> Float64:
    if value < 0.0:
        return -value
    return value
