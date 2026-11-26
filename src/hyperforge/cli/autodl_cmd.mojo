"""CLI for the AutoDL deep-learning search slice."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE, EXIT_UNAVAILABLE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal, rewrite_journal
from hyperforge.autodl.task import make_task
from hyperforge.autodl.model import (
    ArchCandidate,
    valid_candidate,
    serialize_model,
    deserialize_model,
)
from hyperforge.autodl.search import SearchOutcome, run_search

comptime CONFIG_MAGIC = "HAUTODL1"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def outcome_fields(outcome: SearchOutcome) raises -> List[Field]:
    var candidate = outcome.best_candidate.copy()
    var fields = List[Field]()
    fields.append(Field("seed", String(outcome.seed)))
    fields.append(Field("budget", String(outcome.budget)))
    fields.append(Field("policy", outcome.policy))
    fields.append(Field("candidate_id", candidate.id))
    fields.append(Field("depth", String(candidate.depth)))
    fields.append(Field("width", String(candidate.width)))
    fields.append(Field("activation", candidate.activation))
    fields.append(Field("learning_rate", String(candidate.learning_rate)))
    fields.append(Field("batch_size", String(candidate.batch_size)))
    fields.append(Field("val_loss", String(outcome.best_validation_loss)))
    fields.append(Field("test_loss", String(outcome.test_loss)))
    fields.append(Field("test_accuracy", String(outcome.test_accuracy)))
    fields.append(Field("trained", String(outcome.trained)))
    fields.append(Field("distinct_architectures", String(outcome.distinct_architectures)))
    fields.append(Field("wall_seconds", String(outcome.wall_seconds)))
    fields.append(Field("detail", outcome.detail))
    return fields^


def record_candidate(fields: Dict[String, String], seed: UInt64) raises -> ArchCandidate:
    var candidate = ArchCandidate(
        fields["candidate_id"],
        Int(fields["depth"]),
        Int(fields["width"]),
        Float64(fields["learning_rate"]),
        Int(fields["batch_size"]),
        fields["activation"],
        seed,
    )
    return candidate^


def run_autodl(workspace: String, budget: Int, seed: UInt64) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if budget < 2:
        err.write("hyperforge: budget must be at least 2\n")
        return EXIT_USAGE

    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    if journal.status == "RECOVERED":
        rewrite_journal(journal_path(workspace), journal.good_content)

    var task = make_task(seed)
    var random_outcome = run_search("random", task, budget, seed)
    var adaptive_outcome = run_search("adaptive", task, budget, seed)

    var sequence = next_sequence(journal.records)
    var outcomes = List[SearchOutcome]()
    outcomes.append(random_outcome.copy())
    outcomes.append(adaptive_outcome.copy())
    for outcome in outcomes:
        var id = outcome.best_candidate.id + "-" + outcome.policy
        var config = (
            CONFIG_MAGIC + "|seed=" + String(seed) + "|budget=" + String(budget)
            + "|policy=" + outcome.policy + "|task=" + task.name + "\n"
        )
        var checksum = hex64(fnv1a64(config))
        var config_path = workspace + "/artifacts/" + id + ".config.txt"
        var config_file = open(config_path, "w")
        config_file.write(config)
        config_file.close()
        var model_path = workspace + "/artifacts/" + id + ".model.txt"
        var model_file = open(model_path, "w")
        model_file.write(serialize_model(outcome.best_model))
        model_file.close()

        var fields = outcome_fields(outcome)
        fields.append(Field("artifact_id", id))
        fields.append(Field("config_checksum", checksum))
        append_record(journal_path(workspace), sequence, "autodl", fields)
        sequence += 1

    print("AutoDL search (budget=" + String(budget) + ", seed=" + String(seed) + ")")
    print("task:             " + task.name + " (synthetic)")
    print("random:           acc=" + String(random_outcome.test_accuracy)
        + " val_loss=" + String(random_outcome.best_validation_loss)
        + " arch=" + String(random_outcome.best_candidate.depth) + "x"
        + String(random_outcome.best_candidate.width)
        + " trained=" + String(random_outcome.trained)
        + " distinct=" + String(random_outcome.distinct_architectures))
    print("adaptive:         acc=" + String(adaptive_outcome.test_accuracy)
        + " val_loss=" + String(adaptive_outcome.best_validation_loss)
        + " arch=" + String(adaptive_outcome.best_candidate.depth) + "x"
        + String(adaptive_outcome.best_candidate.width)
        + " trained=" + String(adaptive_outcome.trained)
        + " distinct=" + String(adaptive_outcome.distinct_architectures))
    print("selection:        validation loss only; test evaluated once after selection")
    print("architecture:     candidates differ in depth/width, not just hyperparameters")
    if random_outcome.test_accuracy > adaptive_outcome.test_accuracy:
        print("higher_test_acc:  random")
    elif adaptive_outcome.test_accuracy > random_outcome.test_accuracy:
        print("higher_test_acc:  adaptive")
    else:
        print("higher_test_acc:  tie")
    return EXIT_OK


def show_autodl(workspace: String, id: String) raises -> Int:
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
        if record.kind == "autodl" and record.fields["candidate_id"] == id:
            found = True
            print("policy:           " + record.fields["policy"])
            print("architecture:     " + record.fields["depth"] + "x" + record.fields["width"])
            print("activation:       " + record.fields["activation"])
            print("val_loss:         " + record.fields["val_loss"])
            print("test_accuracy:    " + record.fields["test_accuracy"])
            print("distinct_arch:    " + record.fields["distinct_architectures"])
    if not found:
        err.write("hyperforge: AutoDL result not found: " + id + "\n")
        return EXIT_FAILURE
    return EXIT_OK


def replay_autodl(workspace: String, id: String) raises -> Int:
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
        if record.kind == "autodl" and record.fields["candidate_id"] == id:
            var seed = UInt64(Int(record.fields["seed"]))
            var candidate = record_candidate(record.fields, seed)
            if not valid_candidate(candidate):
                err.write("hyperforge: replay refused; recorded candidate is invalid\n")
                return EXIT_FAILURE
            var model_path = workspace + "/artifacts/" + record.fields["artifact_id"] + ".model.txt"
            if not Path(model_path).exists():
                err.write("hyperforge: replay refused; checkpoint missing\n")
                return EXIT_UNAVAILABLE
            var restored = deserialize_model(open(model_path, "r").read())
            if len(restored.parameters) == 0:
                err.write("hyperforge: replay refused; empty checkpoint\n")
                return EXIT_FAILURE
            print("REPLAY_READY " + id)
            print("checkpoint restored; test accuracy remains recorded evidence")
            return EXIT_OK
    err.write("hyperforge: AutoDL result not found: " + id + "\n")
    return EXIT_FAILURE
