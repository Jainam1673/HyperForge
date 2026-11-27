# M18 — Meta-Discovery experiment economy and causal evidence graph

## Experiment economy

`hyperforge meta run [budget] [seed]` compares four allocation policies under an
identical evaluation budget:

| Policy | Rule |
|---|---|
| `fixed` | alternate AI-side and compute-side evaluations |
| `random` | seeded RNG chooses the side each step |
| `adaptive` | choose the side with the larger mean verified gain per unit cost observed so far; ties favor AI |
| `ai_only` | ablation: never allocate to the compute side |

Each evaluation performs real work:
- **AI side**: validation RMSE with 100 vs 300 gradient iterations on the
  documented regression fixture; gain is the positive RMSE reduction.
- **Compute side**: GPU kernel median latency for block 256 vs 128 at vector
  size 1024; gain is the positive latency reduction. Incorrect kernels are
  recorded as invalid, not as improvements.

Cost is one evaluation per side measurement. The policy is transparent and
testable; `choose_side` and `mean_gain` have unit tests. Multi-fidelity is not
used, so no fidelity-ordering claim is made.

## Causal evidence graph

`hyperforge-causal-graph-v1` stores typed nodes (hypothesis, run, metric) and
edges labeled `observed`, `experimentally_supported`, or `hypothesized`.

- A hypothesis-to-run edge is labeled `experimentally_supported` only when a
  controlled intervention was executed and produced a positive measured gain;
  otherwise it remains `hypothesized`.
- The cross-loop coupling edge (`metric-ai -> metric-compute`) is always
  `hypothesized` with evidence `ablation_pending`: shared evidence does not
  establish causation.
- Nodes, edges, evidence IDs, and details are appended as `causal_edge`
  journal records; `meta graph` reconstructs them.

## Observed result (budget 4, seed 42)

| Policy | total gain | AI evals | compute evals | state |
|---|---:|---:|---:|---|
| fixed | 0.03592 | 2 | 2 | IMPROVED |
| random | 0.01796 | 1 | 3 | IMPROVED |
| adaptive | 0.07183 | 4 | 0 | IMPROVED |
| ai_only | 0.07183 | 4 | 0 | IMPROVED |

In this fixture the AI side dominates, so the adaptive policy allocates
entirely to AI and matches the `ai_only` ablation. This is reported without
claiming that adaptive allocation is generally superior. GPU latency varies
between runs, so replay assertions use the deterministic AI-only policy.

## Limits

No multi-fidelity ordering, formal confidence intervals on allocation gains,
energy/memory objectives, or causal claim from shared history. MAX model
inference remains separately blocked; no SciLLM/SciGenAI command is registered.
