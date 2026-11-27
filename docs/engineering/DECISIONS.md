# Engineering decisions

## D001 — Pin Mojo 1.2.0 and MAX 26.7.0 from the stable channel

`pixi.toml` uses `https://conda.modular.com/max` and `conda-forge` with
`mojo >=1.2.0,<2` and `max >=26.7,<27`. Rationale: both versions were observed
installed and working together; stable channel is required for the baseline.
MAX is a platform dependency with a proprietary license and Python package
dependencies; it is not used by the CLI logic. Nightly is excluded.

## D002 — First-party CLI parser, no third-party packages

No argument-parsing, JSON, or CLI library is added. `src/hyperforge/cli/args.mojo`
parses a small deterministic grammar; `doctor` renders its own JSON with
explicit escaping. Rationale: dependency policy defaults to no; the grammar is
small and testable with the standard library.

## D003 — Tests run via `mojo run`, not `mojo test`

The installed Mojo 1.2.0 has no `mojo test` subcommand (observed error). Tests
use `TestSuite.discover_tests[__functions_in_module()]().run()` and are invoked
by `pixi run test`.

## D004 — Stable-version syntax adjustments

The Mojo skills target a newer Mojo than the installed 1.2.0. `guard case` and
`Optional.or_else` are not accepted by this compiler; `if case` with an
explicitly typed `Optional` is used. `len(String)` is replaced by
`byte_length()`. These deltas were found by compile probes, not assumed.

## D005 — Shell is used only for build/test automation

`tests/integration_cli.sh` is a Bash test harness. No HyperForge application
logic is implemented in shell. This follows the directive's allowance for
small build/test automation.

## D036 — GPU catalogue stays reference infrastructure

The catalogue adds a second kernel and a reusable benchmark protocol but does
not move application workloads to the GPU without profiling evidence. MAX model
inference remains a separately blocked capability. Performance numbers are
reported with toolchain pins, warm-up policy, repetitions, and aggregation.

## D035 — Looper events use monotonic ordering, not invented wall time

The installed Mojo stdlib exposes `perf_counter` but no verified wall-clock or
epoch API. Loop events record monotonic sequence and relative monotonic time,
and documentation states that no wall-clock timestamp is claimed. Specialist
roles are sequential passes with recorded identities; no parallel agents are
claimed.

## D034 — SciRL validates the simulator before learning

The Poisson decision simulator is checked against the analytic solution, and
forcing frequencies are chosen to avoid mesh aliasing that could fabricate zero
error. Training and held-out condition sets both cover every observable state
(frequency band) while using disjoint parameter values, preventing untrained
states from dominating evaluation.

## D033 — SciDL reports underperformance honestly

The supervised MLP was evaluated on a harder held-out parameter range and
underperformed both a domain-specific linear fit and the finite-difference PDE
solver. The result is recorded rather than tuned away, and the method is
explicitly distinguished from SINN (no residual loss) and operator learning.

## D032 — SciML uses explicit operators and conventional references

The inverse problem enters physics through the finite-difference Laplacian and
Dirichlet conditions rather than a penalty label. A conventional FD solver and
a data-only constant baseline are evaluated on the same held-out points, and
parameter variability across noise seeds is reported without claiming formal
confidence coverage.

## D031 — AutoLLM reports BLOCKED rather than fabricating inference

No validated native Mojo-to-MAX model-inference boundary exists in this
environment, and no user-supplied model artifact is present. AutoLLM therefore
implements discovery, versioned suites, and offline scoring, and reports
`UNAVAILABLE`/`BLOCKED_BY_MAX_INTERFACE` for execution. No responses, latency,
or throughput values are invented, and no Python bridge is used.

## D030 — AutoTransformers measures, not assumes, config efficiency

Configuration search uses validation MSE and measured inference latency from
real executions. In the observed run the more accurate config had ~6x the
parameters and latency, so no claim is made that smaller configurations are
faster. Cache and precision genes are not registered without execution paths.

## D029 — AutoRL stays tabular with separated phases

Value iteration provides an exact DP reference; Q-learning uses epsilon-greedy
training and a strictly greedy, no-update evaluation. Config selection uses
seeds 1–3 and reporting uses unseen seeds 101–105. No neural policy is
introduced because the tabular benchmark already tests the acceptance claims
and avoids conflating RL quality with function approximation.

## D027 — AutoDL uses the tape, validation-only selection

Depth/width are real structural genes, and every parameter is a tape node;
therefore gradients cannot be detached. Test metrics are deliberately zero in
training results and computed once after validation-based selection. This is
enforced by a unit test rather than relying on documentation.

## D028 — Replay verifies checkpoint restoration, not re-execution

`autodl replay` restores the persisted checkpoint and reports readiness; it does
not claim to reproduce the original test measurement by retraining. This keeps
replay honest under the project's distinction between execution, reproduction,
and validity.

## D025 — Reciprocal proof reports a negative result

The joint policy lost to fixed/independent search on task quality at matched
budgets for two seeds. The result is published in `RECIPROCAL_DISCOVERY.md`
instead of tuning the benchmark until joint wins. No causal or novelty claim is
made; the genome is limited to genes with real execution paths.

## D026 — Memory is NOT_TESTED, not fabricated

No verified Mojo memory-measurement API was established for this release, so
the discovery report prints `memory: NOT_TESTED` rather than inventing a
number. This is an explicit evidence gap in M07.

## D023 — GPU proof stays a separate capability

The vector-add kernel is the only accelerator work in M06. No AutoML, SINN, or
SciTransformers computation was moved to the GPU without profiling evidence.
MAX model serving remains optional and untested. Devices that MAX cannot
support report `BLOCKED` with a remedy and exit 3; the CPU core is unaffected.

