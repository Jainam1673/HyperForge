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

---

## SciTransformers v1 (M05)

**Terminology:** HyperForge's SciTransformers is a scientific-transformer
research family with an exact defined task class, not a claim of one standard
architecture and not a foundation model.

**Task:** deterministic synthetic `decaying_mode_1d`: a regular 8-point grid,
two input frames, and the next frame of `u(x,t) = sin(2πx + φ) exp(-λt)` with
`λ = 0.35`. The generator is analytic and explicitly labeled synthetic. Train
and test cases use different phases with the same seed, so evaluation is held
out by initial condition.

**Model:** one-token-per-cell embedding from value plus absolute `(x,time)`
coordinate encoding, pre-RMS normalization, two-head scaled dot-product
attention with an explicit spatial mask, residual path, position-wise tanh FFN,
second pre-norm/residual, and a scalar output head. Attention is the plain
reference kernel; no FlashAttention or GPU claim is made.

**Differentiation:** a small reverse-mode tape over scalar nodes provides
gradients for all 128 parameters; attention softmax is stabilized by
subtracting the maximum score. Attention output is checked against an
independent numeric implementation and mask semantics are tested.

**Baselines:** persistence (copy last frame), train-fitted per-cell mean, and a
per-cell least-squares linear scale from the last frame to the target. All are
evaluated on the same held-out phases.

**Observed result (seed 42, 10 epochs):**

| Metric | Value |
|---|---:|
| training loss | 0.0435 → 0.000353 |
| model held-out MSE | 0.000266 |
| persistence MSE | 0.021654 |
| mean MSE | 0.132995 |
| linear MSE | 8.19e-33 |
| 5-step rollout drift | 0.00179 |
| state | CONVERGED |

**Honest negative result:** the chosen exact mode makes the next frame an exact
scalar multiple of the previous frame, so the fitted linear baseline is
essentially perfect and beats the transformer by many orders of magnitude. The
transformer beats persistence and mean, but this does **not** demonstrate an
advantage over a simple model. No claim of superiority or operator learning is
made; a harder multi-mode task is required to test that.

**Limitations:** one synthetic task, fixed shapes, no longer-horizon training,
no uncertainty quantification, no physical conservation law, no GPU execution,
and no neural-operator comparison. Training/checkpoint/predict works end to end
and is reproducible across workspaces.
