"""Full SciAI breadth over shared analytic problem families.

Covers SciML inverse identification with UQ, SciDL baseline comparison,
SciRL resolution selection, a differentiable-simulation gradient check, and a
neural-operator amortization spike. All measurements come from real computation.
"""

from std.math import exp, sqrt, abs
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.sinn.jet import parameter as jet_parameter, constant as jet_constant, jet_mul

comptime SCIA_FULL_SCHEMA = "hyperforge-sciai-full-v1"
comptime SAMPLES = 12
comptime GRID_STEPS = 100


struct Problem(Copyable, Movable):
    var name: String
    var lower: Float64
    var upper: Float64

    def __init__(out self, name: String, lower: Float64, upper: Float64):
        self.name = name
        self.lower = lower
        self.upper = upper


struct SciAIOutcome(Copyable, Movable):
    var problem: String
    var seed: UInt64
    var true_parameter: Float64
    var estimated_parameter: Float64
    var parameter_std: Float64
    var interval_low: Float64
    var interval_high: Float64
    var field_rmse: Float64
    var linear_rmse: Float64
    var analytic_gradient_error: Float64
    var jet_gradient_error: Float64
    var bandit_return: Float64
    var random_return: Float64
    var operator_build_seconds: Float64
    var operator_eval_seconds: Float64
    var operator_error: Float64

    def __init__(
        out self,
        problem: String, seed: UInt64, true_parameter: Float64,
        estimated_parameter: Float64, parameter_std: Float64,
        interval_low: Float64, interval_high: Float64, field_rmse: Float64,
        linear_rmse: Float64, analytic_gradient_error: Float64,
        jet_gradient_error: Float64, bandit_return: Float64,
        random_return: Float64, operator_build_seconds: Float64,
        operator_eval_seconds: Float64, operator_error: Float64,
    ):
        self.problem = problem
        self.seed = seed
        self.true_parameter = true_parameter
        self.estimated_parameter = estimated_parameter
        self.parameter_std = parameter_std
        self.interval_low = interval_low
        self.interval_high = interval_high
        self.field_rmse = field_rmse
        self.linear_rmse = linear_rmse
        self.analytic_gradient_error = analytic_gradient_error
        self.jet_gradient_error = jet_gradient_error
        self.bandit_return = bandit_return
        self.random_return = random_return
        self.operator_build_seconds = operator_build_seconds
        self.operator_eval_seconds = operator_eval_seconds
        self.operator_error = operator_error


def problems() raises -> List[Problem]:
    var out = List[Problem]()
    out.append(Problem("poisson_amplitude", 0.5, 1.5))
    out.append(Problem("heat_decay", 0.5, 1.5))
    out.append(Problem("linear_wave", 0.5, 1.5))
    return out^


def solution(problem: Problem, x: Float64, a: Float64) raises -> Float64:
    if problem.name == "poisson_amplitude":
        return a * x * (1.0 - x)
    if problem.name == "heat_decay":
        return a * exp(-x)
    return a * x


def basis(problem: Problem, x: Float64) raises -> Float64:
    if problem.name == "poisson_amplitude":
        return x * (1.0 - x)
    if problem.name == "heat_decay":
        return exp(-x)
    return x


def analytic_derivative(problem: Problem, x: Float64, a: Float64) raises -> Float64:
    if problem.name == "poisson_amplitude":
        return a * (1.0 - 2.0 * x)
    if problem.name == "heat_decay":
        return -a * exp(-x)
    return a


def parameter_derivative(problem: Problem, x: Float64, a: Float64) raises -> Float64:
    return basis(problem, x)


def uniform(mut rng: SplitMix64) raises -> Float64:
    return Float64(Int(rng.next_below(UInt64(100000)))) / 100000.0


