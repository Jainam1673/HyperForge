"""Config-only RSI candidates. No generated code, no shell, no file execution."""

from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.automl.models import MODEL_LINEAR, MODEL_RIDGE, MODEL_KNN
from hyperforge.rsi.protected import config_canonical

comptime CANDIDATE_SCHEMA = "hyperforge-rsi-candidate-v1"


struct ConfigCandidate(Copyable, Movable):
    var model_kind: String
    var iterations: Int
    var regularization: Float64
    var k: Int
    var id: String

    def __init__(
        out self,
        model_kind: String,
        iterations: Int,
        regularization: Float64,
        k: Int,
        id: String,
    ):
        self.model_kind = model_kind
        self.iterations = iterations
        self.regularization = regularization
        self.k = k
        self.id = id


def valid_candidate(candidate: ConfigCandidate) raises -> Bool:
    if candidate.model_kind != MODEL_LINEAR and candidate.model_kind != MODEL_RIDGE and candidate.model_kind != MODEL_KNN:
        return False
    if candidate.iterations < 25 or candidate.iterations > 800:
        return False
    if candidate.regularization < 0.0 or candidate.regularization > 0.1:
        return False
    if candidate.k < 1 or candidate.k > 5:
        return False
    return True


def make_candidate(
    model_kind: String, iterations: Int, regularization: Float64, k: Int
) raises -> ConfigCandidate:
    var canonical = config_canonical(model_kind, iterations, regularization, k)
    return ConfigCandidate(
        model_kind, iterations, regularization, k,
        "rsic-" + hex64(fnv1a64(canonical)),
    )


def propose(seed: UInt64, index: Int) raises -> ConfigCandidate:
    """Deterministic bounded proposal over the config space only."""
    var rng = SplitMix64(derive_seed(seed, "rsi-propose", UInt64(index)))
    var kinds: List[String] = [MODEL_LINEAR, MODEL_RIDGE, MODEL_KNN]
    var steps: List[Int] = [50, 100, 200, 400, 800]
    var regs: List[Float64] = [0.0, 0.001, 0.01, 0.05]
    var ks: List[Int] = [1, 3, 5]
    var candidate = make_candidate(
        kinds[Int(rng.next_below(UInt64(3)))],
        steps[Int(rng.next_below(UInt64(5)))],
        regs[Int(rng.next_below(UInt64(4)))],
        ks[Int(rng.next_below(UInt64(3)))],
    )
    if not valid_candidate(candidate):
        raise Error("proposal violated the config bounds")
    return candidate^


def candidate_size(candidate: ConfigCandidate) raises -> Int:
    """Serialized candidate size, bounded by the protected protocol."""
    return config_canonical(
        candidate.model_kind, candidate.iterations,
        candidate.regularization, candidate.k,
    ).byte_length()
