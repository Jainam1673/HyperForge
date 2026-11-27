"""M12 SciML tests: registry, forward solver, inverse identification, baselines."""

from std.math import abs
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from hyperforge.sciml.problem import (
    registered_problem,
    evaluation_grid,
    exact_solution,
    finite_difference_solution,
)
from hyperforge.sciml.inverse import (
    observation_points,
    observations_with_noise,
    estimate_parameter,
    run_experiment,
    root_mean_square,
)

comptime TOL = 1e-3


def test_registry_metadata() raises:
    var problem = registered_problem()
    assert_equal(problem.name, "poisson_amplitude_1d")
    assert_true(problem.boundary.byte_length() > 0)
    assert_true(problem.units.byte_length() > 0)
    assert_true(problem.assumptions.byte_length() > 0)
    assert_true(problem.reference.byte_length() > 0)
    assert_equal(problem.true_parameter, 1.0)


def test_forward_solver_matches_analytic() raises:
    var problem = registered_problem()
    var grid = evaluation_grid(problem)
    var solution = finite_difference_solution(problem, problem.true_parameter, grid)
    var errors = List[Float64]()
    for i in range(len(grid)):
        errors.append(solution[i] - exact_solution(grid[i], problem.true_parameter))
    assert_true(root_mean_square(errors) < TOL)


def test_observations_and_inverse_identification() raises:
    var problem = registered_problem()
    var points = observation_points(problem, 12)
    var observed = observations_with_noise(problem, points, UInt64(42))
    var again = observations_with_noise(problem, points, UInt64(42))
    assert_equal(len(observed), 12)
    for i in range(len(observed)):
        assert_equal(observed[i], again[i])
    var train = List[Int]()
    for i in range(7):
        train.append(i)
    var parameter = estimate_parameter(problem, points, observed, train)
    assert_true(abs(parameter - problem.true_parameter) < 0.05)


def test_experiment_beats_constant_baseline() raises:
    var problem = registered_problem()
    var outcome = run_experiment(problem, UInt64(42))
    assert_equal(outcome.train_count, 7)
    assert_equal(outcome.heldout_count, 5)
    assert_true(outcome.parameter_error < 0.05)
    assert_true(outcome.parameter_std > 0.0)
    assert_true(outcome.inverse_exact_l2 < outcome.constant_exact_l2)
    assert_true(outcome.hybrid_exact_l2 < outcome.constant_exact_l2)
    assert_true(outcome.finite_difference_l2 < TOL)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
