# M27 — Full SciAI breadth

`hyperforge sciai full [seed]` runs a shared analytic-problem benchmark across three problem families: Poisson amplitude, heat decay, and linear wave. Each has an analytic solution and a finite-difference reference.

| Technique | Real measurement |
|---|---|
| SciML inverse | grid-search parameter identification on noisy observations |
| Uncertainty quantification | bootstrap ensemble mean, std, and 95% interval with stated noise assumptions |
| SciDL baselines | analytic field RMSE vs a fitted linear field model |
| SciRL selection | epsilon-greedy coarse/fine resolution bandit with cost, vs random |
| Differentiable simulation | forward-mode jet parameter gradient checked against central finite differences |
| Neural operator spike | affine parameter-to-solution map with measured amortization; explicitly not DeepONet/FNO |

## Observed result (seed 42, parameter 1.0)

| Problem | Estimate ± std | Field RMSE / linear RMSE | Bandit / random | Operator error |
|---|---|---:|---:|---:|
| poisson_amplitude | 0.99375 ± 0.00518 | 0.00119 / 0.06279 | −0.0132 / −0.0192 | 2.8e−17 |
| heat_decay | 1.0 ± 0.0 | 0.0 / 0.07903 | −0.0132 / −0.0192 | 0.0 |
| linear_wave | 1.0 ± 0.0 | 0.0 / 0.06792 | −0.0132 / −0.0192 | 0.0 |

Finite-difference and jet gradients agree with the analytic parameter derivative to 1e−12. Every outcome is journaled as `sciai_outcome`.

## Boundaries

This is breadth over problem families and cross-cutting scientific techniques, not a full implementation of every neural architecture. No DeepONet/FNO, no calibrated Bayesian posteriors (bootstrap intervals only), no differentiable CFD, no real-world control. Existing SINN and SciTransformers capabilities remain single-problem slices; their multi-problem extension is future work on this same tech.

`test_m27` 2 tests and `test-sciai-full` 17 checks pass.
