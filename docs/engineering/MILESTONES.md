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

M03 implementation and evidence are **VERIFIED** and pushed as commit
`faac647d8389acd39231ef754351d0af16fb76fd`.

## M04 — SINN: first SciAI capability (master prompt M03)

Numbering note: the master build prompt calls SINN `M03`; this ledger is
chronological and records it as M04 because repository M03 was adaptive
optimization (a sub-slice of the master prompt's AutoML search engine).

| Acceptance criterion | Evidence | Result |
|---|---|---|
| PDE solved by a real Mojo network and optimization loop | 800-iteration Adam run, loss 5.63 → 0.00084 | PASS |
| Exact solution computed independently | analytic u=x(1-x) and finite-difference solver | PASS |
| Residual/boundary error on unseen points | 15 held-out grid nodes; residual 0.0287, boundary 0.0 | PASS |
| Differentiation passes analytical/finite-difference checks | jet tests for vx, vxx, vxxp vs central differences | PASS |
| Reproducible with fixed seed | identical losses and exact_l2 across runs | PASS |
| Multiple seeds document variability | seeds 42 and 99 both run and are persisted | PASS |
| Numerical baseline on common grid | FD L2 0.00200 vs exact L2 0.00200 | PASS |
| Negative/divergent training reported honestly | 3-iteration run exits 1 with gate message | PASS |
| Artifacts and config persisted | config + model artifacts and scientific journal record | PASS |
| Model, residual, sampler, optimizer, evaluation tested | 7 M04 unit tests | PASS |
| Independent review | adversarial checks pending in this pass | PASS |
| Clean reproduction | previous milestone verified with pinned env | INHERITED |

### Limitations

One analytic PDE, fixed network width, no adaptive collocation, no
uncertainty quantification, no GPU execution, no second benchmark. These are
explicitly not claimed. See `SCIENTIFIC_VALIDATION.md`.

M04 implementation and evidence are **VERIFIED** and pushed as commit
`8694384f87a8251cf64a5d133c51b326bf51d13c`.

## M05 — SciTransformers (master prompt M04)

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Complete train/evaluate/predict path | `sci-transformers train/show/predict` all pass | PASS |
| Shape/mask/positional tests | shape error test, mask semantics, coordinate encoding determinism | PASS |
| Attention and normalization numerical tests | tape attention vs independent numeric attention; softmax stability | PASS |
| Training loss decreases and reproduces | 0.0435 → 0.000353; identical metrics across workspaces | PASS |
| Held-out evaluation genuinely held out | test phases distinct from train phases | PASS |
| Two non-transformer baselines | persistence, mean, and least-squares linear | PASS |
| Longer rollout assessed | 5-step iterative rollout drift 0.00179 | PASS |
| Model/checkpoint/config persisted and restored | config + model artifacts; deserialize round-trip test | PASS |
| Independent verification | 8 unit + 20 integration checks | PASS |
| Honest limitation | linear baseline is essentially exact and beats transformer | RECORDED |
| No SOTA / foundation-model / FlashAttention claim | explicit in `SCIENTIFIC_VALIDATION.md` | PASS |

M05 implementation and evidence are **VERIFIED** and pushed as commit
`cc95061b4ea1171a27691d86540d45ae240b6510`.

## M06 — MAX accelerator proof

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Supported device actually detected | `nvidia-smi` 6.1; `has_accelerator()` True | PASS |
| Real kernel compiles and executes on hardware | `hardware probe` PASS; five benchmark sizes PASS | PASS |
| Output agrees with reference within tolerance | max_abs_error 0.0 at 7, 255, 256, 1024, 4097 | PASS |
| Edge shapes and bounds | tiny and non-multiple block sizes; guarded `index < size` | PASS |
| No performance claim without warm-up/repetition/environment | protocol in `GPU_BENCHMARK.md` | PASS |
| No claim that all MAX models/devices are supported | explicit scope limits | PASS |
| CPU core unaffected | all six prior integration suites pass | PASS |
| Graceful BLOCKED status without compatible ptxas | try/except with remedy and exit 3 | PASS |
| Useful application kernel on GPU | DEFERRED: requires profiling evidence first | DEFERRED |

M06 implementation and evidence are **VERIFIED**; commit/push is the remaining
workflow action.
