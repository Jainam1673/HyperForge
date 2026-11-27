"""CLI for the joint AI x compute discovery benchmark."""

from std.pathlib import Path
from std.sys import stderr
from std.sys import has_accelerator
from max.gpu.host import DeviceContext
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE, EXIT_UNAVAILABLE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.joint.benchmark import run_joint
from hyperforge.joint.benchmark import JOINT_SCHEMA

comptime POLICIES = "fixed, ai_only, compute_only, independent, sequential, joint, ablation_no_shared_history, ablation_no_adaptive, ablation_no_meta"
comptime DEFAULT_BUDGET = 6


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def policy_names() raises -> List[String]:
    var names = List[String]()
    for name in [
        "fixed",
        "ai_only",
        "compute_only",
        "independent",
        "sequential",
        "joint",
        "ablation_no_shared_history",
        "ablation_no_adaptive",
        "ablation_no_meta",
    ]:
        names.append(name)
    return names^


def run_joint_benchmark(
    workspace: String, budget: Int, seeds: List[UInt64]
) raises -> Int:
    if not workspace_ready(workspace):
        var err = stderr
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if budget < 2:
        var err = stderr
        err.write("hyperforge: budget must be at least 2\n")
        return EXIT_USAGE

    var err = stderr
    comptime if not has_accelerator():
        err.write("hyperforge: joint benchmark blocked; no accelerator reported\n")
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
        var names = policy_names()
        var discovery_totals = List[Int]()
        for _ in range(len(names)):
            discovery_totals.append(0)

        for seed in seeds:
            print("seed: " + String(seed))
            for i in range(len(names)):
                var policy = names[i]
                var outcome = run_joint(ctx, policy, budget, seed)
                discovery_totals[i] += outcome.discoveries
                var fields = List[Field]()
                fields.append(Field("policy", policy))
                fields.append(Field("seed", String(seed)))
                fields.append(Field("budget", String(outcome.budget)))
                fields.append(Field("best_rmse", String(outcome.best_rmse)))
                fields.append(Field("best_latency", String(outcome.best_latency)))
                fields.append(Field("ai_evaluations", String(outcome.ai_evaluations)))
                fields.append(Field(
                    "compute_evaluations", String(outcome.compute_evaluations)
                ))
                fields.append(Field("discoveries", String(outcome.discoveries)))
                fields.append(Field("wall_seconds", String(outcome.wall_seconds)))
                fields.append(Field("detail", outcome.detail))
                append_record(journal_path(workspace), sequence, "joint_outcome", fields)
                sequence += 1
                print(
                    "  " + policy + "  rmse=" + String(outcome.best_rmse)
                    + "  latency=" + String(outcome.best_latency)
                    + "  discoveries=" + String(outcome.discoveries)
                    + "  ai=" + String(outcome.ai_evaluations)
                    + "  compute=" + String(outcome.compute_evaluations)
                    + "  wall=" + String(outcome.wall_seconds)
                )

        print("matched_budget: " + String(budget))
        print("seeds_tested:   " + String(len(seeds)))
        print("schema:         " + JOINT_SCHEMA)
        print("policies:       " + POLICIES)
        print("mean discoveries per policy:")
        var joint_index = -1
        for i in range(len(names)):
            if names[i] == "joint":
                joint_index = i
            print("  " + names[i] + "  " + String(
                Float64(discovery_totals[i]) / Float64(len(seeds))
            ))
        print("memory:         NOT_TESTED (no verified memory API in installed Mojo)")
        print("experiment cost: matched evaluation count per policy")
        if joint_index >= 0:
            var joint_mean = Float64(discovery_totals[joint_index]) / Float64(len(seeds))
            var best_other = Float64(0.0)
            for i in range(len(names)):
                if i != joint_index:
                    var other = Float64(discovery_totals[i]) / Float64(len(seeds))
                    if other > best_other:
                        best_other = other
            if joint_mean > best_other:
                print("result:         joint led mean discoveries")
            else:
                print("result:         joint did NOT lead mean discoveries (negative result)")
        print("note:           ablations constrain but do not prove general coupling")
        print("note:           small fixture; 3 seeds; no claim of universal superiority")
        return EXIT_OK


def show_joint(workspace: String) raises -> Int:
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
        if record.kind == "joint_outcome":
            count += 1
            print(
                "seed=" + record.fields["seed"]
                + "  " + record.fields["policy"]
                + "  discoveries=" + record.fields["discoveries"]
                + "  rmse=" + record.fields["best_rmse"]
            )
    if count == 0:
        err.write("hyperforge: no joint outcomes recorded; run 'hyperforge joint run' first\n")
        return EXIT_FAILURE
    return EXIT_OK
