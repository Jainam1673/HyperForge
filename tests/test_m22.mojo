"""M22 monolithic AutoML tests: all declared algorithms and metrics."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from hyperforge.automl.dataset import load_csv
from hyperforge.automl.split import make_split
from hyperforge.automl.preprocess import fit_preprocessor, transform_row
from hyperforge.automl.full_models import (
    FullCandidate,
    fit_model_full,
    predict_full,
    valid_candidate,
    is_classification_kind,
    F_BASELINE, F_LINEAR, F_RIDGE, F_LASSO, F_ELASTIC, F_HUBER,
    F_POLY, F_KNN_REG, F_TREE_REG, F_FOREST_REG, F_GB_REG,
    F_LOGISTIC, F_NB, F_KNN_CLS, F_TREE_CLS, F_FOREST_CLS,
    F_KMEANS, F_PCA,
)
from hyperforge.automl.full_metrics import compute_full_metrics
from hyperforge.automl.full_validation import (
    detect_classification, kfold_plans, train_from_fold,
    make_candidates, grid_candidates, all_kinds,
)

comptime REG = "/home/jack/Projects/HyperForge/examples/regression_linear.csv"
comptime CLS = "/home/jack/Projects/HyperForge/examples/classification_binary.csv"


def test_all_regression_models_train_and_predict() raises:
    var dataset = load_csv(REG, "y")
    var split = make_split(dataset.rows, UInt64(42))
    var preprocessor = fit_preprocessor(dataset, split.train)
    for kind in [
        F_BASELINE, F_LINEAR, F_RIDGE, F_LASSO, F_ELASTIC, F_HUBER,
        F_POLY, F_KNN_REG, F_TREE_REG, F_FOREST_REG, F_GB_REG,
        F_KMEANS, F_PCA,
    ]:
        var candidate = FullCandidate("t", kind, 60, 0.01, 3, 2)
        assert_true(valid_candidate(candidate))
        var model = fit_model_full(candidate, dataset, split.train, preprocessor, UInt64(42))
        var x = transform_row(preprocessor, dataset, split.validation[0])
        var prediction = predict_full(model, x)
        assert_true(prediction == prediction)


def test_all_classification_models_train_and_predict() raises:
    var dataset = load_csv(CLS, "y")
    var split = make_split(dataset.rows, UInt64(42))
    var preprocessor = fit_preprocessor(dataset, split.train)
    assert_true(detect_classification(dataset, split.train))
    for kind in [F_LOGISTIC, F_NB, F_KNN_CLS, F_TREE_CLS, F_FOREST_CLS]:
        assert_true(is_classification_kind(kind))
        var candidate = FullCandidate("t", kind, 80, 0.01, 3, 2)
        var model = fit_model_full(candidate, dataset, split.train, preprocessor, UInt64(42))
        var x = transform_row(preprocessor, dataset, split.validation[0])
        var prediction = predict_full(model, x)
        assert_true(prediction == prediction)


def test_metrics_analytic_values() raises:
    var predictions = List[Float64]()
    var actuals = List[Float64]()
    for i in range(10):
        predictions.append(Float64(i % 2))
        actuals.append(Float64(i % 2))
    var metrics = compute_full_metrics(predictions, actuals, True)
    assert_true(abs64(metrics.accuracy - 1.0) < 1e-9)
    assert_true(abs64(metrics.f1 - 1.0) < 1e-9)
    assert_true(abs64(metrics.auc - 1.0) < 1e-9)
    assert_equal(metrics.confusion[0], 5)
    assert_equal(metrics.confusion[3], 5)

    predictions[0] = 0.0
    actuals[0] = 1.0
    var imperfect = compute_full_metrics(predictions, actuals, True)
    assert_true(abs64(imperfect.accuracy - 0.9) < 1e-9)
    assert_true(imperfect.log_loss > 0.0)


def abs64(value: Float64) raises -> Float64:
    if value < 0.0:
        return -value
    return value


def test_validation_and_search() raises:
    var plans = kfold_plans(24, 3, UInt64(42))
    assert_equal(len(plans), 3)
    for i in range(len(plans)):
        assert_equal(len(plans[i]), 8)
        assert_equal(len(train_from_fold(24, plans[i])), 16)
    var regression_candidates = make_candidates(UInt64(42), 12, False)
    assert_equal(len(regression_candidates), 12)
    var classification_candidates = make_candidates(UInt64(42), 12, True)
    var has_classifier = False
    for i in range(len(classification_candidates)):
        if is_classification_kind(classification_candidates[i].kind):
            has_classifier = True
    assert_true(has_classifier)
    assert_true(len(grid_candidates(True)) > len(classification_candidates))
    assert_true(len(all_kinds(True)) > len(all_kinds(False)))
    assert_false(valid_candidate(FullCandidate("x", "unknown", 100, 0.0, 1, 1)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
