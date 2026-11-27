"""Bounded, config-only RSI loop with protected evaluator and holdout gate."""

from std.math import sqrt
from std.time import perf_counter
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.automl.dataset import Dataset, load_csv, target_at
from hyperforge.automl.split import make_split
from hyperforge.automl.preprocess import Preprocessor, fit_preprocessor, transform_row
from hyperforge.automl.models import Candidate, fit_model, predict
from hyperforge.automl.metrics import compute_metrics
from hyperforge.evidence.record import Field, JournalRecord
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.rsi.protected import (
    RSI_SCHEMA,
    BASELINE_SCHEMA,
    PROTOCOL_SCHEMA,
    ProtectedConfig,
    EvaluatorProtocol,
    default_protected_config,
    default_protocol,
    verify_protected_config,
    verify_protocol,
    config_canonical,
    protocol_canonical,
)
from hyperforge.rsi.candidate import (
    ConfigCandidate, valid_candidate, candidate_size, propose,
)

comptime DATASET = "/home/jack/Projects/HyperForge/examples/regression_linear.csv"
comptime DECISION_ACCEPT = "ACCEPT"
comptime DECISION_REJECT = "REJECT"
comptime DECISION_DEFER = "DEFER"
comptime DECISION_ROLLBACK = "ROLLBACK"


struct RsiDecision(Copyable, Movable):
    var candidate_id: String
    var decision: String
    var candidate_config: String
    var validation_rmse: Float64
    var test_rmse: Float64
    var baseline_validation_rmse: Float64
    var baseline_test_rmse: Float64
    var reason: String
    var authorized: Bool

    def __init__(
        out self,
        candidate_id: String,
        decision: String,
        candidate_config: String,
        validation_rmse: Float64,
        test_rmse: Float64,
        baseline_validation_rmse: Float64,
        baseline_test_rmse: Float64,
        reason: String,
        authorized: Bool,
    ):
        self.candidate_id = candidate_id
        self.decision = decision
        self.candidate_config = candidate_config
        self.validation_rmse = validation_rmse
        self.test_rmse = test_rmse
        self.baseline_validation_rmse = baseline_validation_rmse
        self.baseline_test_rmse = baseline_test_rmse
        self.reason = reason
        self.authorized = authorized


struct RsiOutcome(Copyable, Movable):
    var trials: Int
    var accepted: Int
    var rejected: Int
    var deferred: Int
    var wall_seconds: Float64
    var budget: Int
    var state: String
    var decisions: List[RsiDecision]

    def __init__(
        out self,
        trials: Int,
        accepted: Int,
        rejected: Int,
        deferred: Int,
        wall_seconds: Float64,
        budget: Int,
        state: String,
        var decisions: List[RsiDecision],
    ):
        self.trials = trials
        self.accepted = accepted
        self.rejected = rejected
        self.deferred = deferred
        self.wall_seconds = wall_seconds
        self.budget = budget
        self.state = state
        self.decisions = decisions^


def abs64(value: Float64) raises -> Float64:
    if value < 0.0:
        return -value
    return value


def rmse_on(
    model_kind: String,
    iterations: Int,
    regularization: Float64,
    k: Int,
    dataset: Dataset,
    rows: List[Int],
    preprocessor: Preprocessor,
) raises -> Float64:
    var candidate = Candidate("rsi", model_kind, iterations, regularization, k)
    var model = fit_model(candidate, dataset, rows, preprocessor)
    var predictions = List[Float64]()
    var actuals = List[Float64]()
    for row in rows:
        predictions.append(predict(
            model, transform_row(preprocessor, dataset, row)
        ))
        actuals.append(target_at(dataset, row))
    return compute_metrics(predictions, actuals).rmse


def independent_rmse(
    model_kind: String,
    iterations: Int,
    regularization: Float64,
    k: Int,
    dataset: Dataset,
    rows: List[Int],
    preprocessor: Preprocessor,
) raises -> Float64:
    """Verifier path: reverse traversal and a direct squared-error accumulator."""
    var candidate = Candidate("rsi-verify", model_kind, iterations, regularization, k)
    var model = fit_model(candidate, dataset, rows, preprocessor)
    var squared_error = Float64(0.0)
    var count = 0
    var i = len(rows) - 1
    while i >= 0:
        var prediction = predict(
            model, transform_row(preprocessor, dataset, rows[i])
        )
        var delta = target_at(dataset, rows[i]) - prediction
        squared_error += delta * delta
        count += 1
        i -= 1
    if count == 0:
        raise Error("independent verifier requires observations")
    return sqrt(squared_error / Float64(count))


