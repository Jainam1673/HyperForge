"""Small, auditable TPE-style adaptive sampler.

This is a genuine density-ratio sampler over recorded observations: it splits
trials into good/bad by validation RMSE, samples candidates near the good group,
and keeps the one with the highest good/bad kernel-density ratio. It is not a
random sampler and is not called Bayesian. `use_feedback=False` disables the
history entirely so a regression test can prove feedback is connected.
"""

from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.automl.models import (
    Candidate,
    MODEL_LINEAR,
    MODEL_RIDGE,
    MODEL_KNN,
    MODEL_BASELINE,
)
from hyperforge.optimization.space import (
    candidate_key,
    prior_candidate,
    MIN_ITERATIONS,
    MAX_ITERATIONS,
    MIN_K,
    MAX_K,
    MAX_REGULARIZATION,
)

comptime TPE_SCHEMA = "hyperforge-tpe-v1"
comptime BANDWIDTH = 0.15
comptime SAMPLES = 16
comptime RANDOM_FRACTION_PERCENT = 20


struct Observation(Copyable, Movable):
    var candidate: Candidate
    var rmse: Float64

    def __init__(out self, candidate: Candidate, rmse: Float64):
        self.candidate = candidate.copy()
        self.rmse = rmse


def clamp_int(value: Int, lower: Int, upper: Int) raises -> Int:
    if value < lower:
        return lower
    if value > upper:
        return upper
    return value


def clamp_float(value: Float64, lower: Float64, upper: Float64) raises -> Float64:
    if value < lower:
        return lower
    if value > upper:
        return upper
    return value


def normalize_candidate(
    kind: String, iterations: Int, regularization: Float64, k: Int
) raises -> Candidate:
    """Zero out parameters that are conditional on a different model kind."""
    if kind == MODEL_KNN:
        return Candidate("", kind, 0, 0.0, clamp_int(k, MIN_K, MAX_K))
    var reg = Float64(0.0)
    if kind == MODEL_RIDGE:
        reg = clamp_float(regularization, 0.0, MAX_REGULARIZATION)
    return Candidate(
        "",
        kind,
        clamp_int(iterations, MIN_ITERATIONS, MAX_ITERATIONS),
        reg,
        0,
    )


def kernel_distance(left: Float64, right: Float64) raises -> Float64:
    var scaled = (left - right) / BANDWIDTH
    return 1.0 / (1.0 + scaled * scaled)


def density(candidate: Candidate, group: List[Observation]) raises -> Float64:
    """Average Parzen density of `candidate` under a group of observations."""
    if len(group) == 0:
        return 0.0
    var total = Float64(0.0)
    for i in range(len(group)):
        var other = group[i].candidate.copy()
        var value = Float64(1.0)
        if candidate.kind != other.kind:
            value *= 0.1
        if candidate.kind == MODEL_KNN:
            value *= kernel_distance(
                Float64(candidate.k) / Float64(MAX_K),
                Float64(other.k) / Float64(MAX_K),
            )
        else:
            value *= kernel_distance(
                Float64(candidate.iterations) / Float64(MAX_ITERATIONS),
                Float64(other.iterations) / Float64(MAX_ITERATIONS),
            )
            if candidate.kind == MODEL_RIDGE:
                value *= kernel_distance(candidate.regularization, other.regularization)
        total += value
    return total / Float64(len(group))


struct TpeSampler:
    var seed: UInt64
    var history: List[Observation]
    var use_feedback: Bool

    def __init__(out self, seed: UInt64, use_feedback: Bool):
        self.seed = seed
        self.history = List[Observation]()
        self.use_feedback = use_feedback

    def observe(mut self, candidate: Candidate, rmse: Float64) raises -> None:
        """Feed one measured result back into the search policy."""
        self.history.append(Observation(candidate.copy(), rmse))

    def observed_count(self) raises -> Int:
        return len(self.history)

    def best_rmse(self) raises -> Float64:
        var best = Float64(1e300)
        for i in range(len(self.history)):
            if self.history[i].rmse < best:
                best = self.history[i].rmse
        return best

    def sorted_history(self) raises -> List[Observation]:
        var sorted_observations = List[Observation]()
        for i in range(len(self.history)):
            var item = self.history[i].copy()
            var inserted = False
            for j in range(len(sorted_observations)):
                if item.rmse < sorted_observations[j].rmse:
                    sorted_observations.insert(j, item.copy())
                    inserted = True
                    break
            if not inserted:
                sorted_observations.append(item.copy())
        return sorted_observations^

    def propose(self, index: Int) raises -> Candidate:
        var rng = SplitMix64(derive_seed(self.seed, "propose", UInt64(index)))
        if not self.use_feedback or len(self.history) == 0:
            return prior_candidate(self.seed, index)
        if Int(rng.next_below(UInt64(100))) < RANDOM_FRACTION_PERCENT:
            return prior_candidate(self.seed, index)

        var sorted_observations = self.sorted_history()
        # The baseline is a control, not a search point: record it in history
        # but do not let it become a parent for adaptive proposals.
        var search_history = List[Observation]()
        for i in range(len(sorted_observations)):
            var item = sorted_observations[i].copy()
            if item.candidate.kind != MODEL_BASELINE:
                search_history.append(item.copy())
        if len(search_history) == 0:
            return prior_candidate(self.seed, index)
        var good_count = Int(Float64(len(search_history)) * 0.3)
        if good_count < 1:
            good_count = 1
        var good = List[Observation]()
        var bad = List[Observation]()
        for i in range(len(search_history)):
            if i < good_count:
                good.append(search_history[i].copy())
            else:
                bad.append(search_history[i].copy())
        if len(bad) == 0:
            for i in range(len(search_history)):
                bad.append(search_history[i].copy())

        var best_sample = prior_candidate(self.seed, index)
        var best_score = Float64(-1.0)
        for sample_index in range(SAMPLES):
            var parent = good[Int(rng.next_below(UInt64(len(good))))].copy()
            var kind = parent.candidate.kind
            if Int(rng.next_below(UInt64(100))) >= 75:
                var prior = prior_candidate(self.seed, index * 100 + sample_index)
                kind = prior.kind
            var iterations = parent.candidate.iterations + Int(rng.next_below(UInt64(201))) - 100
            var regularization = parent.candidate.regularization
            if Int(rng.next_below(UInt64(201))) >= 100:
                regularization += Float64(Int(rng.next_below(UInt64(101)))) / 1000.0
            else:
                regularization -= Float64(Int(rng.next_below(UInt64(101)))) / 1000.0
            var k = parent.candidate.k + Int(rng.next_below(UInt64(5))) - 2
            var candidate = normalize_candidate(kind, iterations, regularization, k)
            candidate.id = candidate_key(
                self.seed, index * 100 + sample_index, candidate.kind,
                candidate.iterations, candidate.regularization, candidate.k,
            )
            var good_density = density(candidate, good)
            var bad_density = density(candidate, bad)
            var score = (good_density + Float64(1e-9)) / (bad_density + Float64(1e-9))
            if score > best_score:
                best_score = score
                best_sample = candidate^
        return best_sample^
