# M17 — DiscoveryGenome v2 and systems-side search

## Genome

`hyperforge-discovery-genome-v2` carries four genes:

| Gene | Values | Executed here? |
|---|---|---|
| `model_kind` | linear/ridge/knn | No — carried for later coupling |
| `compute_kernel` | vector_add, vector_axpy | Carried; search fixes vector_add |
| `block_size` | 64, 128, 256, 512 | Yes — measured launch configuration |
| `vector_size` | 1024 | Fixed task shape |

Only genes with a real measured path are claimed as evidence. The report states
explicitly that the AI gene is carried but not measured in this systems-only
search. Validation rejects unknown kernels, invalid block sizes, and vector
sizes other than 1024. Mutation preserves constraints; canonical strings and
hashes are stable.

## Systems-side search

Three policies receive the same budget:
- `fixed`: block 256 reference;
- `random`: seeded block choices;
- `adaptive`: mutates the best-observed block configuration.

Each evaluation runs the real GPU vector-add kernel through the M16 catalogue
with warm-up, repeated measurements, correctness against a CPU reference, and
two measured objectives: kernel median latency and end-to-end median latency
(including device-to-host mapping). Pareto dominance uses strict improvement on
both objectives; no weighted score is computed. Duplicate configurations are
allowed but recorded separately; ties are not counted as discoveries.

## Observed result (budget 3, seed 42)

| Policy | trials | best kernel median s | Pareto count |
|---|---:|---:|---:|
| fixed | 1 | 1.11e-5 | 1 |
| random | 3 | 7.54e-6 | 2 |
| adaptive | 3 | 7.58e-6 | 2 |

Random and adaptive measured slightly faster blocks than the fixed reference on
this device, but the differences are small and not claimed as general. No
causal claim is made from a single correlated change; M18 will add the typed
causal evidence graph and adaptive experiment economy.

## Persistence

Every trial is appended as a `systems_trial` journal record with policy, genome
ID, block size, error, both medians, throughput, and state. `systems show`
reconstructs the records. Failed/incorrect trials are recorded with their state
rather than dropped.

## Limits

No MAX model inference, no application-kernel migration, no energy or memory
objective, no multi-fidelity ordering, and no AI-side measurement in this
milestone.
