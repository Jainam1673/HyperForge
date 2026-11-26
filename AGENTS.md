# HyperForge — Master Agent Instructions (Mojo-First Reset)

**Status:** authoritative starting directive for a completely fresh repository.
**Product interface:** one excellent command-line application; no frontend.
**Application language:** Mojo for all first-party application logic.
**AI/accelerator platform:** Modular MAX, integrated deliberately rather than treated as a generic host for arbitrary programs.
**Guiding thesis:** Reciprocal Meta-Discovery — AI discovers better AI, computing systems discover better computing systems, and a third loop discovers better ways to conduct and verify both kinds of discovery.

> This file defines intent and operating constraints. It does not prove that any capability has been implemented. Repository evidence always determines implementation status.

## 1. Non-negotiable mission

Build HyperForge from scratch as a native Mojo, CLI-first research and engineering system. Its initial deliverable is a small, compiled, testable CLI and a genuinely working AutoML experiment path. Grow it through complete vertical slices, then connect those capabilities through a shared experiment model and the Reciprocal Meta-Discovery Engine.

Do not create a web frontend, dashboard, SaaS shell, REST API server, database service, Temporal dependency, Python application, TypeScript application, or microservice architecture unless the owner explicitly changes this directive.

Do not reconstruct or assume the contents of the deleted repository. The project starts from an empty repository. No prior feature, metric, implementation, or test result should be claimed as current evidence.

## 2. What “pure Mojo” and “no external dependencies” mean

Apply these definitions strictly:

1. **First-party application code:** `.mojo` files only. Do not implement HyperForge application logic in Python, JavaScript/TypeScript, Rust, Go, or shell.
2. **No third-party application libraries:** use the Mojo standard library and the MAX Mojo/accelerator packages that are necessary for the explicitly supported MAX integration. Do not casually add community packages for CLI parsing, JSON, databases, analytics, optimization, workflow engines, or agent frameworks.
3. **No separate application services in the initial release:** no external database, queue, orchestration service, web frontend, or cloud dependency. Use local files, a versioned project-owned event/artifact format, and deterministic local execution initially.
4. **Toolchain is a build-time/platform dependency:** Mojo compiler, MAX package/runtime components, platform linker, operating system, and optional device drivers are unavoidable. Do not falsely advertise a binary as literally dependency-free.
5. **MAX distinction:** MAX is an AI modeling/serving and accelerator/runtime stack, not a generic promise that any arbitrary Mojo CLI app runs “inside MAX.” Compile HyperForge as a native Mojo executable; integrate the supported MAX Mojo accelerator APIs for kernels/hardware paths. Treat `max serve` as an optional, separate inference process only after the first core milestone, and document its actual runtime requirements.
6. **No Python in HyperForge does not mean no Python exists inside every upstream tool:** MAX’s documented model pipelines/serving components include Python-based pieces. Never conceal this. If zero Python in the entire runtime stack is a hard requirement, do not depend on Python-based MAX Serve for the initial release.
7. **Dependency policy:** every proposed non-standard dependency requires a written decision explaining why the standard library/MAX package is insufficient, its runtime cost, license, maintenance risk, and why a project-owned implementation would be worse. Default answer: no.

## 3. Current source-of-truth hierarchy

At the beginning of every session:

1. Read this `AGENTS.md`.
2. Read `docs/engineering/PROJECT_STATE.md` and `docs/engineering/HANDOFF.md` if they exist.
3. Inspect the actual directory tree, `git status`, current commit, `pixi.toml`, build files, compiler version, and MAX availability.
4. Read the current official Mojo/MAX documentation for any API that may have changed.
5. Compare documented status with the source and latest test evidence.

Truth hierarchy: observed execution and tests > current source/configuration > dated project-state records > design documents > historical discussion. Never rely on historical chat as proof that code exists.

## 4. Technical baseline and version discipline

At the time this directive was written, the current official stable documentation identified Mojo 1.2.0 and MAX 26.7 (released 2026-10-22). Treat these as candidate pins, not an assertion that they are installed on every target. Before fixing versions, check the official release pages and actual host compatibility. Prefer stable releases over nightly builds for baseline development. Nightly versions are permitted only in an isolated experiment branch/environment.

The agent must not invent Mojo or MAX APIs from memory. For every unfamiliar API:

- consult current official documentation and examples;
- identify whether the API is stable, experimental, or platform-specific;
- implement the smallest compiling spike first;
- record the compiler/runtime version and target hardware;
- keep the spike and test as evidence.

`mojo build` is an official route to compile a Mojo file to an executable. The exact workspace/test commands must be checked against the installed release before being put into automation. Do not presume `mojo test`, a native Mojo package manager, stable async, or a distributed runtime exists merely because a design would benefit from it.

