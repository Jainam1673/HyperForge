"""M09 AutoRL tests: environment contracts, tabular RL, and evaluation gate."""

from std.math import abs
from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from hyperforge.autorl.environment import (
    grid_4x4,
    step,
    state_count,
    GOAL_REWARD,
)
from hyperforge.autorl.tabular import (
    RLConfig,
    value_iteration,
    q_from_values,
    greedy_action,
    train_q_learning,
    evaluate_policy,
    random_policy,
)
from hyperforge.autorl.experiment import run_rl_experiment, mean_of, std_of

comptime TOL = 1e-6


def test_environment_contracts() raises:
    var env = grid_4x4()
    assert_equal(state_count(env), 16)
    var first = step(env, env.start, 1, 0)
    assert_equal(first.next_state, 1)
    assert_equal(first.reward, -1.0)
    assert_false(first.terminated)
    assert_false(first.truncated)
    var blocked = step(env, 3, 1, 0)
    assert_equal(blocked.next_state, 3)
    with assert_raises():
        _ = step(env, env.start, 9, 0)
    with assert_raises():
        _ = step(env, env.goal, 0, 0)
    var truncated = step(env, 14, 1, env.max_steps - 1)
    assert_true(truncated.truncated or truncated.terminated)


def test_goal_termination_reward() raises:
    var env = grid_4x4()
    var result = step(env, 14, 1, 0)
    assert_equal(result.next_state, 15)
    assert_true(result.terminated)
    assert_equal(result.reward, GOAL_REWARD)


def test_value_iteration_is_optimal() raises:
    var env = grid_4x4()
    var values = value_iteration(env, 0.9, 1e-8, 200)
    var q = q_from_values(env, values, 0.9)
    var optimal_return = evaluate_policy(env, q, 20, UInt64(7))
    assert_true(abs(optimal_return - 5.0) < TOL)
    assert_equal(greedy_action(q, 14), 1)


def test_evaluation_is_separate_from_training() raises:
    var env = grid_4x4()
    var config = RLConfig(0.2, 0.9, 0.3, 0.05, 50, 10)
    var learned = train_q_learning(env, config, UInt64(42))
    var q = learned[0].copy()
    var snapshot = q.copy()
    var first = evaluate_policy(env, q, 10, UInt64(101))
    var second = evaluate_policy(env, q, 10, UInt64(202))
    assert_true(abs(first - second) < TOL)
    for i in range(len(snapshot)):
        assert_true(abs(snapshot[i] - q[i]) < TOL)


def test_learned_policy_beats_random_over_seeds() raises:
    var env = grid_4x4()
    var outcome = run_rl_experiment(env, 40, 10)
    assert_true(outcome.improvement > 0.0)
    assert_true(outcome.test_mean > outcome.random_mean)
    assert_true(abs(outcome.test_mean - outcome.optimal_mean) < 1e-6)
    assert_equal(outcome.seeds, 5)
    assert_true(outcome.curve[len(outcome.curve) - 1] > outcome.curve[0])
    var values: List[Float64] = [1.0, 2.0, 3.0]
    assert_true(abs(mean_of(values) - 2.0) < TOL)
    assert_true(std_of(values, 2.0) > 0.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
