"""Transparent experiment economy with matched budgets and causal evidence."""

from std.time import perf_counter
from max.gpu.host import DeviceContext
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.automl.dataset import load_csv, target_at
from hyperforge.automl.split import make_split
from hyperforge.automl.preprocess import fit_preprocessor, transform_row
from hyperforge.automl.models import Candidate, fit_model, predict, MODEL_LINEAR
from hyperforge.automl.metrics import compute_metrics
from hyperforge.gpu.kernels import run_vector_add_block
from hyperforge.meta.causal import (
    CausalNode,
    CausalEdge,
    edge_for_measurement,
    coupling_edge,
)

comptime ECONOMY_SCHEMA = "hyperforge-meta-economy-v1"
comptime DATASET = "/home/jack/Projects/HyperForge/examples/regression_linear.csv"
comptime COST_PER_EVALUATION = 1.0


struct Evaluation(Copyable, Movable):
    var side: String
    var gain: Float64
    var cost: Float64
    var valid: Bool
    var detail: String

    def __init__(out self, side: String, gain: Float64, cost: Float64, valid: Bool, detail: String):
        self.side = side
        self.gain = gain
        self.cost = cost
        self.valid = valid
        self.detail = detail


struct EconomyOutcome(Copyable, Movable):
    var policy: String
    var seed: UInt64
    var budget: Int
    var total_gain: Float64
    var ai_evaluations: Int
    var compute_evaluations: Int
    var wall_seconds: Float64
    var state: String
    var nodes: List[CausalNode]
    var edges: List[CausalEdge]

    def __init__(
        out self,
        policy: String,
        seed: UInt64,
        budget: Int,
        total_gain: Float64,
        ai_evaluations: Int,
        compute_evaluations: Int,
        wall_seconds: Float64,
        state: String,
        var nodes: List[CausalNode],
        var edges: List[CausalEdge],
    ):
        self.policy = policy
        self.seed = seed
        self.budget = budget
        self.total_gain = total_gain
        self.ai_evaluations = ai_evaluations
        self.compute_evaluations = compute_evaluations
        self.wall_seconds = wall_seconds
        self.state = state
        self.nodes = nodes^
        self.edges = edges^


def ai_rmse(iterations: Int) raises -> Float64:
    var dataset = load_csv(DATASET, "y")
    var split = make_split(dataset.rows, UInt64(42))
    var preprocessor = fit_preprocessor(dataset, split.train)
    var candidate = Candidate("economy", MODEL_LINEAR, iterations, 0.0, 0)
    var model = fit_model(candidate, dataset, split.train, preprocessor)
    var predictions = List[Float64]()
    var actuals = List[Float64]()
    for row in split.validation:
        predictions.append(predict(model, transform_row(preprocessor, dataset, row)))
        actuals.append(target_at(dataset, row))
    return compute_metrics(predictions, actuals).rmse


def evaluate_side(
    side: String, seed: UInt64, index: Int, mut ctx: DeviceContext, use_gpu: Bool
) raises -> Evaluation:
    if side == "ai":
        var coarse = ai_rmse(100)
        var refined = ai_rmse(300)
        var gain = coarse - refined
        var verified = gain if gain > 0.0 else 0.0
        return Evaluation("ai", verified, COST_PER_EVALUATION, True, "validation RMSE delta")
    if side == "compute":
        if not use_gpu:
            return Evaluation("compute", 0.0, COST_PER_EVALUATION, False, "GPU unavailable")
        var baseline = run_vector_add_block[1024](ctx, 256, 3)
        var candidate = run_vector_add_block[1024](ctx, 128, 3)
        if baseline.state != "PASS" or candidate.state != "PASS":
            return Evaluation("compute", 0.0, COST_PER_EVALUATION, False, "kernel correctness failed")
        var delta = baseline.kernel_median_seconds - candidate.kernel_median_seconds
        var verified = delta if delta > 0.0 else 0.0
        return Evaluation("compute", verified, COST_PER_EVALUATION, True, "kernel median delta")
    raise Error("unknown side: " + side)


def mean_gain(history: List[Evaluation], side: String) raises -> Float64:
    var total = Float64(0.0)
    var count = 0
    for i in range(len(history)):
        var item = history[i].copy()
        if item.valid and item.side == side:
            total += item.gain / item.cost
            count += 1
    if count == 0:
        return 0.0
    return total / Float64(count)


def choose_side(
    policy: String,
    index: Int,
    history: List[Evaluation],
    seed: UInt64,
    use_gpu: Bool,
) raises -> String:
    if policy == "ai_only":
        return String("ai")
    if not use_gpu:
        return String("ai")
    if policy == "fixed":
        return String("ai") if index % 2 == 0 else String("compute")
    if policy == "random":
        var rng = SplitMix64(derive_seed(seed, "economy-random", UInt64(index)))
        if Int(rng.next_below(UInt64(2))) == 0:
            return String("ai")
        return String("compute")
    # adaptive: larger observed verified gain per unit cost wins; ties favor AI.
    if mean_gain(history, "compute") > mean_gain(history, "ai"):
        return String("compute")
    return String("ai")


def run_economy(
    policy: String, seed: UInt64, budget: Int, mut ctx: DeviceContext, use_gpu: Bool
) raises -> EconomyOutcome:
    if budget < 1:
        raise Error("budget must be positive")
    var started = perf_counter()
    var history = List[Evaluation]()
    var total_gain = Float64(0.0)
    var ai_count = 0
    var compute_count = 0
    var nodes = List[CausalNode]()
    var edges = List[CausalEdge]()

    for index in range(budget):
        var side = choose_side(policy, index, history, seed, use_gpu)
        var result = evaluate_side(side, seed, index, ctx, use_gpu)
        history.append(result.copy())
        if result.valid:
            total_gain += result.gain
            if side == "ai":
                ai_count += 1
            else:
                compute_count += 1
        var run_id = "econ-" + policy + "-" + String(index)
        var hypothesis = CausalNode(
            "hyp-" + run_id, "hypothesis",
            "changing " + side + " yields verified improvement", False,
        )
        var run = CausalNode(run_id, "run", side + "|" + result.detail, True)
        nodes.append(hypothesis.copy())
        nodes.append(run.copy())
        edges.append(edge_for_measurement(
            hypothesis, run, result.valid and result.gain > 0.0, run_id
        ))

    var ai_metric = CausalNode("metric-ai", "metric", "validation RMSE", False)
    var compute_metric = CausalNode("metric-compute", "metric", "kernel median latency", False)
    nodes.append(ai_metric.copy())
    nodes.append(compute_metric.copy())
    edges.append(coupling_edge(ai_metric, compute_metric))

    var state = String("NO_IMPROVEMENT")
    if total_gain > 0.0:
        state = "IMPROVED"
    return EconomyOutcome(
        policy, seed, budget, total_gain, ai_count, compute_count,
        perf_counter() - started, state, nodes^, edges^,
    )
