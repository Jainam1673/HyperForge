"""CLI for the complete AutoML algorithm suite (M22 monolith)."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.automl.dataset import Dataset, load_csv, target_at
from hyperforge.automl.split import make_split
from hyperforge.automl.preprocess import Preprocessor, fit_preprocessor, transform_row
from hyperforge.automl.full_models import (
    FullCandidate, fit_model_full, predict_full, predict_label,
    is_classification_kind,
)
from hyperforge.automl.full_metrics import FullMetrics, compute_full_metrics
from hyperforge.automl.full_validation import (
    detect_classification, kfold_plans, train_from_fold, make_candidates,
    grid_candidates,
)
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal

comptime FULL_CLI_SCHEMA = "hyperforge-automl-full-v1"


struct TrialResult(Copyable, Movable):
    var candidate: FullCandidate
    var validation_score: Float64
    var fold_scores: List[Float64]
    var valid: Bool

    def __init__(
        out self, candidate: FullCandidate, validation_score: Float64,
        var fold_scores: List[Float64], valid: Bool,
    ):
        self.candidate = candidate.copy()
        self.validation_score = validation_score
        self.fold_scores = fold_scores^
        self.valid = valid


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def score_of(metrics: FullMetrics, classification: Bool) raises -> Float64:
    if classification:
        return -metrics.accuracy
    return metrics.rmse


def evaluate_candidate(
    candidate: FullCandidate,
    dataset: Dataset,
    train: List[Int],
    validation: List[Int],
    preprocessor: Preprocessor,
    seed: UInt64,
    classification: Bool,
) raises -> TrialResult:
    var model = fit_model_full(candidate, dataset, train, preprocessor, seed)
    var predictions = List[Float64]()
    var actuals = List[Float64]()
    for row in validation:
        var x = transform_row(preprocessor, dataset, row)
        # Metrics derive labels from the raw score at the 0.5 threshold,
        # preserving probabilities for log loss and AUC.
        predictions.append(predict_full(model, x))
        actuals.append(target_at(dataset, row))
    var metrics = compute_full_metrics(predictions, actuals, classification)
    return TrialResult(candidate, score_of(metrics, classification), List[Float64](), True)


def run_full(
    workspace: String,
    dataset_path: String,
    target: String,
    budget: Int,
    seed: UInt64,
    folds: Int,
    use_grid: Bool,
) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if budget < 1 or folds < 2:
        err.write("hyperforge: budget must be positive and folds >= 2\n")
        return EXIT_USAGE

    var dataset = load_csv(dataset_path, target)
    var split = make_split(dataset.rows, seed)
    var preprocessor = fit_preprocessor(dataset, split.train)
    var classification = detect_classification(dataset, split.train)
    var candidates = (
        grid_candidates(classification) if use_grid
        else make_candidates(seed, budget, classification)
    )

    var journal = read_journal(journal_path(workspace))
    var sequence = next_sequence(journal.records)
    var results = List[TrialResult]()
    var best_index = -1
    var best_score = 1e300

    for i in range(len(candidates)):
        var candidate = candidates[i].copy()
        var trial: TrialResult
        try:
            trial = evaluate_candidate(
                candidate, dataset, split.train, split.validation,
                preprocessor, seed, classification,
            )
        except e:
            _ = e
            trial = TrialResult(candidate, 1e300, List[Float64](), False)

        if classification and not is_classification_kind(candidate.kind):
            # Regression kinds emit continuous values on a binary target;
            # they are recorded but cannot win a classification selection.
            trial.validation_score = 1e300

        if trial.valid and trial.validation_score < best_score:
            best_score = trial.validation_score
            best_index = i
        results.append(trial.copy())

        var fields = List[Field]()
        fields.append(Field("candidate_id", candidate.id))
        fields.append(Field("kind", candidate.kind))
        fields.append(Field("task", "classification" if classification else "regression"))
        fields.append(Field("seed", String(seed)))
        fields.append(Field("validation_score", String(trial.validation_score)))
        fields.append(Field("valid", "true" if trial.valid else "false"))
        append_record(journal_path(workspace), sequence, "full_trial", fields)
        sequence += 1

    if best_index < 0:
        err.write("hyperforge: no valid candidate completed\n")
        return EXIT_FAILURE

    var winner = results[best_index].copy()
    # k-fold check on the training partition only (never on the holdout).
    var fold_scores = List[Float64]()
    var plans = kfold_plans(len(split.train), folds, seed)
    for fold in range(len(plans)):
        var validation = plans[fold].copy()
        var train = train_from_fold(len(split.train), validation)
        var fold_trial = evaluate_candidate(
            winner.candidate, dataset, train, validation,
            preprocessor, seed, classification,
        )
        fold_scores.append(fold_trial.validation_score)

    # Holdout is touched once, after selection and cross-validation.
    var model = fit_model_full(winner.candidate, dataset, split.train, preprocessor, seed)
    var test_predictions = List[Float64]()
    var test_actuals = List[Float64]()
    for row in split.test:
        var x = transform_row(preprocessor, dataset, row)
        test_predictions.append(predict_full(model, x))
        test_actuals.append(target_at(dataset, row))
    var test_metrics = compute_full_metrics(test_predictions, test_actuals, classification)

    var summary_fields = List[Field]()
    summary_fields.append(Field("schema", FULL_CLI_SCHEMA))
    summary_fields.append(Field("task", "classification" if classification else "regression"))
    summary_fields.append(Field("winner_id", winner.candidate.id))
    summary_fields.append(Field("winner_kind", winner.candidate.kind))
    summary_fields.append(Field("seed", String(seed)))
    summary_fields.append(Field("budget", String(len(candidates))))
    summary_fields.append(Field("folds", String(folds)))
    summary_fields.append(Field("test_rmse", String(test_metrics.rmse)))
    summary_fields.append(Field("test_accuracy", String(test_metrics.accuracy)))
    summary_fields.append(Field("test_f1", String(test_metrics.f1)))
    summary_fields.append(Field("test_auc", String(test_metrics.auc)))
    append_record(journal_path(workspace), sequence, "full_summary", summary_fields)

    print("schema:          " + FULL_CLI_SCHEMA)
    print("task:            " + ("classification" if classification else "regression"))
    print("candidates:      " + String(len(candidates)))
    print("winner:          " + winner.candidate.kind + " (" + winner.candidate.id + ")")
    print("validation:      " + String(winner.validation_score))
    print("cv_folds:        " + String(len(fold_scores)))
    print("test_rmse:       " + String(test_metrics.rmse))
    print("test_accuracy:   " + String(test_metrics.accuracy))
    print("test_f1:         " + String(test_metrics.f1))
    print("test_auc:        " + String(test_metrics.auc))
    print("test_log_loss:   " + String(test_metrics.log_loss))
    print("dataset:         " + dataset_path)
    print("note:            selection used validation + k-fold; test evaluated once")
    return EXIT_OK
