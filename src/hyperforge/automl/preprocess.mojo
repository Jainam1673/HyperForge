"""Train-only imputation and standardization.

All statistics are fitted exclusively on training indices; validation and test
rows are only transformed. This is the leakage boundary for M02.
"""

from std.math import sqrt
from hyperforge.core.numeric import finite_mean, finite_variance
from hyperforge.automl.dataset import Dataset, value_at, is_missing_at

comptime PREPROCESS_SCHEMA = "hyperforge-preprocess-v1"


struct Preprocessor(Copyable, Movable):
    var columns: List[Int]
    var impute: List[Float64]
    var means: List[Float64]
    var stds: List[Float64]
    var target_mean: Float64

    def __init__(
        out self,
        var columns: List[Int],
        var impute: List[Float64],
        var means: List[Float64],
        var stds: List[Float64],
        target_mean: Float64,
    ):
        self.columns = columns^
        self.impute = impute^
        self.means = means^
        self.stds = stds^
        self.target_mean = target_mean


def fit_preprocessor(dataset: Dataset, train: List[Int]) raises -> Preprocessor:
    var columns = List[Int]()
    for col in range(dataset.cols):
        if col != dataset.target_index:
            columns.append(col)

    var impute = List[Float64]()
    for col in columns:
        var observed = List[Float64]()
        for row in train:
            if not is_missing_at(dataset, row, col):
                observed.append(value_at(dataset, row, col))
        if len(observed) == 0:
            impute.append(Float64(0.0))
        else:
            impute.append(finite_mean(observed))

    var means = List[Float64]()
    var stds = List[Float64]()
    for j in range(len(columns)):
        var transformed = List[Float64]()
        for row in train:
            var value = impute[j]
            if not is_missing_at(dataset, row, columns[j]):
                value = value_at(dataset, row, columns[j])
            transformed.append(value)
        var average = finite_mean(transformed)
        var variance = finite_variance(transformed, average)
        means.append(average)
        if variance <= 0.0:
            stds.append(Float64(1.0))
        else:
            stds.append(sqrt(variance))

    var targets = List[Float64]()
    for row in train:
        targets.append(value_at(dataset, row, dataset.target_index))
    return Preprocessor(
        columns^, impute^, means^, stds^, finite_mean(targets)
    )


def transform_row(preprocessor: Preprocessor, dataset: Dataset, row: Int) raises -> List[Float64]:
    var out = List[Float64]()
    for j in range(len(preprocessor.columns)):
        var value = preprocessor.impute[j]
        if not is_missing_at(dataset, row, preprocessor.columns[j]):
            value = value_at(dataset, row, preprocessor.columns[j])
        out.append((value - preprocessor.means[j]) / preprocessor.stds[j])
    return out^
