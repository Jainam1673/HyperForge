"""M02 AutoML commands: real CSV experiments with durable trial records."""

from std.math import abs
from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE, EXIT_UNAVAILABLE
from hyperforge.evidence.record import (
    Field,
    JournalRecord,
    RECORD_EXPERIMENT,
    RECORD_EVENT,
    RECORD_TRIAL,
)
from hyperforge.evidence.journal import (
    append_record,
    journal_path,
    next_sequence,
    read_journal,
    rewrite_journal,
)
from hyperforge.experiment.spec import (
    config_artifact_path,
    derived_trial_seeds,
    make_experiment_id,
)
from hyperforge.experiment.trial import (
    Trial,
    trial_from_fields,
    trial_to_fields,
    TRIAL_STATE_SUCCEEDED,
    TRIAL_STATE_FAILED,
    TRIAL_SPLIT_VALIDATION,
    TRIAL_SPLIT_TEST,
)
from hyperforge.automl.dataset import (
    Dataset,
    load_csv,
    value_at,
    is_missing_at,
    target_at,
)
from hyperforge.automl.split import make_split
from hyperforge.automl.preprocess import fit_preprocessor, transform_row
from hyperforge.automl.models import Candidate, fit_model, predict
from hyperforge.automl.search import make_candidates
from hyperforge.automl.metrics import compute_metrics

comptime AUTOML_TASK = "regression"
comptime AUTOML_CONFIG_MAGIC = "HFAUTOML1"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def config_blob(dataset: String, target: String, budget: Int, seed: UInt64, fingerprint: String) raises -> String:
    return (
        AUTOML_CONFIG_MAGIC + "|dataset=" + dataset + "|target=" + target
        + "|budget=" + String(budget) + "|seed=" + String(seed)
        + "|fingerprint=" + fingerprint + "\n"
    )


def parse_config_blob(content: String) raises -> List[Field]:
    var out = List[Field]()
    var clean = String("")
    var limit = content.byte_length()
    if content.endswith("\n"):
        limit -= 1
    for i in range(limit):
        clean += String(content[byte=i])
    var parts = clean.split("|")
    if len(parts) < 6:
        raise Error("invalid automl config artifact")
    for part in parts:
        var text = String(part)
        if text == AUTOML_CONFIG_MAGIC:
            continue
        for i in range(text.byte_length()):
            if text[byte=i] == "=":
                var key = String("")
                var value = String("")
                for j in range(i):
                    key += String(text[byte=j])
                for j in range(i + 1, text.byte_length()):
                    value += String(text[byte=j])
                out.append(Field(key, value))
                break
    return out^


def field_value(fields: List[Field], key: String) raises -> String:
    for i in range(len(fields)):
        if fields[i].key == key:
            return fields[i].value
    raise Error("missing config field: " + key)


def automl_experiment_fields(
    id: String,
    name: String,
    seed: UInt64,
    dataset: String,
    target: String,
    budget: Int,
    fingerprint: String,
    config_artifact: String,
    config_checksum: String,
) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("id", id))
    fields.append(Field("name", name))
    fields.append(Field("seed", String(seed)))
    fields.append(Field("state", "COMPLETED"))
    fields.append(Field("config_artifact", config_artifact))
    fields.append(Field("config_checksum", config_checksum))
    fields.append(Field("trial_seeds", derived_trial_seeds(seed)))
    fields.append(Field("task", AUTOML_TASK))
    fields.append(Field("dataset", dataset))
    fields.append(Field("target", target))
    fields.append(Field("budget", String(budget)))
    fields.append(Field("fingerprint", fingerprint))
    return fields^


def load_trials(records: List[JournalRecord], experiment_id: String) raises -> List[Trial]:
    var out = List[Trial]()
    for i in range(len(records)):
        if (
            records[i].kind == RECORD_TRIAL
            and records[i].fields["exp_id"] == experiment_id
        ):
            out.append(trial_from_fields(records[i].fields))
    return out^


