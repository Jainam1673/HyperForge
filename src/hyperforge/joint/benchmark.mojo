"""Joint AI×compute benchmark with matched budgets and explicit ablations."""

from std.time import perf_counter
from max.gpu.host import DeviceContext
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.automl.dataset import load_csv, target_at
from hyperforge.automl.split import make_split
from hyperforge.automl.preprocess import fit_preprocessor, transform_row
from hyperforge.automl.models import (
    Candidate,
    fit_model,
    predict,
    MODEL_LINEAR,
    MODEL_RIDGE,
    MODEL_KNN,
)
from hyperforge.automl.metrics import compute_metrics
from hyperforge.gpu.kernels import run_vector_add_block

comptime JOINT_SCHEMA = "hyperforge-joint-benchmark-v1"
comptime DATASET = "/home/jack/Projects/HyperForge/examples/regression_linear.csv"
comptime ITERATIONS = 200
comptime GPU_REPETITIONS = 3
comptime VECTOR_SIZE = 1024


struct JointGenome(Copyable, Movable):
    var model_kind: String
    var iterations: Int
    var block_size: Int
    var seed: UInt64

    def __init__(
        out self, model_kind: String, iterations: Int, block_size: Int, seed: UInt64
    ):
        self.model_kind = model_kind
        self.iterations = iterations
        self.block_size = block_size
        self.seed = seed


struct JointMeasurement(Copyable, Movable):
    var genome_id: String
    var model_kind: String
    var iterations: Int
    var block_size: Int
    var rmse: Float64
    var latency: Float64
    var valid: Bool

    def __init__(
        out self, genome_id: String, model_kind: String, iterations: Int,
        block_size: Int, rmse: Float64, latency: Float64, valid: Bool,
    ):
        self.genome_id = genome_id
        self.model_kind = model_kind
        self.iterations = iterations
        self.block_size = block_size
        self.rmse = rmse
        self.latency = latency
        self.valid = valid


struct JointOutcome(Copyable, Movable):
    var policy: String
    var seed: UInt64
    var budget: Int
    var best_rmse: Float64
    var best_latency: Float64
    var ai_evaluations: Int
    var compute_evaluations: Int
    var discoveries: Int
    var wall_seconds: Float64
    var detail: String

    def __init__(
        out self,
        policy: String,
        seed: UInt64,
        budget: Int,
        best_rmse: Float64,
        best_latency: Float64,
        ai_evaluations: Int,
        compute_evaluations: Int,
        discoveries: Int,
        wall_seconds: Float64,
        detail: String,
    ):
        self.policy = policy
        self.seed = seed
        self.budget = budget
        self.best_rmse = best_rmse
        self.best_latency = best_latency
        self.ai_evaluations = ai_evaluations
        self.compute_evaluations = compute_evaluations
        self.discoveries = discoveries
        self.wall_seconds = wall_seconds
        self.detail = detail


def joint_id(genome: JointGenome) raises -> String:
    return "joint-" + hex64(fnv1a64(
        genome.model_kind + "|" + String(genome.iterations)
        + "|" + String(genome.block_size) + "|" + String(genome.seed)
    ))


def default_genome(seed: UInt64) raises -> JointGenome:
    return JointGenome(MODEL_LINEAR, ITERATIONS, 256, seed)


def valid_genome(genome: JointGenome) raises -> Bool:
    if genome.block_size != 64 and genome.block_size != 128 and genome.block_size != 256 and genome.block_size != 512:
        return False
    if genome.iterations < 25 or genome.iterations > 800:
        return False
    return (
        genome.model_kind == MODEL_LINEAR
        or genome.model_kind == MODEL_RIDGE
        or genome.model_kind == MODEL_KNN
    )


def mutate(
    genome: JointGenome, side: String, seed: UInt64, index: Int
) raises -> JointGenome:
    var rng = SplitMix64(derive_seed(seed, "joint-mutate", UInt64(index)))
    var child = genome.copy()
    if side == "ai":
        # Alternate between changing the model family and the training budget.
        # Both are genuine AI-side genes that alter measured validation RMSE.
        if index % 2 == 0:
            var kinds: List[String] = [MODEL_LINEAR, MODEL_RIDGE, MODEL_KNN]
            child.model_kind = kinds[Int(rng.next_below(UInt64(3)))]
        else:
            var steps: List[Int] = [50, 100, ITERATIONS, 400, 800]
            child.iterations = steps[Int(rng.next_below(UInt64(5)))]
    else:
        var blocks: List[Int] = [64, 128, 256, 512]
        child.block_size = blocks[Int(rng.next_below(UInt64(4)))]
    if not valid_genome(child):
        raise Error("mutation produced an invalid joint genome")
    return child^


def model_rmse(kind: String, iterations: Int, seed: UInt64) raises -> Float64:
    var dataset = load_csv(DATASET, "y")
    var split = make_split(dataset.rows, seed)
    var preprocessor = fit_preprocessor(dataset, split.train)
    var regularization = Float64(0.0)
    var k = 0
    if kind == MODEL_RIDGE:
        regularization = 0.01
    if kind == MODEL_KNN:
        k = 3
    var candidate = Candidate("joint", kind, iterations, regularization, k)
    var model = fit_model(candidate, dataset, split.train, preprocessor)
    var predictions = List[Float64]()
    var actuals = List[Float64]()
    for row in split.validation:
        predictions.append(predict(model, transform_row(preprocessor, dataset, row)))
        actuals.append(target_at(dataset, row))
    return compute_metrics(predictions, actuals).rmse


