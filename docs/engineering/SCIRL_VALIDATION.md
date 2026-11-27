# SciRL validation (M14)

## Controlled simulator

`solver_selection_1d` is a bounded Poisson solver: `-u''(x) = k*sin(m*pi*x)`,
`u(0)=u(1)=0`. The agent observes the forcing band `m` (1 or 7) and selects a
mesh resolution from the safe action set `{2,4,8,16}`. Reward is
`-(field_RMSE + 0.02*n/16)`, combining numerical accuracy and computational
cost. Each episode is one decision; invalid actions and steps after termination
are rejected.

The simulator is validated against the analytic field `u = k*sin(m*pi*x)`.
Frequencies were chosen to avoid grid aliasing on the available resolutions; an
early `m=6` setting aliased at `n=2` and produced a false zero error, which is
documented in `TEST_RESULTS.md`.

## Conditions, training, and evaluation

- Training uses a deterministic grid of `k` values `[0.50, 1.49]`; held-out
  conditions use an offset grid `[0.505, 1.495]`, so no exact training condition
  is evaluated. Both sets include both frequency bands.
- Q-learning with epsilon-greedy decay is trained on seeds 1–3; reported
  results use unseen seeds 101–105 with greedy, no-update evaluation.
- Baselines: uniform random action and a domain heuristic that always selects
  the finest mesh. Repeated seeds give mean, sample std, and a normal-
  approximation 95% confidence half-width.
- Learning curves and config checksums are persisted as artifacts.

## Observed result (40 episodes, 10 evaluation episodes)

| Policy | mean held-out return |
|---|---:|
| Learned Q-policy | -0.01421 |
| Random action | -0.02233 |
| Finest-mesh heuristic | -0.02114 |

Improvement over random: `+0.00812`; over heuristic: `+0.00693`. The learned
policy chooses a coarser mesh for the smooth band and a finer mesh for the
high-frequency band, trading cost against error. The confidence interval is
small because the deterministic grid makes the held-out conditions nearly
identical across seeds; it should not be read as broad uncertainty.

## Limits

One controlled simulator, one-step decisions, tabular policy, no continuous
control, stochastic transitions, world models, or real-world resources. No
claim of safe deployment outside this simulator.
