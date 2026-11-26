"""Bounded AutoDL search: random baseline vs adaptive architecture search."""

from std.time import perf_counter
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.autodl.task import AutoDLTask
from hyperforge.autodl.model import (
    ArchCandidate,
    MLP,
    valid_candidate,
    init_model,
    ACTIVATION_TANH,
    ACTIVATION_RELU,
)
from hyperforge.autodl.trainer import TrainResult, train_model, evaluate_indices

comptime SEARCH_SCHEMA = "hyperforge-autodl-search-v1"
comptime MAX_EPOCHS = 20
comptime PATIENCE = 3


struct SearchOutcome(Copyable, Movable):
    var policy: String
    var seed: UInt64
    var budget: Int
    var best_candidate: ArchCandidate
    var best_validation_loss: Float64
    var test_loss: Float64
    var test_accuracy: Float64
    var trained: Int
    var distinct_architectures: Int
    var wall_seconds: Float64
    var detail: String
    var best_model: MLP

    def __init__(
        out self,
        policy: String,
        seed: UInt64,
        budget: Int,
        best_candidate: ArchCandidate,
        best_validation_loss: Float64,
        test_loss: Float64,
        test_accuracy: Float64,
        trained: Int,
        distinct_architectures: Int,
        wall_seconds: Float64,
        detail: String,
        best_model: MLP,
    ):
        self.policy = policy
        self.seed = seed
        self.budget = budget
        self.best_candidate = best_candidate.copy()
        self.best_validation_loss = best_validation_loss
        self.test_loss = test_loss
        self.test_accuracy = test_accuracy
        self.trained = trained
        self.distinct_architectures = distinct_architectures
        self.wall_seconds = wall_seconds
        self.detail = detail
        self.best_model = best_model.copy()


def candidate_id(candidate: ArchCandidate) raises -> String:
    return "arch-" + hex64(fnv1a64(
        "autodl|" + String(candidate.depth) + "|" + String(candidate.width)
        + "|" + String(candidate.learning_rate) + "|" + String(candidate.batch_size)
        + "|" + candidate.activation + "|" + String(candidate.seed)
    ))


def random_candidate(seed: UInt64, index: Int) raises -> ArchCandidate:
    var rng = SplitMix64(derive_seed(seed, "autodl-random", UInt64(index)))
    var depths: List[Int] = [1, 2, 3]
    var widths: List[Int] = [4, 8, 16]
    var batches: List[Int] = [4, 8, 16]
    var depth = depths[Int(rng.next_below(UInt64(3)))]
    var width = widths[Int(rng.next_below(UInt64(3)))]
    var batch = batches[Int(rng.next_below(UInt64(3)))]
    var rate = Float64(Int(rng.next_below(UInt64(4))) + 1) / 100.0
    var activation = ACTIVATION_TANH
    if Int(rng.next_below(UInt64(2))) == 1:
        activation = ACTIVATION_RELU
    var candidate = ArchCandidate(
        "", depth, width, rate, batch, activation, seed
    )
    candidate.id = candidate_id(candidate)
    if not valid_candidate(candidate):
        raise Error("random proposal produced an invalid candidate")
    return candidate^


def mutate_candidate(parent: ArchCandidate, seed: UInt64, index: Int) raises -> ArchCandidate:
    var rng = SplitMix64(derive_seed(seed, "autodl-mutate", UInt64(index)))
    var candidate = parent.copy()
    var depths: List[Int] = [1, 2, 3]
    var widths: List[Int] = [4, 8, 16]
    var batches: List[Int] = [4, 8, 16]
    var choice = Int(rng.next_below(UInt64(5)))
    if choice == 0:
        var pos = Int(rng.next_below(UInt64(3)))
        candidate.depth = depths[pos]
    elif choice == 1:
        var pos = Int(rng.next_below(UInt64(3)))
        candidate.width = widths[pos]
    elif choice == 2:
        candidate.learning_rate = Float64(Int(rng.next_below(UInt64(4))) + 1) / 100.0
    elif choice == 3:
        var pos = Int(rng.next_below(UInt64(3)))
        candidate.batch_size = batches[pos]
    else:
        candidate.activation = (
            ACTIVATION_RELU if candidate.activation == ACTIVATION_TANH else ACTIVATION_TANH
        )
    candidate.id = candidate_id(candidate)
    if not valid_candidate(candidate):
        raise Error("mutation produced an invalid candidate")
    return candidate^


def run_search(
    policy: String, task: AutoDLTask, budget: Int, seed: UInt64
) raises -> SearchOutcome:
    if budget < 2:
        raise Error("budget must be at least 2")
    var started = perf_counter()
    var best_candidate = random_candidate(seed, 0)
    var best_validation = Float64(1e300)
    var trained = 0
    var distinct = List[String]()
    var best_model = init_model(best_candidate)

    for index in range(budget):
        var candidate: ArchCandidate
        if policy == "random":
            candidate = random_candidate(seed, index)
        elif index == 0:
            candidate = random_candidate(seed, 0)
        else:
            candidate = mutate_candidate(best_candidate, seed, index)

        var result = train_model(candidate, task, MAX_EPOCHS, PATIENCE)
        var report = result[1].copy()
        if report.state == "TRAINED" and report.parameters_changed:
            trained += 1
            var signature = String(candidate.depth) + "x" + String(candidate.width)
            var seen = False
            for value in distinct:
                if value == signature:
                    seen = True
                    break
            if not seen:
                distinct.append(signature)
            # Selection uses validation loss only; test is untouched here.
            if report.validation_loss < best_validation:
                best_validation = report.validation_loss
                best_candidate = candidate.copy()
                best_model = result[0].copy()

    if trained == 0:
        raise Error("every AutoDL candidate failed to train")

    var test = evaluate_indices(best_model, task, task.test)
    var detail = String("random search over typed candidates")
    if policy == "adaptive":
        detail = "adaptive mutation of best validation candidate"
    return SearchOutcome(
        policy, seed, budget, best_candidate.copy(), best_validation,
        test[0], test[1], trained, len(distinct), perf_counter() - started, detail,
        best_model.copy(),
    )
