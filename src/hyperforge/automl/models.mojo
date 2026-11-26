"""Four genuinely computed regression models for the M02 slice.

All models train only on the supplied training indices and use train-fitted
standardization. Metrics are computed from predictions, never stored literals.
"""

from hyperforge.core.numeric import dot_product
from hyperforge.automl.dataset import Dataset, value_at
from hyperforge.automl.preprocess import Preprocessor, transform_row

comptime MODEL_BASELINE = "mean_baseline"
comptime MODEL_LINEAR = "linear_gd"
comptime MODEL_RIDGE = "ridge_gd"
comptime MODEL_KNN = "knn_regressor"


struct Candidate(Copyable, Movable):
    var id: String
    var kind: String
    var iterations: Int
    var regularization: Float64
    var k: Int

    def __init__(
        out self,
        id: String,
        kind: String,
        iterations: Int,
        regularization: Float64,
        k: Int,
    ):
        self.id = id
        self.kind = kind
        self.iterations = iterations
        self.regularization = regularization
        self.k = k


struct Model(Copyable, Movable):
    var kind: String
    var weights: List[Float64]
    var train_features: List[Float64]
    var train_targets: List[Float64]
    var target_mean: Float64
    var k: Int

    def __init__(
        out self,
        kind: String,
        var weights: List[Float64],
        var train_features: List[Float64],
        var train_targets: List[Float64],
        target_mean: Float64,
        k: Int,
    ):
        self.kind = kind
        self.weights = weights^
        self.train_features = train_features^
        self.train_targets = train_targets^
        self.target_mean = target_mean
        self.k = k


def fit_model(
    candidate: Candidate,
    dataset: Dataset,
    train: List[Int],
    preprocessor: Preprocessor,
) raises -> Model:
    var weights = List[Float64]()
    var train_features = List[Float64]()
    var train_targets = List[Float64]()
    var n_features = len(preprocessor.columns)

    if candidate.kind == MODEL_BASELINE:
        return Model(candidate.kind, weights^, train_features^, train_targets^, preprocessor.target_mean, 0)

    for _ in range(n_features):
        weights.append(Float64(0.0))

    if candidate.kind == MODEL_LINEAR or candidate.kind == MODEL_RIDGE:
        if candidate.iterations < 1:
            raise Error("linear model requires at least one iteration")
        var learning_rate = Float64(0.05)
        var n = Float64(len(train))
        for row in train:
            var x = transform_row(preprocessor, dataset, row)
            for value in x:
                train_features.append(value)
            train_targets.append(value_at(dataset, row, dataset.target_index) - preprocessor.target_mean)

        for _ in range(candidate.iterations):
            var gradient = List[Float64]()
            for _ in range(n_features):
                gradient.append(Float64(0.0))
            for row in train:
                var x = transform_row(preprocessor, dataset, row)
                var centered_target = value_at(dataset, row, dataset.target_index) - preprocessor.target_mean
                var error = dot_product(weights, x) - centered_target
                for j in range(n_features):
                    gradient[j] += error * x[j]
            for j in range(n_features):
                var penalty = Float64(0.0)
                if candidate.kind == MODEL_RIDGE:
                    penalty = candidate.regularization * weights[j]
                weights[j] -= learning_rate * (gradient[j] / n + penalty)
        return Model(candidate.kind, weights^, train_features^, train_targets^, preprocessor.target_mean, 0)

    if candidate.kind == MODEL_KNN:
        if candidate.k < 1:
            raise Error("kNN requires k >= 1")
        for row in train:
            var x = transform_row(preprocessor, dataset, row)
            for value in x:
                train_features.append(value)
            train_targets.append(value_at(dataset, row, dataset.target_index) - preprocessor.target_mean)
        return Model(candidate.kind, weights^, train_features^, train_targets^, preprocessor.target_mean, candidate.k)

    raise Error("unknown model kind: " + candidate.kind)


def predict(model: Model, features: List[Float64]) raises -> Float64:
    if model.kind == MODEL_BASELINE:
        return model.target_mean
    if model.kind == MODEL_LINEAR or model.kind == MODEL_RIDGE:
        return model.target_mean + dot_product(model.weights, features)

    if model.kind == MODEL_KNN:
        if len(model.train_targets) == 0:
            raise Error("kNN model has no training rows")
        var n_features = len(features)
        var neighbors = model.k
        if neighbors > len(model.train_targets):
            neighbors = len(model.train_targets)
        var best_distances = List[Float64]()
        var best_targets = List[Float64]()
        for i in range(len(model.train_targets)):
            var distance = Float64(0.0)
            for j in range(n_features):
                var delta = features[j] - model.train_features[i * n_features + j]
                distance += delta * delta
            if len(best_distances) < neighbors:
                best_distances.append(distance)
                best_targets.append(model.train_targets[i])
            else:
                var insert_at = neighbors
                for slot in range(neighbors):
                    if distance < best_distances[slot]:
                        insert_at = slot
                        break
                if insert_at < neighbors:
                    best_distances.insert(insert_at, distance)
                    best_targets.insert(insert_at, model.train_targets[i])
        var total = Float64(0.0)
        for target in best_targets:
            total += target
        return model.target_mean + total / Float64(len(best_targets))

    raise Error("unknown model kind: " + model.kind)
