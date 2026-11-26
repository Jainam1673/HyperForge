"""Bounded reciprocal-discovery benchmark with matched budgets.

AI objective: validation RMSE on the documented regression task (lower is
better). Compute objective: median GPU kernel latency at a launch block size
(lower is better). Every evaluation measures both objectives, so both loops
contribute to one shared evidence ledger. The central claim is not assumed:
joint search is compared against fixed, single-loop, independent, and ablated
policies under the same evaluation count.
"""

from std.sys import has_accelerator
from std.time import perf_counter
from max.gpu.host import DeviceContext
from hyperforge.automl.dataset import load_csv, target_at
from hyperforge.automl.split import make_split
from hyperforge.automl.preprocess import fit_preprocessor, transform_row
from hyperforge.automl.models import Candidate, fit_model, predict, MODEL_RIDGE
from hyperforge.automl.metrics import compute_metrics
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.gpu.kernels import time_vector_add
from hyperforge.discovery.genome import (
    DiscoveryGenome,
    genome_id,
    canonical_genome,
    is_valid_genome,
    mutate,
    DEFAULT_BLOCK,
)

comptime RECIPROCAL_SCHEMA = "hyperforge-reciprocal-v1"
comptime MODEL_ITERATIONS = 300
comptime GPU_REPETITIONS = 3


struct Observation(Copyable, Movable):
    var genome: DiscoveryGenome
    var rmse: Float64
    var latency: Float64
    var valid: Bool

    def __init__(out self, genome: DiscoveryGenome, rmse: Float64, latency: Float64, valid: Bool):
        self.genome = genome.copy()
        self.rmse = rmse
        self.latency = latency
        self.valid = valid


struct PolicyOutcome(Copyable, Movable):
    var policy: String
    var seed: UInt64
    var budget: Int
    var best_rmse: Float64
    var best_latency: Float64
    var wall_seconds: Float64
    var evaluations: Int
    var discoveries: Int
    var pareto_count: Int
    var detail: String

    def __init__(
        out self,
        policy: String,
        seed: UInt64,
        budget: Int,
        best_rmse: Float64,
        best_latency: Float64,
        wall_seconds: Float64,
        evaluations: Int,
        discoveries: Int,
        pareto_count: Int,
        detail: String,
    ):
        self.policy = policy
        self.seed = seed
        self.budget = budget
        self.best_rmse = best_rmse
        self.best_latency = best_latency
        self.wall_seconds = wall_seconds
        self.evaluations = evaluations
        self.discoveries = discoveries
        self.pareto_count = pareto_count
        self.detail = detail


def evaluate_genome(
    genome: DiscoveryGenome, dataset_path: String, mut ctx: DeviceContext, use_gpu: Bool
) raises -> Observation:
    if not is_valid_genome(genome):
        return Observation(genome, 1e300, 1e300, False)

    var dataset = load_csv(dataset_path, "y")
    var split = make_split(dataset.rows, UInt64(42))
    var preprocessor = fit_preprocessor(dataset, split.train)
    var regularization = Float64(0.0)
    var k = 0
    if genome.model_kind == MODEL_RIDGE:
        regularization = 0.01
    if genome.model_kind == "knn_regressor":
        k = 3
    var candidate = Candidate(
        genome_id(genome), genome.model_kind, MODEL_ITERATIONS, regularization, k
    )
    var model = fit_model(candidate, dataset, split.train, preprocessor)
    var predictions = List[Float64]()
    var actuals = List[Float64]()
    for row in split.validation:
        predictions.append(predict(model, transform_row(preprocessor, dataset, row)))
        actuals.append(target_at(dataset, row))
    var rmse = compute_metrics(predictions, actuals).rmse

    var latency = Float64(0.0)
    if use_gpu:
        latency = time_vector_add(ctx, genome.block_size, GPU_REPETITIONS)
    return Observation(genome, rmse, latency, True)


def best_model(observations: List[Observation]) raises -> String:
    var best = String("linear_gd")
    var value = Float64(1e300)
    for i in range(len(observations)):
        var observation = observations[i].copy()
        if observation.valid and observation.rmse < value:
            value = observation.rmse
            best = observation.genome.model_kind
    return best


