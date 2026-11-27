"""M18 meta-economy and causal evidence graph tests."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.sys import has_accelerator
from max.gpu.host import DeviceContext
from hyperforge.meta.causal import (
    CausalNode,
    edge_for_measurement,
    coupling_edge,
    RELATION_SUPPORTED,
    RELATION_HYPOTHESIZED,
)
from hyperforge.meta.economy import (
    run_economy,
    mean_gain,
    Evaluation,
    choose_side,
)


def test_causal_labels() raises:
    var hypothesis = CausalNode("h", "hypothesis", "claim", False)
    var run = CausalNode("r", "run", "trial", True)
    var supported = edge_for_measurement(hypothesis, run, True, "e1")
    assert_true(supported.relation == RELATION_SUPPORTED)
    var unverified = edge_for_measurement(hypothesis, run, False, "e2")
    assert_true(unverified.relation == RELATION_HYPOTHESIZED)
    var ai = CausalNode("a", "metric", "rmse", False)
    var compute = CausalNode("c", "metric", "latency", False)
    assert_true(coupling_edge(ai, compute).relation == RELATION_HYPOTHESIZED)


def test_allocation_is_testable() raises:
    var history = List[Evaluation]()
    history.append(Evaluation("ai", 0.2, 1.0, True, "d"))
    history.append(Evaluation("compute", 0.01, 1.0, True, "d"))
    assert_true(mean_gain(history, "ai") > mean_gain(history, "compute"))
    assert_true(choose_side("adaptive", 1, history, UInt64(42), True) == "ai")
    assert_true(choose_side("fixed", 1, history, UInt64(42), True) == "compute")
    assert_true(choose_side("ai_only", 0, history, UInt64(42), True) == "ai")


def test_economy_is_bounded_and_replayable() raises:
    comptime if not has_accelerator():
        return
    else:
        var ctx = DeviceContext()
        var fixed = run_economy("fixed", UInt64(42), 4, ctx, True)
        var adaptive = run_economy("adaptive", UInt64(42), 4, ctx, True)
        assert_equal(fixed.budget, 4)
        assert_equal(adaptive.budget, 4)
        assert_equal(fixed.ai_evaluations + fixed.compute_evaluations, 4)
        assert_equal(adaptive.ai_evaluations + adaptive.compute_evaluations, 4)
        assert_true(fixed.total_gain > 0.0)
        assert_true(len(fixed.edges) == 5)
        # AI-only gains are deterministic; GPU latency varies between runs.
        var first_ai = run_economy("ai_only", UInt64(42), 4, ctx, True)
        var again_ai = run_economy("ai_only", UInt64(42), 4, ctx, True)
        assert_true(abs64(first_ai.total_gain - again_ai.total_gain) < 1e-12)


def abs64(value: Float64) raises -> Float64:
    if value < 0.0:
        return -value
    return value


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
