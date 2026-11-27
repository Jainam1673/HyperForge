"""Supervised scientific field dataset for SciDL.

Task: predict the solution field u(x;k) of 1D Poisson from (x, k) pairs. This is
supervised data-driven regression on a grid/field representation. It is not a
physics-informed residual method (SINN) and not an operator learner: it is a
single-parameter family with finite grid outputs.
"""

from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.sciml.problem import exact_solution

comptime TASK_SCHEMA = "hyperforge-scidl-field-v1"
comptime GRID_POINTS = 8
comptime TRAIN_PARAMETERS = 12
comptime TEST_PARAMETERS = 8


struct SciDLTask(Copyable, Movable):
    var name: String
    var grid: List[Float64]
    var train_parameters: List[Float64]
    var test_parameters: List[Float64]
    var seed: UInt64

    def __init__(
        out self,
        name: String,
        var grid: List[Float64],
        var train_parameters: List[Float64],
        var test_parameters: List[Float64],
        seed: UInt64,
    ):
        self.name = name
        self.grid = grid^
        self.train_parameters = train_parameters^
        self.test_parameters = test_parameters^
        self.seed = seed


def make_task(seed: UInt64) raises -> SciDLTask:
    var grid = List[Float64]()
    for i in range(GRID_POINTS):
        grid.append(Float64(i + 1) / Float64(GRID_POINTS + 1))
    var train = List[Float64]()
    var test = List[Float64]()
    # Disjoint physical-parameter ranges: train on lower k, test on higher k.
    for i in range(TRAIN_PARAMETERS):
        train.append(0.5 + 0.5 * Float64(i) / Float64(TRAIN_PARAMETERS - 1))
    for i in range(TEST_PARAMETERS):
        test.append(1.05 + 0.45 * Float64(i) / Float64(TEST_PARAMETERS - 1))
    # Deterministic shuffle confirms reproducibility without mixing ranges.
    var rng = SplitMix64(derive_seed(seed, "scidl-task", UInt64(0)))
    for _ in range(TRAIN_PARAMETERS):
        _ = rng.next_below(UInt64(1000))
    return SciDLTask("poisson_field_supervised", grid^, train^, test^, seed)


def features(grid_x: Float64, parameter: Float64) raises -> List[Float64]:
    var out = List[Float64]()
    out.append(2.0 * grid_x - 1.0)
    out.append((parameter - 1.0) / 0.5)
    return out^


def target(grid_x: Float64, parameter: Float64) raises -> Float64:
    return exact_solution(grid_x, parameter)
