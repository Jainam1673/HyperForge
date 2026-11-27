"""Validated Scientific Looper state machine.

Phases follow the project directive: OBSERVE -> FORMULATE -> HYPOTHESIZE ->
PLAN -> VALIDATE_CONSTRAINTS -> EXECUTE -> MEASURE -> VERIFY -> COMPARE ->
LEARN -> decision (ACCEPT/REJECT/DEFER/ROLLBACK). Invalid transitions are
rejected rather than silently skipped. Terminal decisions are immutable.
"""

comptime LOOPER_SCHEMA = "hyperforge-looper-v1"

comptime OBSERVE = "OBSERVE"
comptime FORMULATE = "FORMULATE"
comptime HYPOTHESIZE = "HYPOTHESIZE"
comptime PLAN = "PLAN"
comptime VALIDATE_CONSTRAINTS = "VALIDATE_CONSTRAINTS"
comptime EXECUTE = "EXECUTE"
comptime MEASURE = "MEASURE"
comptime VERIFY = "VERIFY"
comptime COMPARE = "COMPARE"
comptime LEARN = "LEARN"
comptime ACCEPTED = "ACCEPTED"
comptime REJECTED = "REJECTED"
comptime DEFERRED = "DEFERRED"
comptime ROLLED_BACK = "ROLLED_BACK"


def is_terminal(state: String) raises -> Bool:
    return (
        state == ACCEPTED
        or state == REJECTED
        or state == DEFERRED
        or state == ROLLED_BACK
    )


def can_transition(source: String, target: String) raises -> Bool:
    if is_terminal(source):
        return False
    if source == OBSERVE:
        return target == FORMULATE or target == ROLLED_BACK
    if source == FORMULATE:
        return target == HYPOTHESIZE or target == ROLLED_BACK
    if source == HYPOTHESIZE:
        return target == PLAN or target == ROLLED_BACK
    if source == PLAN:
        return target == VALIDATE_CONSTRAINTS or target == ROLLED_BACK
    if source == VALIDATE_CONSTRAINTS:
        return target == EXECUTE or target == DEFERRED or target == ROLLED_BACK
    if source == EXECUTE:
        return target == MEASURE or target == ROLLED_BACK
    if source == MEASURE:
        return target == VERIFY or target == ROLLED_BACK
    if source == VERIFY:
        return target == COMPARE or target == REJECTED or target == ROLLED_BACK
    if source == COMPARE:
        return target == LEARN or target == ROLLED_BACK
    if source == LEARN:
        return (
            target == ACCEPTED
            or target == REJECTED
            or target == DEFERRED
            or target == ROLLED_BACK
        )
    return False
