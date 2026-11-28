"""Complete AutoML algorithm suite (M22 monolith).

Every model is trained only on the supplied training rows with first-party
Mojo code. No external ML library is used. The declared inventory is in
docs/engineering/EXPANSION_ROADMAP.md.
"""

from std.math import abs, sqrt, exp, log, pow
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.automl.dataset import Dataset, value_at
from hyperforge.automl.preprocess import Preprocessor, transform_row

comptime FULL_MODEL_SCHEMA = "hyperforge-automl-full-model-v1"

comptime F_BASELINE = "mean_baseline"
comptime F_LINEAR = "linear_gd"
comptime F_RIDGE = "ridge_gd"
comptime F_LASSO = "lasso_gd"
comptime F_ELASTIC = "elastic_net_gd"
comptime F_HUBER = "huber_gd"
comptime F_POLY = "polynomial_regression"
comptime F_KNN_REG = "knn_regressor"
comptime F_TREE_REG = "decision_tree_regressor"
comptime F_FOREST_REG = "random_forest_regressor"
comptime F_GB_REG = "gradient_boosting_regressor"
comptime F_LOGISTIC = "logistic_regression"
comptime F_NB = "gaussian_naive_bayes"
comptime F_KNN_CLS = "knn_classifier"
comptime F_TREE_CLS = "decision_tree_classifier"
comptime F_FOREST_CLS = "random_forest_classifier"
comptime F_KMEANS = "kmeans"
comptime F_PCA = "pca_regressor"


struct TreeNode(Copyable, Movable):
    var feature: Int
    var threshold: Float64
    var value: Float64
    var left: Int
    var right: Int
    var leaf: Bool

    def __init__(
        out self, feature: Int, threshold: Float64, value: Float64,
        left: Int, right: Int, leaf: Bool,
    ):
        self.feature = feature
        self.threshold = threshold
        self.value = value
        self.left = left
        self.right = right
        self.leaf = leaf


struct FullCandidate(Copyable, Movable):
    var id: String
    var kind: String
    var iterations: Int
    var regularization: Float64
    var k: Int
    var degree: Int

    def __init__(
        out self, id: String, kind: String, iterations: Int,
        regularization: Float64, k: Int, degree: Int,
    ):
        self.id = id
        self.kind = kind
        self.iterations = iterations
        self.regularization = regularization
        self.k = k
        self.degree = degree


struct FullModel(Copyable, Movable):
    var kind: String
    var weights: List[Float64]
    var train_features: List[Float64]
    var train_targets: List[Float64]
    var target_mean: Float64
    var k: Int
    var nodes: List[TreeNode]
    var tree_starts: List[Int]
    var centers: List[Float64]
    var classes: List[Float64]
    var class_means: List[Float64]
    var class_vars: List[Float64]
    var base_value: Float64
    var learning_rate: Float64
    var degree: Int
    var classifier: Bool

    def __init__(out self, kind: String):
        self.kind = kind
        self.weights = List[Float64]()
        self.train_features = List[Float64]()
        self.train_targets = List[Float64]()
        self.target_mean = 0.0
        self.k = 1
        self.nodes = List[TreeNode]()
        self.tree_starts = List[Int]()
        self.centers = List[Float64]()
        self.classes = List[Float64]()
        self.class_means = List[Float64]()
        self.class_vars = List[Float64]()
        self.base_value = 0.0
        self.learning_rate = 0.1
        self.degree = 1
        self.classifier = False


def is_classification_kind(kind: String) raises -> Bool:
    return (
        kind == F_LOGISTIC or kind == F_NB or kind == F_KNN_CLS
        or kind == F_TREE_CLS or kind == F_FOREST_CLS
    )


