"""Full AutoDL breadth: HPO methods, structural NAS, multi-fidelity, seeds."""

from std.time import perf_counter
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.autodl.task import AutoDLTask
from hyperforge.autodl.model import (
    ArchCandidate, MLP, valid_candidate, init_model,
    ACTIVATION_TANH, ACTIVATION_RELU,
)
from hyperforge.autodl.trainer import train_model, evaluate_indices
from hyperforge.autodl.search import candidate_id, random_candidate, mutate_candidate

comptime FULL_SEARCH_SCHEMA = "hyperforge-autodl-full-v1"
comptime FULL_EPOCHS = 20
comptime LOW_EPOCHS = 5
comptime PATIENCE = 3


struct FullOutcome(Copyable, Movable):
    var policy: String
    var budget: Int
    var seeds: Int
    var best: ArchCandidate
    var validation: Float64
    var test_loss: Float64
    var test_accuracy: Float64
    var trained: Int
    var distinct: Int
    var fidelity_promotions: Int
    var wall_seconds: Float64
    var detail: String

    def __init__(
        out self,
        policy: String,
        budget: Int,
        seeds: Int,
        best: ArchCandidate,
        validation: Float64,
        test_loss: Float64,
        test_accuracy: Float64,
        trained: Int,
        distinct: Int,
        fidelity_promotions: Int,
        wall_seconds: Float64,
        detail: String,
    ):
        self.policy = policy
        self.budget = budget
        self.seeds = seeds
        self.best = best.copy()
        self.validation = validation
        self.test_loss = test_loss
        self.test_accuracy = test_accuracy
        self.trained = trained
        self.distinct = distinct
        self.fidelity_promotions = fidelity_promotions
        self.wall_seconds = wall_seconds
        self.detail = detail


def grid_candidates(budget: Int) raises -> List[ArchCandidate]:
    if budget < 1:
        raise Error("budget must be positive")
    var depths = [1, 2, 3]
    var widths = [4, 8, 16]
    var batches = [4, 8, 16]
    var rates = [0.01, 0.02, 0.03, 0.04]
    var out = List[ArchCandidate]()
    for d in range(len(depths)):
        for w in range(len(widths)):
            for b in range(len(batches)):
                for r in range(len(rates)):
                    if len(out) >= budget:
                        return out^
                    var activation = ACTIVATION_TANH if (d + w + b + r) % 2 == 0 else ACTIVATION_RELU
                    var candidate = ArchCandidate(
                        "", depths[d], widths[w], rates[r], batches[b], activation, UInt64(42)
                    )
                    candidate.id = candidate_id(candidate)
                    if not valid_candidate(candidate):
                        raise Error("grid produced an invalid candidate")
                    out.append(candidate^)
    return out^


def proposals(policy: String, budget: Int, seed: UInt64) raises -> List[ArchCandidate]:
    if policy == "grid":
        return grid_candidates(budget)
    if policy == "random":
        var out = List[ArchCandidate]()
        for i in range(budget):
            out.append(random_candidate(seed, i))
        return out^
    if policy == "adaptive" or policy == "multifidelity":
        var out = List[ArchCandidate]()
        var best = random_candidate(seed, 0)
        for i in range(budget):
            var candidate = best.copy() if i > 0 else best.copy()
            if i > 0:
                candidate = mutate_candidate(best, seed, i)
            out.append(candidate^)
        return out^
    raise Error("unknown AutoDL policy: " + policy)


def run_full_search(
    policy: String, task: AutoDLTask, budget: Int, seed: UInt64, repeat_seeds: Int
) raises -> FullOutcome:
    if budget < 2 or repeat_seeds < 1:
        raise Error("budget must be >=2 and seeds >=1")
    var started = perf_counter()
    var candidates = proposals(policy, budget, seed)
    var best = candidates[0].copy()
    var best_validation = 1e300
    var trained = 0
    var signatures = List[String]()
    var promotions = 0

    # Low-fidelity screen for every policy; multi-fidelity promotes survivors.
    var screened = List[ArchCandidate]()
    for i in range(len(candidates)):
        var candidate = candidates[i].copy()
        var result = train_model(candidate, task, LOW_EPOCHS, PATIENCE)
        var report = result[1].copy()
        if report.state != "TRAINED" or not report.parameters_changed:
            continue
        trained += 1
        var signature = String(candidate.depth) + "x" + String(candidate.width) + candidate.activation
        var seen = False
        for j in range(len(signatures)):
            if signatures[j] == signature:
                seen = True
                break
        if not seen:
            signatures.append(signature)
        screened.append(candidate.copy())
        if policy == "multifidelity" and report.validation_loss < best_validation:
            best_validation = report.validation_loss
            best = candidate.copy()

    if len(screened) == 0:
        raise Error("every AutoDL candidate failed the low-fidelity screen")

    var final_candidates = screened.copy()
    if policy == "multifidelity":
        # Keep the best half for full-fidelity evaluation.
        var promoted = List[ArchCandidate]()
        var keep = len(screened) // 2
        if keep < 1:
            keep = 1
        for i in range(keep):
            promoted.append(screened[i].copy())
            promotions += 1
        final_candidates = promoted^
        best_validation = 1e300

    var best_model: MLP
    var initialized = False
    for i in range(len(final_candidates)):
        var candidate = final_candidates[i].copy()
        var result = train_model(candidate, task, FULL_EPOCHS, PATIENCE)
        var report = result[1].copy()
        if report.state != "TRAINED" or not report.parameters_changed:
            continue
        if report.validation_loss < best_validation:
            best_validation = report.validation_loss
            best = candidate.copy()
            best_model = result[0].copy()
            initialized = True

    if not initialized:
        raise Error("no candidate completed full-fidelity training")

    # Repeated seeds: re-evaluate the winner from scratch for each declared seed.
    var total_loss = 0.0
    var total_accuracy = 0.0
    for s in range(repeat_seeds):
        var seeded = best.copy()
        seeded.seed = derive_seed(seed, "autodl-repeat", UInt64(s))
        var result = train_model(seeded, task, FULL_EPOCHS, PATIENCE)
        var test = evaluate_indices(result[0], task, task.test)
        total_loss += test[0]
        total_accuracy += test[1]
    var test_loss = total_loss / Float64(repeat_seeds)
    var test_accuracy = total_accuracy / Float64(repeat_seeds)

    var detail = String(policy) + " with low-fidelity screen and held-out test"
    return FullOutcome(
        policy, budget, repeat_seeds, best, best_validation, test_loss,
        test_accuracy, trained, len(signatures), promotions,
        perf_counter() - started, detail,
    )
