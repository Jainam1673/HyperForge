"""Typed search space with validation and conditional parameters.

M03 searches only model kinds and parameters that have a real execution path
in M02. Conditional rules are explicit: iterations apply to linear/ridge,
regularization only to ridge, and k only to kNN. Invalid candidates are
rejected before execution and recorded as failed trials.
"""

from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.automl.models import (
    Candidate,
    MODEL_LINEAR,
    MODEL_RIDGE,
    MODEL_KNN,
    MODEL_BASELINE,
)

comptime SPACE_SCHEMA = "hyperforge-search-space-v1"
comptime MIN_ITERATIONS = 100
comptime MAX_ITERATIONS = 600
comptime MIN_K = 1
comptime MAX_K = 7
comptime MAX_REGULARIZATION = 1.0


def is_searchable_kind(kind: String) raises -> Bool:
    return kind == MODEL_LINEAR or kind == MODEL_RIDGE or kind == MODEL_KNN


def validate_candidate(candidate: Candidate) raises -> Bool:
    """Return False for structurally invalid or conditionally inconsistent candidates."""
    if candidate.id == "":
        return False
    if candidate.kind == MODEL_BASELINE:
        return (
            candidate.iterations == 0
            and candidate.regularization == 0.0
            and candidate.k == 0
        )
    if not is_searchable_kind(candidate.kind):
        return False
    if candidate.kind == MODEL_KNN:
        if candidate.iterations != 0 or candidate.regularization != 0.0:
            return False
        return candidate.k >= MIN_K and candidate.k <= MAX_K
    if candidate.k != 0:
        return False
    if candidate.iterations < MIN_ITERATIONS or candidate.iterations > MAX_ITERATIONS:
        return False
    if candidate.regularization < 0.0 or candidate.regularization > MAX_REGULARIZATION:
        return False
    if candidate.kind == MODEL_LINEAR and candidate.regularization != 0.0:
        return False
    return True


def candidate_key(
    seed: UInt64, index: Int, kind: String, iterations: Int, regularization: Float64, k: Int
) raises -> String:
    return "cand-" + hex64(
        fnv1a64(
            "space|" + String(seed) + "|" + String(index) + "|" + kind
            + "|" + String(iterations) + "|" + String(regularization) + "|" + String(k)
        )
    )


def prior_candidate(seed: UInt64, index: Int) raises -> Candidate:
    """Draw from the explicit uniform prior. Pure function of (seed, index)."""
    var rng = SplitMix64(derive_seed(seed, "prior", UInt64(index)))
    var choice = Int(rng.next_below(UInt64(3)))
    var kind: String
    var iterations = 0
    var regularization = Float64(0.0)
    var k = 0
    if choice == 0:
        kind = MODEL_LINEAR
        iterations = MIN_ITERATIONS + Int(rng.next_below(UInt64(MAX_ITERATIONS - MIN_ITERATIONS + 1)))
    elif choice == 1:
        kind = MODEL_RIDGE
        iterations = MIN_ITERATIONS + Int(rng.next_below(UInt64(MAX_ITERATIONS - MIN_ITERATIONS + 1)))
        regularization = Float64(Int(rng.next_below(UInt64(101)))) / 100.0
    else:
        kind = MODEL_KNN
        k = MIN_K + Int(rng.next_below(UInt64(MAX_K - MIN_K + 1)))
    return Candidate(
        candidate_key(seed, index, kind, iterations, regularization, k),
        kind,
        iterations,
        regularization,
        k,
    )
