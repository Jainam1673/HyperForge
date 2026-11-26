"""CLI for the reciprocal meta-discovery proof."""

from std.sys import stderr
from std.sys import has_accelerator
from std.time import perf_counter
from std.pathlib import Path
from max.gpu.host import DeviceContext
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal, rewrite_journal
from hyperforge.discovery.reciprocal import PolicyOutcome, run_policy

comptime DATASET = "/home/jack/Projects/HyperForge/examples/regression_linear.csv"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def fields_for(outcome: PolicyOutcome) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("seed", String(outcome.seed)))
    fields.append(Field("budget", String(outcome.budget)))
    fields.append(Field("policy", outcome.policy))
    fields.append(Field("best_rmse", String(outcome.best_rmse)))
    fields.append(Field("best_latency", String(outcome.best_latency)))
    fields.append(Field("wall_seconds", String(outcome.wall_seconds)))
    fields.append(Field("evaluations", String(outcome.evaluations)))
    fields.append(Field("discoveries", String(outcome.discoveries)))
    fields.append(Field("pareto_count", String(outcome.pareto_count)))
    fields.append(Field("detail", outcome.detail))
    return fields^


def run_discovery(workspace: String, budget: Int, seed: UInt64) raises -> Int:
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

    comptime if not has_accelerator():
        err.write("hyperforge: reciprocal proof blocked; no accelerator reported\n")
        return 3
    else:
        var ctx: DeviceContext
        try:
            ctx = DeviceContext()
        except e:
            err.write("hyperforge: GPU context blocked: " + String(e) + "\n")
            return 3
        var use_gpu = True
        var outcomes = List[PolicyOutcome]()
        var sequence = next_sequence(journal.records)
        var policies: List[String] = [
            "fixed", "ai_only", "compute_only", "independent",
            "joint_reciprocal", "ablation_no_history",
        ]
        for policy in policies:
            var outcome = run_policy(policy, seed, budget, DATASET, ctx, use_gpu)
            outcomes.append(outcome.copy())
            append_record(journal_path(workspace), sequence, "discovery", fields_for(outcome))
            sequence += 1

        print("reciprocal discovery proof (budget=" + String(budget) + ", seed=" + String(seed) + ")")
        print("policy                best_rmse      best_latency_s  discoveries  pareto  wall_s")
        for i in range(len(outcomes)):
            var outcome = outcomes[i].copy()
            print(
                outcome.policy + "  " + String(outcome.best_rmse) + "  "
                + String(outcome.best_latency) + "  " + String(outcome.discoveries)
                + "  " + String(outcome.pareto_count) + "  " + String(outcome.wall_seconds)
            )

        var joint = outcomes[4].copy()
        var independent = outcomes[3].copy()
        print("matched_budget:       " + String(budget))
        print("seeds_repeated:       run twice with different seeds for variability")
        print("memory:               NOT_TESTED (no verified Mojo memory API in this release)")
        if joint.best_rmse < independent.best_rmse:
            print("joint_vs_independent: joint lower RMSE")
        elif independent.best_rmse < joint.best_rmse:
            print("joint_vs_independent: independent lower RMSE")
        else:
            print("joint_vs_independent: tie on RMSE")
        if joint.best_latency < independent.best_latency and joint.best_latency > 0.0:
            print("joint_vs_independent: joint lower latency")
        else:
            print("joint_vs_independent: no joint latency advantage")
        print("note: coupling is not assumed to help; negative results are reported.")
        return EXIT_OK
