"""CLI for the SciDL supervised field-regression slice."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.scidl.trainer import SciDLOutcome, run_experiment

comptime CONFIG_MAGIC = "HSCIDL1"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def run_scidl(workspace: String, seed: UInt64) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    var outcome = run_experiment(seed)
    var id = "scidl-" + hex64(fnv1a64("field|" + String(seed)))
    var config = CONFIG_MAGIC + "|task=poisson_field_supervised|seed=" + String(seed) + "\n"
    var checksum = hex64(fnv1a64(config))
    var config_path = workspace + "/artifacts/" + id + ".config.txt"
    var config_file = open(config_path, "w")
    config_file.write(config)
    config_file.close()
    var model_path = workspace + "/artifacts/" + id + ".model.txt"
    var model_file = open(model_path, "w")
    model_file.write(outcome.checkpoint)
    model_file.close()

    var fields = List[Field]()
    fields.append(Field("seed", String(seed)))
    fields.append(Field("train_rmse", String(outcome.train_rmse)))
    fields.append(Field("learned_rmse", String(outcome.learned_rmse)))
    fields.append(Field("learned_max", String(outcome.learned_max_error)))
    fields.append(Field("linear_rmse", String(outcome.linear_rmse)))
    fields.append(Field("fd_rmse", String(outcome.fd_rmse)))
    fields.append(Field("train_k_max", String(outcome.train_parameter_max)))
    fields.append(Field("test_k_min", String(outcome.test_parameter_min)))
    fields.append(Field("state", outcome.state))
    fields.append(Field("config_checksum", checksum))
    append_record(journal_path(workspace), next_sequence(read_journal(journal_path(workspace)).records), "scidl", fields)

    print("experiment:       " + id)
    print("task:             poisson_field_supervised (synthetic)")
    print("train k range:    [0.5, " + String(outcome.train_parameter_max) + "]")
    print("held-out k range: [" + String(outcome.test_parameter_min) + ", 1.5]")
    print("train RMSE:       " + String(outcome.train_rmse))
    print("learned RMSE:     " + String(outcome.learned_rmse))
    print("learned max err:  " + String(outcome.learned_max_error))
    print("linear baseline:  " + String(outcome.linear_rmse))
    print("FD reference:     " + String(outcome.fd_rmse))
    print("state:            " + outcome.state)
    print("config:           " + config_path)
    print("checkpoint:       " + model_path)
    return EXIT_OK


def show_scidl(workspace: String, id: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    for i in range(len(journal.records)):
        ref record = journal.records[i]
        if record.kind == "scidl":
            print("learned RMSE:    " + record.fields["learned_rmse"])
            print("linear baseline: " + record.fields["linear_rmse"])
            print("FD reference:    " + record.fields["fd_rmse"])
            print("state:           " + record.fields["state"])
            return EXIT_OK
    err.write("hyperforge: SciDL result not found: " + id + "\n")
    return EXIT_FAILURE
