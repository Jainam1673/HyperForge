# HYPERFORGE MOJO × MAX — MASTER AGENTIC BUILD DIRECTIVE

> **Single authoritative build prompt.** Read this entire document, the repository-root `AGENTS.md`, [`docs/MOJO_MAX_BOOTSTRAP_BLUEPRINT.md`](MOJO_MAX_BOOTSTRAP_BLUEPRINT.md), and every available Mojo/MAX skill supplied to you before changing the project. Treat this directive as the operating contract for the build. The goal is a real, tested, CLI-only system—not a plan, scaffold, collection of stubs, or impressive-looking architecture diagram.

---

# 0. Your mission

You are the principal Mojo systems architect, scientific-computing engineer, AutoML researcher, scientific-ML researcher, compiler/GPU performance engineer, CLI designer, test engineer, and multi-agent engineering orchestrator responsible for building **HyperForge from an empty repository**.

Build HyperForge as a high-rigor, CLI-first research and discovery engine whose first-party application, algorithms, CLI, experiment lifecycle, optimization logic, scientific methods, evidence records, and orchestration logic are written in **Mojo**. Use **MAX** only through documented, tested interfaces for model inference and/or accelerator capabilities that the installed version actually exposes. Keep the application self-contained, reproducible, inspectable, and able to run offline for all core operations that do not inherently require an explicitly configured local model artifact or supported accelerator.

The long-term system unifies:

1. **AutoAI** — automated discovery, training, selection, optimization, and evaluation of AI systems.
2. **SciAI** — scientific AI, including SINN and SciTransformers.
3. **Scientific Looper** — a real experiment lifecycle that observes, hypothesizes, plans, executes, measures, verifies, compares, and accepts/rejects changes.
4. **Agentic research swarm** — specialized agents/workers with bounded roles, shared contracts, auditable work, and independent verification. The initial local implementation may be a deterministic task/workflow engine before model-driven agents are introduced.
5. **Computers discovering computers** — search over algorithms, kernels, compiler/execution choices, memory layouts, scheduling, parallelism, and hardware-aware configurations, bounded by what is supported and measurable.
6. **AI discovering AI** — search over models, architectures, training choices, algorithms, and inference configurations.
7. **Meta-Discovery Engine** — a third loop that learns which experiments, search policies, fidelity levels, agent roles, and evaluation procedures produce the most verified value per unit of compute/time/cost.
8. **Reciprocal co-discovery** — the AI and computing loops exchange evidence and constraints so that model/workload needs affect computing search and computing discoveries affect feasible/best AI candidates.
9. **Long-horizon HyperComputers research** — progressively explore hardware/software co-design and architecture discovery. Do not claim new physical computers, materials, quantum advantage, or manufacturing methods without the corresponding evidence and infrastructure.

**Build a unified system, but implement it one complete capability at a time.** Integration is a design goal; indiscriminate parallel implementation is prohibited.

---

# 1. Mandatory context loading and toolchain discovery

Before editing any code:

1. Read this file fully.
2. Read `AGENTS.md` and [`docs/MOJO_MAX_BOOTSTRAP_BLUEPRINT.md`](MOJO_MAX_BOOTSTRAP_BLUEPRINT.md) fully if present.
3. Read all supplied skills for Mojo syntax, project creation, MAX, GPU programming, MAX model lifecycle, and any other relevant skill. Skills have priority over remembered syntax or generic examples.
4. Inspect the current directory and Git status. The old HyperForge repository has been deleted; do not assume old code, tests, dependencies, outcomes, branches, or deployments still exist. Start from the actual current filesystem state.
5. Record the installed `mojo`, `pixi`, and `max` versions and relevant platform details. Verify commands with `--version`/`--help` and the installed docs. Do not assume a prior release or online snippet matches the environment.
6. Inspect the currently supported language features, standard library facilities, GPU APIs, MAX interop paths, test tooling, packaging, and license terms. Write tiny compile/run probes for uncertain APIs before building abstractions around them.
7. Establish whether CPU execution works. Establish GPU availability separately. Establish MAX model inference separately. Do not infer GPU or MAX model support merely from the package being installed.
8. Create an initial `docs/engineering/ENVIRONMENT.md` and `docs/engineering/PROJECT_STATE.md` with observed facts only.

The official Modular platform changes quickly. At this prompt's preparation time, official sources described Mojo 1.2.0 and MAX 26.7 (released 22 October 2026), and MAX 26.7 opened the graph compiler/runtime/device-extensibility source. This is a reference point, **not a command to downgrade or a substitute for inspecting the installed environment**. Choose one coherent, tested stable toolchain; pin it; test it in CI. Keep nightly features out of the production path unless explicitly isolated and justified.

---

# 2. Language, runtime, dependency, and deployment contract

## 2.1 First-party code must be Mojo

All HyperForge application source and algorithm implementations must be written in Mojo. This includes:

- the CLI and command dispatch;
- domain models, types, and validation;
- dataset parsing and preprocessing;
- model implementations and training loops;
- AutoML search and selection;
- the scientific numerical and differentiation substrate;
- SINN methods;
- SciTransformers and AutoTransformers implementations;
- metrics and baselines;
- evidence/provenance and file-backed persistence;
- optimization, candidate generation, scheduling, and the core Scientific Looper;
- local agent/workflow orchestration;
- benchmark execution and reporting;
- CPU kernels and supported custom GPU kernels;
- tests and test helpers, where the Mojo toolchain supports them.

Markdown, license files, TOML/environment metadata, and minimal packaging/configuration files are allowed. Shell may be used for small build/test automation only when necessary. **Do not use Python, TypeScript, Rust, C++, or another language to implement HyperForge application logic.** Do not silently introduce a Python sidecar, Python service, external agent framework, or hidden helper written in another language.

## 2.2 Define “no external dependencies” precisely

The runtime dependency policy is:

- Allowed and expected: the pinned Mojo compiler/runtime and standard library; explicitly supported MAX components for MAX-related functionality; OS facilities; GPU driver/runtime required by the supported device; user-supplied local datasets/model artifacts.
- Disallowed by default: third-party application libraries, package-based ML stacks, Python runtime, SciPy, NumPy, PyTorch, scikit-learn, pandas, Optuna, external databases, task queues, cloud services, web frameworks, agent frameworks, and internet APIs.
- Do not add a package merely to save a modest amount of code. Implement a small, well-tested Mojo-native version when reasonable.
- Before adding any non-platform dependency, explain why it is unavoidable, prove that the project requirement cannot be met with the standard library or supported MAX interfaces, document licensing/security implications, and request authorization. Do not secretly route around this policy.
- Network access must not be required for the core CLI, AutoML, SINN, scientific-transformer training on local data, experiment storage, evaluation, replay, or reports.

Mojo/MAX/OS/driver requirements remain declared platform dependencies; “zero dependencies of any kind” is not technically compatible with using a compiler, runtime, MAX, or GPU driver. The intended constraint is **no third-party application stack and no other-language application code**.

## 2.3 Be precise about MAX

MAX is not automatically a universal runtime for every arbitrary Mojo CLI program. It provides documented AI inference/modeling and accelerator functionality; some model architecture, pipeline, or serving paths in MAX may internally use Python. Therefore:

- Keep the HyperForge CLI and first-party logic native Mojo.
- Use only documented MAX entry points compatible with the no-Python-application policy.
- Prefer MAX's supported Mojo accelerator APIs and custom kernels where they genuinely help.
- For model inference, verify whether the installed MAX release exposes an appropriate supported boundary from a Mojo application. A local MAX Serve process/API may be acceptable only if it remains part of the explicitly allowed MAX installation and the HyperForge client itself is Mojo. Do not disguise an unapproved Python service as native Mojo.
- If no supported native boundary exists for a particular model-serving or training feature, keep the core capability functional without it, expose a clear `UNAVAILABLE` or `BLOCKED_BY_MAX_INTERFACE` status, document the limitation, and continue with other work. Do not fake model execution. Do not block all native development.
- Do not reimplement or copy MAX internals to bypass its documented interfaces or license. Use APIs/extension points as documented and inspect current license obligations before distributing binaries or modifying MAX source.
- Separate capability detection from capability execution. `hyperforge doctor` must clearly report compiler, MAX, CPU, GPU, local model files, and optional integrations individually.

