# M20 — Bounded, config-only recursive self-improvement

## Scope

This milestone implements the RSI control structure, not autonomous code
rewriting. Candidates are **config values only** (model family, training
iterations, regularization, k). No generated code is compiled or executed, and
no candidate can alter the evaluator.

## Protected controls

Two write-once journal records are created on first use and never rewritten:

- `rsi_baseline` — protected baseline config with canonical form and checksum.
- `rsi_protocol` — evaluator thresholds and resource ceilings with checksum.

Both checksums are verified on every load. A mismatch fails the run; the code
contains no path for a candidate proposal to modify either record. The
protocol fixes `min_relative_rmse_gain=0.01`, `max_test_rmse_regression=0.05`,
`max_trials=12`, `max_wall_seconds=30`, `max_recursion_depth=12`, and
`max_candidate_bytes=4096`.

## Loop

`hyperforge rsi run [trials] [--apply]`:

1. load and verify protected baseline and protocol;
2. compute baseline validation and holdout RMSE from the protected config;
3. propose a bounded config candidate from a deterministic seed;
4. screen on validation RMSE (gain must meet the protected threshold);
5. only after passing the screen, evaluate the protected holdout;
6. independently verify holdout RMSE via a second implementation (reverse
   traversal, direct squared-error accumulator); disagreement rejects;
7. compare holdout regression against the protected threshold;
8. decide `ACCEPT`, `REJECT`, or `DEFER`, then append an immutable decision
   record with both checksums.

A candidate cannot see the holdout during screening. The holdout is touched
only at the acceptance gate, and the independent verifier is a separate code
path. Identical candidates are rejected as duplicates.

## Authorization and rollback

Without `--apply`, every candidate that would pass is recorded as `DEFER` with
reason `authorization_required`; state is `AWAITING_AUTHORIZATION`. This is the
explicit human authorization gate. `--apply` is rejected outside `rsi run` and
`rsi rollback`.

`hyperforge rsi rollback [--apply]` appends a recovery decision restoring the
protected baseline config. Without authorization it appends `DEFER`. Rollback
supersedes earlier acceptance decisions in the ledger; it does not rewrite
them.

## Observed result (seed 42, 12 trials)

| Mode | accepted | rejected | deferred | state |
|---|---:|---:|---:|---|
| report-only (no `--apply`) | 0 | 8 | 4 | AWAITING_AUTHORIZATION |
| authorized (`--apply`) | 4 | 8 | 0 | ACCEPTED |

Requested budgets above 12 are clamped to the protected trial ceiling. The
accepted candidates are linear configurations with more iterations; the
rejected ones fail validation gain or holdout gates. No claim is made that the
loop improves general software code — the improvement is within the declared
config space and is independently verified.

## Limits

- No arbitrary code generation, shell execution, or self-modification of
  acceptance rules.
- The "applied" state is an evidence-level decision in the ledger; no runtime
  service consumes it, and no application code is rewritten.
- Memory is not measured; wall clock is measured.
- No MAX model inference; SciLLM/SciGenAI remain blocked.
