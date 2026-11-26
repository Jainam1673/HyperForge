"""Deterministic bounded candidate generation for the M02 search.

This is a random-search baseline, not an adaptive sampler. Every proposal is a
pure function of (seed, index); results are recorded as trials. Adaptive
feedback is M03 and is not claimed here.
"""

from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.automl.models import (
    Candidate,
    MODEL_BASELINE,
    MODEL_LINEAR,
    MODEL_RIDGE,
    MODEL_KNN,
)

comptime SEARCH_SCHEMA = "hyperforge-search-v1"


def candidate_id(seed: UInt64, index: Int) raises -> String:
    return "cand-" + hex64(fnv1a64("candidate|" + String(seed) + "|" + String(index)))


def make_candidates(seed: UInt64, budget: Int) raises -> List[Candidate]:
    """Always include the baseline, then budget-1 deterministic random candidates."""
    if budget < 2:
        raise Error("budget must be at least 2")
    var out = List[Candidate]()
    out.append(Candidate(candidate_id(seed, 0), MODEL_BASELINE, 0, 0.0, 0))

    for i in range(1, budget):
        var rng = SplitMix64(derive_seed(seed, "candidate", UInt64(i)))
        var choice = Int(rng.next_below(UInt64(3)))
        var id = candidate_id(seed, i)
        if choice == 0:
            out.append(Candidate(id, MODEL_LINEAR, 100 + Int(rng.next_below(UInt64(500))), 0.0, 0))
        elif choice == 1:
            var reg = Float64(Int(rng.next_below(UInt64(100)))) / 100.0
            out.append(Candidate(id, MODEL_RIDGE, 100 + Int(rng.next_below(UInt64(500))), reg, 0))
        else:
            out.append(Candidate(id, MODEL_KNN, 0, 0.0, 1 + Int(rng.next_below(UInt64(7)))))
    return out^
