"""CLI for the meta experiment economy and causal evidence graph."""

from std.pathlib import Path
from std.sys import stderr
from std.sys import has_accelerator
from max.gpu.host import DeviceContext
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE, EXIT_UNAVAILABLE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.meta.economy import EconomyOutcome, run_economy
from hyperforge.meta.causal import (
    CAUSAL_SCHEMA,
    RELATION_HYPOTHESIZED,
)

comptime ECONOMY_POLICIES = "fixed, random, adaptive, ai_only"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def run_meta(workspace: String, budget: Int, seed: UInt64) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if budget < 1:
        err.write("hyperforge: budget must be positive\n")
        return EXIT_USAGE

    comptime if not has_accelerator():
        err.write("hyperforge: meta economy blocked; no accelerator reported\n")
        return EXIT_UNAVAILABLE
    else:
        var ctx: DeviceContext
        try:
            ctx = DeviceContext()
        except e:
            err.write("hyperforge: GPU context blocked: " + String(e) + "\n")
            return EXIT_UNAVAILABLE
        return run_meta_with_context(workspace, budget, seed, ctx)


def run_meta_with_context(
    workspace: String, budget: Int, seed: UInt64, mut ctx: DeviceContext
) raises -> Int:
    var use_gpu = True
    var journal = read_journal(journal_path(workspace))
    var sequence = next_sequence(journal.records)
    var policies: List[String] = ["fixed", "random", "adaptive", "ai_only"]
    for policy in policies:
        var outcome = run_economy(policy, seed, budget, ctx, use_gpu)
        var fields = List[Field]()
        fields.append(Field("policy", policy))
        fields.append(Field("seed", String(seed)))
        fields.append(Field("budget", String(outcome.budget)))
        fields.append(Field("total_gain", String(outcome.total_gain)))
        fields.append(Field("ai_evaluations", String(outcome.ai_evaluations)))
        fields.append(Field("compute_evaluations", String(outcome.compute_evaluations)))
        fields.append(Field("wall_seconds", String(outcome.wall_seconds)))
        fields.append(Field("state", outcome.state))
        append_record(journal_path(workspace), sequence, "meta_economy", fields)
        sequence += 1
        for edge in outcome.edges:
            var edge_fields = List[Field]()
            edge_fields.append(Field("source", edge.source))
            edge_fields.append(Field("target", edge.target))
            edge_fields.append(Field("relation", edge.relation))
            edge_fields.append(Field("evidence", edge.evidence))
            edge_fields.append(Field("detail", edge.detail))
            append_record(journal_path(workspace), sequence, "causal_edge", edge_fields)
            sequence += 1
        print(
            policy + "  gain=" + String(outcome.total_gain)
            + "  ai=" + String(outcome.ai_evaluations)
            + "  compute=" + String(outcome.compute_evaluations)
            + "  wall=" + String(outcome.wall_seconds)
            + "  state=" + outcome.state
        )

    print("matched_budget:   " + String(budget))
    print("policies:         " + ECONOMY_POLICIES)
    print("causal_schema:    " + CAUSAL_SCHEMA)
    print("note:             coupling edge remains hypothesized until an ablation isolates it")
    print("note:             no causal claim from a single correlated change")
    return EXIT_OK


def show_graph(workspace: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    var count = 0
    for i in range(len(journal.records)):
        ref record = journal.records[i]
        if record.kind == "causal_edge":
            count += 1
            print(
                record.fields["source"] + " -> " + record.fields["target"]
                + "  [" + record.fields["relation"] + "]"
                + "  evidence=" + record.fields["evidence"]
            )
    if count == 0:
        err.write("hyperforge: no causal edges recorded; run 'hyperforge meta run' first\n")
        return EXIT_FAILURE
    print("note: hypothesized edges are not causal claims")
    _ = RELATION_HYPOTHESIZED
    return EXIT_OK
