# Milestone acceptance evidence

## M00 — Toolchain, project bootstrap, and CLI shell

Directive: master build prompt §9/M00; blueprint §7/M00.

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Verified pinned Mojo/MAX environment | `ENVIRONMENT.md`; `pixi run mojo --version` → 1.2.0; `pixi run max --version` → 26.7.0 | PASS |
| Minimal build/run/test commands | `pixi.toml` tasks `build`, `run`, `test`, `test-cli` | PASS |
| Native executable entry point | `pixi run build` → `hyperforge` (ELF x86-64, 93K) | PASS |
| CLI parser with help/version | unit tests + integration checks | PASS |
| `doctor` with separate capability probes and truthful statuses | probe list in `CLI_SPEC.md`; integration checks | PASS |
| Minimal `init` workspace operation | integration check creates config + 3 dirs | PASS |
| Errors and exit codes tested | integration checks for codes 0 and 2; 24 checks | PASS |
| CPU-only CLI works without GPU/model | probes report `NOT_TESTED`/`UNAVAILABLE` without fatal exit | PASS |
| No Python source or unapproved app packages | source tree contains only `.mojo` application files; TOML/shell only for build/test | PASS |
| Clean checkout reproduces setup | fresh copy: `pixi install --frozen`, `build`, `test`, `test-cli` all pass | PASS |
| Independent verification pass | JSON parsed by `node`; planned commands reject; file target rejects; quote-in-path JSON escaping; clean rebuild with no warnings | PASS |

### Workflow closure

- Commit: `ca44ece6d8290b168eeffc72b6cadd1ce5533ad8`
- Pushed to `https://github.com/Jainam1673/HyperForge.git`, branch `main`.
- GitHub MCP verified working before the push.

M00 implementation and evidence are **VERIFIED** and the milestone is pushed.

## M01 — Core experiment and evidence substrate

