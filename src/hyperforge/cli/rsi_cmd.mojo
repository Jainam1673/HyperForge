"""CLI for bounded, config-only recursive self-improvement."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.evidence.journal import read_journal, journal_path
from hyperforge.rsi.protected import RSI_SCHEMA
from hyperforge.rsi.loop import run_rsi, rollback, ensure_protected

comptime DEFAULT_TRIALS = 8


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def run_rsi_cmd(workspace: String, trials: Int, authorized: Bool) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if trials < 1:
        err.write("hyperforge: trials must be positive\n")
        return EXIT_USAGE
    if trials > 1000:
        err.write("hyperforge: trials exceed the hard CLI ceiling of 1000\n")
        return EXIT_USAGE

    try:
        var outcome = run_rsi(workspace, trials, authorized, UInt64(42))
        print("schema:          " + RSI_SCHEMA)
        print("trials:          " + String(outcome.trials))
        print("budget:          " + String(outcome.budget))
        print("accepted:        " + String(outcome.accepted))
        print("rejected:        " + String(outcome.rejected))
        print("deferred:        " + String(outcome.deferred))
        print("wall_seconds:    " + String(outcome.wall_seconds))
        print("state:           " + outcome.state)
        print("authorization:   " + ("--apply" if authorized else "report-only"))
        print("candidate scope: config only; no generated code execution")
        print("evaluator:       protected thresholds and checksums; holdout gate")
        for i in range(len(outcome.decisions)):
            ref decision = outcome.decisions[i]
            print(
                "  " + decision.decision + "  " + decision.candidate_id
                + "  reason=" + decision.reason
                + "  val=" + String(decision.validation_rmse)
                + "  test=" + String(decision.test_rmse)
            )
        if not authorized:
            print("note:            passing candidates are deferred until --apply")
        return EXIT_OK
    except e:
        err.write("hyperforge: RSI run blocked: " + String(e) + "\n")
        return EXIT_FAILURE


def show_rsi(workspace: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    try:
        var protected = ensure_protected(workspace)
        print("baseline:        " + protected.baseline.model_kind
            + " iterations=" + String(protected.baseline.iterations)
            + " checksum=" + protected.baseline.checksum)
        print("protocol:        min_gain="
            + String(protected.protocol.min_relative_rmse_gain)
            + " max_regression="
            + String(protected.protocol.max_test_rmse_regression)
            + " max_trials=" + String(protected.protocol.max_trials)
            + " checksum=" + protected.protocol.checksum)
    except e:
        err.write("hyperforge: protected records unavailable: " + String(e) + "\n")
        return EXIT_FAILURE

    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    var count = 0
    for i in range(len(journal.records)):
        ref record = journal.records[i]
        if record.kind == "rsi_decision":
            count += 1
            print(
                record.fields["decision"] + "  " + record.fields["candidate_id"]
                + "  " + record.fields["reason"]
            )
    if count == 0:
        err.write("hyperforge: no RSI decisions recorded; run 'hyperforge rsi run' first\n")
        return EXIT_FAILURE
    return EXIT_OK


def rollback_rsi(workspace: String, authorized: Bool) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    try:
        var decision = rollback(
            workspace, authorized,
            "operator authorized recovery to protected baseline",
        )
        print("decision:        " + decision.decision)
        print("restored_config: " + decision.candidate_config)
        print("authorization:   " + ("--apply" if authorized else "report-only"))
        return EXIT_OK
    except e:
        err.write("hyperforge: rollback blocked: " + String(e) + "\n")
        return EXIT_FAILURE
