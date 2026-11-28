# M25 — Full AutoDL breadth (HPO + structural NAS)

`hyperforge autodl full <policy> <budget> <seed> [seeds]` implements four HPO/NAS policies over the existing tape-trained MLP substrate:

| Policy | Method |
|---|---|
| `grid` | Deterministic sweep over depth, width, batch size, learning rate, and activation |
| `random` | Seeded random candidates over the same space |
| `adaptive` | Mutation of the best-observed candidate |
| `multifidelity` | Low-epoch screen, promotes best half to full epochs |

NAS is structural: depth and width change the computation graph, not only parameter values. Every candidate is trained with the autodiff tape; parameters provably change or the candidate is rejected. Early stopping uses validation only; the test split is touched once after selection. Repeated seeds re-evaluate the winner from scratch.

Evidence is appended as an `autodl_full` journal record with policy, budget, seeds, winner architecture, validation/test metrics, architecture diversity, and fidelity promotions.

## Verified result (budget 4, seed 42, 2 seeds)

| Policy | Winner | Test loss | Accuracy |
|---|---|---:|---:|
| grid | depth 1 × width 4 tanh | 0.396 | 0.875 |
| random | depth 1 × width 4 relu | 0.398 | 0.875 |
| adaptive | depth 3 × width 8 relu | 0.385 | 0.875 |
| multifidelity | depth 3 × width 8 relu | 0.385 | 0.875 |

`test_m25` (2 tests) and `test-autodl-full` (17 checks) pass.

## Boundaries

Activation choices are tanh/relu (the model substrate supports those); optimizer breadth, skip connections, and multi-fidelity beyond the two-level screen remain future expansion of this same tech. No claim of a generic NAS framework.
