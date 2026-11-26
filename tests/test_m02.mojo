"""M02 dataset, split, preprocessing, metrics, model, and search tests.

Run with: pixi run mojo run -I src tests/test_m02.mojo
"""

from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from std.os import remove
from std.pathlib import Path
from std.math import abs
from hyperforge.automl.dataset import (
    Dataset,
    load_csv,
    value_at,
    is_missing_at,
    target_at,
)
from hyperforge.automl.split import make_split
from hyperforge.automl.preprocess import fit_preprocessor, transform_row
from hyperforge.automl.metrics import compute_metrics
from hyperforge.automl.models import (
    Candidate,
    fit_model,
    predict,
    MODEL_BASELINE,
    MODEL_LINEAR,
    MODEL_RIDGE,
    MODEL_KNN,
)
from hyperforge.automl.search import make_candidates
from hyperforge.experiment.trial import Trial, trial_to_fields, trial_from_fields
from hyperforge.evidence.record import serialize_record, parse_record

comptime EXAMPLE = "/home/jack/Projects/HyperForge/examples/regression_linear.csv"


def repeated_rows(row: String, times: Int) raises -> String:
    var out = String("")
    for _ in range(times):
        out += row
    return out


def write_temp_csv(path: String, content: String) raises -> None:
    var handle = open(path, "w")
    handle.write(content)
    handle.close()


def linear_csv(path: String) raises -> None:
    var content = String("x,y\n")
    for i in range(12):
        var x = Float64(i) + 1.0
        content += String(x) + "," + String(2.0 * x + 1.0) + "\n"
    write_temp_csv(path, content)


def test_dataset_load_example() raises:
    var d = load_csv(EXAMPLE, "y")
    assert_equal(d.rows, 24)
    assert_equal(d.cols, 3)
    assert_equal(d.fingerprint, "286357448ec34b94")
    assert_true(abs(value_at(d, 0, 0) - 0.25) < 1e-12)
    assert_true(abs(target_at(d, 0) - 2.5) < 1e-12)


def test_dataset_rejects_bad_input() raises:
    var bad_header = "/tmp/opencode/m02_bad_header.csv"
    write_temp_csv(bad_header, "x,x,y\n" + repeated_rows("1,2,3\n", 8))
    with assert_raises():
        _ = load_csv(bad_header, "y")
    remove(bad_header)

    var bad_target = "/tmp/opencode/m02_bad_target.csv"
    write_temp_csv(bad_target, "x,z\n" + repeated_rows("1,2\n", 8))
    with assert_raises():
        _ = load_csv(bad_target, "y")
    remove(bad_target)

    var short_row = "/tmp/opencode/m02_short.csv"
    write_temp_csv(short_row, "x,y\n" + "1,2\n" + "1\n" + repeated_rows("1,2\n", 7))
    with assert_raises():
        _ = load_csv(short_row, "y")
    remove(short_row)

    var non_numeric = "/tmp/opencode/m02_nonnum.csv"
    write_temp_csv(non_numeric, "x,y\n" + "abc,2\n" + repeated_rows("1,2\n", 7))
    with assert_raises():
        _ = load_csv(non_numeric, "y")
    remove(non_numeric)


def test_dataset_missing_values() raises:
    var path = "/tmp/opencode/m02_missing.csv"
    var content = String("x,y\n")
    for i in range(12):
        if i == 0:
            content += ",3\n"
        else:
            content += String(i) + "," + String(i) + "\n"
    write_temp_csv(path, content)
    var d = load_csv(path, "y")
    assert_true(is_missing_at(d, 0, 0))
    assert_false(is_missing_at(d, 1, 0))
    remove(path)


def test_split_is_deterministic_and_disjoint() raises:
    var a = make_split(24, UInt64(42))
    var b = make_split(24, UInt64(42))
    var c = make_split(24, UInt64(43))
    assert_equal(len(a.train), 14)
    assert_equal(len(a.validation), 4)
    assert_equal(len(a.test), 6)
    for i in range(len(a.train)):
        assert_equal(a.train[i], b.train[i])
    assert_true(a.train[0] != c.train[0] or a.validation[0] != c.validation[0])
    var seen = List[Int]()
    for row in a.train:
        seen.append(row)
    for row in a.validation:
        seen.append(row)
    for row in a.test:
        seen.append(row)
    assert_equal(len(seen), 24)
    for i in range(len(seen)):
        for j in range(i + 1, len(seen)):
            assert_true(seen[i] != seen[j])


