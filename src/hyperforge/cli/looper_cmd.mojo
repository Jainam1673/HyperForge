"""CLI for the durable Scientific Looper."""

from std.math import abs
from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.automl.dataset import load_csv, target_at
from hyperforge.automl.split import make_split
from hyperforge.automl.preprocess import fit_preprocessor, transform_row
from hyperforge.automl.models import Candidate, fit_model, predict, MODEL_BASELINE, MODEL_LINEAR
from hyperforge.automl.metrics import compute_metrics
from hyperforge.looper.state_machine import (
    OBSERVE, FORMULATE, HYPOTHESIZE, PLAN, VALIDATE_CONSTRAINTS,
    EXECUTE, MEASURE, VERIFY, COMPARE, LEARN, ACCEPTED, REJECTED,
)
from hyperforge.looper.engine import LoopRun, LoopEvent, run_id, advance, decide, rollback

comptime DATASET = "/home/jack/Projects/HyperForge/examples/regression_linear.csv"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def validation_rmse(kind: String, iterations: Int) raises -> Float64:
    var dataset = load_csv(DATASET, "y")
    var split = make_split(dataset.rows, UInt64(42))
    var preprocessor = fit_preprocessor(dataset, split.train)
    var candidate = Candidate("loop-candidate", kind, iterations, 0.0, 0)
    var model = fit_model(candidate, dataset, split.train, preprocessor)
    var predictions = List[Float64]()
    var actuals = List[Float64]()
    for row in split.validation:
        predictions.append(predict(model, transform_row(preprocessor, dataset, row)))
        actuals.append(target_at(dataset, row))
    return compute_metrics(predictions, actuals).rmse


def run_looper(workspace: String, hypothesis: String, budget: Int) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if budget < 2:
        err.write("hyperforge: budget must be at least 2\n")
        return EXIT_USAGE

    var id = run_id(hypothesis, UInt64(42))
    var loop = LoopRun(id, hypothesis, budget)

    if not advance(loop, FORMULATE, "research-planner", "define measurable claim", "", "claim", "", "bounded regression claim"):
        return EXIT_FAILURE
    if not advance(loop, HYPOTHESIZE, "domain-specialist", hypothesis, "claim", "hypothesis", "", "explicit hypothesis"):
        return EXIT_FAILURE
    if not advance(loop, PLAN, "algorithm-engineer", "baseline plus linear candidate", "hypothesis", "plan", "", "two configurations"):
        return EXIT_FAILURE
    if not advance(loop, VALIDATE_CONSTRAINTS, "security-reliability", "local CPU dataset only", "plan", "constraints", "", "no external services"):
        return EXIT_FAILURE
    if not advance(loop, EXECUTE, "capability-owner", "fit baseline and candidate", "constraints", "trial-1", "", "real model fitting"):
        return EXIT_FAILURE

    var candidate_rmse = validation_rmse(MODEL_LINEAR, 200)
    var baseline_rmse = validation_rmse(MODEL_BASELINE, 0)
    if not advance(loop, MEASURE, "independent-verifier", "validation RMSE", "trial-1", "metrics", "", "computed from predictions"):
        return EXIT_FAILURE

    var verified_rmse = validation_rmse(MODEL_LINEAR, 200)
    if not advance(loop, VERIFY, "independent-verifier", "recompute candidate RMSE", "metrics", "verification", "", "deterministic recomputation"):
        return EXIT_FAILURE
    if not advance(loop, COMPARE, "experiment-economist", "candidate versus baseline", "verification", "comparison", "", "improvement measured"):
        return EXIT_FAILURE
    if not advance(loop, LEARN, "orchestrator", "record decision evidence", "comparison", "decision", "", "evidence-based decision"):
        return EXIT_FAILURE

    var improvement = baseline_rmse - candidate_rmse
    var consistent = abs(verified_rmse - candidate_rmse) < Float64(1e-9)
    var decision = String(REJECTED)
    var reason = String("candidate did not beat baseline or verification disagreed")
    if improvement > 0.0 and consistent:
        decision = ACCEPTED
        reason = "candidate beat baseline and verification matched"

    if not decide(loop, decision, reason, "evidence:" + id):
        return EXIT_FAILURE

    var journal = read_journal(journal_path(workspace))
    var sequence = next_sequence(journal.records)
    for event in loop.events:
        var fields = List[Field]()
        fields.append(Field("run_id", id))
        fields.append(Field("sequence", String(event.sequence)))
        fields.append(Field("from_state", event.from_state))
        fields.append(Field("to_state", event.to_state))
        fields.append(Field("actor", event.actor))
        fields.append(Field("reason", event.reason))
        fields.append(Field("input_id", event.input_id))
        fields.append(Field("output_id", event.output_id))
        fields.append(Field("budget_remaining", String(event.budget_remaining)))
        fields.append(Field("artifact", event.artifact))
        fields.append(Field("detail", event.detail))
        fields.append(Field("final_state", loop.state))
        append_record(journal_path(workspace), sequence, "looper", fields)
        sequence += 1

    print("run_id:          " + id)
    print("hypothesis:      " + hypothesis)
    print("baseline_rmse:   " + String(baseline_rmse))
    print("candidate_rmse:  " + String(candidate_rmse))
    print("verified_rmse:   " + String(verified_rmse))
    print("improvement:     " + String(improvement))
    print("decision:        " + loop.state)
    print("transitions:     " + String(len(loop.events)))
    print("budget_remaining:" + String(loop.budget - loop.trials_used))
    print("note:            roles are sequential passes; no parallel agents claimed")
    return EXIT_OK


def show_looper(workspace: String, id: String) raises -> Int:
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
        if record.kind == "looper" and record.fields["run_id"] == id:
            count += 1
            print(
                record.fields["sequence"] + "  " + record.fields["from_state"]
                + " -> " + record.fields["to_state"]
                + "  actor=" + record.fields["actor"]
                + "  reason=" + record.fields["reason"]
            )
    if count == 0:
        err.write("hyperforge: loop run not found: " + id + "\n")
        return EXIT_FAILURE
    return EXIT_OK
