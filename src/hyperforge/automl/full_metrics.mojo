"""Complete AutoML metric suite with explicit edge-case behavior."""

from std.math import abs, log, sqrt

comptime FULL_METRICS_SCHEMA = "hyperforge-automl-full-metrics-v1"


struct FullMetrics(Copyable, Movable):
    var count: Int
    var mae: Float64
    var mse: Float64
    var rmse: Float64
    var r2: Float64
    var mape: Float64
    var accuracy: Float64
    var precision: Float64
    var recall: Float64
    var f1: Float64
    var log_loss: Float64
    var auc: Float64
    var confusion: List[Int]

    def __init__(out self, count: Int):
        self.count = count
        self.mae = 0.0
        self.mse = 0.0
        self.rmse = 0.0
        self.r2 = 0.0
        self.mape = 0.0
        self.accuracy = 0.0
        self.precision = 0.0
        self.recall = 0.0
        self.f1 = 0.0
        self.log_loss = 0.0
        self.auc = 0.0
        self.confusion = List[Int]()
        for _ in range(4):
            self.confusion.append(0)


def clamp_probability(value: Float64) raises -> Float64:
    var low = 1e-12
    var high = 1.0 - low
    if value < low:
        return low
    if value > high:
        return high
    return value


def compute_full_metrics(
    predictions: List[Float64],
    actuals: List[Float64],
    classification: Bool,
) raises -> FullMetrics:
    if len(predictions) != len(actuals):
        raise Error("metrics length mismatch")
    if len(predictions) == 0:
        raise Error("metrics require at least one observation")

    var metrics = FullMetrics(len(predictions))
    var absolute_error = 0.0
    var squared_error = 0.0
    var total_variance = 0.0
    var average = 0.0
    for i in range(len(actuals)):
        average += actuals[i]
    average /= Float64(len(actuals))
    var percent_error = 0.0
    var percent_count = 0

    for i in range(len(predictions)):
        var prediction = predictions[i]
        var actual = actuals[i]
        if prediction != prediction or actual != actual:
            raise Error("non-finite value in metrics")
        var delta = actual - prediction
        absolute_error += abs(delta)
        squared_error += delta * delta
        total_variance += (actual - average) * (actual - average)
        if actual != 0.0:
            percent_error += abs(delta / actual)
            percent_count += 1

    var n = Float64(len(predictions))
    var count_int = len(predictions)
    metrics.mae = absolute_error / n
    metrics.mse = squared_error / n
    metrics.rmse = sqrt(metrics.mse)
    if total_variance > 0.0:
        metrics.r2 = 1.0 - squared_error / total_variance
    if percent_count > 0:
        metrics.mape = percent_error / Float64(percent_count)

    if classification:
        var true_positive = 0
        var false_positive = 0
        var true_negative = 0
        var false_negative = 0
        var correct = 0
        var loss = 0.0
        # Ranking pairs for AUC; ties count as 0.5.
        var concordant = 0.0
        var pairs = 0
        for i in range(count_int):
            var predicted_label = 1 if predictions[i] >= 0.5 else 0
            var actual_label = 1 if actuals[i] >= 0.5 else 0
            if predicted_label == actual_label:
                correct += 1
            if predicted_label == 1 and actual_label == 1:
                true_positive += 1
            elif predicted_label == 1 and actual_label == 0:
                false_positive += 1
            elif predicted_label == 0 and actual_label == 0:
                true_negative += 1
            else:
                false_negative += 1
            var probability = clamp_probability(predictions[i])
            if actual_label == 1:
                loss -= log(probability)
            else:
                loss -= log(1.0 - probability)
            for j in range(i + 1, count_int):
                var other_actual = 1 if actuals[j] >= 0.5 else 0
                if actual_label == other_actual:
                    continue
                pairs += 1
                if actual_label == 1:
                    if predictions[i] > predictions[j]:
                        concordant += 1.0
                    elif predictions[i] == predictions[j]:
                        concordant += 0.5
                else:
                    if predictions[j] > predictions[i]:
                        concordant += 1.0
                    elif predictions[j] == predictions[i]:
                        concordant += 0.5

        metrics.confusion[0] = true_negative
        metrics.confusion[1] = false_positive
        metrics.confusion[2] = false_negative
        metrics.confusion[3] = true_positive
        metrics.accuracy = Float64(correct) / n
        var positive_predicted = true_positive + false_positive
        var positive_actual = true_positive + false_negative
        metrics.precision = (
            Float64(true_positive) / Float64(positive_predicted)
            if positive_predicted > 0 else 0.0
        )
        metrics.recall = (
            Float64(true_positive) / Float64(positive_actual)
            if positive_actual > 0 else 0.0
        )
        var denominator = metrics.precision + metrics.recall
        metrics.f1 = (
            2.0 * metrics.precision * metrics.recall / denominator
            if denominator > 0.0 else 0.0
        )
        metrics.log_loss = loss / n
        metrics.auc = concordant / Float64(pairs) if pairs > 0 else 0.5

    return metrics^