## 5. Product principles

- **CLI first:** terminal UX is the product. Commands should be discoverable, composable, scriptable, fast to start, and precise in their errors.
- **Native core first:** implement deterministic experiments and correct algorithms before adding model agents.
- **One complete capability at a time:** no broad parallel implementation across dozens of unfinished modules.
- **Measured optimization:** do not use “optimized” as a label without a benchmark and fair baseline.
- **Evidence over narrative:** a candidate is not a discovery until tested against an explicit baseline under a documented protocol.
- **Integrated but modular:** capabilities share IDs, contracts, experiment provenance, resource budgets, and evidence. They must not become one tangled dependency graph.
- **Over-engineered for rigor, not needless complexity:** prefer explicit invariants, reproducibility, recovery, benchmarks, static contracts, and clear abstractions; reject abstractions that do not solve a demonstrated problem.
- **Offline-capable core:** core CLI and deterministic experiment flow should work without internet, model downloads, accounts, or external services.
- **No fabricated capability:** never describe a planned module as implemented.

## 6. Product surface: CLI only

Create one executable named `hyperforge`. Do not create a frontend, dashboard, web server, web API, or interactive TUI in the initial architecture. Use standard terminal output and conventional exit codes. Support `--help` and `--version` and ensure errors tell the user what to do next.

Planned command families (implement incrementally, never scaffold all as fake commands):

- `hyperforge doctor` — inspect executable/build metadata, Mojo/MAX versions where available, host architecture, available targets/devices, writable data directory, and supported capabilities. Report unknowns honestly.
- `hyperforge init <path>` — initialize a project workspace with a versioned configuration and local directories.
- `hyperforge automl run <config>` — run a genuine supported local experiment.
- `hyperforge experiment show <id>` — inspect a stored experiment.
- `hyperforge experiment list` — list local experiment records.
- `hyperforge experiment replay <id>` — rerun an experiment from recorded configuration when required inputs remain available.
- `hyperforge optimize run <config>` — execute an actual candidate propose/evaluate/feedback loop.
- `hyperforge discover run <config>` — later entry point for joint AI/computing/meta search.
- `hyperforge benchmark run <config>` — execute a controlled benchmark with warm-up, repeated measurements, and environment capture.
- `hyperforge verify <id>` — independently verify a result against its acceptance protocol.
- `hyperforge report <id>` — render a terminal and/or local text report using project-owned formats.
- `hyperforge hardware probe` — list capabilities that can actually be detected; never infer capability from a device name alone.

These names are a roadmap. Commands must not be registered until real behavior exists. Every implemented command needs a help entry, success example, failure example, exit-code behavior, and automated tests.

## 7. Architecture: native CLI and local research engine

Use a small modular layout, adapted only after the first compiling spike:

```text
AGENTS.md
README.md
pixi.toml
src/
  main.mojo
  cli/
    args.mojo
    commands.mojo
    output.mojo
  core/
    errors.mojo
    identifiers.mojo
    config.mojo
    state_machine.mojo
  experiment/
    spec.mojo
    candidate.mojo
    trial.mojo
    runner.mojo
    metrics.mojo
  automl/
    dataset.mojo
    split.mojo
    preprocess.mojo
    models.mojo
    objective.mojo
    optimizer.mojo
  discovery/
    genome.mojo
    ai_loop.mojo
    compute_loop.mojo
    meta_loop.mojo
    budget.mojo
    pareto.mojo
  evidence/
    event_log.mojo
    artifact_store.mojo
    provenance.mojo
    certificate.mojo
  runtime/
    scheduler.mojo
    cpu.mojo
    max_adapter.mojo
  gpu/
    kernels.mojo
    benchmarks.mojo
  verification/
    acceptance.mojo
    replay.mojo
    regression.mojo
tests/
benchmarks/
docs/engineering/
```

Do not make empty files just to mirror this tree. Introduce modules only when a capability needs them. Keep public contracts small and explicit.

## 8. Initial persistent state and storage

The first release must not require PostgreSQL, SQLite, Supabase, Redis, Temporal, or another local/remote service. Implement a bounded, project-owned file-based store and artifact directory. Version every serialized record and define corruption detection, incomplete-write handling, atomic replacement where supported, and migration/version rules before relying on the store for experiment history.

Start with the simplest robust format the stable standard library can support without an external package. Do not invent a complex serialization framework prematurely. A record format must have:

