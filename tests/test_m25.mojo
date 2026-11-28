"""M25 full AutoDL breadth tests."""

from std.testing import assert_equal, assert_true, TestSuite
from hyperforge.autodl.task import make_task
from hyperforge.autodl.model import valid_candidate
from hyperforge.autodl.full_search import (
    grid_candidates, proposals, run_full_search, FULL_SEARCH_SCHEMA,
)


def test_grid_and_proposals() raises:
    var grid = grid_candidates(8)
    assert_equal(len(grid), 8)
    for i in range(len(grid)):
        assert_true(valid_candidate(grid[i]))
    for policy in ["grid", "random", "adaptive", "multifidelity"]:
        var items = proposals(policy, 4, UInt64(42))
        assert_true(len(items) >= 2)
        for i in range(len(items)):
            assert_true(valid_candidate(items[i]))


def test_full_search_policies() raises:
    var task = make_task(UInt64(42))
    for policy in ["random", "multifidelity"]:
        var outcome = run_full_search(policy, task, 4, UInt64(42), 2)
        assert_equal(outcome.budget, 4)
        assert_equal(outcome.seeds, 2)
        assert_true(valid_candidate(outcome.best))
        assert_true(outcome.trained >= 1)
        assert_true(outcome.distinct >= 1)
        assert_true(outcome.test_loss > 0.0)
        assert_true(FULL_SEARCH_SCHEMA.byte_length() > 0)
    var multifidelity = run_full_search("multifidelity", task, 4, UInt64(42), 1)
    assert_true(multifidelity.fidelity_promotions >= 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
