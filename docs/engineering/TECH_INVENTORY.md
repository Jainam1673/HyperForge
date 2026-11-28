# HyperForge technology inventory — every name and its full scope

This is the **complete taxonomy** of the project, taken from the master prompt
`§16 All project keywords and their required meaning`, plus the engineering
subsystems that exist in source. For each name it records:

- **What it is** (project-defined meaning, not an assumed academic category);
- **Everything in it** — the full scope of sub-capabilities that the name can
  legitimately cover;
- **Now** — verified repository status;
- **Boundary** — what cannot honestly be claimed at this time.

Statuses: ✅ implemented (declared bounded slice, tested) · ◐ partial ·
⛔ blocked (no execution path, no command registered) · ○ not implemented.

This document is a **scope map, not a claim of implementation**. Only items
marked ✅ are backed by passing tests. Every ○/⛔ item remains visible so it
cannot silently disappear.

---

## 0. Platform and substrate

| Name | What it is | Everything in it | Now | Boundary |
|---|---|---|---|---|
| **HyperForge** | The product: one native CLI research engine | CLI, evidence store, AutoAI, SciAI, discovery loops, RSI, GPU catalogue, interconnection | ✅ M00–M21 | No frontend/server/database/service |
| **Mojo** | First-party implementation language | All application logic, algorithms, CLI, evidence, autodiff, tests | ✅ ~11.9k LOC | No Python/TS/Rust application code |
| **MAX** | Accelerator/model platform dependency | Documented Mojo accelerator APIs; optional model inference | ◐ GPU kernels used | Model inference ⛔ `BLOCKED_BY_MAX_INTERFACE` |
| **HFJ1 journal** | Versioned append-only evidence format | Record types, escaping, checksums, monotonic sequence, tail recovery, corruption rejection | ✅ | No atomic rename; FNV-1a is integrity, not security |
| **Autodiff tape** | Reverse-mode scalar gradient substrate | add/sub/mul/scale/tanh/exp/log/sqrt/divide/relu, backward, parameter accumulation | ✅ | Scalar nodes only; no fusion, no GPU gradients |
| **Hardening** | Input/ceiling enforcement | Path validation, CSV byte/row/column ceilings, doctor probe | ✅ | No symlink resolution |
| **CLI** | Product surface | help/version/doctor/init/experiment/report + all capability commands | ✅ 22 suites | No TUI, no color-only meaning |

---

## 1. AutoAI family

### AutoAI ✅ (umbrella)
Everything in it: every subfamily below — AutoML, AutoDL, AutoRL, AutoLLM,
AutoGenAI, AutoTransformers, plus HPO, NAS, and MLOps/LLMOps lifecycle
support. It must never imply all subfamilies are complete.

### AutoML ✅ (M22 full declared inventory)
**Everything in it:**

- **Data layer** — numeric CSV ✅, classification targets ✅, train-fitted
  preprocessing ✅, seeded splits ✅, k-fold CV ✅; planned: categorical
  encoding, schema inference, grouped/time-series splits, leakage detection.
- **Task families** — regression ✅, classification ✅; planned: ranking,
  clustering as a scored task, time-series forecasting.
- **Model families (18 kinds implemented in M22)**
  - Linear/regularized: baseline ✅, linear GD ✅, ridge ✅, Lasso ✅,
    Elastic Net ✅, Huber ✅, logistic regression ✅; planned: Bayesian ridge,
    linear SVM, LDA.
  - Non-linear/basis: kNN ✅, polynomial degree-2 ✅, PCA projection ✅;
    planned: kernel ridge (RBF), SVR, Gaussian process.
  - Trees/ensembles: decision tree reg/cls ✅, random forest reg/cls ✅,
    gradient boosting reg ✅; planned: ExtraTrees, AdaBoost, bagging, stacking.
  - Probabilistic: Gaussian naive Bayes ✅; planned Bernoulli NB, GMM.
  - Unsupervised: k-means ✅; planned DBSCAN, hierarchical, autoencoder.
  - Neural (planned): MLP, tabular transformer.
- **Search** — random ✅, adaptive with feedback ✅, grid ✅; planned Bayesian,
  TPE, evolutionary, multi-fidelity.
