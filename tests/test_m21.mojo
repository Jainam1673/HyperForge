"""M21 hardening tests: path and CSV input ceilings."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from hyperforge.hardening import (
    validate_path,
    enforce_csv_limits,
    hardening_summary,
    MAX_CSV_BYTES,
    MAX_CSV_ROWS,
    MAX_CSV_COLS,
)
from hyperforge.automl.dataset import load_csv

comptime DATASET = "/home/jack/Projects/HyperForge/examples/regression_linear.csv"


def test_path_validation() raises:
    assert_true(validate_path("./workspace"))
    assert_true(validate_path("workspace-v1"))
    assert_true(validate_path("/tmp/opencode/hf-workspace"))
    assert_false(validate_path(""))
    assert_false(validate_path("../escape"))
    assert_false(validate_path("a/../b"))
    assert_false(validate_path("a/.."))
    assert_false(validate_path(String("a\0b")))
    assert_false(validate_path("x" * 5000))


def test_csv_limits() raises:
    assert_true(enforce_csv_limits(DATASET, MAX_CSV_BYTES, MAX_CSV_ROWS, MAX_CSV_COLS))
    assert_false(enforce_csv_limits(DATASET, 10, MAX_CSV_ROWS, MAX_CSV_COLS))
    assert_false(enforce_csv_limits(DATASET, MAX_CSV_BYTES, 2, MAX_CSV_COLS))
    assert_false(enforce_csv_limits(DATASET, MAX_CSV_BYTES, MAX_CSV_ROWS, 2))
    assert_false(enforce_csv_limits("/no/such/file.csv", MAX_CSV_BYTES, MAX_CSV_ROWS, MAX_CSV_COLS))
    assert_false(enforce_csv_limits("../escape.csv", MAX_CSV_BYTES, MAX_CSV_ROWS, MAX_CSV_COLS))


def test_hardened_loader_still_reads_valid_csv() raises:
    var dataset = load_csv(DATASET, "y")
    assert_equal(dataset.rows, 24)
    assert_equal(dataset.cols, 3)
    assert_true(hardening_summary().byte_length() > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