def within_bounds(candidate: ConfigCandidate, protocol: EvaluatorProtocol) raises -> Bool:
    if not valid_candidate(candidate):
        return False
    return candidate_size(candidate) <= protocol.max_candidate_bytes


def find_record_field(
    records: List[JournalRecord], kind: String, key: String
) raises -> String:
    for i in range(len(records)):
        ref record = records[i]
        if record.kind == kind:
            if key in record.fields:
                return record.fields[key]
    return String("")


struct ProtectedState(Copyable, Movable):
    var baseline: ProtectedConfig
    var protocol: EvaluatorProtocol

    def __init__(out self, baseline: ProtectedConfig, protocol: EvaluatorProtocol):
        self.baseline = baseline.copy()
        self.protocol = protocol.copy()


def ensure_protected(workspace: String) raises -> ProtectedState:
    """Load protected records, creating them once if absent. Never overwrites."""
    var path = journal_path(workspace)
    var journal = read_journal(path)
    if journal.status == "ERROR":
        raise Error("journal error: " + journal.reason)

    var baseline_text = find_record_field(journal.records, "rsi_baseline", "canonical")
    var protocol_text = find_record_field(journal.records, "rsi_protocol", "canonical")
    if baseline_text == "" and protocol_text == "":
        var baseline = default_protected_config()
        var protocol = default_protocol()
        var sequence = next_sequence(journal.records)
        var baseline_fields = List[Field]()
        baseline_fields.append(Field("schema", BASELINE_SCHEMA))
        baseline_fields.append(Field("canonical", config_canonical(
            baseline.model_kind, baseline.iterations,
            baseline.regularization, baseline.k,
        )))
        baseline_fields.append(Field("model_kind", baseline.model_kind))
        baseline_fields.append(Field("iterations", String(baseline.iterations)))
        baseline_fields.append(Field(
            "regularization", String(baseline.regularization)
        ))
        baseline_fields.append(Field("k", String(baseline.k)))
        baseline_fields.append(Field("checksum", baseline.checksum))
        append_record(path, sequence, "rsi_baseline", baseline_fields)
        sequence += 1
        var protocol_fields = List[Field]()
        protocol_fields.append(Field("schema", PROTOCOL_SCHEMA))
        protocol_fields.append(Field("canonical", protocol_canonical(
            protocol.min_relative_rmse_gain,
            protocol.max_test_rmse_regression,
            protocol.max_trials,
            protocol.max_wall_seconds,
            protocol.max_recursion_depth,
            protocol.max_candidate_bytes,
        )))
        protocol_fields.append(Field("checksum", protocol.checksum))
        protocol_fields.append(Field("min_relative_rmse_gain", String(
            protocol.min_relative_rmse_gain
        )))
        protocol_fields.append(Field("max_test_rmse_regression", String(
            protocol.max_test_rmse_regression
        )))
        protocol_fields.append(Field("max_trials", String(protocol.max_trials)))
        protocol_fields.append(Field("max_wall_seconds", String(
            protocol.max_wall_seconds
        )))
        protocol_fields.append(Field("max_recursion_depth", String(
            protocol.max_recursion_depth
        )))
        protocol_fields.append(Field("max_candidate_bytes", String(
            protocol.max_candidate_bytes
        )))
        append_record(path, sequence, "rsi_protocol", protocol_fields)
        return ProtectedState(baseline, protocol)
    if baseline_text == "" or protocol_text == "":
        raise Error("protected RSI records are incomplete")

    var loaded_baseline = default_protected_config()
    loaded_baseline.model_kind = find_record_field(
        journal.records, "rsi_baseline", "model_kind"
    )
    var iterations_text = find_record_field(
        journal.records, "rsi_baseline", "iterations"
    )
    var regularization_text = find_record_field(
        journal.records, "rsi_baseline", "regularization"
    )
    var k_text = find_record_field(journal.records, "rsi_baseline", "k")
    if iterations_text != "":
        loaded_baseline.iterations = Int(iterations_text)
    if regularization_text != "":
        loaded_baseline.regularization = Float64(regularization_text)
    if k_text != "":
        loaded_baseline.k = Int(k_text)
    loaded_baseline.checksum = find_record_field(
        journal.records, "rsi_baseline", "checksum"
    )
    if not verify_protected_config(loaded_baseline):
        raise Error("protected baseline checksum mismatch")

    var loaded_protocol = default_protocol()
    var gain_text = find_record_field(
        journal.records, "rsi_protocol", "min_relative_rmse_gain"
    )
    var regression_text = find_record_field(
        journal.records, "rsi_protocol", "max_test_rmse_regression"
    )
    var trials_text = find_record_field(journal.records, "rsi_protocol", "max_trials")
    var wall_text = find_record_field(journal.records, "rsi_protocol", "max_wall_seconds")
    var depth_text = find_record_field(
        journal.records, "rsi_protocol", "max_recursion_depth"
    )
    var bytes_text = find_record_field(
        journal.records, "rsi_protocol", "max_candidate_bytes"
    )
    if gain_text != "":
        loaded_protocol.min_relative_rmse_gain = Float64(gain_text)
    if regression_text != "":
        loaded_protocol.max_test_rmse_regression = Float64(regression_text)
    if trials_text != "":
        loaded_protocol.max_trials = Int(trials_text)
    if wall_text != "":
        loaded_protocol.max_wall_seconds = Float64(wall_text)
    if depth_text != "":
        loaded_protocol.max_recursion_depth = Int(depth_text)
    if bytes_text != "":
        loaded_protocol.max_candidate_bytes = Int(bytes_text)
    loaded_protocol.checksum = find_record_field(
        journal.records, "rsi_protocol", "checksum"
    )
    if not verify_protocol(loaded_protocol):
        raise Error("protected protocol checksum mismatch")
    return ProtectedState(loaded_baseline, loaded_protocol)