- explicit version and record type;
- stable experiment/trial IDs;
- schema validation;
- safe string escaping or unambiguous field encoding;
- monotonic event sequence or equivalent ordering;
- integrity check where practical;
- write/flush/error behavior;
- forward-compatibility policy;
- test fixtures for corrupt, truncated, unknown-version, and duplicate records.

Keep experiment state and large artifacts separate. The evidence record should point to artifacts by stable relative paths and checksums. Do not embed unbounded arrays or model weights into the event log.

## 9. First real milestone: native AutoML CLI

Do not begin with autonomous agents or self-modifying code. First prove that the native Mojo program can run a complete, reproducible experiment.

M00 — Toolchain and CLI shell:
- Pin a stable Mojo/MAX environment after confirming availability.
- Build a minimal `hyperforge --help`, `hyperforge --version`, and `hyperforge doctor` executable.
- Validate paths, exit codes, diagnostics, output stability, and build reproducibility.
- Avoid external packages.

M01 — Experiment core:
- Strongly structured experiment/config/trial/metric records using supported Mojo features.
- Deterministic random seed handling if supported by the chosen algorithm implementation.
- Explicit trial state machine with invalid transitions rejected.
- Baseline test fixtures and numerical-correctness tests.

M02 — Native regression AutoML slice:
- Load one documented simple CSV dataset using first-party Mojo code.
- Validate schema, target, missing values, types, bounds, and data split.
- Start with a small, clearly specified model/algorithm that can genuinely be implemented and tested in Mojo.
- Execute a baseline and at least two different candidate configurations.
- Evaluate without train/validation/test leakage.
- Write durable trial records and a report.
- Ensure metrics come from model computation, never literals or mock results.

M03 — Adaptive optimization:
- Propose one candidate, run it, measure it, persist it, feed its result back to the search policy, then propose the next candidate.
- Add a regression test that fails if feedback is disconnected.
- Handle invalid candidates and failed trials explicitly.
- Compare the optimizer against a random-search or fixed baseline under the same budget where appropriate.

M04 — Evidence and replay:
- Capture source revision, config, seed, dataset fingerprint, compiler/MAX versions, environment, baseline, metrics, trial log, and artifact hashes.
- Replay the experiment when required inputs are available.
- Distinguish successful execution from independent reproduction and from scientific validity.

M05 — MAX accelerator proof:
- Build a tiny official-example-derived Mojo/MAX kernel for a supported target.
- Test it against a trusted CPU reference and edge cases.
- Measure correctness, launch overhead, latency, throughput, and memory where available.
- Only move the AutoML execution to accelerator-backed computation after the smaller kernel gate passes.

M06 — Reciprocal Meta-Discovery proof:
- Define the first `DiscoveryGenome` that combines one AI-side choice and one compute-side choice.
- Compare fixed, independent, sequential, and joint optimization under a declared equal budget.
- Measure task quality, latency, memory, and experimental cost.
- Add the meta-loop only to choose the next experiment/search strategy based on evidence.
- Publish ablations, including negative results.

M07+ — Expand incrementally into AutoDL, AutoRL, AutoLLM, AutoGenAI, AutoTransformers, SciAI, Scientific Looper, agents, world models, controlled RSI, and broader HPC/hardware co-design only after their prerequisites and validation methods exist.

## 10. Reciprocal Meta-Discovery architecture

The long-term design has three loops sharing a common evidence model:

### Loop A — AI discovers AI
Search over supported model families, architecture/configuration choices, objective functions, training recipes, inference policies, and agent/search strategies. Only implement variables whose execution path exists.

### Loop B — Computing systems discover computing systems
Search over supported algorithms, memory layouts, kernels, CPU/GPU targets, precision settings, batching, parallelism, compiler-visible choices, and runtime scheduling. Keep hardware claims bounded by what the toolchain actually exposes.

### Loop C — Meta-discovery learns how to discover
Select hypotheses, fidelity levels, trial budgets, specialist roles, experiment order, and verification strength. Optimize verified improvement and information gained per unit cost rather than raw candidate count.

### Coupling mechanism
A shared `DiscoveryGenome` describes the joint AI/algorithm/software/runtime/hardware candidate. A shared evidence ledger records the intervention, exact candidate, environment, outcome, costs, uncertainty, and reason for acceptance/rejection. Cross-loop information can constrain or prioritize later search, but cannot bypass experiment validation.

### Fairness and validity
Use comparable budgets, declared objective functions, fixed baselines, held-out workloads, multiple seeds where appropriate, and ablations. Compare joint search to fixed, independent, and sequential search. Do not claim novelty until a literature review and benchmark show what is new and useful.

## 11. Specialist agents and workflow

Where actual subagents are available, assign explicit roles. If they are not available, perform these roles in separate sequential passes; never claim that nonexistent agents ran.

