"""M26 full AutoRL breadth tests."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from hyperforge.autorl.full import (
    run_full_rl, make_environment, forbidden_action, grid_5x5,
    grid_4x4_holdout, FULL_RL_SCHEMA,
)
from hyperforge.autorl.environment import state_count, step

def test_environments_and_safety() raises:
    var env = make_environment("grid_4x4")
    assert_equal(state_count(env), 16)
    var other = make_environment("grid_5x5")
    assert_equal(state_count(other), 25)
    assert_equal(state_count(grid_4x4_holdout()), 16)
    assert_true(forbidden_action(env, 4) >= 0)
    var result = step(env, 0, 1, 0)
    assert_true(result.next_state >= 0)

def test_algorithms_and_heldout() raises:
    for algorithm in ["q_learning", "sarsa", "double_q", "value_iteration", "random"]:
        var outcome = run_full_rl(algorithm, "grid_4x4", 30, 6, UInt64(42), 2)
        assert_equal(outcome.algorithm, algorithm)
        assert_equal(outcome.episodes, 30)
        assert_true(outcome.mean_return == outcome.mean_return)
        assert_true(outcome.holdout_return <= outcome.optimal_return)
        assert_true(outcome.regret >= 0.0)
        assert_equal(outcome.safety_violations, 0)
        assert_true(FULL_RL_SCHEMA.byte_length() > 0)

def test_optimal_algorithm_beats_random() raises:
    var optimal = run_full_rl("value_iteration", "grid_4x4", 30, 6, UInt64(42), 2)
    var random = run_full_rl("random", "grid_4x4", 30, 6, UInt64(42), 2)
    assert_true(optimal.mean_return > random.mean_return)
    assert_true(optimal.success_rate >= random.success_rate)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
