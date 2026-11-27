"""CLI for systems-side DiscoveryGenome search."""

from std.pathlib import Path
from std.sys import stderr
from std.sys import has_accelerator
from max.gpu.host import DeviceContext
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE, EXIT_UNAVAILABLE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.discovery.systems_search import (
    SystemsOutcome,
    run_systems_search,
)
from hyperforge.discovery.genome_v2 import GENOME_V2_SCHEMA, BLOCK_CHOICES

comptime POLICIES = "fixed, random, adaptive"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def run_systems(workspace: String, budget: Int, seed: UInt64) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if budget < 1:
        err.write("hyperforge: budget must be positive\n")
        return EXIT_USAGE

    comptime if not has_accelerator():
        err.write("hyperforge: systems search blocked; no accelerator reported\n")
        return EXIT_UNAVAILABLE
    else:
        var ctx: DeviceContext
        try:
            ctx = DeviceContext()
        except e:
            err.write("hyperforge: GPU context blocked: " + String(e) + "\n")
            return EXIT_UNAVAILABLE
        var journal = read_journal(journal_path(workspace))
        var sequence = next_sequence(journal.records)
        var names: List[String] = ["fixed", "random", "adaptive"]
        for name in names:
            var outcome = run_systems_search(ctx, name, budget, seed)
            var report = String("")
            for trial in outcome.records:
                var fields = List[Field]()
                fields.append(Field("policy", name))
                fields.append(Field("genome_id", trial.id))
                fields.append(Field("block_size", String(trial.block_size)))
                fields.append(Field("error", String(trial.error)))
                fields.append(Field("kernel_median", String(trial.kernel_median)))
                fields.append(Field("end_to_end_median", String(trial.end_to_end_median)))
                fields.append(Field("bytes_per_second", String(trial.bytes_per_second)))
                fields.append(Field("state", trial.state))
                append_record(journal_path(workspace), sequence, "systems_trial", fields)
                sequence += 1
                report += (
                    "  block=" + String(trial.block_size)
                    + " kernel_median_s=" + String(trial.kernel_median)
                    + " e2e_median_s=" + String(trial.end_to_end_median)
                    + " state=" + trial.state + "\n"
                )
            print("policy:           " + name)
            print(report, end="")
            print("  best_latency_s: " + String(outcome.best_kernel_median))
            print("  pareto_count:   " + String(outcome.pareto_count))
            print("  wall_s:         " + String(outcome.wall_seconds))
        print("genome_schema:    " + GENOME_V2_SCHEMA)
        print("block_choices:    " + BLOCK_CHOICES)
        print("policies:         " + POLICIES)
        print("note:             AI genome gene carried but not measured in systems-only search")
        print("note:             Pareto uses two measured latency objectives; no weighted score")
        return EXIT_OK


def show_systems(workspace: String) raises -> Int:
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
        if record.kind == "systems_trial":
            count += 1
            print(
                record.fields["policy"] + "  block=" + record.fields["block_size"]
                + "  median=" + record.fields["kernel_median"]
                + "  state=" + record.fields["state"]
            )
    if count == 0:
        err.write("hyperforge: no systems trials recorded\n")
        return EXIT_FAILURE
    return EXIT_OK
