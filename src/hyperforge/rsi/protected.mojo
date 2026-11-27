"""Protected baseline and immutable evaluator protocol for bounded RSI.

These records are written once and never exposed to a candidate mutation path.
The checksum is verified on every load; a mismatch fails the run rather than
being repaired. Candidates can only propose config values, never these records.
"""

from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.automl.models import MODEL_LINEAR

comptime RSI_SCHEMA = "hyperforge-rsi-v1"
comptime BASELINE_SCHEMA = "hyperforge-rsi-baseline-v1"
comptime PROTOCOL_SCHEMA = "hyperforge-rsi-protocol-v1"


struct ProtectedConfig(Copyable, Movable):
    var model_kind: String
    var iterations: Int
    var regularization: Float64
    var k: Int
    var checksum: String

    def __init__(
        out self,
        model_kind: String,
        iterations: Int,
        regularization: Float64,
        k: Int,
        checksum: String,
    ):
        self.model_kind = model_kind
        self.iterations = iterations
        self.regularization = regularization
        self.k = k
        self.checksum = checksum


struct EvaluatorProtocol(Copyable, Movable):
    var min_relative_rmse_gain: Float64
    var max_test_rmse_regression: Float64
    var max_trials: Int
    var max_wall_seconds: Float64
    var max_recursion_depth: Int
    var max_candidate_bytes: Int
    var checksum: String

    def __init__(
        out self,
        min_relative_rmse_gain: Float64,
        max_test_rmse_regression: Float64,
        max_trials: Int,
        max_wall_seconds: Float64,
        max_recursion_depth: Int,
        max_candidate_bytes: Int,
        checksum: String,
    ):
        self.min_relative_rmse_gain = min_relative_rmse_gain
        self.max_test_rmse_regression = max_test_rmse_regression
        self.max_trials = max_trials
        self.max_wall_seconds = max_wall_seconds
        self.max_recursion_depth = max_recursion_depth
        self.max_candidate_bytes = max_candidate_bytes
        self.checksum = checksum


def config_canonical(
    model_kind: String, iterations: Int, regularization: Float64, k: Int
) raises -> String:
    return (
        model_kind + "|" + String(iterations) + "|" + String(regularization)
        + "|" + String(k)
    )


def config_checksum(
    model_kind: String, iterations: Int, regularization: Float64, k: Int
) raises -> String:
    return hex64(fnv1a64(
        config_canonical(model_kind, iterations, regularization, k)
    ))


def default_protected_config() raises -> ProtectedConfig:
    var canonical = config_canonical(MODEL_LINEAR, 200, 0.0, 0)
    return ProtectedConfig(
        MODEL_LINEAR, 200, 0.0, 0,
        hex64(fnv1a64("baseline|" + canonical)),
    )


def verify_protected_config(config: ProtectedConfig) raises -> Bool:
    var expected = hex64(fnv1a64(
        "baseline|" + config_canonical(
            config.model_kind, config.iterations, config.regularization, config.k
        )
    ))
    return expected == config.checksum


def protocol_canonical(
    min_gain: Float64,
    max_regression: Float64,
    max_trials: Int,
    max_wall: Float64,
    max_depth: Int,
    max_bytes: Int,
) raises -> String:
    return (
        String(min_gain) + "|" + String(max_regression) + "|"
        + String(max_trials) + "|" + String(max_wall) + "|"
        + String(max_depth) + "|" + String(max_bytes)
    )


def default_protocol() raises -> EvaluatorProtocol:
    var canonical = protocol_canonical(0.01, 0.05, 12, 30.0, 12, 4096)
    return EvaluatorProtocol(
        0.01, 0.05, 12, 30.0, 12, 4096,
        hex64(fnv1a64("protocol|" + canonical)),
    )


def verify_protocol(protocol: EvaluatorProtocol) raises -> Bool:
    var expected = hex64(fnv1a64(
        "protocol|" + protocol_canonical(
            protocol.min_relative_rmse_gain,
            protocol.max_test_rmse_regression,
            protocol.max_trials,
            protocol.max_wall_seconds,
            protocol.max_recursion_depth,
            protocol.max_candidate_bytes,
        )
    ))
    return expected == protocol.checksum