def evaluate_joint(
    mut ctx: DeviceContext, genome: JointGenome
) raises -> JointMeasurement:
    if not valid_genome(genome):
        raise Error("invalid joint genome")
    var rmse = model_rmse(genome.model_kind, genome.iterations, UInt64(42))
    var kernel = run_vector_add_block[VECTOR_SIZE](
        ctx, genome.block_size, GPU_REPETITIONS
    )
    var valid = kernel.state == "PASS"
    return JointMeasurement(
        joint_id(genome), genome.model_kind, genome.iterations, genome.block_size,
        rmse, kernel.kernel_median_seconds, valid,
    )


def best_of(history: List[JointMeasurement], side: String) raises -> JointGenome:
    var best = default_genome(UInt64(0))
    var best_value = Float64(1e300)
    for i in range(len(history)):
        var item = history[i].copy()
        if not item.valid:
            continue
        var value = item.rmse if side == "ai" else item.latency
        if value < best_value:
            best_value = value
            best = JointGenome(
                item.model_kind, item.iterations, item.block_size, UInt64(0)
            )
    return best^


def relative_gain(history: List[JointMeasurement], side: String) raises -> Float64:
    """Fractional improvement relative to the first observation on a side.

    Each side is normalized by its own starting value so that incommensurable
    objectives (RMSE vs latency) can be compared without an arbitrary weight.
    """
    var first = Float64(-1.0)
    var best = Float64(1e300)
    for i in range(len(history)):
        var item = history[i].copy()
        if not item.valid:
            continue
        var value = item.rmse if side == "ai" else item.latency
        if first < 0.0:
            first = value
        if value < best:
            best = value
    if first <= 0.0:
        return 0.0
    return (first - best) / first


def choose_side(
    policy: String,
    index: Int,
    history: List[JointMeasurement],
    seed: UInt64,
    budget: Int,
) raises -> String:
    if policy == "ai_only":
        return String("ai")
    if policy == "compute_only":
        return String("compute")
    if policy == "fixed" or policy == "ablation_no_adaptive":
        return String("ai") if index % 2 == 0 else String("compute")
    if policy == "sequential":
        return String("ai") if index * 2 < budget else String("compute")
    if policy == "ablation_no_meta":
        var rng = SplitMix64(derive_seed(seed, "joint-meta", UInt64(index)))
        return String("ai") if Int(rng.next_below(UInt64(2))) == 0 else String("compute")
    # joint and no_shared_history: guarantee exploration of both sides, then
    # allocate by normalized relative gain from the shared evidence ledger.
    var floor = budget // 3
    if index < floor:
        return String("ai") if index % 2 == 0 else String("compute")
    if relative_gain(history, "compute") > relative_gain(history, "ai"):
        return String("compute")
    return String("ai")


def contains_id(items: List[String], target: String) raises -> Bool:
    for i in range(len(items)):
        if items[i] == target:
            return True
    return False


def run_joint(
    mut ctx: DeviceContext, policy: String, budget: Int, seed: UInt64
) raises -> JointOutcome:
    if budget < 2:
        raise Error("budget must be at least 2")
    var started = perf_counter()
    var history = List[JointMeasurement]()
    var ai_history = List[JointMeasurement]()
    var compute_history = List[JointMeasurement]()
    var best_rmse = Float64(1e300)
    var best_latency = Float64(1e300)
    var ai_count = 0
    var compute_count = 0
    var discoveries = 0
    var seen = List[String]()
    var base = default_genome(seed)

    for index in range(budget):
        var side = choose_side(policy, index, history, seed, budget)
        var genome = base.copy()
        if policy == "ai_only":
            genome = mutate(genome, "ai", seed, index)
        elif policy == "compute_only":
            genome = mutate(genome, "compute", seed, index)
        elif policy == "independent":
            if index % 2 == 0:
                genome = mutate(base.copy(), "ai", seed, index)
            else:
                genome = mutate(base.copy(), "compute", seed, index + 100)
        elif policy == "ablation_no_shared_history":
            var source = ai_history.copy() if side == "ai" else compute_history.copy()
            if len(source) > 0:
                var best_ai = best_of(source, "ai")
                var best_compute = best_of(source, "compute")
                genome = JointGenome(
                    best_ai.model_kind, best_ai.iterations,
                    best_compute.block_size, seed,
                )
                genome = mutate(genome, side, seed, index)
        elif policy != "fixed":
            var recombined = best_of(history, "ai")
            recombined.block_size = best_of(history, "compute").block_size
            genome = mutate(recombined, side, seed, index)

        var measurement = evaluate_joint(ctx, genome)
        history.append(measurement.copy())
        if side == "ai":
            ai_history.append(measurement.copy())
            ai_count += 1
        else:
            compute_history.append(measurement.copy())
            compute_count += 1
        # A repeated configuration cannot be a discovery: latency noise on an
        # identical genome is measurement variance, not a verified improvement.
        if measurement.valid and not contains_id(seen, measurement.genome_id):
            seen.append(measurement.genome_id)
            if measurement.rmse < best_rmse:
                best_rmse = measurement.rmse
                discoveries += 1
            if measurement.latency < best_latency:
                best_latency = measurement.latency
                discoveries += 1

    var detail = String("joint shared evidence with adaptive allocation")
    if policy == "ablation_no_shared_history":
        detail = "side-local histories only; no cross-loop recombination"
    elif policy == "ablation_no_adaptive":
        detail = "alternating allocation; no gain-based budgeting"
    elif policy == "ablation_no_meta":
        detail = "random allocation; meta-policy ablated"
    return JointOutcome(
        policy, seed, budget, best_rmse, best_latency, ai_count,
        compute_count, discoveries, perf_counter() - started, detail,
    )