## 2.4 CLI-only product

No frontend, website, dashboard, browser application, or API server is in scope. Provide the best possible command-line UX:

- useful `--help` and subcommand help;
- consistent positional/flag conventions;
- clear errors with actionable suggestions;
- deterministic exit codes;
- human-readable tables and summaries;
- stable `--json` machine-readable output;
- progress output to stderr while machine-readable result output goes to stdout;
- quiet/verbose/debug modes;
- dry-run and resource-budget previews;
- cancellation and safe interruption where supported;
- `doctor`, `version`, `config`, `init`, `dataset`, `experiment`, `automl`, `sinn`, `sci-transformers`, `auto-*`, `discovery`, `benchmark`, `artifact`, `replay`, and `report` commands only when backed by real behavior.

Do not scaffold fake subcommands for features that are not yet implemented. `--help` should distinguish implemented, experimental, unavailable, and planned features.

---

# 3. Engineering principles that outrank stylistic preferences

1. **Reality over rhetoric.** Code, tests, measured outcomes, and reproducible artifacts determine status.
2. **End-to-end capability ownership.** Each milestone gets one accountable implementation owner plus independent verification. The owner is responsible for wiring, tests, integration, error handling, and documentation—not just one isolated function.
3. **Sequential completion.** Finish the current milestone's required acceptance criteria before beginning substantial implementation of the next capability, except for genuine dependencies or isolated read-only research.
4. **Useful sophistication, not complexity theatre.** “Over-engineered” means carefully designed, observable, robust, optimized against measurements, and maintainable. It does not mean indiscriminate abstractions, gratuitous genericity, unused plug-in systems, premature distributed execution, or a home-grown replacement for everything.
5. **State-of-the-art is earned.** Before each research milestone, inspect relevant recent literature and benchmark practice, maintain a dated prior-art register, select a concrete target, and compare against credible baselines. Never claim state of the art without reproducible, fair comparison. If a feature is a proposed project-specific term, say so.
6. **No fake science.** Synthetic data is allowed only when labeled and appropriate. Never invent metrics, benchmark results, model support, GPU availability, scientific novelty, or test success.
7. **No fake integrations.** Imports, structs, interfaces, flags, mock objects, TODOs, and hard-coded sample responses do not prove a capability.
8. **Reproducibility first.** Fixed seeds, dataset fingerprints, versioned configs, deterministic behavior where feasible, honest nondeterminism notes, artifacts, and replay records.
9. **Failure is data.** Persist failed/invalid/interrupted trials with reason and cost; do not silently discard failures or show failures as successful runs.
10. **Baseline before optimization.** Correctness reference, baseline measurement, optimized candidate, equivalence/correctness checks, repeated measurements, then accept/reject.
11. **Protected acceptance.** Candidate code and agents cannot alter hidden holdouts, evaluator authority, or acceptance thresholds to bless themselves.
12. **No destructive actions without authorization.** Never delete user data, run destructive migrations, alter production infrastructure, install system-wide tools, or consume substantial/paid compute without explicit authorization.
13. **No unbounded autonomous work.** Agents have task budgets, maximum trials, time/resource caps, cancellation, and artifact limits.
14. **Update context continuously.** Keep the engineering handoff and status documents accurate after every meaningful milestone and at session end.
15. **Prefer a working narrow capability over many unfinished categories.** AutoML, SINN, and SciTransformers must be genuinely working before broad expansion into their neighboring families.

---

# 4. The intended system: unified yet modular

## 4.1 Three mutually connected discovery loops

### Loop A — AI discovers AI

Search and evaluate models, representations, algorithms, architectures, optimization/training choices, inference strategies, agents, and scientific learning configurations. Candidates must be executable and measured.

### Loop B — Computers discover computers

Search over workload algorithms, data structures, memory layout, compiler-visible configuration, kernels, tiling, parallelism, scheduling, precision, batching, hardware targets, and supported interconnect/resource configurations. Start with what can actually be compiled, measured, and validated on available hardware. Hardware-architecture simulation and physical co-design are later research tracks, not initial assumptions.

### Loop C — Meta-Discovery

Learn how to conduct better search: which proposal strategies, agents, experiments, budget splits, fidelity levels, and verification protocols produce the best verified improvement per unit of compute, time, and cost. Meta-Discovery must use evidence from both Loop A and Loop B.

### Reciprocal coupling

A candidate is not merely a model hyperparameter record. Define a typed, versioned `DiscoveryGenome` that can hold supported choices across:

- task/domain;
- data and preprocessing;
- model/architecture;
- algorithm and objective;
- optimizer/training configuration;
- software implementation/kernel;
- runtime, batching, memory, precision, and parallelism;
- hardware capabilities and resource budget;
- experiment protocol, fidelity, seed, and constraints.

The genome may evolve as the codebase grows. Do not implement unsupported fields that have no execution meaning. A candidate's actual phenotype must be recorded after validation, including normalized/default values and rejected fields.

AI-side performance profiles should inform systems-side search; systems-side latency/memory/throughput measurements should change which AI candidates are feasible or desirable. The engine must benchmark coupled search against independent/sequential baselines to show whether reciprocal coupling provides real value.

## 4.2 Shared substrate

All capabilities should reuse these foundations when justified:

- typed IDs, schemas, validation, and versioned configuration;
- immutable experiment definitions and append-only event histories;
- deterministic random seeds and seed derivation;
- dataset descriptors/fingerprints and leakage-safe split plans;
- common metrics and uncertainty representations;
- baseline registry;
- candidate/individual/trial lifecycle and terminal states;
- resource budget and cancellation contracts;
- artifact manifest and content integrity;
- experiment lineage and derivation graph;
- evaluation/acceptance decision with evidence;
- stable CLI output and exit codes;
- checkpoint/replay/recovery where implemented.

Do not build a universal abstraction too early. Extract shared structures after two real capabilities show the common requirement. Keep domain-specific mathematical meaning explicit.

---

# 5. Required repository and persistent project memory

Create the repository from scratch. Use a clean, understandable structure that matches the current Mojo ecosystem and the project's actual toolchain. A starting proposal is:

```text
AGENTS.md
README.md
pixi.toml                 # or the currently supported official environment manifest
LICENSE
CHANGELOG.md
docs/
  INDEX.md
  VISION.md
  ARCHITECTURE.md
  PROJECT_STATE.md
  ENVIRONMENT.md
  DEPENDENCY_POLICY.md
  CLI_SPEC.md
  CAPABILITY_MATRIX.md
  ROADMAP.md
  MILESTONES.md
  AGENT_WORKFLOW.md
  ENGINEERING_DECISIONS.md
  TESTING_AND_VALIDATION.md
  SECURITY_AND_RELIABILITY.md
  SCIENTIFIC_VALIDATION.md
  STATE_OF_THE_ART_REGISTER.md
  RISKS_AND_BLOCKERS.md
  HANDOFF.md
  milestones/
  research/
src/
  main.mojo
  hyperforge/             # modules as supported by the Mojo project structure
    core/
    cli/
    io/
    data/
    math/
    autodiff/
    models/
    metrics/
    optimization/
    automl/
    sinn/
    scientific_transformers/
    autoai/
    sciai/
    discovery/
    evidence/
    runtime/
    max_backend/
tests/
benchmarks/
examples/
```

This tree is a guide, not a demand to create empty directories/files. Confirm the supported Mojo module/package conventions and build a real minimal module structure. Every created document needs a purpose and useful content.

## Context files must not become stale

