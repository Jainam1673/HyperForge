"""Adaptive propose/evaluate/persist/feedback loop and its random baseline."""

from std.time import perf_counter
from hyperforge.core.hash import hex64, fnv1a64
from hyperforge.automl.dataset import load_csv, target_at, Dataset
from hyperforge.automl.split import make_split
from hyperforge.automl.preprocess import Preprocessor, fit_preprocessor, transform_row
from hyperforge.automl.models import Candidate, fit_model, predict
from hyperforge.automl.metrics import Metrics, compute_metrics
from hyperforge.automl.search import make_candidates
from hyperforge.experiment.spec import make_experiment_id, config_artifact_path, derived_trial_seeds
from hyperforge.experiment.trial import (
    Trial,
    trial_to_fields,
    TRIAL_STATE_SUCCEEDED,
    TRIAL_STATE_FAILED,
    TRIAL_SPLIT_VALIDATION,
    TRIAL_SPLIT_TEST,
)
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import (
    append_record,
    journal_path,
    next_sequence,
    read_journal,
    rewrite_journal,
)
from hyperforge.optimization.space import validate_candidate
from hyperforge.optimization.tpe import TpeSampler

comptime OPTIMIZER_POLICY = "tpe_density_ratio_v1"
comptime BASELINE_POLICY = "random_search_v1"


struct SearchOutcome(Copyable, Movable):
    var experiment_id: String
    var best_kind: String
    var best_id: String
    var validation_rmse: Float64
    var test_rmse: Float64
    var succeeded: Int
    var failed: Int
    var invalid: Int
    var search_seconds: Float64

    def __init__(
        out self,
        experiment_id: String,
        best_kind: String,
        best_id: String,
        validation_rmse: Float64,
        test_rmse: Float64,
        succeeded: Int,
        failed: Int,
        invalid: Int,
        search_seconds: Float64,
    ):
        self.experiment_id = experiment_id
        self.best_kind = best_kind
        self.best_id = best_id
        self.validation_rmse = validation_rmse
        self.test_rmse = test_rmse
        self.succeeded = succeeded
        self.failed = failed
        self.invalid = invalid
        self.search_seconds = search_seconds


def validation_metrics(
    candidate: Candidate,
    dataset: Dataset,
    split_train: List[Int],
    split_validation: List[Int],
    preprocessor: Preprocessor,
) raises -> Metrics:
    var model = fit_model(candidate, dataset, split_train, preprocessor)
    var predictions = List[Float64]()
    var actuals = List[Float64]()
    for row in split_validation:
        predictions.append(predict(model, transform_row(preprocessor, dataset, row)))
        actuals.append(target_at(dataset, row))
    return compute_metrics(predictions, actuals)


def test_metrics_for(
    candidate: Candidate,
    dataset: Dataset,
    split_train: List[Int],
    split_test: List[Int],
    preprocessor: Preprocessor,
) raises -> Metrics:
    var model = fit_model(candidate, dataset, split_train, preprocessor)
    var predictions = List[Float64]()
    var actuals = List[Float64]()
    for row in split_test:
        predictions.append(predict(model, transform_row(preprocessor, dataset, row)))
        actuals.append(target_at(dataset, row))
    return compute_metrics(predictions, actuals)


def optimizer_fields(
    experiment_id: String,
    observed: Int,
    succeeded: Int,
    failed: Int,
    invalid: Int,
    best_rmse: Float64,
    best_candidate: String,
    policy: String,
    elapsed: Float64,
) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("exp_id", experiment_id))
    fields.append(Field("observed", String(observed)))
    fields.append(Field("succeeded", String(succeeded)))
    fields.append(Field("failed", String(failed)))
    fields.append(Field("invalid", String(invalid)))
    fields.append(Field("best_rmse", String(best_rmse)))
    fields.append(Field("best_candidate", best_candidate))
    fields.append(Field("policy", policy))
    fields.append(Field("search_seconds", String(elapsed)))
    return fields^


def experiment_fields_for_optimizer(
    id: String,
    dataset_path: String,
    target: String,
    seed: UInt64,
    budget: Int,
    fingerprint: String,
    config_artifact: String,
    checksum: String,
    policy: String,
) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("id", id))
    fields.append(Field("name", "optimize:" + dataset_path))
    fields.append(Field("seed", String(seed)))
    fields.append(Field("state", "COMPLETED"))
    fields.append(Field("config_artifact", config_artifact))
    fields.append(Field("config_checksum", checksum))
    fields.append(Field("trial_seeds", derived_trial_seeds(seed)))
    fields.append(Field("task", "regression_adaptive"))
    fields.append(Field("dataset", dataset_path))
    fields.append(Field("target", target))
    fields.append(Field("budget", String(budget)))
    fields.append(Field("fingerprint", fingerprint))
    fields.append(Field("policy", policy))
    return fields^


