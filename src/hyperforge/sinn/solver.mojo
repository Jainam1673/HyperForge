"""Training and evaluation for the 1D Poisson SINN slice."""

from std.math import sqrt, pow, abs
from std.time import perf_counter
from hyperforge.sinn.jet import x_variable
from hyperforge.sinn.network import (
    SmallNet,
    init_network,
    forward,
    forward_jet,
    get_param,
    set_param,
    param_count,
)
from hyperforge.sinn.problem import (
    PoissonProblem,
    collocation_points,
    validation_points,
    exact_solution,
    forcing,
    finite_difference_solution,
)

comptime HIDDEN_WIDTH = 4
comptime LEARNING_RATE = 0.01
comptime BETA1 = 0.9
comptime BETA2 = 0.999
comptime ADAM_EPS = 1e-8
comptime CONVERGED_LOSS = 0.05
comptime CONVERGED_EXACT_L2 = 0.05


struct SinnOutcome(Copyable, Movable):
    var problem: String
    var seed: UInt64
    var iterations: Int
    var initial_loss: Float64
    var final_loss: Float64
    var residual_rmse: Float64
    var boundary_abs: Float64
    var exact_l2: Float64
    var fd_l2: Float64
    var state: String
    var detail: String
    var runtime_seconds: Float64

    def __init__(
        out self,
        problem: String,
        seed: UInt64,
        iterations: Int,
        initial_loss: Float64,
        final_loss: Float64,
        residual_rmse: Float64,
        boundary_abs: Float64,
        exact_l2: Float64,
        fd_l2: Float64,
        state: String,
        detail: String,
        runtime_seconds: Float64,
    ):
        self.problem = problem
        self.seed = seed
        self.iterations = iterations
        self.initial_loss = initial_loss
        self.final_loss = final_loss
        self.residual_rmse = residual_rmse
        self.boundary_abs = boundary_abs
        self.exact_l2 = exact_l2
        self.fd_l2 = fd_l2
        self.state = state
        self.detail = detail
        self.runtime_seconds = runtime_seconds


def mean_of(values: List[Float64]) raises -> Float64:
    if len(values) == 0:
        raise Error("empty mean")
    var total = Float64(0.0)
    for value in values:
        total += value
    return total / Float64(len(values))


def squared_mean(values: List[Float64]) raises -> Float64:
    if len(values) == 0:
        raise Error("empty squared mean")
    var total = Float64(0.0)
    for value in values:
        total += value * value
    return sqrt(total / Float64(len(values)))


def residual_at(net: SmallNet, x: Float64, source: Float64) raises -> Float64:
    var jet = forward_jet(net, x_variable(x), -1)
    return -jet.vxx - source


def evaluate(
    net: SmallNet, problem: PoissonProblem, final_loss: Float64, iterations: Int,
    initial_loss: Float64, elapsed: Float64, state_override: String,
) raises -> SinnOutcome:
    var points = validation_points(problem)
    var residual_values = List[Float64]()
    var errors_exact = List[Float64]()
    var errors_fd = List[Float64]()
    var fd = finite_difference_solution(problem, points)

    for i in range(len(points)):
        var x = points[i]
        var prediction = forward(net, x)
        residual_values.append(residual_at(net, x, forcing(x)))
        errors_exact.append(prediction - exact_solution(x))
        errors_fd.append(prediction - fd[i])

    var boundary_error: Float64
    var left_value = forward(net, problem.left)
    var right_value = forward(net, problem.right)
    boundary_error = abs(left_value)
    var right_abs = abs(right_value)
    if right_abs > boundary_error:
        boundary_error = right_abs

    var exact_l2 = squared_mean(errors_exact)
    var state = String("POOR_FIT")
    var detail = String("loss did not reach the declared convergence threshold")
    if state_override != "":
        state = "DIVERGED"
        detail = "non-finite gradient; training rejected"
    elif final_loss < CONVERGED_LOSS and exact_l2 < CONVERGED_EXACT_L2:
        state = "CONVERGED"
        detail = "residual and held-out error below declared thresholds"
    elif final_loss > initial_loss:
        state = "DIVERGED"
        detail = "training loss increased"
    return SinnOutcome(
        problem.name, problem.seed, iterations, initial_loss, final_loss,
        squared_mean(residual_values), boundary_error, exact_l2,
        squared_mean(errors_fd), state, detail, elapsed,
    )


def train(
    problem: PoissonProblem, seed: UInt64, iterations: Int,
    learning_rate: Float64 = LEARNING_RATE,
) raises -> Tuple[SmallNet, SinnOutcome]:
    if iterations < 1:
        raise Error("iterations must be positive")
    var net = init_network(seed, HIDDEN_WIDTH)
    var points = collocation_points(problem)
    var count = len(points)
    var parameters = param_count(net)
    var momentum = List[Float64]()
    var velocity = List[Float64]()
    var gradients = List[Float64]()
    for _ in range(parameters):
        momentum.append(0.0)
        velocity.append(0.0)
        gradients.append(0.0)

    var started = perf_counter()
    var initial_loss = Float64(0.0)
    var loss = Float64(0.0)
    var rejected = String("")

    for iteration in range(iterations):
        loss = 0.0
        for p in range(parameters):
            gradients[p] = 0.0
        for x in points:
            var source = forcing(x)
            var base = forward_jet(net, x_variable(x), 0)
            var residual = -base.vxx - source
            loss += residual * residual
            for p in range(parameters):
                var jet = forward_jet(net, x_variable(x), p)
                var derivative = -jet.vxxp
                gradients[p] += 2.0 * residual * derivative / Float64(count)
        loss /= Float64(count)
        if iteration == 0:
            initial_loss = loss

        var non_finite = False
        for p in range(parameters):
            if gradients[p] != gradients[p]:
                non_finite = True
        if non_finite:
            rejected = "NON_FINITE"
            break

        var progress = Float64(iteration + 1)
        var correction1 = 1.0 - pow(BETA1, progress)
        var correction2 = 1.0 - pow(BETA2, progress)
        for p in range(parameters):
            var gradient = gradients[p]
            momentum[p] = BETA1 * momentum[p] + (1.0 - BETA1) * gradient
            velocity[p] = BETA2 * velocity[p] + (1.0 - BETA2) * gradient * gradient
            var mhat = momentum[p] / correction1
            var vhat = velocity[p] / correction2
            var updated = get_param(net, p) - learning_rate * mhat / (sqrt(vhat) + ADAM_EPS)
            set_param(net, p, updated)

    var elapsed = perf_counter() - started
    var outcome = evaluate(net, problem, loss, iterations, initial_loss, elapsed, rejected)
    return (net^, outcome^)
