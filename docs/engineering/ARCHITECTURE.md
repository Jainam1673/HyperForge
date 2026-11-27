# HyperForge architecture (as implemented, M21)

This document describes the **current** source tree and data flow. It is not a
design wish list. For intent, see the root `AGENTS.md` and the two authoritative
docs in `../`.

## Entry point and process model

`src/main.mojo` is the only executable target. It parses arguments through
`cli/args.mojo`, dispatches to a `cli/*_cmd.mojo` handler, and exits with one of
the documented codes in `core/exit_codes.mojo`. There is one process, no daemon,
no listener, and no background worker.

Command handlers are thin: they validate the workspace, call a capability
module, persist evidence, and print a short human-readable result. Capability
modules do not parse CLI text.

## Module map

| Directory | Responsibility |
|---|---|
| `core/` | Version pins, FNV-1a hashing, deterministic SplitMix64 RNG, numeric helpers, trial state machine |
| `cli/` | Argument grammar, dispatch helpers, help text, one command module per family |
| `experiment/` | Versioned experiment spec and trial records |
| `automl/` | Strict CSV loading, split, preprocessing, four regression models, metrics, bounded search |
| `optimization/` | Adaptive propose/evaluate/feedback loop and search space |
| `autodiff/` | Tape used by the neural slices |
| `discovery/` | Reciprocal genome, genome v2, systems-side measured search |
| `meta/` | Typed causal graph and matched-budget allocation economy |
| `joint/` | Nine-policy joint AI×compute benchmark and ablations |
| `rsi/` | Protected baseline/protocol, config-only candidate, guarded decision loop |
| `gpu/` | Compiled Mojo kernels and reproducible benchmark catalogue |
| `looper/` | Validated scientific experiment loop and transition state machine |
| `sinn/`, `scit/`, `autodl/`, `autotrans/`, `autollm/` | Neural / transformer / LLM-substrate slices |
| `sciml/`, `scidl/`, `scirl/`, `autorl/` | Scientific inverse problems, field models, simulated control, tabular RL |

`workspace.mojo` creates and validates local workspaces. `doctor.mojo` performs
capability detection only; it never launches kernels or models. `hardening.mojo`
is the single source of path and CSV input ceilings.

## Evidence model

All durable state lives in `experiments/hf-journal.hfj` under the selected
workspace. `evidence/record.mojo` defines the wire format and escaping;
`evidence/journal.mojo` reads, validates, and appends records.

```text
HFJ1|<sequence>|<record kind>|<FNV-1a checksum>|<key=value|...>\n
```

Invariants:

1. A record kind is valid only if it is registered and has all required fields.
2. Sequence numbers are monotonic; duplicates and gaps are detected.
3. Checksum covers `sequence|kind|payload`; a mismatch fails the record.
4. A corrupt or truncated **tail** is recovered as the validated prefix; damage
   in the middle of the journal is a hard failure.
5. Large artifacts are referenced by relative path and checksum, never embedded.

Writes are plain file appends: the installed Mojo release has no verified
atomic rename, so recovery rewrites a validated prefix and the code makes no
transactional claim. FNV-1a is an integrity check, not a cryptographic hash.

## Data flow (one capability)

```text
input (CSV / config / seed)
   → validate path and ceilings      (hardening.mojo)
   → parse and fingerprint           (automl/dataset.mojo)
   → train-only preprocessing        (automl/preprocess.mojo)
   → fit candidate                   (automl/models.mojo)
   → validation metrics              (automl/metrics.mojo)
   → decision / selection            (capability-specific policy)
   → journal record + terminal report
```

The train/validation/test boundary is explicit: selection uses validation; the
test split is evaluated once at the end and is not available to search logic.

## Coupling between loops

`discovery/`, `meta/`, and `joint/` share the journal and the genome/measurement
contracts, not a global mutable state. A joint candidate recombines the best
AI-side and compute-side genes observed so far. Ablations remove shared history,
adaptive budgeting, or the meta-policy independently. A causal relationship is
recorded only after a controlled intervention; cross-loop correlation stays
`hypothesized`.

## RSI boundary

`rsi/protected.mojo` defines two write-once records (baseline config and
evaluator protocol), each with a checksum verified on load. No candidate path
can rewrite them. `rsi/candidate.mojo` mutates config values only. Acceptance
requires a validation gain, a protected holdout check, an independent verifier
that recomputes RMSE by a second implementation, and `--apply` authorization.
Decisions are append-only; rollback appends a superseding decision.

## Hardware boundary

`gpu/kernels.mojo` contains compiled Mojo kernels with a CPU-reference
correctness gate. `gpu/catalogue.mojo` captures device, shape, precision,
warm-up, repetitions, and medians. No application workload is moved to the GPU
without profiling evidence, and no MAX model execution is claimed.

## What does not exist

No network client, telemetry, model downloader, generated-code executor,
scheduler, database driver, or service process. Capabilities marked BLOCKED or
PLANNED in `CAPABILITY_MATRIX.md` have no registered command.
