"""Task detection, k-fold validation, and deterministic full search."""

from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.automl.dataset import Dataset, value_at
from hyperforge.automl.full_models import (
    FullCandidate,
    F_BASELINE, F_LINEAR, F_RIDGE, F_LASSO, F_ELASTIC, F_HUBER,
    F_POLY, F_KNN_REG, F_TREE_REG, F_FOREST_REG, F_GB_REG,
    F_LOGISTIC, F_NB, F_KNN_CLS, F_TREE_CLS, F_FOREST_CLS,
    F_KMEANS, F_PCA,
)

comptime FULL_VALIDATION_SCHEMA = "hyperforge-automl-full-validation-v1"


def detect_classification(dataset: Dataset, rows: List[Int]) raises -> Bool:
    """A target is classification when all values are 0/1 class codes."""
    if len(rows) == 0:
        return False
    for row in rows:
        var value = value_at(dataset, row, dataset.target_index)
        if value != 0.0 and value != 1.0:
            return False
    return True


def kfold_plans(rows: Int, folds: Int, seed: UInt64) raises -> List[List[Int]]:
    if rows < 8:
        raise Error("k-fold requires at least 8 rows")
    if folds < 2 or folds > rows:
        raise Error("folds must be between 2 and row count")
    var indices = List[Int]()
    for i in range(rows):
        indices.append(i)
    var rng = SplitMix64(derive_seed(seed, "kfold", UInt64(folds)))
    for i in range(rows - 1, 0, -1):
        var j = Int(rng.next_below(UInt64(i + 1)))
        var tmp = indices[i]
        indices[i] = indices[j]
        indices[j] = tmp
    var plans = List[List[Int]]()
    var fold_size = rows // folds
    for fold in range(folds):
        var validation = List[Int]()
        var start = fold * fold_size
        var end = start + fold_size
        if fold == folds - 1:
            end = rows
        for i in range(start, end):
            validation.append(indices[i])
        plans.append(validation^)
    return plans^


def train_from_fold(rows: Int, validation: List[Int]) raises -> List[Int]:
    var train = List[Int]()
    for i in range(rows):
        var found = False
        for j in range(len(validation)):
            if validation[j] == i:
                found = True
                break
        if not found:
            train.append(i)
    return train^


def all_kinds(classification: Bool) raises -> List[String]:
    var kinds = List[String]()
    if classification:
        # Classification kinds must come first so a small budget still
        # exercises a model that emits valid class labels.
        for kind in [F_LOGISTIC, F_NB, F_KNN_CLS, F_TREE_CLS, F_FOREST_CLS]:
            kinds.append(kind)
    for kind in [
        F_BASELINE, F_LINEAR, F_RIDGE, F_LASSO, F_ELASTIC, F_HUBER,
        F_POLY, F_KNN_REG, F_TREE_REG, F_FOREST_REG, F_GB_REG,
        F_KMEANS, F_PCA,
    ]:
        kinds.append(kind)
    return kinds^


def candidate_id(seed: UInt64, index: Int, kind: String) raises -> String:
    return "full-" + hex64(fnv1a64(
        String(seed) + "|" + String(index) + "|" + kind
    ))


def make_candidates(
    seed: UInt64, budget: Int, classification: Bool
) raises -> List[FullCandidate]:
    if budget < 1:
        raise Error("budget must be positive")
    var kinds = all_kinds(classification)
    var out = List[FullCandidate]()
    # Guarantee one representative of every declared kind before repeats.
    for i in range(budget):
        var rng = SplitMix64(derive_seed(seed, "full-candidate", UInt64(i)))
        var kind = kinds[i % len(kinds)]
        var steps = 50 + Int(rng.next_below(UInt64(250)))
        var regularization = Float64(Int(rng.next_below(UInt64(10)))) / 100.0
        var k = 1 + Int(rng.next_below(UInt64(7)))
        var degree = 1 + Int(rng.next_below(UInt64(2)))
        out.append(FullCandidate(
            candidate_id(seed, i, kind), kind, steps, regularization, k, degree
        ))
    return out^


def grid_candidates(classification: Bool) raises -> List[FullCandidate]:
    """Small deterministic grid spanning all declared families."""
    var kinds = all_kinds(classification)
    var out = List[FullCandidate]()
    var steps = [50, 150, 300]
    var regularizations = [0.0, 0.01, 0.05]
    for index in range(len(kinds)):
        var kind = kinds[index]
        out.append(FullCandidate(
            "grid-" + String(index) + "-a", kind, steps[index % len(steps)],
            regularizations[index % len(regularizations)], 3, 2,
        ))
        out.append(FullCandidate(
            "grid-" + String(index) + "-b", kind, steps[(index + 1) % len(steps)],
            regularizations[(index + 1) % len(regularizations)], 5, 1,
        ))
    return out^
