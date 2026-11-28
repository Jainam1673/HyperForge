# M26 — Full AutoRL breadth

`hyperforge autorl full <algorithm> [env] [episodes] [eval] [seed] [seeds]` implements five algorithms across two training environments with safety constraints and held-out evaluation.

| Algorithm | Method |
|---|---|
| `q_learning` | Off-policy tabular TD control |
| `sarsa` | On-policy tabular TD control |
| `double_q` | Double-Q with decorrelated bootstrap and averaged tables |
| `value_iteration` | Model-based optimal value/Q baseline |
| `random` | Unguided random-policy baseline |

Environments: `grid_4x4` (2 walls), `grid_5x5` (4 walls). Evaluation uses a **different wall layout** (`grid_4x4_holdout`) never seen in training or selection. A safe-action constraint prevents choosing actions that would enter a wall; violations are counted during evaluation. Each algorithm is re-run over the declared seeds, with mean return, standard deviation, success rate, optimal-return regret, and safety violations recorded.

## Observed result (grid_4x4, 40 episodes, 8 evaluation episodes, 2 seeds)

| Algorithm | Mean return | Success rate | Holdout | Optimal | Safety violations |
|---|---:|---:|---:|---:|---:|
| q_learning | -7.64 | 0.44 | -24.0 | 5.0 | 0 |
| sarsa | -5.83 | 0.41 | -24.0 | 5.0 | 0 |
| double_q | -14.55 | 0.09 | -24.0 | 5.0 | 0 |
| value_iteration | 5.00 | 1.00 | -24.0 | 5.0 | 0 |
| random | -5.50 | 0.00 | -24.0 | 5.0 | 0 |

Negative result retained: tabular learners trained 40 episodes do not generalize to the held-out wall layout; value iteration is optimal in-training but also fails the holdout. No claim of robust policy transfer.

`test_m26` (3 tests) and `test-autorl-full` (21 checks) pass.

## Boundaries

No function approximation, deep RL, PPO/DQN, continuous control, or real-world actions. Environments are deterministic simulators. Reward and termination contracts are explicit.
