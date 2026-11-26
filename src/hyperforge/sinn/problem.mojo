"""Typed 1D Poisson benchmark: -u'' = 2 on [0,1], u(0)=u(1)=0.

Exact solution u(x)=x(1-x). An independent finite-difference solver provides a
conventional numerical reference on the same grid used for held-out evaluation.
"""

from hyperforge.core.rng import SplitMix64, derive_seed

comptime PROBLEM_SCHEMA = "hyperforge-sinn-problem-v1"
comptime PROBLEM_POISSON_1D = "poisson_1d"


struct PoissonProblem(Copyable, Movable):
    var name: String
    var left: Float64
    var right: Float64
    var forcing_value: Float64
    var collocation_count: Int
    var validation_count: Int
    var seed: UInt64

    def __init__(
        out self,
        name: String,
        left: Float64,
        right: Float64,
        forcing_value: Float64,
        collocation_count: Int,
        validation_count: Int,
        seed: UInt64,
    ):
        self.name = name
        self.left = left
        self.right = right
        self.forcing_value = forcing_value
        self.collocation_count = collocation_count
        self.validation_count = validation_count
        self.seed = seed


def poisson_1d(seed: UInt64) raises -> PoissonProblem:
    return PoissonProblem(
        PROBLEM_POISSON_1D, 0.0, 1.0, 2.0, 24, 15, seed
    )


def exact_solution(x: Float64) raises -> Float64:
    return x * (1.0 - x)


def forcing(x: Float64) raises -> Float64:
    return 2.0


def collocation_points(problem: PoissonProblem) raises -> List[Float64]:
    var rng = SplitMix64(derive_seed(problem.seed, "sinn-collocation", UInt64(0)))
    var points = List[Float64]()
    for _ in range(problem.collocation_count):
        var unit = Float64(rng.next_below(UInt64(100000))) / 100000.0
        points.append(problem.left + (problem.right - problem.left) * unit)
    return points^


def validation_points(problem: PoissonProblem) raises -> List[Float64]:
    var points = List[Float64]()
    for i in range(1, problem.validation_count + 1):
        var x = problem.left + (problem.right - problem.left) * Float64(i) / Float64(problem.validation_count + 1)
        points.append(x)
    return points^


def finite_difference_solution(problem: PoissonProblem, points: List[Float64]) raises -> List[Float64]:
    """Thomas solve of the tridiagonal system for -u'' = forcing on a grid."""
    var n = len(points)
    if n < 2:
        raise Error("finite difference solver needs at least two interior points")
    var h = points[1] - points[0]
    var rhs = problem.forcing_value * h * h
    var diagonal = List[Float64]()
    var lower = List[Float64]()
    var upper = List[Float64]()
    var right_hand = List[Float64]()
    for _ in range(n):
        diagonal.append(2.0)
        lower.append(-1.0)
        upper.append(-1.0)
        right_hand.append(rhs)

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
    return solution^
