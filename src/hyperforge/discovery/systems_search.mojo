"""Systems-side candidate search with measured objectives and Pareto handling."""

from std.time import perf_counter
from max.gpu.host import DeviceContext
from hyperforge.gpu.kernels import run_vector_add_block
from hyperforge.discovery.genome_v2 import (
    GenomeV2,
    valid_genome,
    genome_id,
    mutate_genome,
)

comptime SYSTEMS_SCHEMA = "hyperforge-systems-search-v1"
comptime REPETITIONS = 5
comptime VECTOR_SIZE = 1024


struct SystemsTrial(Copyable, Movable):
    var id: String
    var block_size: Int
    var error: Float64
    var kernel_median: Float64
    var end_to_end_median: Float64
    var bytes_per_second: Float64
    var state: String

    def __init__(
        out self,
        id: String,
        block_size: Int,
        error: Float64,
        kernel_median: Float64,
        end_to_end_median: Float64,
        bytes_per_second: Float64,
        state: String,
    ):
        self.id = id
        self.block_size = block_size
        self.error = error
        self.kernel_median = kernel_median
        self.end_to_end_median = end_to_end_median
        self.bytes_per_second = bytes_per_second
        self.state = state


struct SystemsOutcome(Copyable, Movable):
    var policy: String
    var budget: Int
    var best_id: String
    var best_kernel_median: Float64
    var best_end_to_end: Float64
    var pareto_count: Int
    var trials: Int
    var wall_seconds: Float64
    var detail: String
    var records: List[SystemsTrial]

    def __init__(
        out self,
        policy: String,
        budget: Int,
        best_id: String,
        best_kernel_median: Float64,
        best_end_to_end: Float64,
        pareto_count: Int,
        trials: Int,
        wall_seconds: Float64,
        detail: String,
        var records: List[SystemsTrial],
    ):
        self.policy = policy
        self.budget = budget
        self.best_id = best_id
        self.best_kernel_median = best_kernel_median
        self.best_end_to_end = best_end_to_end
        self.pareto_count = pareto_count
        self.trials = trials
        self.wall_seconds = wall_seconds
        self.detail = detail
        self.records = records^


def default_genome(seed: UInt64) raises -> GenomeV2:
    return GenomeV2("linear_gd", "vector_add", 256, VECTOR_SIZE, seed)


def evaluate_genome(
    mut ctx: DeviceContext, genome: GenomeV2
) raises -> SystemsTrial:
    if not valid_genome(genome):
        raise Error("invalid systems genome")
    # Only the runtime block gene has a measured execution path in this slice.
    # The AI gene is carried for later coupling and is not claimed as measured.
    var result = run_vector_add_block[VECTOR_SIZE](
        ctx, genome.block_size, REPETITIONS
    )
    return SystemsTrial(
        genome_id(genome), genome.block_size, Float64(result.max_error),
        result.kernel_median_seconds, result.end_to_end_median_seconds,
        result.bytes_per_second, result.state,
    )


def pareto_count(records: List[SystemsTrial]) raises -> Int:
    var count = 0
    for i in range(len(records)):
        var a = records[i].copy()
        if a.state != "PASS":
            continue
        var dominated = False
        for j in range(len(records)):
            var b = records[j].copy()
            if i == j or b.state != "PASS":
                continue
            if (
                b.kernel_median <= a.kernel_median
                and b.end_to_end_median <= a.end_to_end_median
                and (b.kernel_median < a.kernel_median or b.end_to_end_median < a.end_to_end_median)
            ):
                dominated = True
                break
        if not dominated:
            count += 1
    return count


def run_systems_search(
    mut ctx: DeviceContext, policy: String, budget: Int, seed: UInt64
) raises -> SystemsOutcome:
    if budget < 1:
        raise Error("budget must be positive")
    var started = perf_counter()
    var records = List[SystemsTrial]()
    var best_id = String("")
    var best_latency = Float64(1e300)
    var best_end_to_end = Float64(1e300)

    var evaluations = budget
    if policy == "fixed":
        evaluations = 1
    for index in range(evaluations):
        var genome = default_genome(seed)
        if policy == "random":
            genome = mutate_genome(genome, "runtime", seed, index)
        elif policy == "adaptive" and index > 0:
            genome = mutate_genome(genome, "runtime", seed, index + 1000)
        var trial = evaluate_genome(ctx, genome)
        records.append(trial.copy())
        if trial.state == "PASS" and trial.kernel_median < best_latency:
            best_latency = trial.kernel_median
            best_end_to_end = trial.end_to_end_median
            best_id = trial.id

    var detail = String("systems-only search over measured launch configuration")
    if policy == "fixed":
        detail = "fixed block 256 reference"
    return SystemsOutcome(
        policy, evaluations, best_id, best_latency, best_end_to_end,
        pareto_count(records), len(records), perf_counter() - started,
        detail, records^,
    )
