"""CLI for AutoTransformers configuration search."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE, EXIT_UNAVAILABLE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal, rewrite_journal
from hyperforge.scit.task import TaskSpec
from hyperforge.autotrans.model import TransformerConfig, init_model, serialize_model, deserialize_model
from hyperforge.autotrans.search import SearchOutcome, run_search

comptime CONFIG_MAGIC = "HAUTOTRANS1"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def outcome_fields(outcome: SearchOutcome, checksum: String) raises -> List[Field]:
    var config = outcome.config.copy()
    var fields = List[Field]()
    fields.append(Field("policy", outcome.policy))
    fields.append(Field("budget", String(outcome.budget)))
    fields.append(Field("d_model", String(config.d_model)))
    fields.append(Field("heads", String(config.heads)))
    fields.append(Field("ff_hidden", String(config.ff_hidden)))
    fields.append(Field("layers", String(config.layers)))
    fields.append(Field("parameters", String(outcome.parameters)))
    fields.append(Field("validation_mse", String(outcome.validation_mse)))
    fields.append(Field("test_mse", String(outcome.test_mse)))
    fields.append(Field("latency", String(outcome.latency)))
    fields.append(Field("config_checksum", checksum))
    fields.append(Field("detail", outcome.detail))
    return fields^


def run_autotrans(workspace: String, budget: Int, seed: UInt64) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if budget < 1:
        err.write("hyperforge: budget must be positive\n")
        return EXIT_USAGE

    var spec = TaskSpec("decaying_mode_1d", 6, 2, 0.35, 10, 5, seed)
    var outcomes = List[SearchOutcome]()
    var policies: List[String] = ["default", "random", "adaptive"]
    for policy in policies:
        outcomes.append(run_search(policy, spec, budget, seed).copy())

    var sequence = next_sequence(read_journal(journal_path(workspace)).records)
    for outcome in outcomes:
        var config = outcome.config.copy()
        var id = "autotrans-" + outcome.policy + "-" + String(config.d_model) + "x" + String(config.heads)
        var config_text = (
            CONFIG_MAGIC + "|policy=" + outcome.policy + "|d=" + String(config.d_model)
            + "|h=" + String(config.heads) + "|ff=" + String(config.ff_hidden)
            + "|layers=" + String(config.layers) + "|seed=" + String(seed) + "\n"
        )
        var checksum = hex64(fnv1a64(config_text))
        var config_path = workspace + "/artifacts/" + id + ".config.txt"
        var config_file = open(config_path, "w")
        config_file.write(config_text)
        config_file.close()
        var model = init_model(config)
        var model_path = workspace + "/artifacts/" + id + ".model.txt"
        var model_file = open(model_path, "w")
        model_file.write(serialize_model(model))
        model_file.close()
        append_record(
            journal_path(workspace), sequence, "autotrans", outcome_fields(outcome, checksum)
        )
        sequence += 1

    print("AutoTransformers configuration search (budget=" + String(budget) + ", seed=" + String(seed) + ")")
    print("policy    config       params  val_mse        test_mse       latency_s")
    for i in range(len(outcomes)):
        var outcome = outcomes[i].copy()
        var config = outcome.config.copy()
        print(
            outcome.policy + "  " + String(config.d_model) + "x" + String(config.heads)
            + "/ff" + String(config.ff_hidden) + "/L" + String(config.layers)
            + "  " + String(outcome.parameters) + "  " + String(outcome.validation_mse)
            + "  " + String(outcome.test_mse) + "  " + String(outcome.latency)
        )
    print("selection:        validation MSE only; test measured after selection")
    print("constraint:       no model assumed faster from parameter count alone")
    print("scope:            CPU reference kernels; no MAX inference or serving claim")
    return EXIT_OK


def show_autotrans(workspace: String, policy: String) raises -> Int:
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
        if record.kind == "autotrans" and record.fields["policy"] == policy:
            print("policy:       " + record.fields["policy"])
            print("config:       " + record.fields["d_model"] + "x" + record.fields["heads"]
                + "/ff" + record.fields["ff_hidden"] + "/L" + record.fields["layers"])
            print("parameters:   " + record.fields["parameters"])
            print("test_mse:     " + record.fields["test_mse"])
            print("latency_s:    " + record.fields["latency"])
            return EXIT_OK
    err.write("hyperforge: AutoTransformers result not found: " + policy + "\n")
    return EXIT_FAILURE


def replay_autotrans(workspace: String, policy: String) raises -> Int:
    var err = stderr
    var id = "autotrans-" + policy
    var journal = read_journal(journal_path(workspace))
    for i in range(len(journal.records)):
        ref record = journal.records[i]
        if record.kind != "autotrans" or record.fields["policy"] != policy:
            continue
        var artifact_name = (
            id + "-" + record.fields["d_model"] + "x" + record.fields["heads"] + ".config.txt"
        )
        var candidate_path = workspace + "/artifacts/" + artifact_name
        if not Path(candidate_path).exists():
            err.write("hyperforge: replay refused; config artifact missing\n")
            return EXIT_UNAVAILABLE
        if hex64(fnv1a64(open(candidate_path, "r").read())) != record.fields["config_checksum"]:
            err.write("hyperforge: replay refused; config checksum mismatch\n")
            return EXIT_FAILURE
        print("REPLAY_READY " + policy)
        return EXIT_OK
    err.write("hyperforge: AutoTransformers result not found: " + policy + "\n")
    return EXIT_FAILURE