- `AGENTS.md` remains the concise, durable agent contract; link to the detailed docs rather than pasting the whole roadmap into every file.
- `PROJECT_STATE.md` states implemented/verified/partial/blocked/not-implemented features with evidence.
- `CAPABILITY_MATRIX.md` includes owner, milestone, status, dependencies, CLI entry points, tests, and evidence links for every capability.
- `STATE_OF_THE_ART_REGISTER.md` records date, problem, comparison methods, benchmark datasets, sources, evidence quality, accepted/rejected ideas, and limitations. Mark this as an ongoing register, not proof of novelty.
- `HANDOFF.md` states the exact Git revision, current milestone, modified files, checks run and their outcomes, unresolved issues, and the next concrete action.
- Update docs after code and observed results change. Never mark a milestone complete from documentation alone.

---

# 6. CLI product specification

Implement a polished CLI called `hyperforge` (exact binary name to be verified with toolchain packaging).

## 6.1 Global behavior

- `hyperforge --help`
- `hyperforge --version`
- `hyperforge doctor [--json]`
- `hyperforge init [workspace-path]`
- `hyperforge config show|validate` where actual config support exists
- `hyperforge status [--json]`

Use consistent error types and documented exit codes. Suggested exit semantics: success; usage/validation error; experiment failure; dependency/device unavailable; interrupted/cancelled; internal error. Write the mapping in `CLI_SPEC.md` and test it.

`doctor` should separately check: executable/toolchain version; workspace read/write; available memory/CPU information where available; MAX tool/package/interface status; GPU discoverability; device kernel compilation/execution if explicitly requested; local model artifact availability; storage integrity; test/benchmark capability. A missing GPU should not prevent CPU-only use. An unavailable MAX model API should not prevent AutoML/SINN CPU execution.

## 6.2 Experiment and artifact operations

Add real commands as capabilities are implemented:

- `hyperforge experiment list|show|validate|replay|compare`
- `hyperforge artifact list|inspect|verify`
- `hyperforge dataset inspect|validate|fingerprint|split`
- `hyperforge benchmark list|run|compare`
- `hyperforge report show|export`
- `hyperforge discovery status|propose|run|compare|replay`

Do not expose commands ahead of implementation other than `--help` clearly labelling planned features. Never have `experiment replay` claim reproducibility unless it actually reconstructs all required inputs/configuration and executes or verifies them.

## 6.3 AutoML CLI target

Provide a coherent interface, adapting exact syntax to the implementation:

```text
hyperforge automl inspect --data DATA.csv
hyperforge automl run --data DATA.csv --target TARGET --task regression --metric rmse --budget 32 --seed 42 --workspace PATH
hyperforge automl show EXPERIMENT_ID
hyperforge automl compare EXPERIMENT_ID_A EXPERIMENT_ID_B
hyperforge automl replay EXPERIMENT_ID
```

A complete command must actually load data, validate schema, run preprocessing/model fitting and evaluation, persist trial/evidence/artifacts, and return a meaningful summary. Never ship a command that prints canned success text.

## 6.4 SINN CLI target

```text
hyperforge sinn list-problems
hyperforge sinn validate --problem poisson_1d --config PATH
hyperforge sinn solve --problem poisson_1d --config PATH --seed 42 --budget ...
hyperforge sinn evaluate EXPERIMENT_ID
hyperforge sinn compare EXPERIMENT_ID_A EXPERIMENT_ID_B
```

Use schema-validated, versioned problem/config specifications. A supported PDE name is not supported until residual, boundary/initial conditions, numerical baselines, metrics, and tests are real.

## 6.5 Scientific transformer CLI target

```text
hyperforge sci-transformers list-tasks
hyperforge sci-transformers train --task TASK --data PATH --config PATH --seed 42
hyperforge sci-transformers evaluate EXPERIMENT_ID
hyperforge sci-transformers predict EXPERIMENT_ID --input PATH
```

Training, evaluation, and prediction must be executable and share the same model/config artifact contract. If training is CPU-only in the first release, say so and make it useful and correct before acceleration work.

---

# 7. Architecture and implementation quality

## 7.1 Design with typed contracts

Use Mojo structs/enums/traits/generics and ownership/lifetime facilities in accordance with current skills. Separate domain models from CLI rendering and file operations. Make invalid states hard to represent where the language/toolchain permits. Prefer explicit error returns over panics for expected user/data/runtime failures. Keep internal errors diagnosable without leaking sensitive data.

Avoid speculative generic frameworks. Make the smallest interfaces that support two real implementations. Do not create circular module dependencies. The core AutoML/SINN/scientific-transformer code must be testable without GPU or MAX model inference.

## 7.2 Numerical substrate

Build only the numerical primitives actually needed by upcoming milestones; keep them tested against known reference values:

- scalar and vector/matrix operations;
- stable reductions, dot products, norms, and normalization;
- deterministic pseudorandom generator with seed derivation;
- finite-value detection and tolerances;
- numerical differentiation utilities for tests/reference checks;
- linear solvers appropriate for small benchmark problems;
- tensor indexing/shape checks for neural models;
- optimizer primitives and gradient checks.

For a differentiable neural implementation, select a concrete approach supported by Mojo: a small reverse-mode tape, a well-tested operator-level AD system, or analytic sensitivities for the constrained initial model. Scientific residual training may require derivatives of network outputs with respect to inputs and gradients of that residual loss with respect to parameters. Do not use ordinary backprop for parameters while quietly approximating PDE derivatives without labeling and justifying the approximation. Test higher derivatives using analytical functions and finite-difference checks as a test oracle. Document precision and stability limits.

## 7.3 Dataset and file I/O

Start with robust local CSV for tabular AutoML and explicit structured inputs for scientific problems. Validate delimiter/quoting, header uniqueness, row lengths, missing values, numerical parsing, finite values, target presence, categorical cardinality, and file-size/resource limits. Never infer semantics silently if it can change results. Treat data as immutable input; derived/preprocessed data and split metadata must be recorded separately. Prevent train/validation/test leakage.

Do not depend on a separate database server. Use a versioned local append-only event journal and artifact directory, designed for crash safety. Use atomic replacement where supported, checksums/content fingerprints from a verified standard-library primitive or a carefully tested implementation, schema versioning, corruption detection, and recovery. If a preferred serialization format is not supported by the installed Mojo standard library, design a small documented stable format rather than adding a library without approval. Do not invent standard-library API names; verify them.

## 7.4 Testing and benchmarking

Create tests before or alongside each behavior. Use deterministic toy problems with known answers, edge cases, property/invariant tests where practical, malformed input tests, serialization round trips, restart/replay tests, and regression tests. Each optimization must have a correctness check before performance timing. Report medians and dispersion for repeated benchmarks; avoid misleading single-run improvements. Keep correctness suites distinct from performance suites.

## 7.5 Performance policy

First correct, then measure, then optimize. Establish a portable CPU baseline before GPU work. Profile actual bottlenecks. Use SIMD, compile-time specialization, data layout changes, parallelism, and Mojo GPU kernels only when evidence justifies them. Maintain a simple reference implementation for every optimized kernel and check numeric equivalence with documented tolerances. Keep transfer cost, compilation/warm-up, data loading, and model inference overhead visible separately from steady-state kernel time.

---

# 8. Agentic workflow and accountability

Use actual coding-agent subagents only if the environment supports them. If it does not, execute the same roles in distinct sequential passes. Never claim parallel agents ran when they did not.

## Required roles

1. **Chief Architect / Orchestrator** — maintains order, contracts, dependency graph, status, and milestone decisions.
2. **Mojo Toolchain Engineer** — checks current syntax/APIs, project/package conventions, compiler errors, and unsafe assumptions.
3. **Capability Owner** — one dedicated owner for the current capability (AutoML, SINN, SciTransformers, etc.) responsible for complete end-to-end implementation.
4. **Independent Verification Engineer** — creates/adjudicates tests and tries to falsify the claimed behavior; not the same agent as the primary implementation owner where multi-agent execution is available.
5. **Scientific/Algorithmic Reviewer** — checks mathematics, baselines, leakage, numerical behavior, evaluation protocol, and research claims.
6. **Systems/Performance Engineer** — examines profiling, memory, acceleration, scaling, and benchmark validity.
7. **Security/Reliability Reviewer** — checks file safety, resource caps, crash recovery, parser robustness, path handling, and untrusted content.
8. **Documentation/Handoff Engineer** — records real behavior and evidence, not promises.

