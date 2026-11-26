# AutoRL validation (M09)

## Environment contract

`grid_4x4_two_walls`: 16 discrete states, start `(0,0)`, goal `(3,3)`, walls at
indices 5 and 9. Actions are `0=up, 1=right, 2=down, 3=left`. Reward is `-1`
per non-terminal step and `+10` at the goal. `terminated` means the goal was
reached; `truncated` means the 24-step budget was exhausted. Calling `step`
after either state is rejected. All transitions are deterministic. No
real-world actions exist.

## Methods

- **Value iteration** computes optimal state values to `theta=1e-8`; a Q table
  is derived and used as an exact reference policy.
- **Q-learning** with linear epsilon-greedy decay and three candidate
  `(alpha, gamma, epsilon)` configurations. Training uses seeded exploration;
  evaluation uses greedy actions, no exploration, and **no Q updates**.
- **Random policy** baseline uses the same step budget and seeds.
- Configs are selected on seeds 1–3; reported results use unseen seeds
  101–105. This separates training, model/config selection, and evaluation.

## Observed result (60 training episodes, 20 evaluation episodes)

| Policy | mean held-out return |
|---|---:|
| Q-learning (selected config `q0`) | 5.0 |
| Value-iteration optimum | 5.0 |
| Random policy | -19.46 |

Improvement over random: `24.46`. Sample standard deviation across five
held-out seeds: `0.0`; 95% confidence half-width (normal approximation,
`1.96 * s / sqrt(n)`): `0.0`. Learning-curve mean rose from `-24.0` at episode
0 to `5.0` by the end of training. The learned policy matches the dynamic-
programming optimum; no claim is made beyond this small deterministic grid.

## Persistence and replay

Each run writes a versioned config artifact, a CSV learning curve with one mean
training return per episode, and an `autorl` journal record containing the
selected config, mean/std/CI, random and optimal references, seed count, and
state (`IMPROVED` or `NO_IMPROVEMENT`). `autorl replay` verifies the config
checksum and reports readiness; it does not claim to re-run the original
training.

## Limits

Tabular methods only; no neural policies, partial observability, stochastic
transitions, continuous control, off-policy corrections, or importance
sampling. Confidence uses a normal approximation with five seeds and should
not be read as a rigorous interval for small samples.