## D024 — Build wrapper for pre-Turing devices

`scripts/gpu-env.sh` selects a cached CUDA 12 `ptxas` for `sm_52/sm_60/sm_61`,
and `scripts/mojo.sh` passes the detected `--target-accelerator`. This is
build/platform tooling (shell), not application logic. Without a compatible
compiler, the build targets a modern arch and GPU commands report BLOCKED.

## D021 — Reference attention and an honest linear-baseline result

SciTransformers v1 uses a reverse-mode scalar tape and plain two-head
attention; no FlashAttention or GPU claim. The synthetic task is exactly linear
in the previous frame, so the fitted linear baseline is nearly perfect and
outperforms the transformer. This is reported as a negative result instead of
changing the task to favor the new model; a harder multi-mode task is needed to
test any transformer advantage.

## D022 — Explicit mask and numerical parity tests

Attention masks are represented as `List[Bool]`, masked softmax weights are
exactly zero, and the tape kernel output is compared to an independent numeric
implementation. These tests guard the semantics that a fusion-style rewrite
could silently break.

## D019 — Forward-mode higher-order jets for SINN differentiation

The tiny network needs u'' for the PDE residual and ∂u''/∂p for Adam gradients.
A six-component forward jet (v, vx, vxx, vp, vxp, vxxp) implements this exactly
and is checked against central differences. Exact boundary enforcement
`u = x(1-x) N(x)` removes the boundary penalty and its loss-balancing failure
mode. Finite differences are used only as a check and as the independent
numerical solver, never inside training.

## D020 — Honest convergence gate and exit codes

A SINN run returns exit 0 only for `CONVERGED`; `POOR_FIT` and `DIVERGED` are
persisted and return exit 1. The held-out exact/FD errors and residual are
reported separately, and a small collocation residual is not treated as proof
of generalization.

## D017 — TPE-style density ratio, with baseline excluded from the model

M03 uses a small Parzen-density ratio sampler over recorded validation RMSE.
The mean baseline is recorded as a control but excluded from the good/bad
density model, because it has no tunable search dimensions and using it as a
parent produced invalid candidates. This keeps the sampler's categorical model
over the three searchable model kinds only.

## D018 — Honest negative result

At budget 6 on the synthetic fixture, adaptive search lost to random search.
The milestone reports this rather than tuning the fixture to favor the new
policy. No superiority claim is made until a broader matched-budget benchmark.

## D013 — M02 uses deterministic random search, not adaptive search

Candidates are pure functions of `(seed, index)`; the baseline is always first.
An adaptive sampler or multi-fidelity racing would require validated statistics
and a benchmark, which are M03. Calling a random sampler adaptive would violate
the no-fake-science rule.

## D014 — Four real but simple regression models

Mean baseline, linear gradient descent, ridge gradient descent, and kNN are
implemented from scratch in Mojo with train-only standardization. Decision
trees, forests, and boosted trees are deferred because a correct split search
and ensemble are larger, separately verifiable capabilities. Quality on the
documented linear fixture is near-exact; no general AutoML claim is made.

## D015 — Regression-only, numeric-only CSV scope

M02 supports numeric features, empty cells as missing with train-mean
imputation, and a single numeric target. Categoricals, quoting, and
classification are rejected rather than guessed. This keeps validation
deterministic and avoids silent semantic drift.

## D016 — Defined R² edge behavior

Constant targets and single-sample inputs yield R² = 0 instead of NaN or an
invented score; negative R² is allowed when predictions are worse than the
mean. This is recorded in `EXPERIMENT_PROTOCOL.md`.

## D007 — Project-owned HFJ1 journal format

The journal stores one record per line:
`HFJ1|<seq>|<type>|<checksum>|<payload>\n`. Payload is `key=value` fields with
escaping for `\`, `|`, `=`, and newline. The checksum is FNV-1a 64 over
`seq|type|payload`. JSON was rejected for the journal because the installed
stdlib has no JSON parser and a second serializer would add complexity; the CLI
JSON renderers are separate and versioned.

## D008 — FNV-1a is an integrity check, not a security hash

FNV-1a detects accidental corruption and truncation, which is the requirement
for local experiment records. It is not collision-resistant and must not be
used for authenticity. This is stated in the source and in `PROJECT_STATE.md`.

## D009 — Tail-only recovery, no atomic rename

An invalid last record (bad checksum, unknown version, bad sequence, duplicate
ID, or missing newline) is dropped and the validated prefix is rewritten. An
invalid record in the middle is a hard error and the file is untouched.
Installed Mojo 1.2.0 has no `rename` or `truncate`, so recovery is a plain
full-file write; this limitation is explicit rather than claimed as atomic.

## D010 — SplitMix64 and deterministic seed derivation

SplitMix64 with wrapping `UInt64` arithmetic provides reproducible streams.
`derive_seed(base, namespace, index)` is a pure FNV-1a hash of a canonical key,
so recorded seeds can reproduce derived streams without storing all of them.

## D011 — Defer candidate/metric/budget structs to M02

M01 implements the types needed by real behavior. Candidate, metric, budget,
and acceptance structs would have no execution path until AutoML trials exist;
they are deliberately deferred, not forgotten.

## D012 — GitHub MCP launcher reads the token from `gh`

`scripts/github-mcp.sh` launches the cached
`ghcr.io/github/github-mcp-server:latest` Docker image and passes
`GITHUB_PERSONAL_ACCESS_TOKEN` obtained at runtime from `gh auth token`. No
token is stored in the repository or in the OpenCode config. The script was
missing at session start, which caused the GitHub MCP connection failure; it was
recreated and the connection was verified after an OpenCode server restart.