## Capability completion loop

For every capability:

1. **Discover:** inspect actual code/docs and current technical sources. Identify existing reusable implementations and concrete gaps.
2. **Specify:** write a concise milestone specification, data contracts, edge cases, and acceptance criteria before major code changes.
3. **Plan:** list dependencies and files/modules likely to change. Ensure one clear accountable owner.
4. **Implement:** produce real Mojo behavior behind the actual CLI or internal interface. No stub-first project with endless TODOs.
5. **Test:** run targeted tests, add failure-oriented tests, and record commands and outcomes.
6. **Challenge:** independent reviewer checks correctness and tries adverse inputs and misleading cases.
7. **Repair:** fix all release-blocking issues, rerun tests, and inspect the diff.
8. **Integrate:** verify the feature works with file storage, event history, CLI, artifact records, and prior capabilities.
9. **Benchmark:** compare with the chosen baseline where performance or accuracy is claimed.
10. **Document:** update status, capabilities, evidence, limitations, and handoff.
11. **Gate:** mark complete only if every required acceptance criterion passes; otherwise mark partial/blocked and continue repairing.
12. **Advance:** only then begin the next major capability.

Use parallel agents for read-only research, test design, bounded non-overlapping implementation, and independent review. Avoid concurrent edits to the same file/shared contract. Integrate sequentially. Don't waste tokens on agent conversation when a concrete command, test, diff, or artifact is needed.

Do not ask the user to approve ordinary engineering details covered here. Do ask before destructive actions, substantial external costs, licensing-sensitive steps, or a decision that irreversibly violates the no-dependency constraint. If blocked, finish safe independent work and document the exact blocker.

---

# 9. Milestone roadmap — complete these in order

The first three capability anchors must be completed in this order: **AutoML first for AutoAI; SINN first for SciAI; then SciTransformers.** Do not jump to the exciting meta-discovery loop before these foundational research workflows actually work. The Meta-Discovery engine can be developed in minimal form as an experiment ledger from the start, but reciprocal autonomous discovery is a later milestone.

## M00 — Toolchain, project bootstrap, and CLI shell

**Implement**
- Verified pinned Mojo/MAX environment based on installed stable versions.
- Minimal build/run/test commands.
- Native executable entry point.
- CLI parser and help/version.
- `hyperforge doctor` with separate capability probes and truthful statuses.
- Minimal `init` workspace operation.
- First docs and CI/build checks, without adding third-party dependencies.

**Acceptance**
- Clean checkout can reproduce setup and compile.
- Help/version/doctor work; errors and exit codes are tested.
- CPU-only CLI works even when no GPU/model is present.
- No Python source/runtime or unapproved packages are required for HyperForge logic.

## M01 — Core experiment and evidence substrate

**Implement**
- Typed experiment, dataset, candidate, trial, metric, artifact, error, budget, and acceptance types.
- Append-only journal and versioned local store; recovery from truncated/corrupt last record is tested.
- Atomic artifact writes, integrity hashes, provenance, status transitions, and run IDs.
- Seeded RNG and controlled seed derivation.
- Stable JSON output if supported through verified Mojo implementation; otherwise a versioned machine format plus human output.
- Baseline registry, measurement records, replay metadata, and report format.

**Acceptance**
- Persistence survives process restart.
- Corrupt/truncated records are detected/recovered according to documented rules.
- Round trips preserve records and stable IDs.
- Replay refuses missing data/config rather than fabricating it.
- No database server or external storage service.

## M02 — AutoML: the first complete AutoAI capability

**Goal:** deliver a real end-to-end tabular AutoML workflow, not merely a hyperparameter search loop.

### Supported task and data scope for first complete release

Start with local CSV, tabular regression, and classification. Support a clearly declared set of feature types and missing-data policies. Reject unsupported forms instead of silently corrupting them. Expand to multiclass and additional data types only after the binary/classification and regression path is correct; the roadmap may combine the expansions into the AutoML completion gate if the environment permits.

### Required data pipeline

- Inspect schema, target, row/column counts, missingness, constant columns, high-cardinality categories, finite/numeric values, and potential target leakage.
- Train-only fitting for imputation, scaling, categorical encoding, feature selection, and other preprocessing.
- Deterministic holdout splits and configurable cross-validation; stratification for classification where appropriate.
- Keep validation for selection and holdout test data locked until final evaluation. No test metrics may influence hyperparameter/model selection.
- Store split indices/seed and data fingerprint.

### Model ladder — all real, incrementally implemented

Begin with simple, valuable baselines and grow the model set without pretending:

1. Regression mean/median baseline; classification majority-class baseline.
2. Linear regression and regularized ridge regression.
3. Logistic regression for binary classification, then multiclass method where validated.
4. k-nearest neighbors with feature scaling and deterministic tie handling.
5. Decision tree with correct split search, stopping criteria, and leaf predictions.
6. Random forest as a genuine bootstrap/feature-subsampling ensemble of real trees.
7. Gradient-boosted trees or another credible strong tabular learner, if the from-scratch implementation can be made reliable and benchmarked; do not substitute a hard-coded heuristic under its name.
8. Candidate combination/ensembles only when out-of-fold validation makes leakage-safe stacking/selection possible.

Document the exact scope achieved. “AutoML complete” requires more than linear regression but must not become an excuse to implement a dozen weak models. Quality beats breadth; the acceptance gate should include a reasonable strong learner for the target tasks supported.

### Metrics and calibration

Implement and test appropriate metrics: MAE, MSE, RMSE, R² with defined edge cases; accuracy, precision/recall/F1, confusion matrix, and log loss where valid. Calibration metrics or probability quality can be added for classifiers only where reliable probabilities are produced. Define zero denominators, missing classes, constant targets, and non-finite predictions explicitly.

### AutoML search engine

- Typed search-space specification with validation and conditional parameters.
- Deterministic random search baseline.
- A resource-aware multi-fidelity strategy such as successive halving/racing for candidates that can be evaluated at varying resource levels.
- Implement a strong adaptive sampler such as TPE or a carefully scoped Bayesian optimizer natively in Mojo only after validating its statistics and behavior. Do not call a random sampler “Bayesian.”
- Feed every observed valid result back into the optimizer before subsequent adaptive proposals.
- Track failed/invalid candidates, costs, pruning reason, and optimizer state.
- Select candidates using validation/CV score and constraints; evaluate the final chosen model once against held-out test data.
- Support a fixed trial budget, deterministic seed, cancellation, and restart/recovery if the store supports it.
- Report search overhead as well as model runtime.

### AutoML CLI and outputs

Implement `automl inspect`, `automl run`, `automl show`, `automl compare`, `automl replay`, and `report`. Save complete data/config/model/metric lineage and a useful explanation of selection, without presenting post-hoc correlation as a causal explanation.

### AutoML acceptance gate

- Clean local example dataset produces a real, repeatable experiment.
- At least the declared baseline and two non-identical real models run.
- Missing/corrupt data and invalid target fail clearly.
- Data preprocessing is leakage-safe.
- All metric edge cases have tests.
- Search is bounded and adaptive feedback is proven by a regression test that fails if feedback is disconnected.
- Outputs/artifacts can be reopened after process restart.
- Held-out test is isolated from selection.
- Model selection on known toy datasets behaves correctly.
- At least one credible dataset benchmark compares candidates to the baselines, with repeated seeds/folds where appropriate.
- User docs explain supported inputs, limitations, exact run command, and reproducibility.
- Independent verification signs off; all tests/build checks pass.

