# HyperForge Mojo + MAX — Fresh-Start Architecture Blueprint

**Purpose:** executable design guide for a clean start after the former repository has been deleted.

## 1. Decision summary

Build a CLI-only, Mojo-first HyperForge. There is no frontend, hosted web app, HTTP API server, database service, queue, workflow orchestrator, Python application, JavaScript application, or distributed microservice in the first release. Core experiment logic, optimization, state machines, local storage formats, reporting, and CLI behavior are first-party Mojo.

Use Modular MAX for what it actually supplies: accelerator programming and kernels, and optionally model serving through a clearly separated MAX service integration. MAX is not a generic runtime in which arbitrary CLI applications are automatically deployed. HyperForge should compile to a native executable with Mojo and use the supported MAX APIs for accelerator paths.

## 2. “No external dependencies” — achievable definition

Literal dependency-free software is not realistic for a compiled, hardware-accelerated program. The compiler/linker, OS ABI and system libraries, MAX components, optional GPU driver, device firmware, and model weights are external platform requirements.

Set the product requirement to:

- No third-party application libraries.
- No second application language.
- No external database, queue, orchestration service, UI, or required network service.
- Use only Mojo standard library and required MAX Mojo/accelerator packages inside HyperForge.
- Keep MAX model serving optional until an all-Mojo integration is proven. MAX's documented modeling pipelines and server include Python-based components; do not hide that fact.
- Document build-time vs runtime vs optional hardware/model requirements separately.

If “no Python anywhere, including model serving” is absolute, HyperForge's first release must not depend on `max serve`. Implement the native experiment/optimization engine first, then investigate a supported direct MAX API or the feasibility of a Mojo-owned model runtime. Do not start an LLM runtime rewrite as the first milestone.

## 3. Platform facts verified against official documentation on 2026-11-26

- Official Mojo docs identify version 1.2.0. The official MAX stable release page identifies MAX 26.7, released 2026-10-22.
- Mojo offers `mojo run` and `mojo build`; `mojo build` creates an executable. Binary portability still depends on target ABI, operating system, linked runtime/system libraries, and target hardware.
- MAX describes itself as a high-performance AI serving and modeling framework, with OpenAI-compatible serving for supported models, model APIs, and a single programming model for CPU/GPU/ASIC kernels.
- The Modular repository documents the Mojo compiler and stdlib, MAX Mojo GPU abstractions and kernels, but the MAX model pipelines and inference-server components are Python-based.
- Mojo standard library stability is selective and evolving; check API stability markers and release docs instead of assuming every API is stable.
- Mojo does not itself provide a complete distributed execution platform; its official FAQ describes MAX as the runtime/framework layer for graph-level transformations and heterogeneous compute.
- Current official installation/packaging docs still describe Conda/Pixi-based installation/distribution. A native Mojo package manager is still on the roadmap; no need to add community packages just because package management is not native.

Sources:
- https://mojolang.org/docs/cli/index.html
- https://mojolang.org/docs/cli/build/
- https://mojolang.org/docs/faq/
- https://mojolang.org/docs/requirements/
- https://mojolang.org/packages/
- https://docs.modular.com/max/
- https://docs.modular.com/max/get-started/
- https://github.com/modular/modular
- https://www.modular.com/blog/26-7

## 4. Minimal runtime model

The simplest supported product has three pieces:

1. `hyperforge` — compiled Mojo executable; owns CLI, experiment definitions, local deterministic scheduler, optimizer policies, experiment ledger, artifact paths, reports, verification, and benchmarks.
2. Mojo/MAX accelerator APIs — linked/imported where required to run custom kernels and supported hardware operations. Begin with CPU correctness and a standalone official-example-derived GPU kernel.
3. Optional model endpoint — a separate MAX Serve process only after the base core works. HyperForge can define a narrow `ModelBackend` contract and a local endpoint adapter, but the first release should not require model serving to run AutoML or Meta-Discovery smoke tests.

Do not claim the full CLI is “deployed inside MAX.” Prefer: “HyperForge is a native Mojo CLI that integrates MAX for accelerator execution and optionally uses MAX Serve for model inference.”

## 5. CLI command contract

The product is a CLI, not a terminal UI. Start with:

