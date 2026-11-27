"""M13 SciDL tests: field task, supervised training, baselines, honesty."""

from std.math import abs
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from hyperforge.scidl.task import make_task, features, target
from hyperforge.scidl.trainer import (
    run_experiment,
    field_errors,
    rmse,
    linear_coefficient,
    finite_difference_errors,
)
from hyperforge.autodl.model import ArchCandidate, init_model, predict

comptime TOL = 1e-6


def test_task_parameter_ranges_are_disjoint() raises:
    var task = make_task(UInt64(42))
    assert_equal(len(task.grid), 8)
    assert_equal(len(task.train_parameters), 12)
    assert_equal(len(task.test_parameters), 8)
    var max_train = task.train_parameters[len(task.train_parameters) - 1]
    var min_test = task.test_parameters[0]
    assert_true(max_train < min_test)
    var again = make_task(UInt64(42))
    assert_equal(task.train_parameters[0], again.train_parameters[0])


def test_domain_features_and_target() raises:
    var f = features(0.5, 1.0)
    assert_equal(f[0], 0.0)
    assert_equal(f[1], 0.0)
    from std.math import pi
    assert_true(abs(target(0.5, 1.0) - 1.0 / (pi * pi)) < TOL)


def test_baselines_are_real_and_reproducible() raises:
    var task = make_task(UInt64(42))
    var coefficient = linear_coefficient(task)
    assert_true(abs(coefficient - 1.0) < 1e-6)
    var fd = finite_difference_errors(task, task.test_parameters)
    assert_true(rmse(fd) < 1e-2)
    var candidate = ArchCandidate("c", 2, 8, 0.02, 8, "tanh", UInt64(42))
    var model = init_model(candidate)
    var errors = field_errors(model, task, task.test_parameters)
    assert_true(rmse(errors) > 0.0)


def test_experiment_reports_honest_comparison() raises:
    var outcome = run_experiment(UInt64(42))
    assert_equal(outcome.state, "TRAINED")
    assert_true(outcome.train_rmse > 0.0)
    assert_true(outcome.learned_rmse > 0.0)
    assert_true(outcome.learned_max_error > 0.0)
    assert_true(outcome.fd_rmse < outcome.learned_rmse)
    assert_true(outcome.linear_rmse < outcome.learned_rmse)
    assert_true(outcome.train_parameter_max < outcome.test_parameter_min)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
