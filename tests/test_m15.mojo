"""M15 Scientific Looper tests: validated, idempotent, terminal transitions."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from hyperforge.looper.state_machine import (
    can_transition,
    is_terminal,
    OBSERVE,
    FORMULATE,
    HYPOTHESIZE,
    VALIDATE_CONSTRAINTS,
    EXECUTE,
    MEASURE,
    VERIFY,
    COMPARE,
    LEARN,
    ACCEPTED,
    REJECTED,
    ROLLED_BACK,
)
from hyperforge.looper.engine import LoopRun, advance, decide, rollback, run_id

comptime TOL = 1e-9


def test_transition_rules() raises:
    assert_true(can_transition(OBSERVE, FORMULATE))
    assert_true(can_transition(VALIDATE_CONSTRAINTS, EXECUTE))
    assert_true(can_transition(LEARN, ACCEPTED))
    assert_false(can_transition(OBSERVE, EXECUTE))
    assert_false(can_transition(MEASURE, LEARN))
    assert_false(can_transition(ACCEPTED, OBSERVE))
    assert_true(is_terminal(REJECTED))
    assert_false(is_terminal(VERIFY))


def test_idempotency_and_budget() raises:
    var loop = LoopRun("run-test", "claim", 2)
    assert_true(advance(loop, FORMULATE, "planner", "why", "a", "b", "", "d"))
    assert_equal(len(loop.events), 1)
    assert_true(advance(loop, FORMULATE, "planner", "why", "a", "b", "", "d"))
    assert_equal(len(loop.events), 1)
    assert_true(advance(loop, HYPOTHESIZE, "planner", "different", "a", "b", "", "d"))
    assert_equal(loop.state, HYPOTHESIZE)
    assert_equal(len(loop.events), 2)


def test_terminal_decision_and_rollback() raises:
    var loop = LoopRun("run-test-2", "claim", 2)
    assert_false(decide(loop, ACCEPTED, "early", ""))
    assert_true(can_transition(loop.state, ROLLED_BACK))
    assert_true(rollback(loop, "invalid constraints"))
    assert_true(is_terminal(loop.state))
    assert_false(rollback(loop, "too late"))
    assert_false(decide(loop, REJECTED, "too late", ""))


def test_run_id_is_stable() raises:
    assert_equal(run_id("claim", UInt64(42)), run_id("claim", UInt64(42)))
    assert_false(run_id("claim", UInt64(42)) == run_id("other", UInt64(42)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