def run_experiment(
    workspace: String,
    dataset_path: String,
    target: String,
    budget: Int,
    seed: UInt64,
) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if budget < 2:
        err.write("hyperforge: budget must be at least 2\n")
        return EXIT_USAGE

    var dataset: Dataset
    try:
        dataset = load_csv(dataset_path, target)
    except e:
        err.write("hyperforge: dataset error: " + String(e) + "\n")
        return EXIT_FAILURE

    var split = make_split(dataset.rows, seed)
    var preprocessor = fit_preprocessor(dataset, split.train)
    var candidates = make_candidates(seed, budget)

    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    if journal.status == "RECOVERED":
        rewrite_journal(journal_path(workspace), journal.good_content)
        err.write("hyperforge: recovered journal tail: " + journal.reason + "\n")

    var id = make_experiment_id("automl:" + dataset_path + ":" + target, seed)
    for i in range(len(journal.records)):
        if (
            journal.records[i].kind == RECORD_EXPERIMENT
            and journal.records[i].fields["id"] == id
        ):
            err.write("hyperforge: experiment already exists: " + id + "\n")
            return EXIT_USAGE

    var config = config_blob(dataset_path, target, budget, seed, dataset.fingerprint)
    var checksum = hex64(fnv1a64(config))
    var artifact = workspace + "/" + config_artifact_path(id)
    var handle = open(artifact, "w")
    handle.write(config)
    handle.close()

    var seq = next_sequence(journal.records)
    append_record(
        journal_path(workspace),
        seq,
        RECORD_EXPERIMENT,
        automl_experiment_fields(
            id,
            "automl:" + dataset_path,
            seed,
            dataset_path,
            target,
            budget,
            dataset.fingerprint,
            config_artifact_path(id),
            checksum,
        ),
    )

    var best_index = -1
    var best_rmse = Float64(1e300)
    var trial_seq = seq + 1

    for i in range(len(candidates)):
        var candidate = candidates[i].copy()
        var status = TRIAL_STATE_SUCCEEDED
        var detail = String("validation evaluation")
        var mae = Float64(0.0)
        var rmse = Float64(0.0)
        var r2 = Float64(0.0)
        try:
            var model = fit_model(candidate, dataset, split.train, preprocessor)
            var predictions = List[Float64]()
            var actuals = List[Float64]()
            for row in split.validation:
                predictions.append(predict(model, transform_row(preprocessor, dataset, row)))
                actuals.append(target_at(dataset, row))
            var metrics = compute_metrics(predictions, actuals)
            mae = metrics.mae
            rmse = metrics.rmse
            r2 = metrics.r2
            if rmse < best_rmse:
                best_rmse = rmse
                best_index = i
        except e:
            status = TRIAL_STATE_FAILED
            detail = String(e)

        append_record(
            journal_path(workspace),
            trial_seq,
            RECORD_TRIAL,
            trial_to_fields(
                Trial(
                    id,
                    candidate.id,
                    candidate.kind,
                    i,
                    TRIAL_SPLIT_VALIDATION,
                    mae,
                    rmse,
                    r2,
                    status,
                    detail,
                )
            ),
        )
        trial_seq += 1

    if best_index < 0:
        err.write("hyperforge: every candidate failed\n")
        return EXIT_FAILURE

    var best = candidates[best_index].copy()
    var final_model = fit_model(best, dataset, split.train, preprocessor)
    var test_predictions = List[Float64]()
    var test_actuals = List[Float64]()
    for row in split.test:
        test_predictions.append(predict(final_model, transform_row(preprocessor, dataset, row)))
        test_actuals.append(target_at(dataset, row))
    var test_metrics = compute_metrics(test_predictions, test_actuals)

    append_record(
        journal_path(workspace),
        trial_seq,
        RECORD_TRIAL,
        trial_to_fields(
            Trial(
                id,
                best.id,
                best.kind,
                best_index,
                TRIAL_SPLIT_TEST,
                test_metrics.mae,
                test_metrics.rmse,
                test_metrics.r2,
                TRIAL_STATE_SUCCEEDED,
                "held-out test; evaluated once after selection",
            )
        ),
    )
    trial_seq += 1

    var event_fields = List[Field]()
    event_fields.append(Field("exp_id", id))
    event_fields.append(Field("kind", "COMPLETED"))
    event_fields.append(Field("detail", "best=" + best.kind + " validation_rmse=" + String(best_rmse)))
    event_fields.append(Field("state", "COMPLETED"))
    append_record(journal_path(workspace), trial_seq, RECORD_EVENT, event_fields)

    print("experiment: " + id)
    print("best:       " + best.kind + " (" + best.id + ")")
    print("validation: rmse=" + String(best_rmse))
    print("test:       rmse=" + String(test_metrics.rmse) + " mae=" + String(test_metrics.mae) + " r2=" + String(test_metrics.r2))
    return EXIT_OK


