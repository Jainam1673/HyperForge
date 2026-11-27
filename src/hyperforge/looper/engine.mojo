"""Durable loop run with validated, idempotent, replayable transitions."""

from std.time import perf_counter
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.looper.state_machine import (
    can_transition,
    is_terminal,
    OBSERVE,
    EXECUTE,
    MEASURE,
    VERIFY,
    COMPARE,
    LEARN,
    ACCEPTED,
    REJECTED,
    DEFERRED,
    ROLLED_BACK,
)

comptime CONFIG_VERSION = "hyperforge-looper-v1"


struct LoopEvent(Copyable, Movable):
    var sequence: Int
    var monotonic_seconds: Float64
    var from_state: String
    var to_state: String
    var actor: String
    var reason: String
    var input_id: String
    var output_id: String
    var budget_remaining: Int
    var artifact: String
    var detail: String

    def __init__(
        out self,
        sequence: Int,
        monotonic_seconds: Float64,
        from_state: String,
        to_state: String,
        actor: String,
        reason: String,
        input_id: String,
        output_id: String,
        budget_remaining: Int,
        artifact: String,
        detail: String,
    ):
        self.sequence = sequence
        self.monotonic_seconds = monotonic_seconds
        self.from_state = from_state
        self.to_state = to_state
        self.actor = actor
        self.reason = reason
        self.input_id = input_id
        self.output_id = output_id
        self.budget_remaining = budget_remaining
        self.artifact = artifact
        self.detail = detail


struct LoopRun(Copyable, Movable):
    var id: String
    var hypothesis: String
    var state: String
    var budget: Int
    var trials_used: Int
    var events: List[LoopEvent]
    var started: Float64

    def __init__(out self, id: String, hypothesis: String, budget: Int):
        self.id = id
        self.hypothesis = hypothesis
        self.state = OBSERVE
        self.budget = budget
        self.trials_used = 0
        self.events = List[LoopEvent]()
        self.started = perf_counter()


def run_id(hypothesis: String, seed: UInt64) raises -> String:
    return "loop-" + hex64(fnv1a64(hypothesis + "|" + String(seed)))


def advance(
    mut run: LoopRun,
    target: String,
    actor: String,
    reason: String,
    input_id: String,
    output_id: String,
    artifact: String,
    detail: String,
) raises -> Bool:
    if len(run.events) > 0:
        ref last = run.events[len(run.events) - 1]
        if (
            last.to_state == run.state
            and target == run.state
            and last.actor == actor
            and last.reason == reason
            and last.input_id == input_id
            and last.output_id == output_id
        ):
            return True
    if not can_transition(run.state, target):
        return False
    if target == EXECUTE and run.trials_used >= run.budget:
        return False

    if target == EXECUTE:
        run.trials_used += 1
    var remaining = run.budget - run.trials_used
    run.events.append(LoopEvent(
        len(run.events) + 1,
        perf_counter() - run.started,
        run.state,
        target,
        actor,
        reason,
        input_id,
        output_id,
        remaining,
        artifact,
        detail,
    ))
    run.state = target
    return True


def rollback(mut run: LoopRun, reason: String) raises -> Bool:
    if is_terminal(run.state):
        return False
    return advance(
        run, ROLLED_BACK, "orchestrator", reason, run.id.copy(), run.id.copy(), "", "terminal rollback"
    )


def decide(
    mut run: LoopRun, decision: String, reason: String, artifact: String
) raises -> Bool:
    if run.state != LEARN:
        return False
    if (
        decision != ACCEPTED
        and decision != REJECTED
        and decision != DEFERRED
    ):
        return False
    return advance(
        run, decision, "orchestrator", reason, run.id.copy(), run.id.copy(), artifact, reason
    )