def valid_candidate(candidate: FullCandidate) raises -> Bool:
    if candidate.iterations < 0 or candidate.iterations > 2000:
        return False
    if candidate.regularization < 0.0 or candidate.regularization > 1.0:
        return False
    if candidate.k < 1 or candidate.k > 32:
        return False
    if candidate.degree < 1 or candidate.degree > 2:
        return False
    for kind in [
        F_BASELINE, F_LINEAR, F_RIDGE, F_LASSO, F_ELASTIC, F_HUBER,
        F_POLY, F_KNN_REG, F_TREE_REG, F_FOREST_REG, F_GB_REG,
        F_LOGISTIC, F_NB, F_KNN_CLS, F_TREE_CLS, F_FOREST_CLS,
        F_KMEANS, F_PCA,
    ]:
        if candidate.kind == kind:
            return True
    return False


def flatten_features(
    dataset: Dataset, train: List[Int], preprocessor: Preprocessor
) raises -> List[Float64]:
    var out = List[Float64]()
    for row in train:
        var x = transform_row(preprocessor, dataset, row)
        for value in x:
            out.append(value)
    return out^


def flatten_targets(dataset: Dataset, train: List[Int]) raises -> List[Float64]:
    var out = List[Float64]()
    for row in train:
        out.append(value_at(dataset, row, dataset.target_index))
    return out^


def mean_of(values: List[Float64]) raises -> Float64:
    if len(values) == 0:
        return 0.0
    var total = 0.0
    for i in range(len(values)):
        total += values[i]
    return total / Float64(len(values))


def sigmoid(value: Float64) raises -> Float64:
    return 1.0 / (1.0 + exp(-value))


def dot(values: List[Float64], features: List[Float64]) raises -> Float64:
    var total = 0.0
    for i in range(len(values)):
        total += values[i] * features[i]
    return total


def expand_degree2(features: List[Float64]) raises -> List[Float64]:
    var out = List[Float64]()
    for value in features:
        out.append(value)
    for value in features:
        out.append(value * value)
    for i in range(len(features)):
        for j in range(i + 1, len(features)):
            out.append(features[i] * features[j])
    return out^


def fit_linear(
    mut model: FullModel, features: List[Float64], targets: List[Float64],
    n_features: Int, iterations: Int, alpha: Float64, kind: String,
) raises -> None:
    var n = Float64(len(targets))
    if n < 1.0:
        raise Error("linear fit requires training rows")
    for _ in range(n_features):
        model.weights.append(0.0)
    for _ in range(iterations):
        for j in range(n_features):
            var gradient = 0.0
            for i in range(len(targets)):
                var prediction = dot(model.weights, slice_features(features, i, n_features))
                var residual = prediction - targets[i]
                if kind == F_HUBER and abs(residual) > alpha:
                    residual = alpha * (1.0 if residual > 0.0 else -1.0)
                gradient += residual * features[i * n_features + j]
            gradient /= n
            if kind == F_RIDGE:
                gradient += alpha * model.weights[j]
            elif kind == F_LASSO:
                gradient += alpha * (1.0 if model.weights[j] > 0.0 else -1.0)
            elif kind == F_ELASTIC:
                gradient += alpha * (
                    0.5 * (1.0 if model.weights[j] > 0.0 else -1.0)
                    + 0.5 * model.weights[j]
                )
            model.weights[j] -= 0.05 * gradient


def slice_features(
    features: List[Float64], row: Int, n_features: Int
) raises -> List[Float64]:
    var out = List[Float64]()
    for j in range(n_features):
        out.append(features[row * n_features + j])
    return out^


def fit_logistic(
    mut model: FullModel, features: List[Float64], targets: List[Float64],
    n_features: Int, iterations: Int,
) raises -> None:
    var n = Float64(len(targets))
    if n < 1.0:
        raise Error("logistic fit requires training rows")
    for _ in range(n_features):
        model.weights.append(0.0)
    for _ in range(iterations):
        for j in range(n_features):
            var gradient = 0.0
            for i in range(len(targets)):
                var prediction = sigmoid(dot(model.weights, slice_features(features, i, n_features)))
                gradient += (prediction - targets[i]) * features[i * n_features + j]
            model.weights[j] -= 0.05 * gradient / n


