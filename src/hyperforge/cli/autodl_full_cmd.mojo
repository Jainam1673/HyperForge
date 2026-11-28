"""CLI for full AutoDL breadth (HPO + structural NAS)."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.autodl.task import make_task
from hyperforge.autodl.full_search import FULL_SEARCH_SCHEMA, run_full_search

comptime POLICIES = "grid, random, adaptive, multifidelity"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def run_autodl_full(
    workspace: String, policy: String, budget: Int, seed: UInt64, seeds: Int
) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if budget < 2 or seeds < 1:
        err.write("hyperforge: budget must be >=2 and seeds >=1\n")
        return EXIT_USAGE
    try:
        var task = make_task(seed)
        var outcome = run_full_search(policy, task, budget, seed, seeds)
        var fields = List[Field]()
        fields.append(Field("schema", FULL_SEARCH_SCHEMA))
        fields.append(Field("policy", policy))
        fields.append(Field("seed", String(seed)))
        fields.append(Field("budget", String(budget)))
        fields.append(Field("seeds", String(seeds)))
        fields.append(Field("candidate_id", outcome.best.id))
        fields.append(Field("depth", String(outcome.best.depth)))
        fields.append(Field("width", String(outcome.best.width)))
        fields.append(Field("activation", outcome.best.activation))
        fields.append(Field("validation_loss", String(outcome.validation)))
        fields.append(Field("test_loss", String(outcome.test_loss)))
        fields.append(Field("test_accuracy", String(outcome.test_accuracy)))
        fields.append(Field("trained", String(outcome.trained)))
        fields.append(Field("distinct_architectures", String(outcome.distinct)))
        fields.append(Field("fidelity_promotions", String(outcome.fidelity_promotions)))
        fields.append(Field("wall_seconds", String(outcome.wall_seconds)))
        fields.append(Field("detail", outcome.detail))
        append_record(
            journal_path(workspace),
            next_sequence(read_journal(journal_path(workspace)).records),
            "autodl_full", fields,
        )
        print("schema:              " + FULL_SEARCH_SCHEMA)
        print("policy:              " + policy)
        print("policies:            " + POLICIES)
        print("budget:              " + String(budget))
        print("seeds:               " + String(seeds))
        print("winner:              " + outcome.best.id)
        print("architecture:        depth=" + String(outcome.best.depth)
            + " width=" + String(outcome.best.width)
            + " activation=" + outcome.best.activation)
        print("validation_loss:     " + String(outcome.validation))
        print("test_loss:           " + String(outcome.test_loss))
        print("test_accuracy:       " + String(outcome.test_accuracy))
        print("distinct_architectures: " + String(outcome.distinct))
        print("fidelity_promotions: " + String(outcome.fidelity_promotions))
        print("detail:              " + outcome.detail)
        print("note:                NAS varies structure; HPO varies validated parameters")
        return EXIT_OK
    except e:
        err.write("hyperforge: autodl full failed: " + String(e) + "\n")
        return EXIT_FAILURE
