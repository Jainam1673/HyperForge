"""Controlled scientific simulator for solver-selection decisions.

Condition: Poisson forcing `-u'' = k*sin(m*pi*x)` with Dirichlet boundaries.
The agent observes the frequency band m (1 or 2) and selects a mesh resolution
from a bounded safe action set. Reward combines field error and computational
cost. No real-world actions or resources are controlled.
"""

from std.math import sin, pi, sqrt
from hyperforge.core.rng import SplitMix64, derive_seed

comptime ENV_SCHEMA = "hyperforge-scirl-solver-selection-v1"
comptime COST_WEIGHT = 0.02
comptime ACTION_COUNT = 4
comptime STATE_COUNT = 2


struct StepOutcome(Copyable, Movable):
    var reward: Float64
    var error: Float64
    var cost: Float64
    var terminated: Bool

    def __init__(out self, reward: Float64, error: Float64, cost: Float64, terminated: Bool):
        self.reward = reward
        self.error = error
        self.cost = cost
        self.terminated = terminated


struct ScientificEnv(Copyable, Movable):
    var resolutions: List[Int]
    var cost_weight: Float64
    var max_steps: Int

    def __init__(out self, var resolutions: List[Int], cost_weight: Float64, max_steps: Int):
        self.resolutions = resolutions^
        self.cost_weight = cost_weight
        self.max_steps = max_steps


def default_env() raises -> ScientificEnv:
    var resolutions: List[Int] = [2, 4, 8, 16]
    return ScientificEnv(resolutions^, COST_WEIGHT, 1)


def exact_field(x: Float64, parameter: Float64, frequency: Int) raises -> Float64:
    var factor = Float64(frequency) * pi
    return parameter * sin(factor * x)


def finite_difference_field(
    parameter: Float64, frequency: Int, resolution: Int
) raises -> List[Float64]:
    var h = 1.0 / Float64(resolution + 1)
    var n = resolution
    var diagonal = List[Float64]()
    var upper = List[Float64]()
    var lower = List[Float64]()
    var right_hand = List[Float64]()
    for i in range(n):
        var x = h * Float64(i + 1)
        diagonal.append(2.0)
        upper.append(-1.0)
        lower.append(-1.0)
        var wave = Float64(frequency) * pi
        right_hand.append(parameter * wave * wave * sin(wave * x) * h * h)
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


def field_error(parameter: Float64, frequency: Int, resolution: Int) raises -> Float64:
    var solution = finite_difference_field(parameter, frequency, resolution)
    var total = Float64(0.0)
    for i in range(resolution):
        var x = Float64(i + 1) / Float64(resolution + 1)
        var delta = solution[i] - exact_field(x, parameter, frequency)
        total += delta * delta
    return sqrt(total / Float64(resolution))


def sample_condition(seed: UInt64, episode: Int, training: Bool) raises -> Tuple[Float64, Int]:
    # Both frequency bands appear in training and held-out sets; held-out
    # condition values are offset so no exact training k is reused.
    var index = episode % 100
    var parameter = 0.5 + 0.01 * Float64(index)
    if not training:
        parameter += 0.005
    var frequency = 1
    if parameter > 0.95:
        frequency = 7
    return (parameter, frequency)


def step(env: ScientificEnv, action: Int, parameter: Float64, frequency: Int, elapsed: Int) raises -> StepOutcome:
    if action < 0 or action >= len(env.resolutions):
        raise Error("invalid resolution action")
    if elapsed >= env.max_steps:
        raise Error("step after episode termination")
    var resolution = env.resolutions[action]
    var error = field_error(parameter, frequency, resolution)
    var cost = env.cost_weight * Float64(resolution) / 16.0
    return StepOutcome(-error - cost, error, cost, True)


def heuristic_action(frequency: Int) raises -> Int:
    # Domain heuristic: always use the finest affordable mesh. It is safe but
    # ignores the cost/frequency tradeoff that the learned policy can exploit.
    _ = frequency
    return 3