def node_mean(targets: List[Float64], indices: List[Int]) raises -> Float64:
    if len(indices) == 0:
        return 0.0
    var total = 0.0
    for i in range(len(indices)):
        total += targets[indices[i]]
    return total / Float64(len(indices))


def build_tree(
    mut nodes: List[TreeNode], features: List[Float64], targets: List[Float64],
    indices: List[Int], n_features: Int, depth: Int, max_depth: Int,
) raises -> Int:
    var index = len(nodes)
    var value = node_mean(targets, indices)
    nodes.append(TreeNode(-1, 0.0, value, -1, -1, True))

    if depth >= max_depth or len(indices) < 2:
        return index
    var first = targets[indices[0]]
    var pure = True
    for i in range(1, len(indices)):
        if targets[indices[i]] != first:
            pure = False
            break
    if pure:
        return index

    var best_gain = 0.0
    var best_feature = -1
    var best_threshold = 0.0
    for j in range(n_features):
        var threshold = 0.0
        for i in range(len(indices)):
            threshold += features[indices[i] * n_features + j]
        threshold /= Float64(len(indices))
        var left_sum = 0.0
        var left_sq = 0.0
        var right_sum = 0.0
        var right_sq = 0.0
        var left_count = 0
        var right_count = 0
        for i in range(len(indices)):
            var row = indices[i]
            var target = targets[row]
            if features[row * n_features + j] <= threshold:
                left_sum += target
                left_sq += target * target
                left_count += 1
            else:
                right_sum += target
                right_sq += target * target
                right_count += 1
        if left_count == 0 or right_count == 0:
            continue
        var impurity = 0.0
        if left_count > 0:
            impurity += left_sq - left_sum * left_sum / Float64(left_count)
        if right_count > 0:
            impurity += right_sq - right_sum * right_sum / Float64(right_count)
        var total_sq = 0.0
        var total_sum = 0.0
        for i in range(len(indices)):
            total_sq += targets[indices[i]] * targets[indices[i]]
            total_sum += targets[indices[i]]
        var before = total_sq - total_sum * total_sum / Float64(len(indices))
        var gain = before - impurity
        if gain > best_gain:
            best_gain = gain
            best_feature = j
            best_threshold = threshold

    if best_feature < 0:
        return index

    var left_indices = List[Int]()
    var right_indices = List[Int]()
    for i in range(len(indices)):
        var row = indices[i]
        if features[row * n_features + best_feature] <= best_threshold:
            left_indices.append(row)
        else:
            right_indices.append(row)

    var left = build_tree(
        nodes, features, targets, left_indices, n_features, depth + 1, max_depth
    )
    var right = build_tree(
        nodes, features, targets, right_indices, n_features, depth + 1, max_depth
    )
    nodes[index].feature = best_feature
    nodes[index].threshold = best_threshold
    nodes[index].left = left
    nodes[index].right = right
    nodes[index].leaf = False
    return index


def tree_predict(
    model: FullModel, start: Int, features: List[Float64], n_features: Int
) raises -> Float64:
    var index = start
    var guard = 0
    while guard < 1024:
        ref node = model.nodes[index]
        if node.leaf:
            return node.value
        if features[node.feature] <= node.threshold:
            index = node.left
        else:
            index = node.right
        guard += 1
    raise Error("tree traversal exceeded depth limit")


def ensemble_predict(
    model: FullModel, features: List[Float64], n_features: Int, boosting: Bool
) raises -> Float64:
    var total = 0.0
    for i in range(len(model.tree_starts)):
        total += tree_predict(model, model.tree_starts[i], features, n_features)
    if boosting:
        return model.base_value + model.learning_rate * total
    return total / Float64(len(model.tree_starts))


