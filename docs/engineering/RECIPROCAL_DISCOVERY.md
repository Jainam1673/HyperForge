# Reciprocal Meta-Discovery proof (M07)

## Scope and claim

This is a bounded benchmark, not a claim that reciprocal coupling works. The
central claim is tested: six policies receive the **same number of genome
evaluations**, and both objectives are measured in every evaluation.

## DiscoveryGenome (v1)

| Gene | Side | Values | Execution path |
|---|---|---|---|
| `model_kind` | AI | `linear_gd`, `ridge_gd`, `knn_regressor` | M02 AutoML models |
| `block_size` | Compute | 64, 128, 256, 512 | M06 GPU vector-add launch |

Unsupported values are rejected; mutation changes only one side and validates
the child. The genome is canonicalized as `model|block=N` and referenced by a
stable hash. Only genes with real execution paths exist.

## Objectives and evidence

- **Task quality:** validation RMSE on `examples/regression_linear.csv` with a
  fixed split seed. Lower is better. Computed by M02 model fitting; no literals.
- **System quality:** median GPU kernel latency at `N=1024` for the selected
  block size, with 3 repeated launches and synchronization. Lower is better.
- Every evaluation produces one `Observation` containing the genome, both
  metrics, and validity. The shared ledger is the evidence base for proposals.
- Memory is reported `NOT_TESTED`: no verified Mojo memory API was established
  for this release. No causal claim is made from a single correlated change.

## Policies (matched budget)

| Policy | Rule |
|---|---|
| `fixed` | Same genome every evaluation. |
| `ai_only` | Mutate only the AI gene; compute gene fixed. |
| `compute_only` | Mutate only the compute gene; AI gene fixed. |
| `independent` | Alternate sides with separate histories; no coupling. |
| `joint_reciprocal` | Use shared history: allocate the next evaluation to the side with the larger normalized marginal gain, then recombine the best observed model and block. |
| `ablation_no_history` | Random valid genome; meta-policy ablated. |

The adaptive budget in `joint_reciprocal` is transparent and testable:
`next_genome` is selected by compared gains. A unit test asserts that changing
the gain argument changes the chosen side.

## Observed results

Budget 6, seed 42 (release binary, MX230 sm_61):

| Policy | best RMSE | best latency s | discoveries | Pareto | wall s |
|---|---:|---:|---:|---:|---:|
| fixed | 8.81e-7 | 7.73e-6 | 4 | 1 | 0.0073 |
| ai_only | 0.0435 | 8.07e-6 | 4 | 2 | 0.0017 |
| compute_only | 8.81e-7 | 8.21e-6 | 2 | 1 | 0.0104 |
| independent | 8.81e-7 | 8.04e-6 | 4 | 2 | 0.0060 |
| joint_reciprocal | 0.0435 | 8.33e-6 | 3 | 2 | 0.0050 |
| ablation_no_history | 0.0435 | 8.06e-6 | 5 | 1 | 0.0027 |

Budget 6, seed 43: the ordering is materially unchanged; joint still ends with
worse RMSE than independent/fixed and no latency advantage.

## Negative result

**Reciprocal coupling did not improve task quality in this benchmark.** Joint
search ended at RMSE `0.0435` while fixed and independent search reached
`8.81e-7` on the same task and budget. Joint search also showed no latency
advantage. These failures are reported rather than hidden; no novelty or
superiority claim is made. Likely causes to investigate later: tiny search
space, near-constant kernel latency across block sizes on this device, and an
allocation rule based on raw marginal gain without uncertainty estimates.

## Ablations and validity

- `ablation_no_history` tests the value of the meta-policy; it changed which
  genomes were visited but did not beat fixed/independent on task quality.
- `independent` uses separate histories, so no cross-loop evidence is shared.
- All policies are replayable from `(policy, seed, budget)`; records are
  appended to the local `HFJ1` journal as `discovery` records.
- Pareto counts use strict two-objective dominance; equal-objective duplicates
  are not counted as improvements.

## Out of scope

No full Causal Discovery Graph, Bayesian/TPE meta-posterior, multi-fidelity
racing, energy measurement, GPU-backed application kernels, or broad AutoAI
families. The genome will gain genes only when their execution paths exist.
