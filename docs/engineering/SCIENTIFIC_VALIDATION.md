# Scientific validation — SINN v1 (M04)

## Terminology

In HyperForge, **SINN** means *Science-Informed Neural Networks*: a proposed
umbrella/design direction, not a standardized method name. This v1 is a
physics-informed neural network for one Poisson problem. It is not presented as
a novel PINN formulation or as state of the art.

## Problem and assumptions

- PDE: `-u''(x) = 2` on `x ∈ [0,1]`, with `u(0) = u(1) = 0`.
- Exact solution: `u(x) = x(1-x)`. This is an analytic fixture, not experimental
  data. Units/scaling are dimensionless; the domain and forcing are fixed by
  the typed problem record.
- Validity range: only this problem is supported. No claim extends to other
  PDEs, higher dimensions, stiffness, or inverse problems.

## Representation and differentiation

- Network: one hidden layer of 4 tanh units, scalar output, explicit weights
  and biases, deterministic seeded initialization.
- Exact boundary enforcement: `u(x) = x(1-x) * N(x)`, so `u(0)=u(1)=0` holds by
  construction rather than by a penalty.
- Differentiation: a forward-mode higher-order jet carries `v`, `vx`, `vxx`,
  and the same derivatives along one parameter direction (`vp`, `vxp`,
  `vxxp`). `vxx` is the PDE derivative; `vxxp` gives training gradients.
- Verification: jet `vx` and `vxx` are checked against central finite
  differences; `vxxp` is checked against a finite-difference parameter
  perturbation. Tests enforce tolerances of 1e-4 (derivatives) and 1e-3
  (parameter derivative). No second derivative is claimed without a test.

## Training and optimizer

- Loss: mean squared PDE residual at 24 deterministically sampled interior
  collocation points. Boundary loss is zero by construction and reported as
  `boundary: 0.0`.
- Optimizer: Adam with `lr=0.01`, `beta1=0.9`, `beta2=0.999`, `eps=1e-8`.
- Non-finite gradients reject the run; `DIVERGED`/`POOR_FIT` states are recorded
  and the command exits 1 instead of claiming success.
- Held-out evaluation uses 15 interior grid nodes that were **not** used for
  training. Residual, exact-solution L2, and finite-difference L2 are reported
  separately on that grid.

## Reference method

An independent finite-difference solver (Thomas algorithm on the same interior
grid) solves the tridiagonal system for `-u'' = 2`. It agrees with the analytic
solution to <1e-3 in tests. The network is compared to both the analytic
solution and the numerical solver, never only to itself.

## Observed result (seed 42, 800 iterations)

| Metric | Value |
|---|---:|
| training loss | 5.6308 → 0.000838 |
| held-out residual RMSE | 0.0287 |
| boundary error | 0.0 |
| exact-solution L2 | 0.00200 |
| finite-difference L2 | 0.00200 |
| state | CONVERGED |

A second seed (99) also converged; a 3-iteration run did **not** meet the gate
and was reported as a failure with exit 1. A small residual at collocation
points is not treated as proof of generalization: held-out errors are the
reported evidence.

## Alternatives and limitations

- Exact boundary multiplication was chosen over a boundary penalty because the
  Dirichlet form is known; penalty enforcement would add a loss-balancing
  failure mode.
- Forward jets were chosen over a general reverse-mode tape because the network
  is tiny and the required mixed derivative is explicit and testable.
- Limitations: one analytic PDE, fixed network width, no adaptive collocation,
  no uncertainty quantification, no GPU execution, no second benchmark. PINNs
  can fail through loss imbalance, stiffness, spectral bias, and optimization
  difficulty; this implementation detects non-finite gradients and reports
  convergence honestly but does not solve those broader failure modes.

## Reproduction

```bash
pixi run build
./hyperforge init ./workspace
cd ./workspace
../hyperforge sinn solve poisson_1d 42 800
../hyperforge sinn show <experiment-id>
```
