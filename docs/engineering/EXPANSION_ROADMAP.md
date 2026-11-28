# Expansion roadmap — post-M21 scope (owner directive, 2026-11-28)

The owner expanded the project scope after M21:

1. **Every tech should eventually include as much of its algorithm space as is
   genuinely implementable** — e.g. AutoML should cover many algorithm
   families, not just four regression models.
2. **AutoLLM must be an end-to-end lifecycle**: PreTrain → MidTrain →
   PostTrain → Infer, with real execution at each stage.
3. **Everything must be interconnected** — capabilities exchange evidence and
   constraints, not just names.

These are requirements on the *direction*, not permission to fabricate. The
root `AGENTS.md` still governs: one complete vertical slice at a time, no
registered command without a real execution path, no claimed capability
without tested evidence. Each item below is therefore ordered into discrete
milestones with acceptance gates. An "implemented" label always means a
declared, bounded, tested scope — never the entire infinite algorithm space.

---

## A. AutoML — expand the algorithm space

### Already real (M02–M03)
- Regression: mean baseline, linear GD, ridge GD, kNN.
- Search: bounded random + adaptive with real feedback; validation/test split.

### Prerequisites before expanding
- CSV loader currently handles numeric targets only; classification targets
  and richer schemas must be added first with the same strict validation.
- A shared metric registry must be added so new model families report
  comparable held-out results.

### Concrete expansion inventory (first-party Mojo, no external libs)

| Family | Candidates |
|---|---|
| Linear / regularized | Lasso (L1), Elastic Net, Huber (robust), Bayesian-style ridge |
| Non-linear regression | polynomial basis regression, kernel ridge (linear/RBF), SVR-style epsilon loss |
| Tree ensembles | decision tree regressor/classifier, random forest, AdaBoost, gradient boosting |
| Classification | logistic regression, Gaussian naive Bayes, kNN classifier, linear SVM, tree classifiers |
| Clustering / structure | k-means, DBSCAN, PCA projection |
| Metrics | accuracy, precision/recall/F1, confusion matrix, log loss, ROC-AUC, MAE/RMSE/R² already present |

Each algorithm is introduced as one slice: implementation → unit tests with
known analytic answers → integration test through `automl run` → persisted
trials → documentation with its validity assumptions and failure modes.
"All algorithms" is not a finite target; the inventory above is the declared
first wave, and this table is extended only when a slice is actually verified.

---

## B. AutoLLM — real end-to-end lifecycle

### Feasibility finding
The installed Mojo `1.2.0` has a working reverse-mode scalar tape
(`autodiff/tape.mojo`) and the SciTransformers slice already trains a tiny
attention model with it. A **tiny first-party language model** with genuine
gradients is therefore feasible on CPU without MAX. This is not a frontier
LLM and is not MAX inference; both facts must be stated in every report.

### Lifecycle stages

| Stage | Real work in this project | Boundary |
|---|---|---|
| **PreTrain** | Build a deterministic tokenizer/vocab from a local text corpus; train a tiny next-token model with the autodiff tape; persist checkpoint + config + data fingerprint | Tiny vocab/context; no web data, no downloaded checkpoints |
| **MidTrain** | Resume from a PreTrain checkpoint; continued training on a different declared corpus; reject invalid transitions | Domain adaptation at tiny scale, not broad continual pretraining |
| **PostTrain** | Supervised instruction pairs and preference pairs from local files; fine-tune; score with the existing prompt/evaluation suites | No RLHF at frontier scale; preference scoring is explicit and bounded |
| **Infer** | Autoregressive decoding from the trained first-party checkpoint; record responses; evaluate with the offline score suite | First-party decoding only. MAX-served inference remains `BLOCKED_BY_MAX_INTERFACE` and is reported separately |

### Required control structure
- A lifecycle state machine: `PRETRAIN → MIDTRAIN → POSTTRAIN → INFER`, with
  invalid transitions rejected and every transition journaled.
- Each stage consumes the previous stage's **checksummed** checkpoint and
  config; outputs a new versioned artifact and evidence record.
- `autollm status` must report per-stage status (not one global status) and
  keep the MAX boundary distinct.
- Lineage: an inference result must name the exact checkpoint chain that
  produced it. No inference result may be attributed to an unrecorded model.

---

## C. Interconnection — one evidence graph for all capabilities

### Meaning
"Everything interconnected" means capabilities exchange **typed evidence and
constraints** through a shared ledger. It does **not** mean a tangled import
graph or shared mutable state.

