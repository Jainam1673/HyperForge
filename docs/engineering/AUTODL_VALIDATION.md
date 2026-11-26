# AutoDL validation (M08)

## Scope

AutoDL in HyperForge is a real deep-learning experimentation loop over tiny
MLPs trained on CPU. It is **not** a general deep-learning framework and makes
no state-of-the-art claim. Architecture candidates genuinely differ in depth
and width; hyperparameter-only changes are not called NAS.

## Task

`concentric_circles_2d`: 120 deterministic synthetic samples in `[0,1]^2`,
label 1 inside a circle of radius 0.22 centered at (0.5, 0.5), label 0 outside.
Generated analytically and explicitly labeled synthetic. Fixed seed-derived
shuffle gives 72 train / 24 validation / 24 test; splits are disjoint and
reproducible.

## Model and differentiation

- MLP with 1–3 hidden layers, width 4/8/16, tanh or ReLU activations, sigmoid
  output, binary cross-entropy loss.
- All weights and biases are explicit tape parameter nodes in the verified
  reverse-mode tape (`autodiff/tape.mojo`). `log` and `relu` were added with
  derivative tests. No detached gradients.
- Mini-batch Adam with learning rate and batch size searched explicitly.
- Validation-only early stopping with patience; best validation checkpoint
  retained. Test is evaluated **once after selection** — training records hold
  `test_loss = 0.0` and `test_accuracy = 0.0` until then, and a unit test asserts
  this.

## Search policies and budget

Both policies receive the same number of candidate trainings:

- `random`: seeded uniform proposal over depth, width, learning rate, batch
  size, and activation.
- `adaptive`: mutates the candidate with the best validation loss.

Observed run (seed 42, budget 4):

| Policy | best architecture | validation loss | test accuracy | trained | distinct architectures |
|---|---|---:|---:|---:|---:|
| random | 1x4, relu | 0.5549 | 0.875 | 4 | 4 |
| adaptive | 3x8 | 0.5634 | 0.875 | 4 | 1 |

At this budget both policies reach the same held-out accuracy; adaptive search
does not demonstrate an advantage. This is reported as a result, not hidden.
The random policy did train four structurally distinct architectures, which
satisfies the architecture-diversity requirement.

## Verification

- Unit tests check tape derivatives, split disjointness, parameter counts,
  serialization round-trip, non-zero parameter change, loss decrease, and test
  lock.
- Integration checks run both policies, persist two `autodl` records, write
  config/model artifacts, and verify `show`/`replay`.
- `replay` restores the checkpoint and reports `REPLAY_READY`; it does not claim
  a re-run comparison because the recorded test metric was produced once by the
  original protocol. This distinction is explicit.

## Limits

Synthetic task only; no convolution, recurrence, normalization layers, weight
decay search, multi-fidelity racing, GPU training, or large datasets. No claim
that adaptive search beats random search. Model artifacts are plain versioned
text, not an optimized format.
