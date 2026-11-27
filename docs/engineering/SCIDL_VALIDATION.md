# SciDL validation (M13)

## Scope and task

Supervised scientific deep learning on a 1D Poisson field: predict
`u(x;k)` from `(x, k)` pairs on a fixed 8-point grid. Data are analytic and
explicitly labeled synthetic; no external dataset is used.

- Train parameters: `k ∈ [0.5, 1.0]` (12 values).
- Held-out parameters: `k ∈ [1.05, 1.5]` (8 values) — **parameter extrapolation**,
  not a random split of the same range.
- Input representation: normalized `(2x-1, (k-1)/0.5)`; output: scalar field value.
- Model: tanh MLP (width 8, 2 layers) trained with mini-batch-free Adam over the
  verified reverse-mode tape. Every parameter is a tape node.

This is **supervised data-driven** learning. It is not SINN: no physics residual
enters the loss. It is not operator learning: a single parameter family and
fixed grid are used, and no function-space claim is made.

## Baselines and physical reference

- Data-only linear baseline: one coefficient fitted on training fields against
  the known analytic shape `k*sin(pi*x)/pi^2`.
- Conventional numerical reference: finite-difference Poisson solver at the
  known parameter, evaluated on the same grid.
- Held-out metrics: field RMSE and maximum absolute error over all held-out
  `(k, x)` pairs; parameter ranges recorded explicitly.

## Observed result (seed 42)

| Model | Held-out field RMSE |
|---|---:|
| Supervised MLP | 0.08675 |
| Linear data-driven baseline | 7.42e-18 |
| Finite-difference reference | 0.00398 |

Training RMSE was 0.02322 and maximum held-out error 0.24618. The learned MLP
generalized poorly outside its training parameter range and was **worse** than
both the domain-specific linear baseline and the numerical solver. This negative
result is reported rather than hidden: a generic MLP is not automatically better
than a known-form fit or a validated PDE solver on this task.

## Persistence and limits

Each run writes a config artifact, a serialized checkpoint, and a `scidl`
journal record with train/held-out metrics, parameter ranges, and state. Limits:
single analytic PDE, fixed grid, no convolutional/operator architectures, no
physics residual, no uncertainty quantification, and no GPU training.
