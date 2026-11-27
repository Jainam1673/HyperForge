# Scientific Looper validation (M15)

## State machine

Validated sequence:
`OBSERVE → FORMULATE → HYPOTHESIZE → PLAN → VALIDATE_CONSTRAINTS → EXECUTE → MEASURE → VERIFY → COMPARE → LEARN → decision`.
Decisions are `ACCEPTED`, `REJECTED`, `DEFERRED`, or `ROLLED_BACK` and are
terminal. Invalid transitions are rejected; repeated identical transitions are
idempotent; execution is bounded by a trial budget.

Each event records: monotonic sequence, monotonic relative time, actor role,
source and target state, input/output IDs, remaining budget, artifact pointer,
and reason. Wall-clock timestamps are **not** claimed: the installed Mojo
stdlib exposes only a monotonic counter, and records say so explicitly.

## Specialist roles as sequential passes

Roles are recorded as strings: research-planner, domain-specialist,
algorithm-engineer, security-reliability, capability-owner, independent-verifier,
and experiment-economist, with the orchestrator making the terminal decision.
These are **sequential passes**, not parallel agents; output explicitly states
that no parallel agents are claimed.

## Real execution and evidence

The demonstration hypothesis is tested on the documented regression fixture:
- baseline: mean predictor validation RMSE `4.841229`;
- candidate: linear gradient descent validation RMSE `9.97e-05`;
- verification: deterministic recomputation gives an identical RMSE;
- decision: `ACCEPTED` because improvement is positive and verification agrees.

No mock metrics are used: all values come from the project's AutoML modules.
A proposal is not treated as a result; measurement and verification precede the
decision. Ten transition events and their reasons are persisted in the local
journal and displayed by `looper show`.

## Recovery and replay properties

Runs have stable IDs derived from hypothesis and seed. Repeating an identical
transition does not duplicate an event. Budget exhaustion and terminal states
block further transitions. Replay of the recorded sequence is possible from the
stored events; this milestone does not claim re-execution of the original trial
from artifacts, only reconstruction of the decision trail.

## Limits

One built-in demonstration hypothesis; no parallel worker execution, no wall-
clock timestamps, no dynamic agent spawning, no candidate code generation, no
self-modification of acceptance rules, and no claim that a looper decision is
scientific truth beyond the recorded evidence.