def fit_naive_bayes(
    mut model: FullModel, features: List[Float64], targets: List[Float64],
    n_features: Int,
) raises -> None:
    for i in range(len(targets)):
        var found = False
        for j in range(len(model.classes)):
            if model.classes[j] == targets[i]:
                found = True
                break
        if not found:
            model.classes.append(targets[i])
    for c in range(len(model.classes)):
        var count = 0
        var sums = List[Float64]()
        for _ in range(n_features):
            sums.append(0.0)
        for i in range(len(targets)):
            if targets[i] == model.classes[c]:
                count += 1
                for j in range(n_features):
                    sums[j] += features[i * n_features + j]
        var means = List[Float64]()
        for j in range(n_features):
            means.append(sums[j] / Float64(count) if count > 0 else 0.0)
        var variances = List[Float64]()
        for j in range(n_features):
            var accum = 0.0
            for i in range(len(targets)):
                if targets[i] == model.classes[c]:
                    var delta = features[i * n_features + j] - means[j]
                    accum += delta * delta
            variances.append(accum / Float64(count) if count > 0 else 1.0)
            if variances[j] < 1e-9:
                variances[j] = 1e-9
        for value in means:
            model.class_means.append(value)
        for value in variances:
            model.class_vars.append(value)


def fit_model_full(
    candidate: FullCandidate,
    dataset: Dataset,
    train: List[Int],
    preprocessor: Preprocessor,
    seed: UInt64,
) raises -> FullModel:
    if not valid_candidate(candidate):
        raise Error("invalid full AutoML candidate")
    var model = FullModel(candidate.kind)
    model.classifier = is_classification_kind(candidate.kind)
    model.k = candidate.k
    model.degree = candidate.degree
    model.learning_rate = 0.1 if candidate.regularization == 0.0 else candidate.regularization

    var raw_features = flatten_features(dataset, train, preprocessor)
    var raw_targets = flatten_targets(dataset, train)
    var n_raw = len(preprocessor.columns)
    if n_raw < 1:
        raise Error("dataset has no features")

    var features = raw_features.copy()
    var n_features = n_raw
    if candidate.kind == F_POLY:
        features = List[Float64]()
        var expanded_width = 0
        for i in range(len(raw_targets)):
            var expanded = expand_degree2(slice_features(raw_features, i, n_raw))
            expanded_width = len(expanded)
            for value in expanded:
                features.append(value)
        n_features = expanded_width
    elif candidate.kind == F_PCA:
        # Power iteration for the leading principal direction.
        var direction = List[Float64]()
        for _ in range(n_raw):
            direction.append(0.5)
        for _ in range(candidate.iterations if candidate.iterations > 0 else 20):
            var projected = List[Float64]()
            var norm = 0.0
            for i in range(len(raw_targets)):
                var value = dot(direction, slice_features(raw_features, i, n_raw))
                projected.append(value)
                norm += value * value
            norm = sqrt(norm)
            if norm < 1e-12:
                break
            var next_dir = List[Float64]()
            for j in range(n_raw):
                var accum = 0.0
                for i in range(len(raw_targets)):
                    accum += raw_features[i * n_raw + j] * projected[i]
                next_dir.append(accum / norm)
            direction = next_dir^
        features = List[Float64]()
        for i in range(len(raw_targets)):
            features.append(dot(direction, slice_features(raw_features, i, n_raw)))
        n_features = 1

    model.train_features = features.copy()
    model.train_targets = raw_targets.copy()

    if candidate.kind == F_BASELINE:
        model.target_mean = mean_of(raw_targets)
        return model^

    if candidate.kind == F_LINEAR or candidate.kind == F_RIDGE:
        model.target_mean = mean_of(raw_targets)
        var centered = List[Float64]()
        for value in raw_targets:
            centered.append(value - model.target_mean)
        fit_linear(model, features, centered, n_features, candidate.iterations, candidate.regularization, candidate.kind)
        return model^

    if candidate.kind == F_LASSO or candidate.kind == F_ELASTIC or candidate.kind == F_HUBER:
        model.target_mean = mean_of(raw_targets)
        var centered = List[Float64]()
        for value in raw_targets:
            centered.append(value - model.target_mean)
        var alpha = 0.01 if candidate.regularization == 0.0 else candidate.regularization
        fit_linear(model, features, centered, n_features, candidate.iterations, alpha, candidate.kind)
        return model^

    if candidate.kind == F_POLY or candidate.kind == F_PCA:
        model.target_mean = mean_of(raw_targets)
        var centered = List[Float64]()
        for value in raw_targets:
            centered.append(value - model.target_mean)
        fit_linear(model, features, centered, n_features, candidate.iterations, 0.0, F_LINEAR)
        return model^

    if candidate.kind == F_KNN_REG or candidate.kind == F_KNN_CLS:
        return model^

    if candidate.kind == F_LOGISTIC:
        fit_logistic(model, features, raw_targets, n_features, candidate.iterations)
        return model^

    if candidate.kind == F_NB:
        fit_naive_bayes(model, features, raw_targets, n_features)
        return model^

    if candidate.kind == F_KMEANS:
        model.centers = List[Float64]()
        var rng = SplitMix64(derive_seed(seed, "kmeans", UInt64(candidate.k)))
        for _ in range(candidate.k):
            var row = Int(rng.next_below(UInt64(len(raw_targets))))
            var center = slice_features(raw_features, row, n_raw)
            for value in center:
                model.centers.append(value)
        for _ in range(candidate.iterations if candidate.iterations > 0 else 20):
            var sums = List[Float64]()
            var counts = List[Int]()
            for _ in range(candidate.k):
                counts.append(0)
                for _ in range(n_raw):
                    sums.append(0.0)
            for i in range(len(raw_targets)):
                var x = slice_features(raw_features, i, n_raw)
                var best = 0
                var best_distance = 1e300
                for cluster in range(candidate.k):
                    var distance = 0.0
                    for j in range(n_raw):
                        var delta = x[j] - model.centers[cluster * n_raw + j]
                        distance += delta * delta
                    if distance < best_distance:
                        best_distance = distance
                        best = cluster
                counts[best] += 1
                for j in range(n_raw):
                    sums[best * n_raw + j] += x[j]
            for cluster in range(candidate.k):
                if counts[cluster] > 0:
                    for j in range(n_raw):
                        model.centers[cluster * n_raw + j] = sums[cluster * n_raw + j] / Float64(counts[cluster])
        return model^

    if (
        candidate.kind == F_TREE_REG or candidate.kind == F_TREE_CLS
        or candidate.kind == F_FOREST_REG or candidate.kind == F_FOREST_CLS
        or candidate.kind == F_GB_REG
    ):
        var indices = List[Int]()
        for i in range(len(raw_targets)):
            indices.append(i)
        var max_depth = candidate.k if candidate.kind != F_GB_REG else 3
        if max_depth < 1:
            max_depth = 3
        var trees = candidate.iterations if candidate.kind != F_TREE_REG and candidate.kind != F_TREE_CLS else 1
        if trees < 1:
            trees = 1
        if trees > 64:
            trees = 64

        if candidate.kind == F_GB_REG:
            model.base_value = mean_of(raw_targets)
            var residuals = List[Float64]()
            for value in raw_targets:
                residuals.append(value - model.base_value)
            for _ in range(trees):
                var start = len(model.nodes)
                model.tree_starts.append(start)
                var root = build_tree(model.nodes, features, residuals, indices, n_features, 0, max_depth)
                _ = root
                for i in range(len(residuals)):
                    residuals[i] -= model.learning_rate * tree_predict(model, start, slice_features(features, i, n_features), n_features)
        else:
            var rng = SplitMix64(derive_seed(seed, "tree-" + candidate.kind, UInt64(trees)))
            for _ in range(trees):
                var start = len(model.nodes)
                model.tree_starts.append(start)
                var sample = List[Int]()
                if candidate.kind == F_FOREST_REG or candidate.kind == F_FOREST_CLS:
                    for _ in range(len(indices)):
                        sample.append(indices[Int(rng.next_below(UInt64(len(indices))))])
                else:
                    for i in range(len(indices)):
                        sample.append(indices[i])
                var root = build_tree(model.nodes, features, raw_targets, sample, n_features, 0, max_depth)
                _ = root
        return model^

    raise Error("unknown full model kind: " + candidate.kind)


