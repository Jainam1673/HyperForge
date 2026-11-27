"""M14 SciRL tests: validated simulator, safe actions, scientific decisions."""

from std.math import abs
from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from hyperforge.scirl.simulator import (
    default_env,
    step,
    sample_condition,
    field_error,
    heuristic_action,
    exact_field,
)
from hyperforge.scirl.agent import (
    run_experiment,
    train_q,
    evaluate_policy,
    RLConfig,
    mean_of,
)

comptime TOL = 1e-9


def test_simulator_contracts() raises:
    var env = default_env()
    var outcome = step(env, 2, 1.2, 1, 0)
    assert_true(outcome.terminated)
    assert_true(outcome.error > 0.0)
    assert_true(outcome.cost > 0.0)
    assert_true(outcome.reward < 0.0)
    with assert_raises():
        _ = step(env, 9, 1.2, 1, 0)
    with assert_raises():
        _ = step(env, 0, 1.2, 1, env.max_steps)
    var again = step(env, 2, 1.2, 1, 0)
    assert_equal(outcome.reward, again.reward)


def test_frequency_changes_best_resolution() raises:
    var env = default_env()
    var best_low = 0
    var low_value = Float64(-1e300)
    var best_high = 0
    var high_value = Float64(-1e300)
    for action in range(4):
        var low_reward = step(env, action, 1.2, 1, 0).reward
        var high_reward = step(env, action, 1.2, 7, 0).reward
        if low_reward > low_value:
            low_value = low_reward
            best_low = action
        if high_reward > high_value:
            high_value = high_reward
            best_high = action
    assert_true(best_low < best_high)
    assert_equal(heuristic_action(7), 3)


def test_holdout_conditions_are_disjoint() raises:
    var train = sample_condition(UInt64(42), 0, True)
    var heldout = sample_condition(UInt64(42), 0, False)
    assert_true(abs(train[0] - heldout[0]) > TOL)
    var high_train = sample_condition(UInt64(42), 60, True)
    var high_holdout = sample_condition(UInt64(42), 60, False)
    assert_equal(high_train[1], 7)
    assert_equal(high_holdout[1], 7)
    assert_true(abs(exact_field(0.5, 1.0, 1) - 1.0) < TOL)


def test_scientific_decision_beats_baselines() raises:
    var env = default_env()
    var outcome = run_experiment(env, 30, 8)
    assert_true(outcome.improvement_random > 0.0)
    assert_true(outcome.improvement_heuristic > 0.0)
    assert_true(outcome.learned_mean > outcome.random_mean)
    assert_true(outcome.learned_mean > outcome.heuristic_mean)
    assert_true(outcome.curve[len(outcome.curve) - 1] > outcome.curve[0])
    var config = RLConfig(0.2, 0.9, 0.3, 0.05, 10)
    var learned = train_q(env, config, UInt64(7))
    var first = evaluate_policy(env, learned[0], 8, UInt64(101))
    var second = evaluate_policy(env, learned[0], 8, UInt64(202))
    assert_true(abs(first - second) < TOL)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
