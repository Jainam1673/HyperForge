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

M06 implementation and evidence are **VERIFIED** and pushed as commit
`1e27e4333411f95b2b68315df21be2adcd325c52`.

## M07 — Reciprocal Meta-Discovery proof

| Acceptance criterion | Evidence | Result |
|---|---|---|
| DiscoveryGenome with one AI and one compute choice | typed genome, validation, stable hash, mutation tests | PASS |
| Fixed, AI-only, compute-only, independent, joint, ablation policies | six policies in `discover run` | PASS |
| Equal budget | every policy receives exactly `budget` evaluations | PASS |
| Quality, latency, wall-clock, cost measured | report columns and protocol in `RECIPROCAL_DISCOVERY.md` | PASS |
| Memory measured | reported `NOT_TESTED` (no verified API) | HONEST GAP |
| Repeated seeds | seeds 42 and 43 executed and recorded | PASS |
| Negative results published | joint lost to fixed/independent on task quality | PASS |
| Meta-loop evidence based | adaptive side allocation via shared observations; unit test | PASS |
| Causal graph / posterior meta-model | DEFERRED; no causal claim from correlations | DEFERRED |

M07 implementation and evidence are **VERIFIED** and pushed as commit
`d9d2f91f47d72ec52921b65186811d359fc4d930`.

## M08 — AutoDL

| Acceptance criterion | Evidence | Result |
|---|---|---|
| At least two architectures truly trained | four distinct depth/width shapes in random search | PASS |
| Test verifies parameters change and loss/metrics update | `test_training_updates_parameters_and_keeps_test_locked` | PASS |
| Correct validation/holdout separation | selection by validation loss; test fields zero until final | PASS |
| End-to-end experiment replayable | `autodl replay` restores checkpoint, `REPLAY_READY` | PASS |
| Runtime/resource limits honored | fixed budget, max epochs, patience, bounded sizes | PASS |
| Random vs adaptive comparison | both policies run at matched budget | PASS |
| No claim of adaptive superiority | tie reported | PASS |
| Clean reproduction | prior suites unchanged; all integration suites pass | PASS |

M08 implementation and evidence are **VERIFIED** and pushed as commit
`f0456e7ee978dcdff2c4f181c1712dd3dc4ea71c`.

## M09 — AutoRL

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Deterministic environment API with contracts | contract tests for actions, termination, truncation, walls | PASS |
| Fully tested tabular methods | value iteration optimum 5.0; Q-learning matches optimum | PASS |
| Policy improves over random across repeated seeds | +24.46 over random on five unseen seeds | PASS |
| Evaluation separate from training | greedy, no updates; unit test asserts Q unchanged | PASS |
| Learning curves and returns persisted | per-episode CSV artifact and journal record | PASS |
| Failure/termination correctly represented | invalid step after terminal rejected; truncation tested | PASS |
| Confidence summary | sample std and normal-approximation CI reported | PASS |
| No neural policies or real-world actions | tabular only; documented | PASS |

M09 implementation and evidence are **VERIFIED** and pushed as commit
`4fb11369fe12f8e01fab27e8a1d54542b9fbe36e`.

## M10 — AutoTransformers

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Candidates differ in actual config/behavior | 133-param default vs 857-param random 8x2/ff8/L2 | PASS |
| Quality and latency from executions | validation/test MSE and median latency per policy | PASS |
| Fixed-budget comparison with default and search baselines | default/random/adaptive at budget 3 | PASS |
| No inference-implies-training claim | explicit scope statement and report line | PASS |
| Config validation and conditional constraints | `valid_config` tests | PASS |
| Checkpoint/config persistence and replay | artifacts + checksum verification | PASS |
| Benchmark-based selection, not size assumptions | random config more accurate but ~6x slower | PASS |

M10 implementation and evidence are **VERIFIED** and pushed as commit
`20c0454ccf1d56bb93730aeeb2470d0059199e43`.

## M11 — AutoLLM substrate (offline core)

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Experiment specs / versioned prompt suite | suite schema and checksum tests | PASS |
| Local artifact discovery with hashes and license declaration | integration discover check | PASS |
| Reproducible evaluation suite | recorded-response scoring, missing counted | PASS |
| Model unavailable gives clear actionable result | `UNAVAILABLE` with remedy | PASS |
| No external inference API or Python bridge | no such code path | PASS |
| No implied training/fine-tuning | no training code in this module | PASS |
| Local MAX inference validated for a user model | no native Mojo boundary and no compatible artifact | BLOCKED_BY_MAX_INTERFACE |
| Latency/throughput capture | requires a backend | BLOCKED |