- **Metrics** — MAE/MSE/RMSE/R²/MAPE ✅, accuracy/precision/recall/F1/confusion
  matrix/log loss/ROC-AUC ✅; planned silhouette, NDCG.
- **Lifecycle** — inspect/run/full/show/replay/compare ✅; planned leaderboard,
  seed sweeps, paired significance tests.

Remaining planned items are a future expansion **of this same tech**, not a new
technology or a thin slice. See `AUTOML_FULL.md`.

**Boundary:** "all algorithms" is unbounded; the declared first wave is in
`EXPANSION_ROADMAP.md` and grows only as slices are verified.

### AutoDL ✅ (bounded MLP search)
Everything in it: depth/width/activation/initialization/optimizer/LR/
regularization/batch-size search over real trainable models; early stopping; checkpoint
recovery; repeated seeds; CPU execution; NAS-style structural variants
(planned). Held-out evaluation is already real.

### AutoRL ✅ (bounded tabular slice)
Everything in it: deterministic environments, safe action constraints,
Q-learning/policy evaluation, held-out episodes, replay/verification; planned
value/policy iteration, SARSA, DQN, REINFORCE, A2C/PPO, model-based control,
regret and sample-efficiency metrics.

### AutoLLM ◐ — full lifecycle required by owner
**Everything in it (end-to-end):**

- **PreTrain** — corpus ingestion, tokenizer/vocab construction, dedup/
  filtering, data provenance, tiny first-party transformer, next-token
  objective, optimizer, checkpoint, config + data fingerprint.
- **MidTrain** — resume from checkpoint, continued training on a second
  declared corpus, domain adaptation, replay of prior data, LR schedule reset,
  invalid-transition rejection.
- **PostTrain** — supervised instruction pairs, preference pairs, bounded
  reward/preference scoring, SFT-style fine-tuning, distillation, evaluation
  suites; frontier-scale RLHF is out of scope.
- **Infer** — autoregressive decoding (greedy/temperature/top-k/beam),
  context window, response recording, offline scoring, lineage to exact
  checkpoint chain; MAX-served inference remains ⛔ and is reported separately.
- **Ops** — model/artifact registry, per-stage status, versioned evaluation
  suites, CLI-level rollout comparison, provenance.

**Feasibility:** the autodiff tape already trains a tiny transformer in
SciTransformers, so a **tiny first-party** PreTrain→Infer path with genuine
gradients is achievable on CPU. It must be labeled as tiny and first-party —
not a MAX-served frontier LLM.

### AutoGenAI ⛔
Everything in it: text/code/config/hypothesis candidate generation, explicit
constraint parsers, validators, novelty screening, diversity metrics,
downstream success evaluation. Generated output is never self-validating
evidence. Blocked on a verified inference boundary.

### AutoTransformers ✅ (config search)
Everything in it: layers, heads, d_model, FFN width, positional encoding,
attention variants, normalization, activation, optimizer/schedule, inference
latency/memory choices. Distinct from SciTransformers research tasks.

### HPO ◐
Everything in it: explicit parameter search with validated feedback — random,
grid, Bayesian, TPE, multi-fidelity, early stopping, seed sweeps. Exists
inside AutoML/AutoDL; no standalone named capability yet.

### NAS ◐
Everything in it: search over structures that change the computational graph
— cell-based, layer-skip, operator selection, differentiable/evolutionary
search. Partially exercised by AutoDL/AutoTransformers; no generic engine.

### MLOps / LLMOps ◐
Everything in it: lifecycle records, reproduction, checkpoints, artifact
registry, evaluation suites, CLI-level monitoring/rollout comparison. CLI
equivalents exist; no web dashboard, no service, no remote monitoring.

---

## 2. SciAI family

### SciAI ✅ (umbrella)
Everything in it: SINN, SciTransformers, SciML, SciDL, SciRL, SciLLM,
SciGenAI, neural operators, PINNs, UQ, differentiable simulation.

### SINN ✅ (project-defined Science-Informed Neural Networks)
Everything in it: PDE/domain benchmarks (Poisson ✅, heat/wave/Burgers/
Navier–Stokes planned), physical constraints (strong/weak/boundary),
collocation strategies, differentiated model, conventional reference solver,
out-of-sample validation, loss-imbalance/stiffness/spectral-bias failure
diagnosis. It is an umbrella, not a claim of a standardized new method.