**Do not move to SINN until this gate passes or a documented external blocker makes a specific criterion impossible.**

## M03 — SINN: first SciAI capability, built from scientific and numerical foundations

**Terminology:** In HyperForge, SINN means the project's proposed **Science-Informed Neural Networks** framework. It is an umbrella/design direction, not a claim that the acronym names one universally standardized new method. Distinguish established PINN methods and other known formulations from HyperForge's own contributions. Do not rename a conventional MLP as SINN.

### Minimum scientifically meaningful v1

Implement a fully reproducible physics-informed neural method for a small, analytically solvable PDE such as 1D Poisson, selected after checking numerical difficulty and available Mojo capabilities. Prefer a benchmark with a known exact solution, explicit boundary conditions, and a dependable finite-difference/reference solution. Add at least one second benchmark only after the first converges reliably.

### Implement the whole pipeline

- Typed scientific problem specification: domain, equation/residual, forcing, boundary/initial conditions, parameters, units/scaling where relevant, collocation strategy, training objective, solver settings, and validation protocol.
- Neural network implementation in Mojo with fully explicit weights, biases, activation functions, initialization, forward pass, trainable parameter lifecycle, and serialization.
- A verified differentiation path to compute derivatives required by the PDE and gradients required for training. Choose a small reverse-mode AD engine, analytic sensitivity approach, or other fully tested approach. Do not claim second derivatives are supported until tested.
- Stable loss computation combining data/physics residual, boundary conditions, initial conditions where applicable, and optional observation loss.
- Enforce boundary constraints exactly when the formulation supports it; otherwise quantify and validate penalty methods.
- Training optimizer such as Adam with explicit hyperparameters, gradient checks, convergence diagnostics, clipping only where justified, and non-finite rejection.
- Collocation sampling, fixed validation points, deterministic seeds, and optional adaptive residual-based sampling after basic correctness.
- Separate physics residual, boundary/initial violation, data error, held-out solution error, training stability, runtime, and uncertainty/limitations where implemented.
- A conventional numerical solver/reference method for the same problem, implemented in Mojo, to test the learned approximation. Do not compare PINN only against itself.
- Run diagnostics for failed convergence, poorly balanced loss terms, stiffness, scale imbalance, and boundary violations. A small residual at sampled points is not proof of correct generalization.

### SINN research quality

For each equation family, state the mathematical assumptions and validity range. Compare the chosen representation, constraint enforcement, optimizer, and collocation strategy with reasonable alternatives. Include failure cases. PINNs can fail due to loss imbalance, stiffness, spectral bias, boundary enforcement, and optimization difficulty; the implementation must diagnose these rather than assume physics loss guarantees correct results.

### SINN acceptance gate

- At least one PDE problem is solved through an actual Mojo neural network and optimization loop.
- Exact/reference solution is computed independently.
- Equation residual and boundary error are evaluated on unseen points, not only training collocation points.
- Differentiation passes analytical/finite-difference unit checks within stated tolerances.
- Training is reproducible with fixed seed to the degree promised.
- Multiple seeds or a repeated run document variability.
- Numerical baseline is compared using a common evaluation grid and honest runtime conditions.
- Negative/divergent training is represented honestly and does not return `SUCCESS`.
- Artifacts and config are persisted and the experiment can be inspected/replayed.
- The model, residual, sampler, optimizer, and evaluation each have tests.
- Independent scientific review approves the result.

## M04 — SciTransformers: second SciAI flagship

**Terminology:** SciTransformers is HyperForge's scientific-transformer research family, not a claim of one standardized architecture. Define an exact problem class and architecture variant before coding. Do not call generic next-token text prediction a scientific transformer.

### First target problem

Start with scientific sequences or regular-grid spatiotemporal fields where inputs, outputs, coordinates, physical parameters, and reference data are fully specified. Choose one deterministic, local benchmark with an independent reference solution/simulator or a transparent synthetic generator, explicitly labeled. Begin small enough to train and test on CPU; use GPU acceleration only when available and separately verified.

### Model components

- Schema-aware input pipeline for time steps/fields, physical parameters, coordinates, masks, units/scales where available, and boundary/initial-condition metadata.
- Tokenization/patching suitable for the selected domain and reproducible reconstruction of outputs.
- Explicit positional/coordinate encodings; assess absolute, relative, rotary, or continuous coordinate representations only where compatible with the task.
- Pre-normalization or another justified stable block arrangement; multi-head attention; residual paths; feed-forward block (e.g. gated FFN/SwiGLU only if implemented correctly); output head appropriate to the scientific target.
- Correct causal/bidirectional/mask semantics for the task.
- Stable attention softmax with masking and numerical tests.
- Parameter initialization, training objective, optimizer, gradient flow, checkpointing, inference path, and a validated tensor shape system.
- Optional physical-residual loss or conservation/constraint checks only when mathematically justified for the benchmark.
- No unsupported claims of FlashAttention or GPU fusion. Implement the straightforward reference kernel first, then optimize with correctness comparisons and profiling.

### Comparisons

Compare against a naive persistence/mean or simple physical baseline as applicable, an MLP or linear model, and the best suited simple numerical/reference method. If the objective is operator learning across families of PDE parameters, compare against a relevant neural-operator baseline where a fair and implemented comparison is possible. Report accuracy, long-rollout stability, conservation/constraint error where relevant, latency, memory, throughput, and generalization across held-out initial conditions/parameters—not only training loss.

### SciTransformers acceptance gate

- A complete train/evaluate/predict path works end to end.
- Shape/mask/positional semantics have unit tests.
- Attention and normalization pass numerical tests against known small cases.
- Training loss decreases on a small known task and reproduces within declared tolerance.
- Held-out evaluation is genuinely held out.
- At least two non-transformer baselines are evaluated when feasible.
- Longer rollouts and physical constraints are assessed for the chosen task.
- The model/checkpoint/config is persisted and restored.
- Independent verification and scientific review pass.

**Do not move to broad transformer search or scientific foundation model claims before this gate passes.**

---

# 10. Complete remaining AutoAI capabilities, one at a time

Every family below receives a specific milestone file, an accountable owner, a supported-scope definition, real CLI entry point, tests, baseline, and acceptance gate. They must reuse common infrastructure but retain their own semantics.

## AutoDL — Automated Deep Learning

Implement a real deep-learning experimentation loop on top of verified model/tensor/autodiff primitives. Search model depth/width, activation, initialization, optimizer, learning rate, regularization, batch size, and supported architecture choices. Use bounded search and resource budgets; compare random search to the selected adaptive/multi-fidelity method. Support repeated seeds, early stopping based on validation only, checkpoint recovery, parameter/resource limits, and a reproducible benchmark. Do not call hyperparameter tuning alone neural architecture search; architecture candidates must actually differ structurally. Do not call model training complete if gradients are detached or parameters never update.

Acceptance: at least two architectures are truly trained; a test verifies parameters change and loss/metrics update; correct validation/holdout separation; an end-to-end experiment is replayable; runtime/resource limits are honored.

## AutoRL — Automated Reinforcement Learning

Start with a small deterministic environment API and fully tested tabular methods such as dynamic programming or Q-learning/SARSA where appropriate. Define observation/action/reward/termination contracts; episode boundaries; exploration schedule; policy evaluation separate from training; return distribution, variability, and confidence summaries; deterministic seeding; environment step/time budgets; and baseline random/policy methods. Only introduce neural policies when AutoDL's training foundation is validated. Avoid large or unsafe real-world actions.

Acceptance: policy improves on a known benchmark compared with a random baseline over repeated seeds; evaluation runs are separate from training; learning curves and returns are persisted; failure/termination is correctly represented.

## AutoTransformers — automated transformer discovery/optimization

Keep distinct from SciTransformers: SciTransformers is a science-task architecture family; AutoTransformers is the system that searches supported transformer configurations. Search actual architecture/attention/embedding/FFN/context/cache/precision and supported inference/training parameters. Add parameter-count, memory, latency and quality constraints. Use benchmark-based selection; do not assume a theoretically smaller configuration is faster. Support MAX-backed inference configurations only through documented local interfaces; training is a separate capability and must not be implied by inference support.