def inspect_dataset(dataset_path: String, target: String) raises -> Int:
    var err = stderr
    var dataset: Dataset
    try:
        dataset = load_csv(dataset_path, target)
    except e:
        err.write("hyperforge: dataset error: " + String(e) + "\n")
        return EXIT_FAILURE
    var missing_cells = 0
    for i in range(len(dataset.missing)):
        if dataset.missing[i]:
            missing_cells += 1
    var constant_columns = 0
    for col in range(dataset.cols):
        if col == dataset.target_index:
            continue
        var first = Float64(0.0)
        var found = False
        var constant = True
        for row in range(dataset.rows):
            if is_missing_at(dataset, row, col):
                continue
            var value = value_at(dataset, row, col)
            if not found:
                first = value
                found = True
            elif value != first:
                constant = False
                break
        if constant:
            constant_columns += 1
    print("dataset:        " + dataset_path)
    print("target:         " + target)
    print("rows:           " + String(dataset.rows))
    print("columns:        " + String(dataset.cols))
    print("feature_columns:" + String(dataset.cols - 1))
    print("missing_cells:  " + String(missing_cells))
    print("constant_features:" + String(constant_columns))
    print("fingerprint:    " + dataset.fingerprint)
    return EXIT_OK


def find_experiment(records: List[JournalRecord], id: String) raises -> Int:
    for i in range(len(records)):
        if (
            records[i].kind == RECORD_EXPERIMENT
            and records[i].fields["id"] == id
        ):
            return i
    return -1


