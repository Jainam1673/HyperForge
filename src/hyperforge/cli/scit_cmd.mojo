"""CLI for the SciTransformers slice (master prompt M04)."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.exit_codes import (
    EXIT_OK,
    EXIT_FAILURE,
    EXIT_USAGE,
    EXIT_UNAVAILABLE,
)
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import (
    append_record,
    journal_path,
    next_sequence,
    read_journal,
    rewrite_journal,
)
from hyperforge.scit.task import default_task, sample_task, TASK_SCHEMA
from hyperforge.scit.model import (
    init_model,
    predict,
    serialize_model,
    deserialize_model,
)
from hyperforge.scit.trainer import train_and_evaluate, SciOutcome

comptime SCIT_CONFIG_MAGIC = "HSCIT1"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def experiment_id(seed: UInt64) raises -> String:
    return "scit-" + hex64(fnv1a64("scit|decaying_mode_1d|" + String(seed)))


def outcome_fields(id: String, outcome: SciOutcome) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("exp_id", id))
    fields.append(Field("task", outcome.problem))
    fields.append(Field("seed", String(outcome.seed)))
    fields.append(Field("epochs", String(outcome.epochs)))
    fields.append(Field("initial_loss", String(outcome.initial_loss)))
    fields.append(Field("final_loss", String(outcome.final_loss)))
    fields.append(Field("model_mse", String(outcome.model_mse)))
    fields.append(Field("persistence_mse", String(outcome.persistence_mse)))
    fields.append(Field("mean_mse", String(outcome.mean_mse)))
    fields.append(Field("linear_mse", String(outcome.linear_mse)))
    fields.append(Field("drift", String(outcome.rollout_drift)))
    fields.append(Field("state", outcome.state))
    fields.append(Field("detail", outcome.detail))
    fields.append(Field("runtime", String(outcome.runtime_seconds)))
    return fields^


def train_scit(workspace: String, seed: UInt64, epochs: Int) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if epochs < 1:
        err.write("hyperforge: epochs must be positive\n")
        return EXIT_USAGE

    var spec = default_task(seed)
    var result = train_and_evaluate(spec, seed, epochs)
    var model = result[0].copy()
    var outcome = result[1].copy()
    var id = experiment_id(seed)

    var config = (
        SCIT_CONFIG_MAGIC + "|task=" + spec.name + "|seed=" + String(seed)
        + "|epochs=" + String(epochs) + "|grid=" + String(spec.grid_points)
        + "|history=" + String(spec.history) + "|schema=" + TASK_SCHEMA + "\n"
    )
    var checksum = hex64(fnv1a64(config))
    var config_path = workspace + "/artifacts/" + id + ".config.txt"
    var config_file = open(config_path, "w")
    config_file.write(config)
    config_file.close()
    var model_path = workspace + "/artifacts/" + id + ".model.txt"
    var model_file = open(model_path, "w")
    model_file.write(serialize_model(model))
    model_file.close()

    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    if journal.status == "RECOVERED":
        rewrite_journal(journal_path(workspace), journal.good_content)
        err.write("hyperforge: recovered journal tail: " + journal.reason + "\n")
    for i in range(len(journal.records)):
        if (
            journal.records[i].kind == "experiment"
            and journal.records[i].fields["id"] == id
        ):
            err.write("hyperforge: experiment already exists: " + id + "\n")
            return EXIT_USAGE

    var seq = next_sequence(journal.records)
    var experiment_fields = List[Field]()
    experiment_fields.append(Field("id", id))
    experiment_fields.append(Field("name", "scit:" + spec.name))
    experiment_fields.append(Field("seed", String(seed)))
    experiment_fields.append(Field("state", outcome.state))
    experiment_fields.append(Field("config_artifact", "artifacts/" + id + ".config.txt"))
    experiment_fields.append(Field("config_checksum", checksum))
    experiment_fields.append(Field("trial_seeds", ""))
    experiment_fields.append(Field("task", "scientific_transformer"))
    experiment_fields.append(Field("dataset", "synthetic:decaying_mode_1d"))
    experiment_fields.append(Field("target", "next_frame"))
    experiment_fields.append(Field("budget", String(epochs)))
    experiment_fields.append(Field("fingerprint", checksum))
    append_record(journal_path(workspace), seq, "experiment", experiment_fields)
    seq += 1
    append_record(journal_path(workspace), seq, "scit", outcome_fields(id, outcome))

    print("experiment:       " + id)
    print("task:             " + spec.name)
    print("state:            " + outcome.state)
    print("loss:             " + String(outcome.initial_loss) + " -> " + String(outcome.final_loss))
    print("model_mse:        " + String(outcome.model_mse))
    print("persistence_mse:  " + String(outcome.persistence_mse))
    print("mean_mse:         " + String(outcome.mean_mse))
    print("linear_mse:       " + String(outcome.linear_mse))
    print("rollout_drift:    " + String(outcome.rollout_drift))
    print("runtime_s:        " + String(outcome.runtime_seconds))
    print("config:           " + config_path)
    print("model:            " + model_path)

    if outcome.state == "CONVERGED":
        return EXIT_OK
    err.write("hyperforge: SciTransformers run did not meet the gate: " + outcome.state + "\n")
    return EXIT_FAILURE


def show_scit(workspace: String, id: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    var found = False
    for i in range(len(journal.records)):
        ref record = journal.records[i]
        if record.kind == "scit" and record.fields["exp_id"] == id:
            found = True
            print("task:            " + record.fields["task"])
            print("state:           " + record.fields["state"])
            print("model_mse:       " + record.fields["model_mse"])
            print("persistence_mse: " + record.fields["persistence_mse"])
            print("mean_mse:        " + record.fields["mean_mse"])
            print("linear_mse:      " + record.fields["linear_mse"])
            print("rollout_drift:   " + record.fields["drift"])
    if not found:
        err.write("hyperforge: SciTransformers result not found: " + id + "\n")
        return EXIT_FAILURE
    return EXIT_OK


def predict_scit(workspace: String, id: String, sample_index: Int) raises -> Int:
    var err = stderr
    var model_path = workspace + "/artifacts/" + id + ".model.txt"
    if not Path(model_path).exists():
        err.write("hyperforge: model artifact missing: " + model_path + "\n")
        return EXIT_UNAVAILABLE
    var spec = default_task(UInt64(0))
    var model = deserialize_model(open(model_path, "r").read())
    var sample = sample_task(spec, sample_index, False)
    var inputs = sample[0].copy()
    var target = sample[1].copy()
    var output = predict(model, spec, inputs)
    print("held-out sample: " + String(sample_index))
    var line = String("prediction:")
    var actual = String("actual:    ")
    for i in range(len(output)):
        line += " " + String(output[i])
        actual += " " + String(target[i])
    print(line)
    print(actual)
    return EXIT_OK
