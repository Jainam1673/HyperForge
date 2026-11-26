"""Explicit trial and experiment lifecycle transitions.

Invalid transitions are rejected by returning False; callers must not mutate
state without a successful check. States are versioned string constants rather
than enums because the installed Mojo 1.2.0 does not support module-level
`enum` declarations.
"""

comptime TRIAL_CREATED = "CREATED"
comptime TRIAL_QUEUED = "QUEUED"
comptime TRIAL_RUNNING = "RUNNING"
comptime TRIAL_SUCCEEDED = "SUCCEEDED"
comptime TRIAL_FAILED = "FAILED"
comptime TRIAL_CANCELLED = "CANCELLED"
comptime TRIAL_INTERRUPTED = "INTERRUPTED"

comptime EXP_DRAFT = "DRAFT"
comptime EXP_RUNNING = "RUNNING"
comptime EXP_COMPLETED = "COMPLETED"
comptime EXP_FAILED = "FAILED"
comptime EXP_CANCELLED = "CANCELLED"


def is_terminal_trial_state(state: String) -> Bool:
    return (
        state == TRIAL_SUCCEEDED
        or state == TRIAL_FAILED
        or state == TRIAL_CANCELLED
        or state == TRIAL_INTERRUPTED
    )


def can_transition_trial(source: String, target: String) -> Bool:
    if source == TRIAL_CREATED:
        return target == TRIAL_QUEUED or target == TRIAL_CANCELLED
    if source == TRIAL_QUEUED:
        return target == TRIAL_RUNNING or target == TRIAL_CANCELLED
    if source == TRIAL_RUNNING:
        return (
            target == TRIAL_SUCCEEDED
            or target == TRIAL_FAILED
            or target == TRIAL_CANCELLED
            or target == TRIAL_INTERRUPTED
        )
    return False


def can_transition_experiment(source: String, target: String) -> Bool:
    if source == EXP_DRAFT:
        return (
            target == EXP_RUNNING
            or target == EXP_FAILED
            or target == EXP_CANCELLED
        )
    if source == EXP_RUNNING:
        return (
            target == EXP_COMPLETED
            or target == EXP_FAILED
            or target == EXP_CANCELLED
        )
    return False
