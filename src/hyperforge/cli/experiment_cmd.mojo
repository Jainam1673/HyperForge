"""M01 experiment commands backed by the versioned local journal."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.state_machine import EXP_DRAFT
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE, EXIT_UNAVAILABLE
from hyperforge.evidence.record import (
    Field,
    JournalRecord,
    RECORD_EXPERIMENT,
    RECORD_EVENT,
)
from hyperforge.evidence.journal import (
    JournalReadResult,
    append_record,
    journal_path,
    next_sequence,
    read_journal,
    rewrite_journal,
)
from hyperforge.experiment.spec import (
    Experiment,
    DEFAULT_SEED,
    config_artifact_content,
    config_artifact_path,
    derived_trial_seeds,
    experiment_from_fields,
    experiment_to_fields,
    make_experiment_id,
)


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def find_experiment_index(records: List[JournalRecord], id: String) raises -> Int:
    for i in range(len(records)):
        if records[i].kind == RECORD_EXPERIMENT and records[i].fields["id"] == id:
            return i
    return -1


def load_experiments(records: List[JournalRecord]) raises -> List[Experiment]:
    var out = List[Experiment]()
    for i in range(len(records)):
        if records[i].kind == RECORD_EXPERIMENT:
            out.append(experiment_from_fields(records[i].fields))
    return out^


def json_string(value: String) raises -> String:
    var out = String("\"")
    for i in range(value.byte_length()):
        var ch = value[byte=i]
        if ch == "\"":
            out += "\\\""
        elif ch == "\\":
            out += "\\\\"
        elif ch == "\n":
            out += "\\n"
        else:
            out += String(ch)
    return out + "\""


def create_experiment(workspace: String, name: String, seed_text: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE

    var seed = DEFAULT_SEED
    if seed_text != "":
        seed = UInt64(Int(seed_text))

    var id = make_experiment_id(name, seed)
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    if journal.status == "RECOVERED":
        rewrite_journal(journal_path(workspace), journal.good_content)
        print("Recovered journal tail: " + journal.reason)

    if find_experiment_index(journal.records, id) >= 0:
        err.write("hyperforge: experiment already exists: " + id + "\n")
        return EXIT_USAGE

    var config_path = workspace + "/" + config_artifact_path(id)
    var config = config_artifact_content(name, seed)
    var checksum = hex64(fnv1a64(config))
    var handle = open(config_path, "w")
    handle.write(config)
    handle.close()

    var trial_seeds = derived_trial_seeds(seed)
    var experiment = Experiment(
        id,
        name,
        seed,
        EXP_DRAFT,
        config_artifact_path(id),
        checksum,
        trial_seeds,
    )
    var seq = next_sequence(journal.records)
    append_record(journal_path(workspace), seq, RECORD_EXPERIMENT, experiment_to_fields(experiment))

    var event_fields = List[Field]()
    event_fields.append(Field("exp_id", id))
    event_fields.append(Field("kind", "CREATED"))
    event_fields.append(Field("detail", "experiment created with derived trial seeds"))
    event_fields.append(Field("state", EXP_DRAFT))
    append_record(journal_path(workspace), seq + 1, RECORD_EVENT, event_fields)

    print(id)
    return EXIT_OK


def list_experiments(workspace: String, as_json: Bool) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    if journal.status == "RECOVERED":
        err.write("hyperforge: recovered journal tail: " + journal.reason + "\n")

    var experiments = load_experiments(journal.records)
    if as_json:
        var out = String(
            "{\"schema\":\"hyperforge-experiment-list-v1\",\"experiments\":["
        )
        for i in range(len(experiments)):
            if i > 0:
                out += ","
            var e = experiments[i].copy()
            out += (
                "{\"id\":" + json_string(e.id) + ",\"name\":"
                + json_string(e.name) + ",\"seed\":" + String(e.seed)
                + ",\"state\":" + json_string(e.state) + "}"
            )
        out += "]}"
        print(out)
    else:
        for i in range(len(experiments)):
            var e = experiments[i].copy()
            print(e.id + "  " + e.name + "  seed=" + String(e.seed) + "  " + e.state)
    return EXIT_OK


def show_experiment(workspace: String, id: String, as_json: Bool) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    var index = find_experiment_index(journal.records, id)
    if index < 0:
        err.write("hyperforge: experiment not found: " + id + "\n")
        return EXIT_FAILURE
    var e = experiment_from_fields(journal.records[index].fields)
    if as_json:
        print(
            "{\"schema\":\"hyperforge-experiment-v1\",\"id\":" + json_string(e.id)
            + ",\"name\":" + json_string(e.name) + ",\"seed\":" + String(e.seed)
            + ",\"state\":" + json_string(e.state)
            + ",\"config_artifact\":" + json_string(e.config_artifact)
            + ",\"config_checksum\":" + json_string(e.config_checksum)
            + ",\"trial_seeds\":" + json_string(e.trial_seeds) + "}"
        )
    else:
        print("id:              " + e.id)
        print("name:            " + e.name)
        print("seed:            " + String(e.seed))
        print("state:           " + e.state)
        print("config_artifact: " + e.config_artifact)
        print("config_checksum: " + e.config_checksum)
        print("trial_seeds:     " + e.trial_seeds)
        for i in range(len(journal.records)):
            if (
                journal.records[i].kind == RECORD_EVENT
                and journal.records[i].fields["exp_id"] == id
            ):
                print(
                    "event:           "
                    + journal.records[i].fields["kind"] + " -> "
                    + journal.records[i].fields["state"]
                )
    return EXIT_OK


def replay_experiment(workspace: String, id: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    var index = find_experiment_index(journal.records, id)
    if index < 0:
        err.write("hyperforge: experiment not found: " + id + "\n")
        return EXIT_FAILURE
    var e = experiment_from_fields(journal.records[index].fields)
    var artifact = workspace + "/" + e.config_artifact
    if not Path(artifact).exists():
        err.write(
            "hyperforge: replay refused; config artifact missing: "
            + e.config_artifact + "\n"
        )
        return EXIT_UNAVAILABLE
    var content = open(artifact, "r").read()
    if hex64(fnv1a64(content)) != e.config_checksum:
        err.write(
            "hyperforge: replay refused; config artifact checksum mismatch: "
            + e.config_artifact + "\n"
        )
        return EXIT_UNAVAILABLE
    print("REPLAY_READY " + id)
    print("Execution is not implemented until M02; this command verifies inputs only.")
    return EXIT_OK