def run_adaptive(
    workspace: String,
    dataset_path: String,
    target: String,
    budget: Int,
    seed: UInt64,
) raises -> SearchOutcome:
    """One full adaptive run; every observation is persisted before the next proposal."""
    if budget < 2:
        raise Error("budget must be at least 2")
    var dataset = load_csv(dataset_path, target)
    var split = make_split(dataset.rows, seed)
    var preprocessor = fit_preprocessor(dataset, split.train)

    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        raise Error("journal error: " + journal.reason)
    if journal.status == "RECOVERED":
        rewrite_journal(journal_path(workspace), journal.good_content)

    var id = make_experiment_id("optimize:" + dataset_path + ":" + target, seed)
    for i in range(len(journal.records)):
        if (
            journal.records[i].kind == "experiment"
            and journal.records[i].fields["id"] == id
        ):
            raise Error("experiment already exists: " + id)

    var config = (
        "HFOPTIMIZE1|dataset=" + dataset_path + "|target=" + target
        + "|budget=" + String(budget) + "|seed=" + String(seed)
        + "|fingerprint=" + dataset.fingerprint + "|policy=" + OPTIMIZER_POLICY + "\n"
    )
    var checksum = hex64(fnv1a64(config))
    var artifact = workspace + "/" + config_artifact_path(id)
    var handle = open(artifact, "w")
    handle.write(config)
    handle.close()

    var seq = next_sequence(journal.records)
    append_record(
        journal_path(workspace),
        seq,
        "experiment",
        experiment_fields_for_optimizer(
            id, dataset_path, target, seed, budget, dataset.fingerprint,
            config_artifact_path(id), checksum, OPTIMIZER_POLICY,
        ),
    )
    seq += 1

    var sampler = TpeSampler(seed, True)
    var candidates = make_candidates(seed, budget)
    var succeeded = 0
    var failed = 0
    var invalid = 0
    var started = perf_counter()

    for i in range(budget):
        var candidate = candidates[0].copy() if i == 0 else sampler.propose(i)
        var index = i
        var detail: String
        var rmse = Float64(1e300)
        var state = TRIAL_STATE_SUCCEEDED
        var valid = validate_candidate(candidate)
        if not valid:
            invalid += 1
            state = TRIAL_STATE_FAILED
            detail = "invalid candidate rejected by typed search space"
        else:
            try:
                var metrics = validation_metrics(
                    candidate, dataset, split.train, split.validation, preprocessor
                )
                rmse = metrics.rmse
                detail = "adaptive validation evaluation"
                succeeded += 1
                sampler.observe(candidate, metrics.rmse)
            except e:
                failed += 1
                state = TRIAL_STATE_FAILED
                detail = String(e)

        append_record(
            journal_path(workspace),
            seq,
            "trial",
            trial_to_fields(
                Trial(
                    id, candidate.id, candidate.kind, index,
                    TRIAL_SPLIT_VALIDATION, 0.0, rmse, 0.0, state, detail,
                )
            ),
        )
        seq += 1
        var elapsed = perf_counter() - started
        append_record(
            journal_path(workspace),
            seq,
            "optimizer",
            optimizer_fields(
                id,
                sampler.observed_count(),
                succeeded,
                failed,
                invalid,
                sampler.best_rmse(),
                candidate.id,
                OPTIMIZER_POLICY,
                elapsed,
            ),
        )
        seq += 1

    if succeeded == 0:
        raise Error("every adaptive trial failed")

    var best_observation = sampler.sorted_history()[0].copy()
    var best_candidate = best_observation.candidate.copy()
    var test_result = test_metrics_for(
        best_candidate, dataset, split.train, split.test, preprocessor
    )
    append_record(
        journal_path(workspace),
        seq,
        "trial",
        trial_to_fields(
            Trial(
                id, best_candidate.id, best_candidate.kind, budget,
                TRIAL_SPLIT_TEST, test_result.mae, test_result.rmse,
                test_result.r2, TRIAL_STATE_SUCCEEDED,
                "held-out test; evaluated once after adaptive selection",
            )
        ),
    )
    seq += 1
    var event = List[Field]()
    event.append(Field("exp_id", id))
    event.append(Field("kind", "COMPLETED"))
    event.append(Field("detail", "adaptive best=" + best_candidate.kind))
    event.append(Field("state", "COMPLETED"))
    append_record(journal_path(workspace), seq, "event", event)

    return SearchOutcome(
        id,
        best_candidate.kind,
        best_candidate.id,
        best_observation.rmse,
        test_result.rmse,
        succeeded,
        failed,
        invalid,
        perf_counter() - started,
    )


def run_random_baseline(
    dataset_path: String, target: String, budget: Int, seed: UInt64
) raises -> SearchOutcome:
    """M02-style deterministic random search on the same split, no persistence."""
    var dataset = load_csv(dataset_path, target)
    var split = make_split(dataset.rows, seed)
    var preprocessor = fit_preprocessor(dataset, split.train)
    var candidates = make_candidates(seed, budget)
    var started = perf_counter()
    var best_rmse = Float64(1e300)
    var best_candidate = candidates[0].copy()
    var succeeded = 0
    for i in range(budget):
        var candidate = candidates[i].copy()
        try:
            var metrics = validation_metrics(
                candidate, dataset, split.train, split.validation, preprocessor
            )
            succeeded += 1
            if metrics.rmse < best_rmse:
                best_rmse = metrics.rmse
                best_candidate = candidate.copy()
        except e:
            _ = e
    var test_result = test_metrics_for(
        best_candidate, dataset, split.train, split.test, preprocessor
    )
    return SearchOutcome(
        "random-baseline",
        best_candidate.kind,
        best_candidate.id,
        best_rmse,
        test_result.rmse,
        succeeded,
        0,
        0,
        perf_counter() - started,
    )