def decision_fields(
    decision: RsiDecision, baseline: ProtectedConfig, protocol: EvaluatorProtocol
) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("candidate_id", decision.candidate_id))
    fields.append(Field("decision", decision.decision))
    fields.append(Field("candidate_config", decision.candidate_config))
    fields.append(Field("validation_rmse", String(decision.validation_rmse)))
    fields.append(Field("test_rmse", String(decision.test_rmse)))
    fields.append(Field(
        "baseline_validation_rmse", String(decision.baseline_validation_rmse)
    ))
    fields.append(Field("baseline_test_rmse", String(decision.baseline_test_rmse)))
    fields.append(Field("reason", decision.reason))
    fields.append(Field("authorized", String(decision.authorized).lower()))
    fields.append(Field("baseline_checksum", baseline.checksum))
    fields.append(Field("protocol_checksum", protocol.checksum))
    return fields^


def run_rsi(
    workspace: String, trials: Int, authorized: Bool, seed: UInt64
) raises -> RsiOutcome:
    var protected = ensure_protected(workspace)
    var baseline = protected.baseline.copy()
    var protocol = protected.protocol.copy()

    var dataset = load_csv(DATASET, "y")
    var split = make_split(dataset.rows, UInt64(42))
    var preprocessor = fit_preprocessor(dataset, split.train)

    var baseline_validation = rmse_on(
        baseline.model_kind, baseline.iterations, baseline.regularization,
        baseline.k, dataset, split.validation, preprocessor,
    )
    var baseline_test = rmse_on(
        baseline.model_kind, baseline.iterations, baseline.regularization,
        baseline.k, dataset, split.test, preprocessor,
    )

    var budget = trials
    if budget > protocol.max_trials:
        budget = protocol.max_trials
    if budget > protocol.max_recursion_depth:
        budget = protocol.max_recursion_depth
    if budget < 1:
        budget = 1

    var path = journal_path(workspace)
    var journal = read_journal(path)
    var sequence = next_sequence(journal.records)
    var started = perf_counter()
    var decisions = List[RsiDecision]()
    var accepted = 0
    var rejected = 0
    var deferred = 0
    var seen = List[String]()

    for index in range(budget):
        if perf_counter() - started > protocol.max_wall_seconds:
            break
        var candidate = propose(seed, index)
        var canonical = config_canonical(
            candidate.model_kind, candidate.iterations,
            candidate.regularization, candidate.k,
        )
        var validation = Float64(1e300)
        var test = Float64(1e300)

        if not within_bounds(candidate, protocol):
            rejected += 1
            decisions.append(RsiDecision(
                candidate.id, DECISION_REJECT, canonical, validation, test,
                baseline_validation, baseline_test,
                "candidate exceeded config bounds or size ceiling", authorized,
            ))
            continue
        var duplicate = False
        for j in range(len(seen)):
            if seen[j] == candidate.id:
                duplicate = True
                break
        if duplicate:
            rejected += 1
            decisions.append(RsiDecision(
                candidate.id, DECISION_REJECT, canonical, validation, test,
                baseline_validation, baseline_test,
                "duplicate candidate", authorized,
            ))
            continue
        seen.append(candidate.id)

        validation = rmse_on(
            candidate.model_kind, candidate.iterations,
            candidate.regularization, candidate.k,
            dataset, split.validation, preprocessor,
        )
        var gain = (baseline_validation - validation) / baseline_validation
        if gain < protocol.min_relative_rmse_gain:
            rejected += 1
            decisions.append(RsiDecision(
                candidate.id, DECISION_REJECT, canonical, validation, test,
                baseline_validation, baseline_test,
                "insufficient validation gain", authorized,
            ))
            continue

        # Holdout is touched only after the validation screen passes.
        test = rmse_on(
            candidate.model_kind, candidate.iterations,
            candidate.regularization, candidate.k,
            dataset, split.test, preprocessor,
        )
        var verified = independent_rmse(
            candidate.model_kind, candidate.iterations,
            candidate.regularization, candidate.k,
            dataset, split.test, preprocessor,
        )
        if abs64(verified - test) > 1e-9:
            rejected += 1
            decisions.append(RsiDecision(
                candidate.id, DECISION_REJECT, canonical, validation, test,
                baseline_validation, baseline_test,
                "independent verifier disagreement", authorized,
            ))
            continue
        var regression = (test - baseline_test) / baseline_test
        if regression > protocol.max_test_rmse_regression:
            rejected += 1
            decisions.append(RsiDecision(
                candidate.id, DECISION_REJECT, canonical, validation, test,
                baseline_validation, baseline_test,
                "holdout regression", authorized,
            ))
            continue
        if not authorized:
            deferred += 1
            decisions.append(RsiDecision(
                candidate.id, DECISION_DEFER, canonical, validation, test,
                baseline_validation, baseline_test,
                "authorization_required", authorized,
            ))
            continue
        accepted += 1
        decisions.append(RsiDecision(
            candidate.id, DECISION_ACCEPT, canonical, validation, test,
            baseline_validation, baseline_test,
            "validation gain and holdout gate passed", authorized,
        ))

    for i in range(len(decisions)):
        var fields = decision_fields(decisions[i], baseline, protocol)
        append_record(path, sequence, "rsi_decision", fields)
        sequence += 1

    var state = String("NO_ACCEPTED_CANDIDATE")
    if accepted > 0:
        state = "ACCEPTED"
    elif deferred > 0:
        state = "AWAITING_AUTHORIZATION"
    return RsiOutcome(
        len(decisions), accepted, rejected, deferred,
        perf_counter() - started, budget, state, decisions^,
    )


def rollback(
    workspace: String, authorized: Bool, reason: String
) raises -> RsiDecision:
    """Append a recovery decision restoring the protected baseline config."""
    var protected = ensure_protected(workspace)
    var baseline = protected.baseline.copy()
    var protocol = protected.protocol.copy()
    var canonical = config_canonical(
        baseline.model_kind, baseline.iterations,
        baseline.regularization, baseline.k,
    )
    var decision = RsiDecision(
        "rollback-" + hex64(fnv1a64(canonical)),
        DECISION_ROLLBACK if authorized else DECISION_DEFER,
        canonical, 0.0, 0.0, 0.0, 0.0,
        reason if authorized else "authorization_required", authorized,
    )
    var path = journal_path(workspace)
    var journal = read_journal(path)
    var fields = decision_fields(decision, baseline, protocol)
    append_record(path, next_sequence(journal.records), "rsi_decision", fields)
    return decision^