- Architect/orchestrator: owns task sequencing, shared contracts, and milestone gates.
- Capability owner: implements one complete vertical slice end to end.
- Independent verifier: writes adversarial tests and reproduces behavior.
- Algorithm/science reviewer: validates mathematical assumptions and experimental design.
- Performance reviewer: profiles actual code and checks fair baseline comparisons.
- Integration reviewer: checks that modules work together and no interface was left mocked.
- Security/reliability reviewer: checks resource bounds, failure behavior, safe paths, and recovery.

For a major milestone: discover -> scope -> define contracts -> implement -> test -> independently review -> repair -> integrate -> regression-test -> document -> accept/reject/defer. A single capability has one accountable owner. Do not allow agents to conflict-edit shared interfaces without an orchestrator decision.

## 12. CLI quality requirements

- Deterministic command syntax and meaningful `--help`.
- Stable exit-code conventions documented in README.
- Errors printed to stderr, normal results to stdout where practical.
- No success message before the operation actually succeeds.
- Clear progress for long work; allow a quiet/scriptable mode when feasible.
- No color-only meaning; honor redirected output.
- Avoid dumping enormous logs by default; provide paths to detailed logs.
- Validate all input paths and output roots; prevent path traversal.
- Do not execute generated code automatically in the first release.
- Use bounded resource settings and cancellation semantics once long-running work is introduced.
- Offer deterministic, machine-readable output only when its encoding is properly implemented and tested; do not add an external serializer just for convenience.

## 13. Security, reliability, and self-improvement controls

- No unrestricted code execution by generated candidates.
- No self-modification of acceptance rules, protected baselines, or verification code.
- Candidate execution is isolated by process/workspace/resource boundaries that are genuinely implemented; don't claim sandboxing if it is only a directory convention.
- Use explicit resource ceilings for time, memory, trial count, file size, and output size where supported.
- Preserve failures and partial state for diagnosis; never turn a failed run into success.
- Every accepted change has review evidence and a rollback/recovery path.
- Keep a protected evaluation suite not available to candidate search logic where practicable.
- Separate observed data from hypotheses and causal claims.

## 14. Benchmark discipline

Every performance claim must include hardware/device, OS, Mojo/MAX versions, compiler flags, workload, data shape, precision, warm-up policy, repetition count, aggregation method, correctness check, and the baseline implementation. Separate compile/startup time from steady-state kernel/runtime time. Include failed runs and resource usage. Never compare a GPU result against an unfair CPU baseline or tune on the test set.

## 15. Documentation that survives context loss

Create these files as soon as they are useful, and update them after meaningful work:

- `docs/engineering/PROJECT_STATE.md` — verified truth only.
- `docs/engineering/ARCHITECTURE.md` — architecture as implemented, not imagined.
- `docs/engineering/MILESTONES.md` — acceptance criteria and evidence.
- `docs/engineering/DECISIONS.md` — dependency and architecture decisions with reasons.
- `docs/engineering/TEST_RESULTS.md` — exact commands, versions, outcomes, and limits.
- `docs/engineering/EXPERIMENT_PROTOCOL.md` — datasets, metrics, baselines, seeds, and reporting.
- `docs/engineering/HANDOFF.md` — next exact action, current state, blockers, and commands to resume.

Do not duplicate this master directive in every file. Link to it as the invariant source of project intent. Never fill a document with aspirations merely to make the project look substantial.

## 16. Completion gate

A milestone is complete only when its actual behavior works, tests detect plausible defects, output is persisted/retrievable when promised, relevant integration and regression checks pass, the independent reviewer has examined it, documentation matches the implementation, and limitations are explicit. “Compiles,” “module exists,” “agent claims success,” or “demo uses mock data” are not completion criteria.

## 17. First session instructions

1. Confirm repository state is genuinely fresh and inspect toolchain availability.
2. Check current official stable Mojo/MAX releases and hardware requirements; do not trust stale commands.
3. Create only the minimal project skeleton and engineering state files.
4. Build and run the smallest native Mojo CLI executable.
5. Add tested `--help`, `--version`, and `doctor` behavior.
6. Make the toolchain and build reproducible with a pinned environment manifest.
7. Do not begin AutoML until the CLI/build gate passes.
8. Then build the smallest complete native AutoML experiment.
9. Update `HANDOFF.md` with the exact next action and observed results.

**Final directive:** HyperForge is a single, excellent Mojo CLI and native research engine. MAX provides the supported accelerator/model-inference capabilities where actually available. The three discovery loops must exchange evidence and constraints, not merely share names. Build one real vertical slice at a time, measure it, independently verify it, and only then expand.