### SciTransformers ✅
Everything in it: scientific sequence/field representations, coordinate
encoding, multi-head attention, residual FFN, checkpointing, prediction,
rigorous generalization tests. The current model is tiny (scalar tape).

### Scientific Transformers ✅
Project prose alias for SciTransformers — not a separate capability.

### SciML ✅
Everything in it: forward problems, inverse problems/parameter identification
(✅), data assimilation, hybrid physics+ML models, operator learning,
scientific constraints, reference-solver comparison.

### SciDL ✅
Everything in it: scientific datasets/representations, deep models with
physical/numerical baselines, failure analysis. Current MLP underperformed
linear/FD baselines — negative result retained.

### SciRL ✅
Everything in it: bounded decision/control policies, experimental design,
safe action constraints, explicit rewards, held-out environment conditions,
repeated seeds, evaluation separate from training. Current: PDE solver
resolution selection in a simulator.

### SciLLM ⛔
Everything in it: model-assisted scientific workflows with provenance and
verification — literature/candidate assistance, result interpretation,
experiment planning. Blocked on verified inference.

### SciGenAI ⛔
Everything in it: generation of equations, parameter sets, experiment designs,
code candidates, structured samples; domain parsers, dimensional checks,
simulators/reference solvers, validity filters, novelty screening. A generated
hypothesis is not a discovery until independently tested.

### Neural operators ○
Everything in it: parameter-to-solution mappings (DeepONet-like, Fourier/
operator-based), train/test separation over entire parameters or initial
conditions, inference-amortization vs solver cost. Must not be a label-only
operator.

### PINNs ◐
Everything in it: physics-informed loss formulations, boundary enforcement,
collocation, comparison against conventional solvers. Exercised through the
SINN formulation, not as a standalone named capability.

### Uncertainty quantification ○
Everything in it: measured/estimated uncertainty with stated assumptions —
ensembles, MC dropout, conformal prediction, calibrated intervals, bootstrap.
No confidence values are invented.

### Differentiable simulation ○
Everything in it: simulators whose relevant computational path supports
verified gradients; gradient checks against finite differences; adjoint vs
tape comparison. Existing simulators are not yet differentiable.

---

## 3. Intelligence and discovery infrastructure

### Scientific Looper ✅
Everything in it: hypothesis→evidence→decision state machine, validated and
idempotent transitions, resource budgets, artifact pointers, failure details,
replay from stored inputs, actor identity, monotonic sequence. Wall-clock
timestamps and parallel workers are not available in this Mojo release.

### Agentic research swarm ◐
Everything in it: bounded specialized actors, shared contracts, auditable
work, independent verification, deterministic local scheduler, task budgets/
timeouts/output schemas/terminal states. Currently sequential passes by one
agent — no parallel agents are claimed.

**Named roles** (all ◐, performed as passes, not distinct agents):
Research Planner · AutoML/SciAI specialist · Algorithm Engineer · Systems
Optimizer · Experiment Economist · Skeptic/Red Team · Reproducer · Integrator
· Orchestrator.

### World models ○
Everything in it: models predicting environment/system transitions, evaluated
against observations or a validated simulator, used for planning and counter-
factual rollout. No implementation.

### Meta-Discovery ◐
Everything in it: learn which experiments, proposal strategies, fidelity
levels, agent roles, and verification protocols yield the most verified value
per unit compute/time/cost. Current: transparent allocation policies and a
causal ledger; no learned policy yet.

### Reciprocal Meta-Discovery / co-discovery ◐
Everything in it: Loop A (AI discovers AI), Loop B (computing discovers
computing), Loop C (learns how to discover), joint genome, equal-budget
comparisons, ablations, negative results. Coupling stays a hypothesis until
ablations isolate it.

### DiscoveryGenome ◐
Everything in it: typed joint candidate across model, algorithm, software,
runtime, compute, and experiment-protocol genes; validation, canonical
config, stable hash, constraint-preserving mutation/crossover. v2 measures
compute/runtime genes; the AI gene is carried but unmeasured.

### Causal Discovery Graph ◐
Everything in it: nodes for hypotheses, runs, configs, datasets/workloads,
interventions, metrics, artifacts, failures, decisions; edges labeled
`observed` / `experimentally_supported` / `hypothesized`; controlled
interventions required before causal claims; correlation never promoted alone.