def show_experiment(workspace: String, id: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    if find_experiment(journal.records, id) < 0:
        err.write("hyperforge: experiment not found: " + id + "\n")
        return EXIT_FAILURE
    var trials = load_trials(journal.records, id)
    for i in range(len(trials)):
        var trial = trials[i].copy()
        print(
            "trial " + String(trial.index) + "  " + trial.split + "  "
            + trial.model_kind + "  rmse=" + String(trial.rmse)
            + "  r2=" + String(trial.r2) + "  " + trial.state
        )
    return EXIT_OK


def report_experiment(workspace: String, id: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    var index = find_experiment(journal.records, id)
    if index < 0:
        err.write("hyperforge: experiment not found: " + id + "\n")
        return EXIT_FAILURE
    var fields = journal.records[index].fields.copy()
    var trials = load_trials(journal.records, id)
    print("HyperForge AutoML report")
    print("experiment:  " + id)
    print("task:        " + fields["task"])
    print("dataset:     " + fields["dataset"])
    print("target:      " + fields["target"])
    print("fingerprint: " + fields["fingerprint"])
    print("seed:        " + fields["seed"])
    print("budget:      " + fields["budget"])
    var best_test = Float64(1e300)
    var best_model = String("none")
    for i in range(len(trials)):
        var trial = trials[i].copy()
        if trial.split == TRIAL_SPLIT_TEST and trial.rmse < best_test:
            best_test = trial.rmse
            best_model = trial.model_kind
    print("trials:      " + String(len(trials)))
    print("best_test:   " + best_model + " rmse=" + String(best_test))
    print("Note: selection used validation only; test was evaluated once.")
    return EXIT_OK


def best_candidate_for(records: List[JournalRecord], id: String, seed: UInt64, budget: Int) raises -> Candidate:
    var trials = load_trials(records, id)
    var best_rmse = Float64(1e300)
    var best_id = String("")
    for i in range(len(trials)):
        var trial = trials[i].copy()
        if trial.split == TRIAL_SPLIT_VALIDATION and trial.state == TRIAL_STATE_SUCCEEDED:
            if trial.rmse < best_rmse:
                best_rmse = trial.rmse
                best_id = trial.candidate_id
    var candidates = make_candidates(seed, budget)
    for i in range(len(candidates)):
        if candidates[i].id == best_id:
            return candidates[i].copy()
    raise Error("recorded best candidate not found in regenerated search space")


def replay_experiment(workspace: String, id: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    var index = find_experiment(journal.records, id)
    if index < 0:
        err.write("hyperforge: experiment not found: " + id + "\n")
        return EXIT_FAILURE
    var fields = journal.records[index].fields.copy()
    var artifact = workspace + "/" + fields["config_artifact"]
    if not Path(artifact).exists():
        err.write("hyperforge: replay refused; config artifact missing\n")
        return EXIT_UNAVAILABLE
    var content = open(artifact, "r").read()
    if hex64(fnv1a64(content)) != fields["config_checksum"]:
        err.write("hyperforge: replay refused; config artifact checksum mismatch\n")
        return EXIT_UNAVAILABLE

    var dataset: Dataset
    var dataset_path = String(fields["dataset"])
    var target_name = String(fields["target"])
    try:
        dataset = load_csv(dataset_path, target_name)
    except e:
        err.write("hyperforge: replay refused; dataset error: " + String(e) + "\n")
        return EXIT_UNAVAILABLE
    if dataset.fingerprint != fields["fingerprint"]:
        err.write("hyperforge: replay refused; dataset fingerprint changed\n")
        return EXIT_UNAVAILABLE

    var seed = UInt64(Int(fields["seed"]))
    var budget = Int(fields["budget"])
    var split = make_split(dataset.rows, seed)
    var preprocessor = fit_preprocessor(dataset, split.train)
    var candidate = best_candidate_for(journal.records, id, seed, budget)
    var model = fit_model(candidate, dataset, split.train, preprocessor)
    var predictions = List[Float64]()
    var actuals = List[Float64]()
    for row in split.test:
        predictions.append(predict(model, transform_row(preprocessor, dataset, row)))
        actuals.append(target_at(dataset, row))
    var recomputed = compute_metrics(predictions, actuals)

    var recorded = Float64(1e300)
    var trials = load_trials(journal.records, id)
    for i in range(len(trials)):
        if trials[i].split == TRIAL_SPLIT_TEST and trials[i].rmse < recorded:
            recorded = trials[i].rmse
    if abs(recomputed.rmse - recorded) > Float64(1e-9):
        err.write("hyperforge: replay mismatch; recorded=" + String(recorded) + " recomputed=" + String(recomputed.rmse) + "\n")
        return EXIT_FAILURE
    print("REPLAY_OK " + id + " test_rmse=" + String(recomputed.rmse))
    return EXIT_OK


def best_test_rmse(records: List[JournalRecord], id: String) raises -> Float64:
    var trials = load_trials(records, id)
    var best = Float64(1e300)
    for i in range(len(trials)):
        if trials[i].split == TRIAL_SPLIT_TEST and trials[i].state == TRIAL_STATE_SUCCEEDED:
            if trials[i].rmse < best:
                best = trials[i].rmse
    return best


def compare_experiments(workspace: String, id_a: String, id_b: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    if find_experiment(journal.records, id_a) < 0 or find_experiment(journal.records, id_b) < 0:
        err.write("hyperforge: experiment not found\n")
        return EXIT_FAILURE
    var rmse_a = best_test_rmse(journal.records, id_a)
    var rmse_b = best_test_rmse(journal.records, id_b)
    print("A: " + id_a + " test_rmse=" + String(rmse_a))
    print("B: " + id_b + " test_rmse=" + String(rmse_b))
    if rmse_a < rmse_b:
        print("lower_test_rmse: A")
    elif rmse_b < rmse_a:
        print("lower_test_rmse: B")
    else:
        print("lower_test_rmse: tie")
    return EXIT_OK