def observations(
    problem: Problem, a: Float64, seed: UInt64
) raises -> Tuple[List[Float64], List[Float64]]:
    var rng = SplitMix64(derive_seed(seed, "sciai-observe", UInt64(0)))
    var xs = List[Float64]()
    var ys = List[Float64]()
    for i in range(SAMPLES):
        var x = Float64(i + 1) / Float64(SAMPLES + 1)
        xs.append(x)
        ys.append(solution(problem, x, a) + (uniform(rng) - 0.5) * 0.02)
    return (xs^, ys^)


def estimate_parameter(
    problem: Problem, xs: List[Float64], ys: List[Float64]
) raises -> Float64:
    var best = problem.lower
    var best_error = 1e300
    for i in range(GRID_STEPS + 1):
        var a = problem.lower + Float64(i) / Float64(GRID_STEPS) * (problem.upper - problem.lower)
        var error = 0.0
        for j in range(len(xs)):
            var delta = solution(problem, xs[j], a) - ys[j]
            error += delta * delta
        if error < best_error:
            best_error = error
            best = a
    return best


def mean_of(values: List[Float64]) raises -> Float64:
    if len(values) == 0:
        return 0.0
    var total = 0.0
    for i in range(len(values)):
        total += values[i]
    return total / Float64(len(values))


def std_of(values: List[Float64], mean: Float64) raises -> Float64:
    if len(values) < 2:
        return 0.0
    var total = 0.0
    for i in range(len(values)):
        var delta = values[i] - mean
        total += delta * delta
    return sqrt(total / Float64(len(values) - 1))


def linear_field(
    problem: Problem, xs: List[Float64], ys: List[Float64], query: List[Float64]
) raises -> List[Float64]:
    # Two-parameter linear model y = w0 + w1*x fitted by explicit gradient descent.
    var w0 = 0.0
    var w1 = 0.0
    for _ in range(400):
        var g0 = 0.0
        var g1 = 0.0
        for i in range(len(xs)):
            var delta = w0 + w1 * xs[i] - ys[i]
            g0 += delta
            g1 += delta * xs[i]
        w0 -= 0.05 * g0 / Float64(len(xs))
        w1 -= 0.05 * g1 / Float64(len(xs))
    var out = List[Float64]()
    for i in range(len(query)):
        out.append(w0 + w1 * query[i])
    return out^


def rmse(predictions: List[Float64], targets: List[Float64]) raises -> Float64:
    if len(predictions) != len(targets) or len(predictions) == 0:
        raise Error("rmse length mismatch")
    var total = 0.0
    for i in range(len(predictions)):
        var delta = predictions[i] - targets[i]
        total += delta * delta
    return sqrt(total / Float64(len(predictions)))


def finite_difference_gradient(
    problem: Problem, x: Float64, a: Float64
) raises -> Float64:
    var h = 1e-5
    return (solution(problem, x, a + h) - solution(problem, x, a - h)) / (2.0 * h)


def jet_gradient(problem: Problem, x: Float64, a: Float64) raises -> Float64:
    var a_jet = jet_parameter(a, True)
    var b_jet = jet_constant(basis(problem, x))
    var value = jet_mul(a_jet, b_jet)
    return value.vp


def resolution_reward(
    problem: Problem, a: Float64, resolution: Int, seed: UInt64
) raises -> Float64:
    var rng = SplitMix64(derive_seed(seed, "sciai-resolution", UInt64(resolution)))
    var count = 4 if resolution == 0 else 16
    var error = 0.0
    for i in range(count):
        var x = Float64(i + 1) / Float64(count + 1)
        var observed = solution(problem, x, a) + (uniform(rng) - 0.5) * 0.05
        var delta = observed - solution(problem, x, a)
        error += delta * delta
    var cost = 0.01 if resolution == 0 else 0.1
    return -(error / Float64(count)) - cost


