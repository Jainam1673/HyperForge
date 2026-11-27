"""Fixed-budget AutoTransformers configuration search."""

from std.time import perf_counter
from std.math import abs
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.scit.task import TaskSpec
from hyperforge.autotrans.model import (
    TransformerConfig,
    TransformerModel,
    init_model,
    parameter_count,
    valid_config,
)
from hyperforge.autotrans.trainer import (
    train,
    evaluate,
    inference_latency,
    range_indices,
)

comptime EPOCHS = 3
comptime LEARNING_RATE = 0.03
comptime LATENCY_REPETITIONS = 7


struct SearchOutcome(Copyable, Movable):
    var policy: String
    var budget: Int
    var config: TransformerConfig
    var parameters: Int
    var validation_mse: Float64
    var test_mse: Float64
    var latency: Float64
    var wall_seconds: Float64
    var trained: Int
    var detail: String

    def __init__(
        out self,
        policy: String,
        budget: Int,
        config: TransformerConfig,
        parameters: Int,
        validation_mse: Float64,
        test_mse: Float64,
        latency: Float64,
        wall_seconds: Float64,
        trained: Int,
        detail: String,
    ):
        self.policy = policy
        self.budget = budget
        self.config = config.copy()
        self.parameters = parameters
        self.validation_mse = validation_mse
        self.test_mse = test_mse
        self.latency = latency
        self.wall_seconds = wall_seconds
        self.trained = trained
        self.detail = detail


def default_config(seed: UInt64) raises -> TransformerConfig:
    return TransformerConfig(4, 2, 4, 1, 2, seed)


def random_config(seed: UInt64, index: Int) raises -> TransformerConfig:
    var rng = SplitMix64(derive_seed(seed, "autotrans-random", UInt64(index)))
    var d_model = 4
    if Int(rng.next_below(UInt64(2))) == 1:
        d_model = 8
    var heads = 1
    if d_model == 4 or Int(rng.next_below(UInt64(2))) == 1:
        heads = 2
    var ff_choices: List[Int] = [4, 8, 16]
    var ff = ff_choices[Int(rng.next_below(UInt64(3)))]
    var layers = 1
    if Int(rng.next_below(UInt64(2))) == 1:
        layers = 2
    var history = 2
    if Int(rng.next_below(UInt64(2))) == 1:
        history = 3
    var config = TransformerConfig(d_model, heads, ff, layers, history, seed)
    if not valid_config(config):
        raise Error("random configuration is invalid")
    return config^


def mutate_config(parent: TransformerConfig, seed: UInt64, index: Int) raises -> TransformerConfig:
    var rng = SplitMix64(derive_seed(seed, "autotrans-mutate", UInt64(index)))
    var config = parent.copy()
    var choice = Int(rng.next_below(UInt64(4)))
    if choice == 0:
        config.d_model = 8 if config.d_model == 4 else 4
        config.heads = 2 if config.d_model == 4 else 1
    elif choice == 1:
        var ff_choices: List[Int] = [4, 8, 16]
        config.ff_hidden = ff_choices[Int(rng.next_below(UInt64(3)))]
    elif choice == 2:
        config.layers = 2 if config.layers == 1 else 1
    else:
        config.history = 3 if config.history == 2 else 2
    if not valid_config(config):
        raise Error("mutation produced an invalid configuration")
    return config^


def run_search(
    policy: String, spec: TaskSpec, budget: Int, seed: UInt64
) raises -> SearchOutcome:
    if budget < 1:
        raise Error("budget must be positive")
    var started = perf_counter()
    var best_config = default_config(seed)
    var best_validation = Float64(1e300)
    var trained = 0
    var evaluation_count = budget
    if policy == "default":
        evaluation_count = 1

    for index in range(evaluation_count):
        var config: TransformerConfig
        if policy == "default":
            config = default_config(seed)
        elif policy == "random":
            config = random_config(seed, index)
        elif index == 0:
            config = default_config(seed)
        else:
            config = mutate_config(best_config, seed, index)
        config.history = spec.history
        var model = init_model(config)
        var losses = train(model, spec, range_indices(spec.train_count), EPOCHS, LEARNING_RATE)
        if losses[EPOCHS - 1] == losses[EPOCHS - 1]:
            trained += 1
        var validation = evaluate(model, spec, range_indices(spec.test_count), False)
        if validation[0] < best_validation:
            best_validation = validation[0]
            best_config = config.copy()

    var best_model = init_model(best_config)
    _ = train(best_model, spec, range_indices(spec.train_count), EPOCHS, LEARNING_RATE)
    var test = evaluate(best_model, spec, range_indices(spec.test_count, 100), False)
    var latency = inference_latency(best_model, spec, range_indices(spec.test_count, 100)[0], LATENCY_REPETITIONS)
    var detail = String("configuration search over verified attention implementation")
    if policy == "default":
        detail = "fixed reference configuration"
    return SearchOutcome(
        policy, evaluation_count, best_config.copy(),
        parameter_count(best_config), best_validation, test[0], latency,
        perf_counter() - started, trained, detail,
    )