### Adaptive Experiment Economy ◐
Everything in it: transparent allocation by expected improvement, information
gain/uncertainty, cost, failure risk, and Pareto relevance; baseline policy,
random baseline, replayable sequences, multi-fidelity only when ordering and
correlation to full evaluation are checked. Current: 4 policies, no
multi-fidelity or confidence intervals.

### Discovery Certificate ○
Everything in it: reproducible evidence package for a claim — artifacts,
configuration, benchmark environment, verifier identity, limitations, source
revision, seed, data fingerprint. No packaged certificate yet.

### RSI (recursive self-improvement) ◐
Everything in it: protected baseline, written hypothesis, isolated candidate,
compile/unit/property/regression/benchmark tests, independent verifier,
threshold + holdout comparison, accept/reject/defer/rollback, immutable
evidence; **candidates cannot alter acceptance authority**. Current:
config-only, `--apply` gate, no code rewriting or runtime consumer.

---

## 4. Systems and long-horizon computing

### HPC ◐
Everything in it: performance measurement, parallelism/memory, CPU/GPU paths,
distributed execution, scheduling, compiler-visible choices. Current:
single-device kernels and medians only; no parallelism, memory measurement,
or distributed work.

### Hardware-aware optimization ◐
Everything in it: real device detection, measured latency/throughput, device
limits and precision, batching, memory layouts, launch configuration search.
Current: real detection + measured latency via `systems search`.

### Computers discovering computers ◐
Everything in it: search over algorithms, kernels, compiler/execution choices,
memory layouts, scheduling, parallelism, hardware-aware configs; hardware
simulation/physical design only when explicitly implemented. Current: kernel
and launch-config search only.

### AI discovering AI ✅ (within registered slices)
Everything in it: search over models, architectures, training choices,
algorithms, inference configurations. Exercised by AutoML/AutoDL/AutoRL/
AutoTransformers.

### HyperComputers ○
Everything in it: long-horizon AI-assisted co-design of algorithms, compilers,
kernels, memory, interconnects, architectures, materials, manufacturing. It is
an ambition, not an existing product capability.

### Quantum computing ○
Everything in it: a separate justified research track with a defined quantum
formulation, simulated or measured advantage. Not forced into any workflow.

---

## 5. Interconnection layer (planned, required by owner)

| Edge type | Meaning | Required for |
|---|---|---|
| `informs` | one capability's evidence seeds another's proposal | Loop A/B/C coupling |
| `constrains` | one result limits another's feasible space | genome validity, budgets |
| `verifies` | independent check of a claim | acceptance, replay |
| `reproduces` | rerun from recorded inputs | certificates |
| `supersedes` | new evidence replaces a prior decision | rollback, RSI |
| `ablates` | removes one factor to isolate a cause | promoting coupling past hypothesis |

Everything in it: typed nodes (capability, experiment, trial, artifact, claim,
verifier, decision), standard claim records (task, metric, budget, seed,
baseline, checksums, limitations), downstream consumption by discovery
proposals, meta allocation, verifier holdout selection, and RSI novelty
checks. It must not become shared mutable state, and no capability may write
another's protected records.

---

## Summary counts

- **Platform/substrate:** 7 names — 6 ✅, 1 ◐.
- **AutoAI:** 10 names — 5 ✅ (including the umbrella), 4 ◐, 1 ⛔.
- **SciAI:** 13 names — 7 ✅ (including the umbrella and alias), 1 ◐, 2 ⛔, 3 ○.
- **Discovery infrastructure:** 10 names — 1 ✅, 7 ◐, 2 ○; plus 9 agent roles ◐.
- **Systems/long-horizon:** 6 names — 1 ✅, 3 ◐, 2 ○.
- **Interconnection:** 6 edge types, 0 implemented.

Counts are by name, not by code volume; an umbrella ✅ does not imply every
subfamily is complete. `CAPABILITY_MATRIX.md` is the authoritative per-item
evidence and `EXPANSION_ROADMAP.md` is the ordered plan for ○/⛔ items.

The full, current per-item evidence is in `CAPABILITY_MATRIX.md`; the ordered
implementation plan for the ○/⛔ items is in `EXPANSION_ROADMAP.md`.
