"""M03 adaptive optimization tests.

Run with: pixi run mojo run -I src tests/test_m03.mojo
"""

from std.math import abs
from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from std.os import mkdir, remove
from std.pathlib import Path
from hyperforge.automl.models import (
    Candidate,
    MODEL_BASELINE,
    MODEL_LINEAR,
    MODEL_RIDGE,
    MODEL_KNN,
)
from hyperforge.optimization.space import validate_candidate, prior_candidate
from hyperforge.optimization.tpe import TpeSampler
from hyperforge.optimization.loop import run_adaptive, run_random_baseline
from hyperforge.evidence.record import serialize_record, parse_record

comptime EXAMPLE = "/home/jack/Projects/HyperForge/examples/regression_linear.csv"


def make_workspace(path: String) raises -> None:
    if Path(path).exists():
        return
    mkdir(path)
    mkdir(path + "/experiments")
    mkdir(path + "/artifacts")
    var config = open(path + "/hyperforge.toml", "w")
    config.write("schema=\"hyperforge-workspace-v1\"\nversion=1\n")
    config.close()


def test_validation_rules() raises:
    assert_true(validate_candidate(Candidate("a", MODEL_BASELINE, 0, 0.0, 0)))
    assert_true(validate_candidate(Candidate("b", MODEL_LINEAR, 300, 0.0, 0)))
    assert_true(validate_candidate(Candidate("c", MODEL_RIDGE, 300, 0.25, 0)))
    assert_true(validate_candidate(Candidate("d", MODEL_KNN, 0, 0.0, 3)))
    assert_false(validate_candidate(Candidate("e", "unknown", 300, 0.0, 0)))
    assert_false(validate_candidate(Candidate("f", MODEL_LINEAR, 50, 0.0, 0)))
    assert_false(validate_candidate(Candidate("g", MODEL_LINEAR, 300, 0.5, 0)))
    assert_false(validate_candidate(Candidate("h", MODEL_KNN, 300, 0.0, 3)))
    assert_false(validate_candidate(Candidate("i", MODEL_KNN, 0, 0.0, 9)))
    assert_false(validate_candidate(Candidate("", MODEL_LINEAR, 300, 0.0, 0)))


def test_prior_is_deterministic() raises:
    var a = prior_candidate(UInt64(42), 7)
    var b = prior_candidate(UInt64(42), 7)
    var c = prior_candidate(UInt64(43), 7)
    assert_equal(a.id, b.id)
    assert_equal(a.kind, b.kind)
    assert_false(a.id == c.id)


def test_feedback_is_connected() raises:
    """Regression test: if observations are ignored, this assertion must fail."""
    var with_feedback = TpeSampler(UInt64(11), True)
    var no_feedback = TpeSampler(UInt64(11), False)
    for i in range(6):
        with_feedback.observe(Candidate("good" + String(i), MODEL_LINEAR, 200 + i, 0.0, 0), 0.1 + Float64(i) / 100.0)
        with_feedback.observe(Candidate("bad" + String(i), MODEL_KNN, 0, 0.0, i + 1), 5.0 + Float64(i))
        no_feedback.observe(Candidate("good" + String(i), MODEL_LINEAR, 200 + i, 0.0, 0), 0.1 + Float64(i) / 100.0)
        no_feedback.observe(Candidate("bad" + String(i), MODEL_KNN, 0, 0.0, i + 1), 5.0 + Float64(i))

    var feedback_linear = 0
    var prior_linear = 0
    var differing = 0
    for i in range(24):
        var guided = with_feedback.propose(i)
        var unguided = no_feedback.propose(i)
        assert_true(validate_candidate(guided))
        assert_true(validate_candidate(unguided))
        if guided.kind == MODEL_LINEAR:
            feedback_linear += 1
        if unguided.kind == MODEL_LINEAR:
            prior_linear += 1
        if guided.id != unguided.id:
            differing += 1
    assert_true(feedback_linear > prior_linear)
    assert_true(differing > 0)


def test_observations_update_state() raises:
    var sampler = TpeSampler(UInt64(5), True)
    assert_equal(sampler.observed_count(), 0)
    sampler.observe(Candidate("a", MODEL_LINEAR, 300, 0.0, 0), 2.0)
    sampler.observe(Candidate("b", MODEL_RIDGE, 300, 0.1, 0), 1.0)
    assert_equal(sampler.observed_count(), 2)
    assert_true(abs(sampler.best_rmse() - 1.0) < 1e-12)


def test_adaptive_run_persists_state() raises:
    var workspace = "/tmp/opencode/m03_workspace"
    var marker = workspace + "/experiments/hf-journal.hfj"
    if Path(marker).exists():
        remove(marker)
    make_workspace(workspace)
    var outcome = run_adaptive(workspace, EXAMPLE, "y", 4, UInt64(9))
    assert_equal(outcome.succeeded, 4)
    assert_equal(outcome.failed, 0)
    assert_equal(outcome.invalid, 0)
    assert_true(outcome.test_rmse > 0.0)
    var journal_content = open(marker, "r").read()
    var state_count = 0
    for line in journal_content.split("\n"):
        var text = String(line)
        if "|optimizer|" in text:
            state_count += 1
    assert_equal(state_count, 4)
    remove(marker)


def test_baseline_is_matched_and_real() raises:
    var adaptive = run_adaptive("/tmp/opencode/m03_workspace", EXAMPLE, "y", 3, UInt64(21))
    var random = run_random_baseline(EXAMPLE, "y", 3, UInt64(21))
    assert_true(adaptive.test_rmse > 0.0)
    assert_true(random.test_rmse > 0.0)
    assert_true(random.succeeded <= 3)
    remove("/tmp/opencode/m03_workspace/experiments/hf-journal.hfj")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
