"""Regression metrics with explicit zero-denominator behavior."""

from std.math import abs, sqrt
from hyperforge.core.numeric import is_finite, finite_mean

comptime METRICS_SCHEMA = "hyperforge-metrics-v1"


struct Metrics(Copyable, Movable):
    var mae: Float64
    var mse: Float64
    var rmse: Float64
    var r2: Float64
    var count: Int

    def __init__(out self, mae: Float64, mse: Float64, rmse: Float64, r2: Float64, count: Int):
        self.mae = mae
        self.mse = mse
        self.rmse = rmse
        self.r2 = r2
        self.count = count


def compute_metrics(predictions: List[Float64], actuals: List[Float64]) raises -> Metrics:
    """Compute MAE, MSE, RMSE and R².

    Edge cases: empty input is an error; non-finite predictions are an error;
    a constant target or a single sample yields R² = 0 by definition here
    (documented rather than reporting NaN or a fabricated score).
    """
    if len(predictions) != len(actuals):
        raise Error("metrics length mismatch")
    if len(predictions) == 0:
        raise Error("metrics require at least one observation")

    var absolute_error = Float64(0.0)
    var squared_error = Float64(0.0)
    for i in range(len(predictions)):
        if not is_finite(predictions[i]) or not is_finite(actuals[i]):
            raise Error("non-finite value in metrics")
        var delta = actuals[i] - predictions[i]
        absolute_error += abs(delta)
        squared_error += delta * delta

    var count = Float64(len(predictions))
    var mae = absolute_error / count
    var mse = squared_error / count
    var average = finite_mean(actuals)
    var total_variance = Float64(0.0)
    for value in actuals:
        var delta = value - average
        total_variance += delta * delta

    var r2 = Float64(0.0)
    if total_variance > 0.0:
        r2 = 1.0 - squared_error / total_variance
    return Metrics(mae, mse, sqrt(mse), r2, len(predictions))
