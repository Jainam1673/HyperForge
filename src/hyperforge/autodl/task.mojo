"""Deterministic synthetic binary classification task for AutoDL.

Two concentric regions in [0,1]^2: label 1 inside a circle, 0 outside. The
generator is analytic and explicitly labeled synthetic. Train/validation/test
splits are seed-derived and fixed for every candidate in a run, so held-out
test data never influences training or early stopping.
"""

from std.math import sqrt
from hyperforge.core.rng import SplitMix64, derive_seed

comptime TASK_SCHEMA = "hyperforge-autodl-task-v1"
comptime TASK_NAME = "concentric_circles_2d"
comptime FEATURE_COUNT = 2
comptime TOTAL_SAMPLES = 120
comptime TRAIN_COUNT = 72
comptime VALIDATION_COUNT = 24
comptime TEST_COUNT = 24


struct AutoDLTask(Copyable, Movable):
    var name: String
    var features: List[List[Float64]]
    var labels: List[Int]
    var train: List[Int]
    var validation: List[Int]
    var test: List[Int]
    var seed: UInt64

    def __init__(
        out self,
        name: String,
        var features: List[List[Float64]],
        var labels: List[Int],
        var train: List[Int],
        var validation: List[Int],
        var test: List[Int],
        seed: UInt64,
    ):
        self.name = name
        self.features = features^
        self.labels = labels^
        self.train = train^
        self.validation = validation^
        self.test = test^
        self.seed = seed


def make_task(seed: UInt64) raises -> AutoDLTask:
    var feature_rng = SplitMix64(derive_seed(seed, "autodl-features", UInt64(0)))
    var features = List[List[Float64]]()
    var labels = List[Int]()
    for _ in range(TOTAL_SAMPLES):
        var x1 = Float64(feature_rng.next_below(UInt64(10000))) / 10000.0
        var x2 = Float64(feature_rng.next_below(UInt64(10000))) / 10000.0
        var dx = x1 - 0.5
        var dy = x2 - 0.5
        var radius = sqrt(dx * dx + dy * dy)
        var row = List[Float64]()
        row.append(x1)
        row.append(x2)
        features.append(row^)
        labels.append(1 if radius < 0.22 else 0)

    var order = List[Int]()
    for i in range(TOTAL_SAMPLES):
        order.append(i)
    var shuffle_rng = SplitMix64(derive_seed(seed, "autodl-split", UInt64(0)))
    for i in range(TOTAL_SAMPLES - 1, 0, -1):
        var j = Int(shuffle_rng.next_below(UInt64(i + 1)))
        var tmp = order[i]
        order[i] = order[j]
        order[j] = tmp

    var train = List[Int]()
    var validation = List[Int]()
    var test = List[Int]()
    for i in range(TOTAL_SAMPLES):
        if i < TRAIN_COUNT:
            train.append(order[i])
        elif i < TRAIN_COUNT + VALIDATION_COUNT:
            validation.append(order[i])
        else:
            test.append(order[i])
    return AutoDLTask(
        TASK_NAME, features^, labels^, train^, validation^, test^, seed
    )