Acceptance: candidates differ in actual configuration/behavior; quality and performance metrics come from executions; fixed-budget comparisons against default and search baselines are reproducible.

## AutoLLM — automated language-model experimentation

Within the no-third-party-dependency policy, implement experiment specifications, local model artifact discovery, prompt/test-suite versioning, evaluation datasets, task metrics, inference parameters, latency/throughput/memory capture, result comparison, regression tests, and supported MAX model execution. Model weights must be explicitly user-provided or downloaded through a separately documented process with hashes/license checks; core offline workflows must not rely on network access. Do not imply model training/fine-tuning if the supported native stack only provides inference. Adapter/LoRA/fine-tuning is in scope only if a documented, validated Mojo/MAX path exists and tests prove parameter updates.

Acceptance: local MAX inference is real and validated for at least one compatible user-supplied model/environment; prompt/evaluation suite is reproducible; model unavailable produces a clear actionable result; no external inference API or Python bridge is silently invoked.

## AutoGenAI — automated generative experimentation

Implement candidate specification, supported local model invocation, deterministic or seed-controlled generation where the model interface provides it, constraint/format validation, duplicate detection, candidate grading using explicit measurable criteria, human-review hooks through exported artifacts, and evaluation records. Do not grade a generation solely by another unconstrained model's opinion; combine exact metrics, reference comparisons, rule-based checks, and clearly labelled model-judged metrics as appropriate. This family must build on a verified AutoLLM/local MAX interface.

Acceptance: actual generated candidates are saved, validators run, invalid candidates are not counted as successes, comparisons are repeatable where possible, and costs/failures are recorded.

---

# 11. Complete remaining SciAI capabilities, one at a time

SINN and SciTransformers are the first completed SciAI anchors. After them, add the following as distinct capabilities. Reuse the numerical substrate but do not conflate task classes.

## SciML — Scientific Machine Learning

Unify supported scientific data, models, numerical solvers, observations, constraints, parameter identification, inverse problems, data assimilation, uncertainty, and hybrid physics/data-driven methods. Support an explicit problem registry. For each problem, define units, scaling, governing assumptions, reference solution, boundary conditions, and evaluation. Compare learned methods with conventional solvers and simple baselines. Do not use “physics-informed” as a decoration; specify how the physics enters the objective/architecture/solver and validate the resulting solution.

## SciDL — Scientific Deep Learning

Apply validated deep-learning primitives to scientific tasks: grid/field/sequence data; domain-aware representations; stable normalization and optimization; held-out generalization over physical parameters/conditions; appropriate PDE/numerical baselines; and physical metrics. Distinguish supervised data-driven scientific DL from SINN methods and operator learning. Acceptance requires a real benchmark, baseline comparison, reproducibility, and a scientifically valid evaluation protocol.

## SciRL — Scientific Reinforcement Learning

Use bounded, reproducible environments to optimize scientific decisions such as experimental design, solver selection, resource scheduling, control in a validated simulator, or adaptive sampling. Include safe action constraints, explicit reward/objective definitions, held-out environment conditions, random and domain-heuristic baselines, repeated seeds, and evaluation separate from training. Start with one controlled simulator, not an unconstrained real-world system.

## SciLLM — scientific language-model workflows

Use verified local MAX model inference where available for literature/explanation/candidate-generation support, scientific document structuring, hypothesis drafting, tool routing, and experiment interpretation. Every scientific claim must retain source/provenance or be labelled a hypothesis. Separate model-generated interpretation from computed measurements. Provide structured outputs, explicit uncertainty, citation/reference records when external sources are used, and validation gates. Do not treat an LLM output as numerical truth or allow it to accept its own experiment.

## SciGenAI — scientific generative AI

Generate scientific candidates such as equations, parameter sets, experiment designs, code candidates, or valid structured samples within a specific bounded domain. Build domain-specific parsers, constraints, dimensional checks, simulators/reference solvers, validity filters, and novelty screening that acknowledges limitations. Measure candidate validity, diversity, downstream success, resource cost, and domain-specific metrics. A generated hypothesis is not a discovery until independently tested.

## Additional operator-learning research

After the initial milestones, evaluate a scientifically justified neural-operator family (for example, DeepONet-like or Fourier/operator-based approaches) for a well-defined parameterized PDE family. Define train/test separation over entire initial conditions or parameters, compare against conventional numerical solvers and simpler models, and report inference amortization versus solver cost. Do not implement a label-only “neural operator.”

---

# 12. MAX and hardware acceleration milestone

Only integrate MAX features verified in the current installed version and allowed by the dependency/licensing policy.

## Work items

- Add a MAX capability probe and compatibility record.
- Demonstrate one documented, minimal Mojo GPU kernel on a supported device (vector operation or reduction); maintain a CPU reference.
- Test device selection, allocation, bounds, transfers, launch configuration, error propagation, and cleanup.
- Benchmark correctness, compile/warm-up, transfer time, kernel time, and end-to-end time separately.
- Implement one useful kernel for an actual bottleneck discovered in AutoML/SINN/SciTransformers (e.g. a matrix operation/reduction) only after profiling proves it matters.
- Add a MAX model-inference adapter only via a supported documented API/endpoint; test request, response, timeout, unavailable model, context/shape errors, and provenance. It must be optional to core CPU work.
- Record MAX version, driver, device name/capability, kernel/model settings, precision, artifact hashes, and benchmark protocol.
- Provide `hyperforge doctor --gpu` / `--max` or equivalent supported flags to run explicit checks without making normal CLI startup slow or crashing on missing devices.

## GPU acceptance gate

- A supported device is actually detected; if not, report blocked and retain CPU correctness.
- The real kernel compiles and executes on hardware when available.
- Output agrees with a reference within a stated tolerance.
- Tests cover edge shapes, non-multiple block sizes, empty/invalid input policy, and bounds.
- No performance claim without repeated measurement, warm-up policy, and environment capture.
- The project does not claim all MAX models or devices are supported merely because one kernel works.

---

# 13. Scientific Looper and research swarm

The Scientific Looper must become real durable workflow behavior, not a motto:

**OBSERVE → FORMULATE → HYPOTHESIZE → PLAN → VALIDATE CONSTRAINTS → EXECUTE → MEASURE → VERIFY → COMPARE → LEARN → ACCEPT / REJECT / DEFER / ROLLBACK.**

Each transition records event, timestamp, actor/agent identity, input/output IDs, configuration/version, reason, resource budget, artifact pointers, and failure details. Transitions must be validated, idempotent where required, and replayable to the extent supported by stored inputs. Use a deterministic local scheduler first; add parallel worker execution only after concurrency/resource behavior is tested.

## Specialized agent roles within HyperForge

When MAX inference is available, agents may use it for bounded proposals/explanations, but core acceptance logic remains deterministic/explicit and independently verified. Roles may include:

- Research Planner: specifies problem, constraints, metrics and experiment plan.
- AutoML/SciAI specialist: proposes task-specific candidates.
- Algorithm Engineer: explores algorithmic alternatives.
- Systems Optimizer: profiles and proposes kernel/runtime changes.
- Experiment Economist: chooses fidelity/budget and expected information gain.
- Skeptic/Red Team: seeks counterexamples, leakage, invalid assumptions and benchmark gaming.
- Reproducer: independently reruns promising candidates from recorded artifacts.
- Integrator: packages accepted changes into the supported interface.
- Orchestrator: assigns bounded tasks and maintains state.

Each task needs owner, inputs, allowed actions, max trials/resources, timeout, output schema, acceptance criteria, and terminal state. Agent count is not a goal. Specialized work, reduced failure, and measurable improvements are goals. An agent proposal is not a result; execution and verification are mandatory.

---