### Planned contract
- A `links` module with typed nodes: capability, experiment, trial, artifact,
  claim, verifier, decision.
- Typed edges: `informs`, `constrains`, `verifies`, `reproduces`, `supersedes`,
  `ablates`.
- Every capability emits a standard claim record: task, metric, budget, seed,
  baseline, artifact checksums, and limitations.
- Discovery loops read claims to propose candidates; the meta-policy reads
  claims to allocate budget; the verifier reads claims to select holdouts;
  RSI reads claims to decide whether a candidate is genuinely new.
- CLI surface (registered only when real): `links graph`, `links trace <id>`,
  `links add` — all read/writes go through the existing journal.

### Acceptance
- A change in one capability's evidence must be traceable to any downstream
  decision that used it.
- An ablation edge must be required before a coupling claim is promoted past
  `hypothesized`.
- No capability may write another capability's protected records.

---

## Owner strategy change (2026-11-28): monolithic per tech

The owner changed the implementation strategy: **implement one technology at
a time, but implement the whole declared breadth of that technology in one
monolithic milestone**, rather than taking thin slices across many
technologies. This remains compatible with the root directive's "one complete
capability at a time" rule: one tech at a time, fully, with tests, before
moving to the next.

Because "everything possible" is unbounded, each tech's breadth is defined by
a **finite declared inventory** recorded in this roadmap before implementation
starts. "Complete" for a tech means every item in that inventory has a real,
tested execution path — not that an infinite algorithm space was exhausted.
If an item cannot be implemented honestly, it is marked BLOCKED with the
reason, and the inventory is updated explicitly.

### Monolithic milestone order

1. **M22 — AutoML, complete.** Full declared inventory (below), one milestone.
2. **M23 — AutoLLM, complete.** PreTrain→MidTrain→PostTrain→Infer lifecycle.
3. **M24 — AutoDL + AutoTransformers + NAS/HPO breadth**, one milestone.
4. **M25 — AutoRL breadth**, one milestone.
5. **M26 — SciAI breadth** (SINN/SciML/SciDL/SciRL/SciTransformers + UQ +
   differentiable simulation + neural-operator feasibility spike), one milestone.
6. **M27 — Discovery/RSI/HPC breadth + full interconnection**, one milestone.

No next tech begins until the current tech's inventory is verified, documented,
and pushed.

### M22 AutoML declared inventory (monolithic)

- **Regression models:** mean baseline, linear GD, ridge, lasso, elastic net,
  Huber robust, polynomial basis, kNN, decision tree, random forest,
  gradient boosting.
- **Classification models:** logistic regression, Gaussian naive Bayes, kNN,
  decision tree, random forest.
- **Unsupervised:** k-means, PCA projection.
- **Metrics:** regression MAE/MSE/RMSE/R²/MAPE; classification accuracy,
  precision, recall, F1, confusion matrix, log loss, ROC-AUC.
- **Validation:** deterministic holdout + k-fold cross-validation.
- **Search:** random, grid, and adaptive (feedback-connected) over the full
  candidate space.
- **Evidence:** every trial persisted in the journal with task type, config,
  seed, metrics, and checksums.

## Original slice-based milestones (superseded by the strategy above)

| Milestone | Slice | Gate |
|---|---|---|
| M22 | Evidence interconnection layer (`links`) | typed edges, trace CLI, cross-capability regression test |
| M23 | AutoML classification support + metric registry | numeric-classification CSV, real classifiers, held-out metrics |
| M24 | AutoML tree ensemble wave | decision tree + random forest + boosting, analytic unit tests |
| M25 | AutoLLM PreTrain (tiny first-party model) | real gradient descent, checkpoint, per-stage status |
| M26 | AutoLLM MidTrain + PostTrain | valid/invalid transitions, checkpoint lineage, local instruction pairs |
| M27 | AutoLLM Infer + offline evaluation | autoregressive decoding, response records, lineage enforcement |
| M28+ | AutoDL / SciDL algorithm waves; neural-operator spike; further interconnection | each gated by its own prerequisite |

Order may be adjusted only for a documented dependency (recorded here with a
reason). A milestone name alone is not progress.

---

## Explicit non-goals at this time

- No claim of full "all algorithms" coverage — the space is unbounded.
- No frontier-scale LLM training, no downloaded checkpoints, no web corpus.
- No MAX model serving until the `BLOCKED_BY_MAX_INTERFACE` boundary is
  actually resolved and independently verified.
- No quantum, world-model, HyperComputers, broad HPC, or agent swarm claim.
- No registration of a command whose execution path does not exist.
