"""Deterministic train/validation/test split with a recorded seed."""

from hyperforge.core.rng import SplitMix64, derive_seed

comptime SPLIT_SCHEMA = "hyperforge-split-v1"


struct SplitPlan(Copyable, Movable):
    var train: List[Int]
    var validation: List[Int]
    var test: List[Int]
    var seed: UInt64

    def __init__(
        out self,
        var train: List[Int],
        var validation: List[Int],
        var test: List[Int],
        seed: UInt64,
    ):
        self.train = train^
        self.validation = validation^
        self.test = test^
        self.seed = seed


def make_split(rows: Int, seed: UInt64) raises -> SplitPlan:
    """Shuffle indices with a derived seed, then split 60/20/20.

    The same (rows, seed) always produces the same plan. Validation is used
    only for candidate selection; test is not touched until final evaluation.
    """
    if rows < 8:
        raise Error("split requires at least 8 rows")
    var indices = List[Int]()
    for i in range(rows):
        indices.append(i)
    var rng = SplitMix64(derive_seed(seed, "split", UInt64(0)))
    for i in range(rows - 1, 0, -1):
        var j = Int(rng.next_below(UInt64(i + 1)))
        var tmp = indices[i]
        indices[i] = indices[j]
        indices[j] = tmp

    var train_size = Int(Float64(rows) * 0.6)
    var validation_size = Int(Float64(rows) * 0.2)
    if train_size < 1 or validation_size < 1 or train_size + validation_size >= rows:
        raise Error("split sizes are invalid for this row count")

    var train = List[Int]()
    var validation = List[Int]()
    var test = List[Int]()
    for i in range(rows):
        if i < train_size:
            train.append(indices[i])
        elif i < train_size + validation_size:
            validation.append(indices[i])
        else:
            test.append(indices[i])
    return SplitPlan(train^, validation^, test^, seed)