# 14. Reciprocal Meta-Discovery Engine

Build the full meta-engine only after AutoML, SINN, SciTransformers, the experiment ledger, and enough benchmark fixtures exist.

## 14.1 Discovery Genome

Represent only supported candidate dimensions across AI/model/algorithm/software/runtime/hardware/experiment configuration. Validate each gene, define dependencies, prohibit unsupported combinations, and store canonical configs/hashes. Ensure genome mutation/crossover or proposal operators preserve type/constraint validity.

## 14.2 Causal Discovery Graph

Store hypotheses, runs, candidate parents, code/config changes, datasets/workloads, interventions, metrics, artifacts, failure reasons, and decisions as a typed graph. Label relationships as observed, hypothesized, or experimentally supported. Use ablations/controlled interventions before causal claims. Do not infer that a single correlated change caused the result.

## 14.3 Adaptive Experiment Economy

Allocate budgets using a transparent, testable policy that considers expected improvement, information gain/uncertainty, cost, failure risk, and relevance to the Pareto frontier. Start with a baseline policy, compare against random allocation, and evaluate with replayable experiment sequences. Use multi-fidelity evaluations only when fidelity ordering and correlation to full evaluation are checked.

## 14.4 Pareto optimization

Support multi-objective candidate evaluation for supported dimensions such as quality/error, latency, throughput, memory, resource/time cost, and measured energy if available. Correctly handle missing/incomparable objectives, constraints, normalization, dominance, duplicate candidates, and ties. Do not collapse objectives into arbitrary weighted scores without making weights and assumptions explicit. Keep Pareto candidates and final decision rationale.

## 14.5 Reciprocal feedback test

Build a bounded benchmark where AI choices and systems choices can both alter measurable outcomes. Compare at least:

A. fixed model + fixed compute;
B. AI search only;
C. compute/system search only;
D. independent or sequential search under a matched budget;
E. joint reciprocal search;
F. ablations removing shared history, adaptive budgeting, or the meta-policy.

Use same total evaluation budget as far as practical. Measure task quality, wall-clock, memory, and experiment cost. Repeat seeds where stochasticity matters. Report negative results too. The central claim is not assumed true: evaluate whether coupling improves outcome or verified discoveries per unit cost.

## 14.6 Controlled recursive self-improvement

RSI is limited to isolated proposed code/config/algorithm changes:

1. protected baseline;
2. written hypothesis and expected measurable change;
3. isolated candidate workspace/branch;
4. compile, unit, property, regression, and benchmark tests;
5. independent verifier;
6. threshold comparison and holdout evaluation;
7. accept/reject/defer/rollback;
8. immutable evidence record.

The agent cannot modify the authority or protected evaluator, turn off required tests, replace baseline data, or update the trusted acceptance criteria that judge its own candidate. The evaluator may itself be improved only through a separate reviewed process, adversarial/holdout tests, and versioned acceptance protocol. Require explicit human authorization for changes to privileged controls, destructive operations, production environment, or expensive execution. No unbounded self-modifying loop.

---

# 15. State-of-the-art process for every capability

The instruction “state of the art only” must be operationalized. It does not authorize unsupported claims or infinite scope.

Before a milestone starts:

1. Identify the exact task, compute envelope, data conditions, metrics, and failure costs.
2. Search current primary papers, official implementations, surveys, and credible benchmarks where browsing/research skills are available. Record access date and version. If browsing is unavailable, state it and do not make a novelty claim.
3. Identify practical baselines, current strong methods, evaluation pitfalls, and failure modes.
4. Select the strongest method that can be implemented correctly under the Mojo-only/no-third-party policy and the actual compute budget. State what cannot be reproduced because of dependency, data, model, or hardware limits.
5. Include a clear “why this method” decision and a rejected-alternative note.
6. Define baselines, ablations, seeds/folds, holdout policy, compute budget, and a minimum success criterion before running experiments.
7. Implement, benchmark, test, and publish machine-readable evidence.
8. Compare outcomes, not marketing labels. If the result is behind a known method, report honestly and identify the cause or unresolved uncertainty.

Record sources, method, exact code/config/data versions, metric definitions, and limitations in `STATE_OF_THE_ART_REGISTER.md` and per-capability research notes.

Relevant starting points for the agent's research—not an exhaustive survey and not a substitute for checking versions—include:

- Modular 26.7 announcement / MAX release notes: https://www.modular.com/blog/26-7 and https://max.modular.com/releases/v26.7/
- Modular platform source overview and component boundaries: https://github.com/modular/modular
- Official Mojo/MAX GPU examples: https://github.com/modular/modular/tree/main/max/examples/gpu-functions
- Official Modular agent skills: https://github.com/modular/skills
- AlphaEvolve, evolutionary algorithm discovery with automated evaluators: https://deepmind.google/blog/alphaevolve-a-gemini-powered-coding-agent-for-designing-advanced-algorithms/
- The AI Scientist-v2, agentic scientific discovery and experiment management: https://arxiv.org/abs/2504.08066
- Automated ML survey (2025/2026 publication): https://link.springer.com/article/10.1007/s10462-025-11397-2
- Neural operator comparative review (2025): https://www.sciencedirect.com/science/article/pii/S0925231225011907
- Scientific foundation model survey: https://pubmed.ncbi.nlm.nih.gov/41547123/

Do not copy competitors' code or present an integration of known methods as automatically novel. The defensible contribution may be the Mojo-native unified engineering substrate, the reciprocal coupling, a new evaluation protocol, or demonstrated empirical gains—but each claim requires separate evidence.

---

# 16. All project keywords and their required meaning

Use this as the project taxonomy and implementation inventory. Each term must have a precise definition, support status, evidence, and milestone. These names do not automatically denote standardized academic categories; treat project-defined umbrellas honestly.

## AutoAI family

- **AutoAI:** umbrella for systems that automate well-defined parts of the AI lifecycle. It must not imply all subfamilies are implemented.
- **AutoML:** tabular data, preprocessing, candidate models, validation, search, selection, reports; first AutoAI capability and M02.
- **AutoDL:** deep-learning architecture/training/configuration experiments over real trainable models.
- **AutoRL:** automated RL algorithm/environment/policy and hyperparameter experiments with safe evaluation.
- **AutoLLM:** local model configuration, prompt/evaluation, inference comparison, and training/adaptation only where actually supported.
- **AutoGenAI:** generation candidates and explicit evaluation/constraints; generated text/code is not self-validating evidence.
- **AutoTransformers:** automated search/optimization of transformer architecture/training/inference choices, clearly distinct from SciTransformers research tasks.
- **HPO:** explicit search over validated parameters with proper outcome feedback.
- **NAS:** actual search over structures that differ in computational graph, not only hyperparameters.
- **MLOps/LLMOps:** lifecycle, records, reproduction, monitoring/operations where applicable; implement CLI equivalents without a web dashboard.

## SciAI family

- **SciAI:** umbrella for AI methods used in scientific computing/discovery with domain-appropriate validation.
- **SINN:** Science-Informed Neural Networks, HyperForge's proposed umbrella. Build from a defined PDE/domain benchmark, scientific constraints, differentiated model, reference solver, and out-of-sample validation.
- **SciTransformers:** transformer architectures for scientifically structured sequences/fields with domain representations and rigorous generalization tests.
- **SciML:** scientific ML including forward/inverse problems, parameter identification, data assimilation, hybrid models, operators, and scientific constraints.
- **SciDL:** deep learning for scientific datasets/representations with physical/numerical baselines.
- **SciRL:** learning-based policies for bounded scientific decision/control and experimental design.
- **SciLLM:** model-assisted scientific workflows with provenance and verification.
- **SciGenAI:** generation of scientific candidates under formal/domain constraints and tested validators.
- **Scientific Transformers:** generic term in prose; map it to the defined SciTransformers scope.
- **Neural operators:** learn mappings between function spaces/PDE parameter families; distinguish them from a pointwise PINN.
- **PINNs:** specific physics-informed neural-network family; use this term only when the model formulation fits.
- **Uncertainty quantification:** measured/estimated uncertainty with stated assumptions; do not invent confidence values.
- **Differentiable simulation:** a simulator whose relevant computational path supports verified gradients; not just a numerical simulator.