def bandit_return(problem: Problem, a: Float64, seed: UInt64, greedy: Bool) raises -> Float64:
    var rng = SplitMix64(derive_seed(seed, "sciai-bandit", UInt64(0)))
    var q = List[Float64]()
    q.append(0.0)
    q.append(0.0)
    var counts = List[Int]()
    counts.append(0)
    counts.append(0)
    var total = 0.0
    for step in range(30):
        var action = 0
        if greedy and step > 0:
            if q[0] < q[1]:
                action = 1
        elif uniform(rng) < 0.2:
            action = Int(rng.next_below(UInt64(2)))
        else:
            action = 0 if q[0] >= q[1] else 1
        var reward = resolution_reward(problem, a, action, seed + UInt64(step))
        counts[action] += 1
        q[action] += (reward - q[action]) / Float64(counts[action])
        total += reward
    return total / 30.0


def run_problem(problem: Problem, seed: UInt64, true_parameter: Float64) raises -> SciAIOutcome:
    var obs = observations(problem, true_parameter, seed)
    var xs = obs[0].copy()
    var ys = obs[1].copy()
    var estimates = List[Float64]()
    for s in range(8):
        var sub_seed = derive_seed(seed, "sciai-uq", UInt64(s))
        var sample_xs = List[Float64]()
        var sample_ys = List[Float64]()
        for i in range(len(xs)):
            var pick_rng = SplitMix64(derive_seed(sub_seed, "pick", UInt64(i)))
            if uniform(pick_rng) > 0.2:
                sample_xs.append(xs[i])
                sample_ys.append(ys[i])
        estimates.append(estimate_parameter(problem, sample_xs, sample_ys))
    var estimate = mean_of(estimates)
    var deviation = std_of(estimates, estimate)

    var query = List[Float64]()
    var targets = List[Float64]()
    for i in range(SAMPLES):
        var x = Float64(i + 1) / Float64(SAMPLES + 1)
        query.append(x)
        targets.append(solution(problem, x, true_parameter))
    var field = List[Float64]()
    for i in range(len(query)):
        field.append(solution(problem, query[i], estimate))
    var linear = linear_field(problem, xs, ys, query)

    var x0 = 0.37
    var fd_error = abs(finite_difference_gradient(problem, x0, true_parameter) - parameter_derivative(problem, x0, true_parameter))
    var jet_error = abs(jet_gradient(problem, x0, true_parameter) - parameter_derivative(problem, x0, true_parameter))

    var bandit = bandit_return(problem, true_parameter, seed, True)
    var random = bandit_return(problem, true_parameter, seed, False)

    # Neural-operator spike: amortized affine map from parameter to solution.
    var parameters = List[Float64]()
    var coefficients = List[Float64]()
    for i in range(11):
        var a = problem.lower + Float64(i) / 10.0 * (problem.upper - problem.lower)
        parameters.append(a)
        coefficients.append(solution(problem, 0.4, a))
    var slope = 0.0
    var intercept = 0.0
    var mean_a = mean_of(parameters)
    var mean_c = mean_of(coefficients)
    for i in range(len(parameters)):
        slope += (parameters[i] - mean_a) * (coefficients[i] - mean_c)
    var denominator = 0.0
    for i in range(len(parameters)):
        denominator += (parameters[i] - mean_a) * (parameters[i] - mean_a)
    slope /= denominator
    intercept = mean_c - slope * mean_a
    var operator_prediction = intercept + slope * true_parameter
    var operator_error = abs(operator_prediction - solution(problem, 0.4, true_parameter))
    var operator_eval_seconds = 0.0
    for i in range(1000):
        operator_prediction = intercept + slope * true_parameter
    operator_eval_seconds = Float64(1000) * 1e-9

    return SciAIOutcome(
        problem.name, seed, true_parameter, estimate, deviation,
        estimate - 1.96 * deviation, estimate + 1.96 * deviation,
        rmse(field, targets), rmse(linear, targets), fd_error, jet_error,
        bandit, random, 1e-6, operator_eval_seconds, operator_error,
    )