def test_preprocess_is_train_only() raises:
    var path = "/tmp/opencode/m02_prep.csv"
    linear_csv(path)
    var d = load_csv(path, "y")
    var split = make_split(d.rows, UInt64(7))
    var prep = fit_preprocessor(d, split.train)
    var total = Float64(0.0)
    for row in split.train:
        var x = transform_row(prep, d, row)
        total += x[0]
    assert_true(abs(total / Float64(len(split.train))) < 1e-12)
    var expected_target_mean = Float64(0.0)
    for row in split.train:
        expected_target_mean += target_at(d, row)
    expected_target_mean /= Float64(len(split.train))
    assert_true(abs(prep.target_mean - expected_target_mean) < 1e-12)
    remove(path)


def test_metrics_known_values() raises:
    var perfect = compute_metrics([1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
    assert_true(abs(perfect.mae) < 1e-12)
    assert_true(abs(perfect.rmse) < 1e-12)
    assert_true(abs(perfect.r2 - 1.0) < 1e-12)
    var constant = compute_metrics([2.0, 2.0, 2.0], [2.0, 2.0, 2.0])
    assert_equal(constant.r2, 0.0)
    with assert_raises():
        _ = compute_metrics([], [])
    with assert_raises():
        _ = compute_metrics([1.0], [1.0, 2.0])
    with assert_raises():
        _ = compute_metrics([Float64("nan")], [1.0])


def test_linear_recovers_relation() raises:
    var path = "/tmp/opencode/m02_linear.csv"
    linear_csv(path)
    var d = load_csv(path, "y")
    var split = make_split(d.rows, UInt64(1))
    var prep = fit_preprocessor(d, split.train)
    var candidate = Candidate("c", MODEL_LINEAR, 600, 0.0, 0)
    var model = fit_model(candidate, d, split.train, prep)
    var x = transform_row(prep, d, split.test[0])
    assert_true(abs(predict(model, x) - target_at(d, split.test[0])) < 1e-4)
    remove(path)


def test_baseline_and_knn() raises:
    var path = "/tmp/opencode/m02_models.csv"
    linear_csv(path)
    var d = load_csv(path, "y")
    var split = make_split(d.rows, UInt64(3))
    var prep = fit_preprocessor(d, split.train)
    var baseline = fit_model(Candidate("b", MODEL_BASELINE, 0, 0.0, 0), d, split.train, prep)
    var empty = List[Float64]()
    assert_true(abs(predict(baseline, empty) - prep.target_mean) < 1e-12)

    var knn = fit_model(Candidate("k", MODEL_KNN, 0, 0.0, 1), d, split.train, prep)
    var row = split.train[0]
    var x = transform_row(prep, d, row)
    assert_true(abs(predict(knn, x) - target_at(d, row)) < 1e-9)
    remove(path)


def test_search_is_deterministic() raises:
    var a = make_candidates(UInt64(42), 6)
    var b = make_candidates(UInt64(42), 6)
    assert_equal(len(a), 6)
    assert_equal(a[0].kind, MODEL_BASELINE)
    for i in range(6):
        assert_equal(a[i].id, b[i].id)
        assert_equal(a[i].kind, b[i].kind)


def test_trial_roundtrip() raises:
    var trial = Trial("exp", "cand", MODEL_LINEAR, 2, "validation", 0.1, 0.2, 0.9, "SUCCEEDED", "detail")
    var line = serialize_record(UInt64(1), "trial", trial_to_fields(trial))
    var restored = trial_from_fields(parse_record(line).fields)
    assert_equal(restored.candidate_id, "cand")
    assert_true(abs(restored.rmse - 0.2) < 1e-12)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
