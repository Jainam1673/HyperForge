"""M27 full SciAI breadth tests."""

from std.testing import assert_equal, assert_true, TestSuite
from hyperforge.sciai.full import (
    problems, solution, basis, estimate_parameter, run_problem,
    finite_difference_gradient, parameter_derivative, jet_gradient,
    observations, rmse, SCIA_FULL_SCHEMA,
)


def test_problems_and_solutions() raises:
    var families = problems()
    assert_equal(len(families), 3)
    for i in range(len(families)):
        var problem = families[i].copy()
        assert_true(solution(problem, 0.5, 1.0) > 0.0)
        var obs = observations(problem, 1.0, UInt64(42))
        var xs = obs[0].copy()
        var ys = obs[1].copy()
        assert_equal(len(xs), len(ys))
        var estimate = estimate_parameter(problem, xs, ys)
        assert_true(estimate > 0.4 and estimate < 1.6)


def test_gradients_and_breadth() raises:
    var families = problems()
    for i in range(len(families)):
        var problem = families[i].copy()
        var outcome = run_problem(problem, UInt64(42), 1.0)
        assert_equal(outcome.problem, problem.name)
        assert_true(outcome.interval_low <= outcome.estimated_parameter)
        assert_true(outcome.interval_high >= outcome.estimated_parameter)
        assert_true(outcome.field_rmse <= outcome.linear_rmse)
        assert_true(outcome.bandit_return > outcome.random_return)
        assert_true(outcome.analytic_gradient_error < 1e-8)
        assert_true(outcome.jet_gradient_error < 1e-8)
        assert_true(outcome.operator_error < 0.05)
        var fd = finite_difference_gradient(problem, 0.37, 1.0)
        var analytic = parameter_derivative(problem, 0.37, 1.0)
        assert_true(abs64(fd - analytic) < 1e-8)
        var jet = jet_gradient(problem, 0.37, 1.0)
        assert_true(abs64(jet - analytic) < 1e-8)
    assert_true(SCIA_FULL_SCHEMA.byte_length() > 0)


def abs64(value: Float64) raises -> Float64:
    if value < 0.0:
        return -value
    return value


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