Directive: master build prompt §9/M01; AGENTS.md §8 and M01; blueprint §9.

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Typed experiment/candidate/trial/metric/error/budget types | M01 adds typed `Experiment`, `Field`, `JournalRecord`, `JournalReadResult`; state constants; status labels. Candidate/dataset/metric/budget/error/acceptance structs are DEFERRED to M02, where execution first needs them, under the directive's no-speculative-abstraction rule | DEFERRED (justified) |
| Append-only versioned journal with checksums | `HFJ1` format, FNV-1a checksum, `experiment`/`event` record types; round-trip and tamper tests | PASS |
| Recovery from truncated/corrupt last record | unit tests for corrupt tail, truncated tail, duplicate ID; integration check | PASS |
| Atomic artifact writes | config artifact written in one `write` + `close`; no rename available | DOCUMENTED LIMITATION |
| Integrity hashes and provenance | config checksum recorded and verified by replay | PASS |
| Status transitions with invalid transitions rejected | `state_machine.mojo` tests | PASS |
| Seeded RNG and seed derivation | SplitMix64 known-value and determinism tests | PASS |
| Stable machine-readable output | 3 versioned JSON schemas, parsed by `node` in verification | PASS |
| Persistence survives process restart | create/list/show/replay across separate processes; integration script | PASS |
| Round trips preserve records and stable IDs | experiment field round-trip test | PASS |
| Replay refuses missing data/config | exit 3 for missing and tampered config artifact | PASS |
| No database server or external storage service | journal is a local file under `experiments/` | PASS |
| Independent verification | adversarial names with `|`, `=`, `\`; duplicate create; JSON parsed; clean-copy reproduction | PASS |
| Clean checkout reproduction | fresh copy: install, build, 26 unit tests, 24 CLI checks, 17 experiment checks | PASS |

### Deferred within M01

Candidate, metric, budget, and acceptance structs are not created yet because
no execution path uses them; the directive says not to build speculative
abstractions. They will be introduced with M02 when AutoML trials need them.

M01 implementation and evidence are **VERIFIED** and pushed as commit
`fe06b843f203d29320b71c06a769146870cd817d`.

## M02 — Native regression AutoML slice

Directive: master build prompt §9/M02; AGENTS.md M02; blueprint §7/M03.

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Clean local example dataset produces a real repeatable experiment | `examples/regression_linear.csv`; identical IDs/metrics across two workspaces | PASS |
| Declared baseline and at least two non-identical real models run | mean baseline, linear GD, ridge GD, kNN; journal trials from one run | PASS |
| Missing/corrupt data and invalid target fail clearly | unit rejection tests; integration checks | PASS |
| Data preprocessing is leakage-safe | stats fitted on train only; protocol in `EXPERIMENT_PROTOCOL.md` | PASS |
| Metric edge cases tested | perfect, constant, empty, length mismatch, NaN | PASS |
| Search is bounded and deterministic | fixed budget/seed; cross-workspace determinism | PASS |
| Adaptive feedback proven by regression test | DEFERRED to M03; M02 explicitly uses random search, not adaptive sampling | DEFERRED (justified) |
| Outputs/artifacts reopened after process restart | `automl show`, `report`, `replay` in separate processes | PASS |
| Held-out test isolated from selection | test evaluated once after validation selection | PASS |
| Model selection behaves correctly on a toy dataset | linear model found relation y=2x1-3x2+5; test RMSE ~2.2e-8 | PASS |
| Credible benchmark with repeated seeds/folds | DEFERRED: single documented synthetic fixture, no repeated-seed benchmark yet | DEFERRED |
| User docs explain inputs, limits, commands, reproducibility | `EXPERIMENT_PROTOCOL.md`, `CLI_SPEC.md`, README | PASS |
| Independent verification | determinism, missing-value run, config/dataset tamper refusal, 49 checks | PASS |
| Clean checkout reproduction | clean source build + all suites pass with pinned env; fresh install blocked by disk quota | PASS with environment limitation |

### Deferred within M02

Adaptive feedback and a repeated-seed benchmark belong to the next milestone;
implementing an adaptive sampler without validated statistics would violate the
"no fake science" rule. These items are explicitly not claimed as M02 results.

M02 implementation and evidence are **VERIFIED** and pushed as commit
`18bcfde9ec3b5dc86264b737b738f5237a8d5224`.

## M03 — Adaptive optimization

Directive: AGENTS.md M03; blueprint §7/M04; master build prompt search-engine
requirements.

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Propose, run, measure, persist, feed back, propose next | journal alternates trial and optimizer records; observed=1..budget | PASS |
| Regression test fails if feedback disconnected | `test_feedback_is_connected` compares guided vs unguided proposals | PASS |
| Invalid candidates handled explicitly | typed space validation rejects inconsistent conditional params | PASS |
| Failed trials handled explicitly | FAILED trial records with reason; exception path in loop | PASS |
| Comparison with random/fixed baseline at matched budget | `optimize run` reports both policies, same seed/split/budget | PASS |
| Typed search space with conditional parameters | `space.mojo` validation and prior sampler | PASS |
| Track optimizer state and cost | optimizer records include counts, best RMSE, elapsed seconds | PASS |
| Held-out test evaluated once after selection | single test trial per adaptive run | PASS |
| Clean reproduction | identical ID and metrics across two workspaces | PASS |
| Multi-fidelity racing | DEFERRED; no fidelity ordering validated yet | DEFERRED |
| Classification | DEFERRED to a later AutoML expansion | DEFERRED |
| Independent verification | 42 unit + 76 integration checks; negative result reported honestly | PASS |

### Negative result

On the synthetic linear fixture at budget 6, seed 42, the adaptive policy's
held-out RMSE was `1.9183755652814585`, while matched random search reached
`2.2272160351028695e-08`. The adaptive policy did **not** win on this small
fixture; this is reported rather than hidden. No claim is made that reciprocal
or adaptive search is superior without a broader benchmark.

M03 implementation and evidence are **VERIFIED**; commit/push is the remaining
workflow action.