- `hyperforge --help`
- `hyperforge --version`
- `hyperforge doctor`
- `hyperforge init <directory>`
- `hyperforge automl run <config>`
- `hyperforge experiment list`
- `hyperforge experiment show <id>`
- `hyperforge experiment replay <id>`
- `hyperforge optimize run <config>`
- `hyperforge benchmark run <config>`
- `hyperforge verify <id>`
- `hyperforge report <id>`
- later: `hyperforge hardware probe`, `hyperforge discover run <config>`

Only register a command when it has real behavior. Keep stdout for results and stderr for errors where practical. Document stable exit codes. CLI parser is first-party Mojo unless there is an explicit, reviewed decision to add a package (default is no).

## 6. First source tree

```text
AGENTS.md
README.md
pixi.toml
src/main.mojo
src/hyperforge/cli/args.mojo
src/hyperforge/cli/commands.mojo
src/hyperforge/core/errors.mojo
src/hyperforge/core/config.mojo
src/hyperforge/core/state_machine.mojo
src/hyperforge/experiment/spec.mojo
src/hyperforge/experiment/candidate.mojo
src/hyperforge/experiment/trial.mojo
src/hyperforge/experiment/runner.mojo
src/hyperforge/automl/dataset.mojo
src/hyperforge/automl/split.mojo
src/hyperforge/automl/models.mojo
src/hyperforge/automl/metrics.mojo
src/hyperforge/automl/optimizer.mojo
src/hyperforge/evidence/event_log.mojo
src/hyperforge/evidence/artifact_store.mojo
src/hyperforge/evidence/certificate.mojo
src/hyperforge/discovery/genome.mojo
src/hyperforge/discovery/ai_loop.mojo
src/hyperforge/discovery/compute_loop.mojo
src/hyperforge/discovery/meta_loop.mojo
src/hyperforge/runtime/cpu.mojo
src/hyperforge/runtime/max_adapter.mojo
tests/
benchmarks/
docs/engineering/
```

This is a target layout, not a demand to generate all files as empty scaffolds. Start with a small vertical slice and split modules as needed.

## 7. First 7 milestones

### M00 — Environment truth

Check installed versions, OS, CPU target, MAX version, GPU visibility, linker and available official commands. Pin stable versions only after confirming the exact package names and current resolver result. Save command output and versions to `docs/engineering/TEST_RESULTS.md`.

### M01 — Native CLI

Build a Mojo executable with `--help`, `--version`, `doctor`. Add malformed-argument tests, clear errors, stable exit codes, and no network dependency. `doctor` must distinguish “not available” from “not tested.”

### M02 — Experiment core

Implement experiment/trial types, state transitions, candidate IDs, objective/metric records, a small deterministic pseudo-random/search primitive if needed, and native test fixtures. Reject invalid state changes.

### M03 — Native AutoML

Implement one CSV input path, one transparent regression task and baseline, at least two genuine candidate configurations, valid split discipline, metrics computed from predictions, durable experiment results, and report. Do not claim general AutoML from a single algorithm; describe exact scope.

### M04 — Adaptivity and evidence

Use actual observations to inform the next candidate. Store exact config, data fingerprint, seed, toolchain, baseline, metrics, failures, and artifacts. Verify replay and add a test that fails if optimizer feedback is disabled.

### M05 — MAX kernel and inference capability probes

Compile/run a simple GPU kernel derived from official examples on detected hardware. Compare with CPU reference and benchmark fairly. Separately probe whether desired model can be served by the selected stable MAX build. Model serving is optional and not a blocker to core CLI functionality.

### M06 — Reciprocal discovery proof

Add a cross-layer candidate containing one AI choice and one computing/runtime choice. Compare fixed baseline, independent search, sequential search, and joint search with comparable budgets. Report quality, latency, memory, and experiment cost. Add the meta-loop only when the preceding loops are working.

### M07 — Expand into AutoAI/SciAI and controlled agentic improvement

AutoDL, AutoRL, AutoLLM, AutoGenAI, AutoTransformers, SciML/SciDL/SciRL/SciLLM/SciGenAI, SINN, scientific transformers, world models, RSI, HPC, and HyperComputers remain capabilities to implement and validate. Do not register a command for a capability that does not exist.

## 8. Reciprocally connected discovery design

A shared `DiscoveryGenome` represents an experiment candidate across layers:

