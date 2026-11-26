# Experiment protocol (M02 regression slice)

## Task and data

- Task: single-target tabular regression on local CSV.
- Example: `examples/regression_linear.csv`, 24 rows, features `x1,x2`, target
  `y = 2*x1 - 3*x2 + 5`. Synthetic, deterministic, explicitly labeled; it is a
  correctness fixture, not a scientific benchmark claim.
- Supported CSV: header, comma separator, numeric cells, empty feature cell =
  missing. No quoting, categoricals, or whitespace trimming. Unsupported input
  is rejected. Target cells must be present and finite.
- Dataset fingerprint: FNV-1a 64 over the raw file content, recorded in both the
  config artifact and the experiment record.

## Split and leakage boundary

- Deterministic 60/20/20 shuffle split derived from `(seed, "split", 0)` via
  SplitMix64. Split sizes are recorded through the seed; no row index tables
  are stored in M02.
- Imputation means, feature means, feature standard deviations, and target mean
  are fitted **only on training rows**.
- Validation is used only to select a candidate. The held-out test set is
  evaluated **once**, after selection, and its metrics never influence search.

## Models (all real computations)

| Model | Computation |
|---|---|
| `mean_baseline` | Predicts the train target mean. |
| `linear_gd` | Batch gradient descent on standardized features with centered target. |
| `ridge_gd` | Same with L2 penalty on weights. |
| `knn_regressor` | k nearest standardized training points, deterministic tie order by training index. |

## Metrics and edge cases

MAE, MSE, RMSE, and R² are computed from predictions. Non-finite predictions or
targets are rejected. Empty input and length mismatch are errors. When the
target is constant (or there is one sample), R² is defined as 0 rather than
NaN or a fabricated score; R² may be negative for predictions worse than the
mean.

## Search and reproducibility

- Search is deterministic random search: baseline first, then `budget-1`
  candidates generated as pure functions of `(seed, index)`. It is **not**
  adaptive and is not called Bayesian or TPE.
- Fixed budget and seed produce identical experiment IDs and trial metrics
  across processes and workspaces (verified).
- Every candidate's validation trial, plus the single final test trial, is
  appended to the local `HFJ1` journal with its metrics and status.
- `automl replay` re-runs the recorded pipeline from the config artifact and
  compares the recomputed held-out RMSE with the recorded value (tolerance
  1e-9). It refuses with exit 3 if the config artifact or dataset changed.

## Reporting

`report <id>` prints the task, dataset path, fingerprint, seed, budget, trial
count, and the best held-out result. It explicitly notes that selection used
validation only. No causal explanation is inferred from correlations.

## Out of scope for M02

Classification, multiclass, cross-validation, multi-fidelity racing, adaptive
samplers, decision trees, ensembles, neural models, GPU execution, and any
claim of state-of-the-art quality. These are separate milestones.