def predict_full(model: FullModel, features: List[Float64]) raises -> Float64:
    if model.kind == F_BASELINE:
        return model.target_mean
    if (
        model.kind == F_LINEAR or model.kind == F_RIDGE or model.kind == F_LASSO
        or model.kind == F_ELASTIC or model.kind == F_HUBER
        or model.kind == F_POLY or model.kind == F_PCA
    ):
        var x = features.copy()
        if model.kind == F_POLY:
            x = expand_degree2(features)
        return model.target_mean + dot(model.weights, x)

    if model.kind == F_KNN_REG or model.kind == F_KNN_CLS:
        if len(model.train_targets) == 0:
            raise Error("kNN model has no training rows")
        var n_features = len(features)
        var neighbors = model.k
        if neighbors > len(model.train_targets):
            neighbors = len(model.train_targets)
        var distances = List[Float64]()
        var targets = List[Float64]()
        for i in range(len(model.train_targets)):
            var distance = 0.0
            for j in range(n_features):
                var delta = features[j] - model.train_features[i * n_features + j]
                distance += delta * delta
            distances.append(distance)
            targets.append(model.train_targets[i])
        for i in range(len(distances)):
            for j in range(i + 1, len(distances)):
                if distances[j] < distances[i]:
                    var tmp_d = distances[i]
                    distances[i] = distances[j]
                    distances[j] = tmp_d
                    var tmp_t = targets[i]
                    targets[i] = targets[j]
                    targets[j] = tmp_t
        var total = 0.0
        for i in range(neighbors):
            total += targets[i]
        return total / Float64(neighbors)

    if model.kind == F_LOGISTIC:
        return sigmoid(dot(model.weights, features))

    if model.kind == F_NB:
        if len(model.classes) == 0:
            raise Error("naive Bayes model has no classes")
        var best_class = model.classes[0]
        var best_score = -1e300
        var n_features = len(features)
        for c in range(len(model.classes)):
            var score = 0.0
            for j in range(n_features):
                var mean = model.class_means[c * n_features + j]
                var variance = model.class_vars[c * n_features + j]
                var delta = features[j] - mean
                score -= 0.5 * log(variance) - delta * delta / (2.0 * variance)
            if score > best_score:
                best_score = score
                best_class = model.classes[c]
        return best_class

    if model.kind == F_KMEANS:
        if len(model.centers) == 0:
            raise Error("k-means model has no centers")
        var n_features = len(features)
        var best = 0
        var best_distance = 1e300
        for cluster in range(model.k):
            var distance = 0.0
            for j in range(n_features):
                var delta = features[j] - model.centers[cluster * n_features + j]
                distance += delta * delta
            if distance < best_distance:
                best_distance = distance
                best = cluster
        return Float64(best)

    if (
        model.kind == F_TREE_REG or model.kind == F_TREE_CLS
        or model.kind == F_FOREST_REG or model.kind == F_FOREST_CLS
        or model.kind == F_GB_REG
    ):
        var n_features = len(features)
        if model.kind == F_POLY:
            n_features = len(features)
        return ensemble_predict(model, features, n_features, model.kind == F_GB_REG)

    raise Error("unknown full model kind: " + model.kind)


def predict_label(model: FullModel, features: List[Float64]) raises -> Float64:
    var value = predict_full(model, features)
    return 1.0 if value >= 0.5 else 0.0