- AI: model family, configuration, learning/inference strategy.
- Algorithm: mathematical routine and approximation choices.
- Software: implementation, kernel, data layout, precision, compiler-exposed options.
- Runtime: batch/parallel execution and scheduling options.
- Hardware: available device and measured capability constraints.
- Experiment: objective, constraints, fidelity, seed, and budget.

Three connected loops:

1. **AI-discovery:** searches for better supported AI candidates.
2. **Computing-discovery:** searches for better supported algorithms and execution configurations.
3. **Meta-discovery:** selects what to test next, which agent/search policy is useful, and how to allocate resources.

All loops share evidence but retain separate acceptance gates. Do not let candidates inspect or modify protected acceptance criteria. Every discovered improvement must be measured against a baseline and pass independent verification.

## 9. Evidence store

Start with a local project-owned append-oriented event log and separate artifact directory. Do not invent a complex storage engine unnecessarily. Use a versioned format and tests for truncated writes, corrupt records, unknown versions, invalid references, and duplicate IDs. Use checksums for artifacts. Make incomplete runs visible and replay behavior explicit.

Minimum result record: experiment ID, trial ID, run status, candidate genome/config, dataset fingerprint, source revision, compiler/MAX versions, seed, objective and metrics, baseline ID, run timing, resource measures, logs/artifact references, error details, verification result, decision rationale.

## 10. Benchmark protocol

Every benchmark captures hardware, OS, target architecture, Mojo/MAX versions, compilation settings, workload, data shape, precision, warm-up, measurement repetitions, aggregation, correctness result, and baseline. Report startup/compile separately from steady-state timings. Avoid performance claims without repeatable evidence and fair comparisons.

For reciprocal search compare:
- fixed AI + fixed compute;
- AI search only;
- compute search only;
- sequential AI then compute or vice versa;
- joint reciprocal search;
- joint search with the meta-policy ablated.

Keep budgets comparable and report failure counts. Do not tune on final holdouts.

## 11. Build and installation note

The official Mojo CLI documents `mojo build` as compiling a `.mojo` file into an executable. Official docs currently describe installation via supported package managers; Pixi/Conda is an environment/build-time tool, not a runtime dependency of the end-user CLI after packaged appropriately. However, binary dynamic-linking and MAX/device requirements must be tested per target OS/hardware.

Do not copy commands from old chat. Check current official docs first. Candidate stable versions at the document date: Mojo 1.2.0 and MAX 26.7. Confirm current availability and use pinned manifests. Never assume command names, package names, CLI parser APIs, JSON support, async runtime, or GPU API imports without compiling a minimal smoke test.

## 12. Definition of first usable release

- A native executable is produced reproducibly from Mojo sources.
- `--help`, `--version`, `doctor`, `init` work and are tested.
- One native regression experiment runs end-to-end on CPU from a documented data file.
- Baseline and at least two real candidates are evaluated; results are not hard-coded.
- Result records persist and can be displayed/replayed as specified.
- The optimizer gets real feedback from evaluated candidates.
- Failed runs are accurately recorded.
- Benchmarks include environment information.
- No frontend, external database, queue, Python app, or network service is required.
- MAX accelerator support is a separately tested capability, not assumed from compiling the CLI.

## 13. Project state documentation

Maintain `PROJECT_STATE.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `TEST_RESULTS.md`, `EXPERIMENT_PROTOCOL.md`, and `HANDOFF.md` under `docs/engineering/`. Include observed facts, command lines, exit codes, compiler versions, blocked items, and the next exact action. The project is new: all historical implementation metrics must be considered stale until reproduced.

## 14. Official sources

- Mojo CLI: https://mojolang.org/docs/cli/index.html
- Mojo build: https://mojolang.org/docs/cli/build/
- Mojo FAQ: https://mojolang.org/docs/faq/
- Mojo requirements: https://mojolang.org/docs/requirements/
- Mojo packages: https://mojolang.org/packages/
- Mojo packaging: https://mojolang.org/docs/tools/packaging/
- MAX overview: https://docs.modular.com/max/
- MAX quickstart: https://docs.modular.com/max/get-started/
- Modular 26.7: https://www.modular.com/blog/26-7
- Modular source repository overview: https://github.com/modular/modular
