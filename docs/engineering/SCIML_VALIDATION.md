# SciML validation (M12)

## Problem registry

One typed registry entry is implemented: `poisson_amplitude_1d`.

- Equation: `-u''(x) = k*sin(pi*x)` on `[0,1]`, `u(0)=u(1)=0`.
- Exact solution: `u(x) = (k/pi^2)*sin(pi*x)`.
- Truth parameter `k = 1.0`; search range `[0.5, 1.5]`.
- Units are dimensionless; scaling is O(1); assumptions and reference solution
  are stored in the registry and printed by `sciml list-problems`.
- Physics enters **explicitly** through the discrete Laplacian and Dirichlet
  conditions, not as a decorative "physics-informed" label.

## Forward and inverse methods

- Conventional forward solver: Thomas algorithm on a 20-point interior grid;
  RMS error versus the analytic solution is below `1e-3`.
- Observations: 12 noisy points from a fixed seed; 7 train, 5 held-out. Noise is
  deterministic per seed and reproducible.
- Inverse identification: grid search plus local refinement minimizes the sum
  of squared errors between the finite-difference prediction and observations
  on **training points only**.
- Physics+data hybrid: the forward solver output at the estimated parameter is
  scaled by a least-squares correction fitted on training observations only.
- Data-only baseline: constant predictor equal to the mean of training
  observations.

## Observed result (seed 42)

| Quantity | Value |
|---|---:|
| Estimated k | 0.989 |
| True k | 1.0 |
| Parameter error | 0.011 |
| Parameter std (5 noise seeds) | 0.03698 |
| Inverse held-out exact L2 | 0.000905 |
| Hybrid held-out exact L2 | 0.000922 |
| Constant baseline held-out exact L2 | 0.044053 |
| FD reference error vs exact | 0.000185 |

The inverse and hybrid methods beat the data-only constant baseline on held-out
points. The parameter variability across noise seeds is reported rather than
presented as a deterministic exact identification.

## Persistence and limits

Each run writes a config artifact and a `sciml` journal record with parameter
estimate, error, variability, held-out errors, and baseline comparison. Only
this one problem is supported; no data assimilation, full Bayesian inversion,
uncertainty intervals with formal coverage, operator learning, or higher
dimensions are claimed.