def best_block(observations: List[Observation]) raises -> Int:
    var best = DEFAULT_BLOCK
    var value = Float64(1e300)
    for i in range(len(observations)):
        var observation = observations[i].copy()
        if observation.valid and observation.latency > 0.0 and observation.latency < value:
            value = observation.latency
            best = observation.genome.block_size
    return best


def pareto_count(observations: List[Observation]) raises -> Int:
    var count = 0
    for i in range(len(observations)):
        var a = observations[i].copy()
        if not a.valid or a.latency <= 0.0:
            continue
        var dominated = False
        for j in range(len(observations)):
            var b = observations[j].copy()
            if i == j or not b.valid or b.latency <= 0.0:
                continue
            if b.rmse <= a.rmse and b.latency <= a.latency and (
                b.rmse < a.rmse or b.latency < a.latency
            ):
                dominated = True
                break
        if not dominated:
            count += 1
    return count


def next_genome(
    policy: String,
    observations: List[Observation],
    index: Int,
    seed: UInt64,
    last_ai_gain: Float64,
    last_compute_gain: Float64,
) raises -> DiscoveryGenome:
    var base = DiscoveryGenome(best_model(observations), best_block(observations))
    if policy == "fixed":
        return DiscoveryGenome("linear_gd", DEFAULT_BLOCK)
    if policy == "ai_only":
        return mutate(base, "ai", 1)
    if policy == "compute_only":
        return mutate(base, "compute", 1)
    if policy == "independent":
        if index % 2 == 0:
            return mutate(DiscoveryGenome("linear_gd", DEFAULT_BLOCK), "ai", index % 3)
        return mutate(DiscoveryGenome("linear_gd", DEFAULT_BLOCK), "compute", index % 4)
    if policy == "ablation_no_history":
        var rng = SplitMix64(derive_seed(seed, "ablation", UInt64(index)))
        var kind_index = Int(rng.next_below(UInt64(3)))
        var block_index = Int(rng.next_below(UInt64(4)))
        var kinds = List[String]()
        kinds.append("linear_gd")
        kinds.append("ridge_gd")
        kinds.append("knn_regressor")
        var blocks: List[Int] = [64, 128, 256, 512]
        return DiscoveryGenome(kinds[kind_index], blocks[block_index])
    # joint_reciprocal: allocate the next evaluation to the side with the
    # larger normalized marginal gain, then recombine the best known genes.
    if last_ai_gain >= last_compute_gain:
        return mutate(base, "ai", 1)
    return mutate(base, "compute", 1)


def run_policy(
    policy: String,
    seed: UInt64,
    budget: Int,
    dataset_path: String,
    mut ctx: DeviceContext,
    use_gpu: Bool,
) raises -> PolicyOutcome:
    var observations = List[Observation]()
    var started = perf_counter()
    var best_rmse = Float64(1e300)
    var best_latency = Float64(1e300)
    var discoveries = 0
    var last_rmse = Float64(1e300)
    var last_latency = Float64(1e300)
    var ai_gain = Float64(0.0)
    var compute_gain = Float64(0.0)

    for index in range(budget):
        var genome = next_genome(
            policy, observations, index, seed, ai_gain, compute_gain
        )
        var observation = evaluate_genome(genome, dataset_path, ctx, use_gpu)
        observations.append(observation.copy())
        if not observation.valid:
            continue
        if observation.rmse < best_rmse:
            best_rmse = observation.rmse
            discoveries += 1
        if use_gpu and observation.latency < best_latency:
            best_latency = observation.latency
            discoveries += 1
        if last_rmse < Float64(1e299):
            ai_gain = last_rmse - observation.rmse
        if use_gpu and last_latency < Float64(1e299):
            compute_gain = (last_latency - observation.latency) / last_latency
        last_rmse = observation.rmse
        last_latency = observation.latency

    var elapsed = perf_counter() - started
    var detail = String("fixed genome")
    if policy == "joint_reciprocal":
        detail = "shared history and adaptive side allocation"
    elif policy == "ablation_no_history":
        detail = "meta-policy ablated: random proposals"
    elif policy == "independent":
        detail = "separate AI/compute histories, no coupling"
    return PolicyOutcome(
        policy, seed, budget, best_rmse, best_latency, elapsed,
        budget, discoveries, pareto_count(observations), detail,
    )
