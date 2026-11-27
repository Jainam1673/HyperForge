"""M20 bounded config-only RSI tests."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std import os
from std.pathlib import Path
from hyperforge.automl.dataset import load_csv
from hyperforge.automl.split import make_split
from hyperforge.automl.preprocess import fit_preprocessor
from hyperforge.automl.models import MODEL_LINEAR
from hyperforge.rsi.protected import (
    default_protected_config,
    default_protocol,
    verify_protected_config,
    verify_protocol,
)
from hyperforge.rsi.candidate import (
    ConfigCandidate,
    make_candidate,
    propose,
    valid_candidate,
    candidate_size,
)
from hyperforge.rsi.loop import (
    within_bounds,
    rmse_on,
    independent_rmse,
    run_rsi,
    rollback,
    DECISION_DEFER,
    DECISION_ROLLBACK,
)


def temp_workspace() raises -> String:
    var path = String("/tmp/opencode/hf-rsi-unit")
    if not Path(path).exists():
        os.mkdir(path)
    var experiments = path + "/experiments"
    if not Path(experiments).exists():
        os.mkdir(experiments)
    var journal = experiments + "/hf-journal.hfj"
    if Path(journal).exists():
        os.remove(journal)
    return path


def test_protected_checksums() raises:
    var baseline = default_protected_config()
    assert_true(verify_protected_config(baseline))
    var tampered = baseline.copy()
    tampered.iterations = 999
    assert_false(verify_protected_config(tampered))

    var protocol = default_protocol()
    assert_true(verify_protocol(protocol))
    var bad_protocol = protocol.copy()
    bad_protocol.max_trials = 999
    assert_false(verify_protocol(bad_protocol))


def test_candidate_bounds_and_proposals() raises:
    var candidate = make_candidate(MODEL_LINEAR, 400, 0.01, 3)
    assert_true(valid_candidate(candidate))
    assert_true(candidate_size(candidate) > 0)
    assert_true(within_bounds(candidate, default_protocol()))
    assert_false(valid_candidate(make_candidate("bogus", 200, 0.0, 1)))
    assert_false(valid_candidate(make_candidate(MODEL_LINEAR, 10, 0.0, 1)))
    var oversized = ConfigCandidate("x" * 5000, 200, 0.0, 1, "id")
    assert_false(within_bounds(oversized, default_protocol()))

    for index in range(8):
        var proposal = propose(UInt64(42), index)
        assert_true(valid_candidate(proposal))
    var first = propose(UInt64(42), 0)
    var again = propose(UInt64(42), 0)
    assert_equal(first.id, again.id)


def test_independent_verifier_agrees() raises:
    var dataset = load_csv(
        "/home/jack/Projects/HyperForge/examples/regression_linear.csv", "y"
    )
    var split = make_split(dataset.rows, UInt64(42))
    var preprocessor = fit_preprocessor(dataset, split.train)
    var primary = rmse_on(
        MODEL_LINEAR, 200, 0.0, 0, dataset, split.test, preprocessor
    )
    var verified = independent_rmse(
        MODEL_LINEAR, 200, 0.0, 0, dataset, split.test, preprocessor
    )
    assert_true(abs64(verified - primary) < 1e-10)


def abs64(value: Float64) raises -> Float64:
    if value < 0.0:
        return -value
    return value


def test_budget_ceiling_and_authorization() raises:
    var workspace = temp_workspace()
    var dry = run_rsi(workspace, 100, False, UInt64(42))
    assert_equal(dry.budget, 12)
    assert_equal(dry.trials, 12)
    assert_equal(dry.accepted, 0)
    assert_true(dry.deferred > 0)
    assert_true(dry.state == "AWAITING_AUTHORIZATION")

    var applied = run_rsi(workspace, 12, True, UInt64(42))
    assert_true(applied.accepted > 0)
    assert_true(applied.state == "ACCEPTED")
    assert_equal(applied.accepted + applied.rejected + applied.deferred, applied.trials)

    var recovered = rollback(workspace, True, "unit recovery")
    assert_true(recovered.decision == DECISION_ROLLBACK)
    assert_true(recovered.candidate_config == "linear_gd|200|0.0|0")

    var blocked = rollback(workspace, False, "unit recovery")
    assert_true(blocked.decision == DECISION_DEFER)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
