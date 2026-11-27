"""Typed scientific problem registry and conventional numerical solvers.

Problem v1: 1D Poisson with an unknown forcing amplitude.

    -u''(x) = k * sin(pi*x),  u(0)=u(1)=0,  exact u(x) = (k/pi^2)*sin(pi*x)

Units are dimensionless; scaling is O(1). The physics enters explicitly through
the differential operator and Dirichlet conditions in the finite-difference
solver, not as a decorative label.
"""

from std.math import sin, pi

comptime PROBLEM_SCHEMA = "hyperforge-sciml-problem-v1"
comptime PROBLEM_NAME = "poisson_amplitude_1d"
comptime TRUE_PARAMETER = 1.0
comptime PARAMETER_LOWER = 0.5
comptime PARAMETER_UPPER = 1.5


struct ScientificProblem(Copyable, Movable):
    var name: String
    var domain: String
    var equation: String
    var boundary: String
    var units: String
    var scaling: String
    var assumptions: String
    var reference: String
    var parameter_lower: Float64
    var parameter_upper: Float64
    var true_parameter: Float64
    var evaluation_points: Int

    def __init__(
        out self,
        name: String,
        domain: String,
        equation: String,
        boundary: String,
        units: String,
        scaling: String,
        assumptions: String,
        reference: String,
        parameter_lower: Float64,
        parameter_upper: Float64,
        true_parameter: Float64,
        evaluation_points: Int,
    ):
        self.name = name
        self.domain = domain
        self.equation = equation
        self.boundary = boundary
        self.units = units
        self.scaling = scaling
        self.assumptions = assumptions
        self.reference = reference
        self.parameter_lower = parameter_lower
        self.parameter_upper = parameter_upper
        self.true_parameter = true_parameter
        self.evaluation_points = evaluation_points


def registered_problem() raises -> ScientificProblem:
    return ScientificProblem(
        PROBLEM_NAME,
        "x in [0,1] dimensionless",
        "-u''(x) = k*sin(pi*x)",
        "u(0)=u(1)=0 enforced in the discrete operator",
        "dimensionless",
        "O(1); no rescaling applied",
        "linear Poisson operator; smooth forcing; exact solution known analytically",
        "analytic solution and independent finite-difference solver",
        PARAMETER_LOWER,
        PARAMETER_UPPER,
        TRUE_PARAMETER,
        20,
    )


def exact_solution(x: Float64, parameter: Float64) raises -> Float64:
    return parameter / (pi * pi) * sin(pi * x)


def evaluation_grid(problem: ScientificProblem) raises -> List[Float64]:
    var points = List[Float64]()
    for i in range(1, problem.evaluation_points + 1):
        points.append(Float64(i) / Float64(problem.evaluation_points + 1))
    return points^


def forcing(x: Float64, parameter: Float64) raises -> Float64:
    return parameter * sin(pi * x)


def finite_difference_solution(
    problem: ScientificProblem, parameter: Float64, points: List[Float64]
) raises -> List[Float64]:
    """Thomas solve on the full interior grid, sampled at the requested points."""
    var grid = evaluation_grid(problem)
    var n = len(grid)
    if n < 2:
        raise Error("finite-difference solver needs at least two points")
    var h = grid[1] - grid[0]
    var right_hand = List[Float64]()
    for x in grid:
        right_hand.append(forcing(x, parameter) * h * h)

    var diagonal = List[Float64]()
    var upper = List[Float64]()
    var lower = List[Float64]()
    for _ in range(n):
        diagonal.append(2.0)
        upper.append(-1.0)
        lower.append(-1.0)
    for i in range(1, n):
        var factor = lower[i] / diagonal[i - 1]
        diagonal[i] -= factor * upper[i - 1]
        right_hand[i] -= factor * right_hand[i - 1]

    var solution = List[Float64]()
    for _ in range(n):
        solution.append(0.0)
    solution[n - 1] = right_hand[n - 1] / diagonal[n - 1]
    for i in range(n - 2, -1, -1):
        solution[i] = (right_hand[i] - upper[i] * solution[i + 1]) / diagonal[i]

    var sampled = List[Float64]()
    for point in points:
        var best_index = 0
        var best_distance = abs_value(grid[0] - point)
        for i in range(1, n):
            var distance = abs_value(grid[i] - point)
            if distance < best_distance:
                best_distance = distance
                best_index = i
        sampled.append(solution[best_index])
    return sampled^


def abs_value(value: Float64) raises -> Float64:
    if value < 0.0:
        return -value
    return value