## Intelligence and discovery infrastructure

- **Scientific Looper:** real experiment state machine from hypothesis through evidence and decision.
- **Agentic swarm:** specialized, bounded actors coordinated by tasks, contracts, and verification—not merely multiple prompts.
- **World models:** models that predict environment/system transitions and are evaluated against observations or a validated simulator.
- **Meta-Discovery:** learns search/experiment allocation and method selection from results.
- **Reciprocal Meta-Discovery:** couples AI discovery and computing discovery and tests whether the coupling improves results under fair budgets.
- **DiscoveryGenome:** typed joint candidate across model, algorithm, software, runtime, compute, and experiment protocol where supported.
- **Causal Discovery Graph:** provenance graph distinguishing correlation, hypothesis, controlled intervention, and evidence-backed conclusion.
- **Adaptive Experiment Economy:** transparent resource-allocation policy using uncertainty, improvement, cost, and relevance.
- **Discovery Certificate:** reproducible evidence package for a claim, including artifacts, configuration, benchmark, verifier, and limitations.
- **RSI / recursive self-improvement:** guarded isolated propose-test-compare-accept/rollback loop. Do not let candidates alter their own acceptance authority.

## Systems and long-horizon computing

- **HPC:** performance, parallelism, memory, CPU/GPU and distributed systems where supported.
- **Hardware-aware optimization:** candidate evaluation uses real device limits and measured performance.
- **Computers discovering computers:** software/kernel/algorithm/architecture configuration search; hardware simulation/physical design only when explicitly implemented.
- **HyperComputers:** long-horizon ambition for AI-assisted co-design of algorithms, compilers, kernels, memory, interconnects, architectures, materials and manufacturing. Do not present as an existing product capability without evidence.
- **Quantum computing:** only a separate, justified research track where there is a defined quantum formulation and plausible measured/simulated advantage; do not force it into every workflow.

---

# 17. Milestone expansion after the three anchors

After M02 AutoML, M03 SINN, and M04 SciTransformers are verified, continue in a dependency-aware sequence such as:

- M05 AutoDL;
- M06 AutoRL;
- M07 AutoTransformers;
- M08 AutoLLM through supported local MAX boundaries;
- M09 AutoGenAI;
- M10 SciML extensions / operator learning;
- M11 SciDL;
- M12 SciRL;
- M13 SciLLM;
- M14 SciGenAI;
- M15 local Scientific Looper and bounded specialist swarm;
- M16 MAX/GPU kernel catalogue and reproducible performance infrastructure;
- M17 DiscoveryGenome and systems-side candidate search;
- M18 Meta-Discovery experiment economy and causal evidence graph;
- M19 reciprocal joint AI×compute discovery benchmark;
- M20 bounded RSI and evaluator hardening;
- M21 system-wide hardening, documentation, release packaging, and comprehensive verification.

Adjust this order only for a documented dependency or a materially better evidence-driven plan. Update the roadmap with a reason whenever order changes. A milestone name alone is not progress. Keep a clear status for every AutoAI and SciAI keyword; incomplete items must remain partial/planned, never silently disappear from the matrix.

---

# 18. Release engineering, security, and reliability

- Keep the workspace free of secrets and credentials. Never print environment secret values or store them in experiment records.
- Validate all user input and paths; prevent path traversal and accidental writes outside the chosen workspace.
- Use resource limits for CSV size, rows/columns, model parameters, trial count, wall time, memory, generated artifacts, and recursive depth.
- Treat dataset/model artifacts and model-generated candidates as untrusted inputs.
- Candidate code must never be compiled/executed from an untrusted path without isolated, bounded, explicitly authorized execution. Prefer parameter/config candidates over arbitrary code generation initially.
- Record compiler/runtime versions, device and driver versions, config, seeds, data fingerprint, code revision, and commands for every benchmark.
- Handle Ctrl-C by persisting a terminal/interrupted status and any safe checkpoint; never mark interrupted runs succeeded.
- Test crash recovery and damaged files. Keep writes atomic where supported. Do not claim a transaction where none exists.
- Make clean checkout reproducible from documented commands. Pin the toolchain and verify CI uses the same version family.
- Keep any licensing notes for MAX, model artifacts, benchmark datasets, and user-supplied assets. Do not automatically download checkpoints or datasets.
- Avoid telemetry or outbound network calls in the core. Report precisely if any optional command contacts a local MAX server or other configured endpoint.

---

# 19. Definition of “complete” for a capability

A capability is **COMPLETE** only when all of the following apply:

1. There is real implementation in Mojo behind a real internal/CLI entry point.
2. Inputs, assumptions, supported cases, and failure behavior are specified.
3. The core behavior executes rather than returning placeholders.
4. Numeric/model outputs are tested against analytical/known/reference baselines appropriate to the task.
5. Tests cover valid, invalid, boundary, and failure cases.
6. Its artifacts and provenance are persisted and can be inspected/reloaded as promised.
7. Its required integration with the previous platform is working.
8. Relevant tests/builds pass in the documented environment.
9. A fair benchmark is run for every accuracy/performance improvement claim.
10. Scientific limitations, known weaknesses, and platform requirements are documented.
11. Independent review has tried to falsify the claimed behavior and found no release-blocking issue.
12. The CLI reflects the real status and exit code.
13. `CAPABILITY_MATRIX.md`, milestone doc, project state, and handoff agree with observed facts.

Use status labels: `PLANNED`, `IN_PROGRESS`, `IMPLEMENTED_NOT_VERIFIED`, `PARTIAL`, `BLOCKED`, `VERIFIED`, or `DEFERRED`. Never use percentages invented from impressions. If measuring aggregate completion, define the denominator and rules.

---

# 20. First session: execute, don't merely plan

Immediately do the following in this session:

1. Inspect all context/skill files and the actual current environment.
2. Verify Mojo/MAX versions and APIs with small probes. Pin the toolchain and create the native project skeleton.
3. Implement the real CLI entry point with `--help`, `--version`, and `doctor`.
4. Set up a real test command and minimal CI/build script using supported tooling.
5. Create the initial engineering docs and handoff.
6. Define M01 shared persistence and experiment contracts at minimum sufficient scope.
7. Implement and test the first real M01 vertical slice—not just structs.
8. Start M02 AutoML implementation as soon as the core allows it.
9. Continue through tests, independent review, repair, and evidence updates; do not stop after preparing a roadmap.
10. At session end, report exactly what was written, exact commands run, results observed, files modified, unresolved blockers, and the next concrete action.

Do not ask the user to restate the vision in this file. Do not ask permission for ordinary reversible coding decisions. If code execution is impossible because the environment lacks Mojo/MAX, complete safe repository/docs work, provide exact setup instructions, and do not claim anything compiled or tested.

---

# 21. Final operating instruction

Be ambitious about the research vision, exacting about the mathematics, disciplined about the language/runtime boundary, and uncompromising about evidence.

The system must not be a pile of disconnected modules. AutoML, SINN, SciTransformers, AutoAI, SciAI, the Scientific Looper, computing discovery, and Meta-Discovery must share experiment identity, provenance, contracts, budgets, metrics, and verification where scientifically appropriate.

But “interconnected” does not mean all modules depend on all others. Use clear boundaries, explicit interfaces, real shared infrastructure, and tested integration.

**The required order is: establish the Mojo environment and CLI; finish AutoML as the first AutoAI capability; finish SINN as the first SciAI capability; finish SciTransformers next; then expand the remaining families in the dependency-aware order; finally prove that AI discovery and computing discovery improve one another through a fair, reproducible benchmark.**

Do not merely describe the future system. Build it, run it, test it, challenge it, measure it, document it, and only then claim it works.
