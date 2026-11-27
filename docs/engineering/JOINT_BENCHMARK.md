# M19 — Joint AI×compute discovery benchmark

## Design

`hyperforge joint run [budget] [seed...]` compares nine strategies under the
same evaluation budget and the same declared seeds. Each evaluation measures
two real objectives on the same workload:

- **Task quality**: validation RMSE from the native regression models on the
  documented `regression_linear.csv` fixture.
- **System cost**: GPU vector-add kernel median latency (block size gene).

The joint genome carries `model_kind`, `iterations`, `block_size`, and `seed`.
Both sides have a genuine improvement path: RMSE falls from 0.287 (50 steps)
to 1.6e-14 (800 steps), and launch configuration changes measured latency.

## Compared strategies

| Strategy | Allocation | Coupling |
|---|---|---|
| `fixed` | alternating, no mutation | none — baseline A |
| `ai_only` | all AI | none — baseline B |
| `compute_only` | all compute | none — baseline C |
| `independent` | alternating | side-local proposals only — baseline D |
| `sequential` | AI half, then compute half | none — baseline D |
| `joint` | explore both, then allocate by normalized relative gain | recombine best of both sides — baseline E |
| `ablation_no_shared_history` | same allocation as joint | side-local recombination only |
| `ablation_no_adaptive` | alternating | shared recombination, no gain-based budgeting |
| `ablation_no_meta` | random allocation | shared recombination, no policy |

Relative gain is normalized by each side's own first observation, so RMSE and
latency are compared without an arbitrary weighted score. A two-step
exploration floor guarantees both sides are exercised before adaptive
allocation begins. Duplicate configurations are never counted as discoveries:
latency noise on an identical genome is measurement variance, not evidence.

## Observed result (budget 6, seeds 42/7/123)

| Strategy | Mean discoveries |
|---|---:|
| fixed | 2.00 |
| ai_only | 3.00 |
| compute_only | 3.00 |
| independent | 3.33 |
| sequential | 3.67 |
| ablation_no_meta | 3.33 |
| ablation_no_adaptive | 3.67 |
| ablation_no_shared_history | 2.67 |
| **joint** | **4.00** |

Joint led mean verified discoveries in this fixture, ahead of every isolated
baseline and every ablation. This is a measured outcome, not an assumed truth.
It does **not** establish universal superiority: the fixture is small, only
three seeds were used, and latency varies between runs. The report explicitly
states that ablations constrain but do not prove general coupling.

## Measurement discipline

- Wall-clock is measured; experiment cost is the matched evaluation count.
- Memory is reported `NOT_TESTED` because no verified memory API exists in the
  installed Mojo release.
- Incorrect kernels are recorded as invalid and cannot produce discoveries.
- Every `(seed, policy)` outcome is appended as a `joint_outcome` journal
  record; `joint show` reconstructs the ledger.

## Limits

No MAX model inference, no application-kernel migration, no energy objective,
no formal confidence intervals, and no general causal claim. SciLLM/SciGenAI
remain blocked by the unverified MAX inference boundary.