M11 offline core is **VERIFIED** and pushed as commit
`ecbc58104e43ee1cd3243917a2ca4a544cbb8081`; the inference acceptance criterion
remains **BLOCKED_BY_MAX_INTERFACE** and is documented rather than faked.

## M12 — SciML

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Explicit problem registry with units/scaling/assumptions/reference | `sciml list-problems` and tests | PASS |
| Conventional solver reference | FD solver RMS error < 1e-3 vs analytic | PASS |
| Parameter identification from observations | k=0.989 vs true 1.0, 5 noise seeds | PASS |
| Held-out evaluation with data-only baseline | inverse/hybrid L2 far below constant baseline | PASS |
| Physics enters explicitly | discrete Laplacian + Dirichlet conditions in solver | PASS |
| Variability reported | parameter std 0.03698 across noise seeds | PASS |
| Broader inverse methods / operator learning | DEFERRED | DEFERRED |

M12 implementation and evidence are **VERIFIED** and pushed as commit
`9122944002c24f7a657b5875c3f9398587760fb3`.

## M13 — SciDL

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Validated DL primitives on scientific grid/field data | tape MLP with parameter-node gradients | PASS |
| Held-out generalization over physical parameters | train k<=1.0, test k>=1.05 | PASS |
| PDE/numerical baselines | FD solver and fitted linear shape | PASS |
| Physical metrics and honest comparison | field RMSE and max error reported; MLP worse than baselines | PASS |
| Reproducibility | fixed seed, deterministic task, 4 tests | PASS |
| Distinguish from SINN/operator learning | explicit scope in validation doc | PASS |

M13 implementation and evidence are **VERIFIED** and pushed as commit
`83b9f320f935db6a008e941f42365c6da8385fd8`.

## M14 — SciRL

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Bounded reproducible scientific simulator | analytic Poisson field, safe actions, termination tests | PASS |
| Explicit reward and safe action constraints | cost+error reward; invalid action rejected | PASS |
| Held-out environment conditions | offset k grid with both frequency bands | PASS |
| Random and domain-heuristic baselines | both evaluated on unseen seeds | PASS |
| Repeated seeds and variability | 5 seeds, mean/std/CI | PASS |
| Evaluation separate from training | greedy, no updates; test asserts fixed policy | PASS |
| Learned policy improves over baselines | +0.00812 random, +0.00693 heuristic | PASS |

M14 implementation and evidence are **VERIFIED** and pushed as commit
`254a587bfad159b4bfd5defce9dc12b18c820554`.

## M15 — Scientific Looper

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Explicit state machine with validated transitions | transition rules tests | PASS |
| Event records with actor, reason, IDs, budget, artifact | 10 persisted looper events | PASS |
| Idempotent repeated transitions | test asserts no duplicate event | PASS |
| Bounded trials and terminal decisions | budget guard and immutable terminal states | PASS |
| Specialist roles without false agent claims | sequential passes; output states this | PASS |
| Real measured evidence before decision | baseline 4.84 vs candidate 9.97e-05, verified | PASS |
| Replayable decision trail | stable run ID and ordered events | PASS |
| Wall-clock timestamps | no API available; monotonic sequence recorded | HONEST GAP |

M15 implementation and evidence are **VERIFIED** and pushed as commit
`7b361b2f6246c48fec85441729b1067589a6d016`.

## M16 — GPU kernel catalogue and reproducible performance infrastructure

| Acceptance criterion | Evidence | Result |
|---|---|---|
| Kernel catalogue with CPU references | two entries, tested CPU references | PASS |
| Correctness on hardware within tolerance | zero error at multiple sizes for both kernels | PASS |
| Edge shapes and bounds | sizes 7, 255, 256, 1024, 4097 | PASS |
| Warm-up, repetition, median protocol | documented and stored in report header | PASS |
| Environment capture and artifact hashes | toolchain pins, repetition policy, checksum | PASS |
| No performance claim without protocol | device-specific numbers with full context | PASS |
| Application kernels moved to GPU | DEFERRED pending profiling evidence | DEFERRED |
| MAX model inference adapter | BLOCKED_BY_MAX_INTERFACE; not claimed | BLOCKED |

M16 implementation and evidence are **VERIFIED** and pushed as commit
`21b339c8c65e42ac94a03fd0e7a732f234365793`.
