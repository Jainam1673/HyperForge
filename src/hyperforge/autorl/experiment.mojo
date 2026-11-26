"""Seeded RL comparison with separated selection, evaluation, and reporting."""

from std.math import sqrt
from hyperforge.autorl.environment import GridWorld
from hyperforge.autorl.tabular import (
    RLConfig,
    value_iteration,
    q_from_values,
    train_q_learning,
    evaluate_policy,
    random_policy,
)

def selection_seeds() raises -> List[UInt64]:
    var out: List[UInt64] = [1, 2, 3]
    return out^


def holdout_seeds() raises -> List[UInt64]:
    var out: List[UInt64] = [101, 102, 103, 104, 105]
    return out^


comptime CI_Z = 1.96


struct RLExperiment(Copyable, Movable):
    var selected: String
    var alpha: Float64
    var gamma: Float64
    var epsilon_start: Float64
    var epsilon_min: Float64
    var test_mean: Float64
    var test_std: Float64
    var ci95: Float64
    var random_mean: Float64
    var optimal_mean: Float64
    var improvement: Float64
    var episodes: Int
    var seeds: Int
    var detail: String
    var curve: List[Float64]

    def __init__(
        out self,
        selected: String,
        alpha: Float64,
        gamma: Float64,
        epsilon_start: Float64,
        epsilon_min: Float64,
        test_mean: Float64,
        test_std: Float64,
        ci95: Float64,
        random_mean: Float64,
        optimal_mean: Float64,
        improvement: Float64,
        episodes: Int,
        seeds: Int,
        detail: String,
        var curve: List[Float64],
    ):
        self.selected = selected
        self.alpha = alpha
        self.gamma = gamma
        self.epsilon_start = epsilon_start
        self.epsilon_min = epsilon_min
        self.test_mean = test_mean
        self.test_std = test_std
        self.ci95 = ci95
        self.random_mean = random_mean
        self.optimal_mean = optimal_mean
        self.improvement = improvement
        self.episodes = episodes
        self.seeds = seeds
        self.detail = detail
        self.curve = curve^


def mean_of(values: List[Float64]) raises -> Float64:
    var total = Float64(0.0)
    for value in values:
        total += value
    return total / Float64(len(values))


def std_of(values: List[Float64], average: Float64) raises -> Float64:
    if len(values) < 2:
        return 0.0
    var total = Float64(0.0)
    for value in values:
        var delta = value - average
        total += delta * delta
    return sqrt(total / Float64(len(values) - 1))


def candidate_configs(episodes: Int, evaluation_episodes: Int) raises -> List[RLConfig]:
    var configs = List[RLConfig]()
    configs.append(RLConfig(0.2, 0.9, 0.3, 0.05, episodes, evaluation_episodes))
    configs.append(RLConfig(0.1, 0.95, 0.5, 0.05, episodes, evaluation_episodes))
    configs.append(RLConfig(0.3, 0.85, 0.2, 0.01, episodes, evaluation_episodes))
    return configs^


def run_rl_experiment(
    env: GridWorld, episodes: Int, evaluation_episodes: Int
) raises -> RLExperiment:
    if episodes < 4 or evaluation_episodes < 2:
        raise Error("episodes and evaluation_episodes are too small")

    var configs = candidate_configs(episodes, evaluation_episodes)
    var selection = selection_seeds()
    var holdout = holdout_seeds()
    var selection_scores = List[Float64]()
    for config in configs:
        var score = Float64(0.0)
        for seed in selection:
            var learned = train_q_learning(env, config, seed)
            score += evaluate_policy(env, learned[0], config.evaluation_episodes, seed + 1000)
        selection_scores.append(score / Float64(len(selection)))

    var best_index = 0
    for i in range(len(selection_scores)):
        if selection_scores[i] > selection_scores[best_index]:
            best_index = i
    var selected = configs[best_index].copy()

    var test_returns = List[Float64]()
    for seed in holdout:
        var learned = train_q_learning(env, selected, seed)
        test_returns.append(evaluate_policy(env, learned[0], evaluation_episodes, seed + 1000))

    var random_returns = List[Float64]()
    for seed in holdout:
        random_returns.append(random_policy(env, evaluation_episodes, seed + 2000))

    var optimal_values = value_iteration(env, selected.gamma, 1e-8, 200)
    var optimal_q = q_from_values(env, optimal_values, selected.gamma)
    var optimal_returns = List[Float64]()
    for seed in holdout:
        optimal_returns.append(evaluate_policy(env, optimal_q, evaluation_episodes, seed + 3000))

    var test_mean = mean_of(test_returns)
    var test_std = std_of(test_returns, test_mean)
    var random_mean = mean_of(random_returns)
    var optimal_mean = mean_of(optimal_returns)

    # Learning curve: mean training return per episode over selection seeds.
    # Reuse already-determined training runs instead of retraining per episode.
    var recorded = List[List[Float64]]()
    for seed in selection:
        var learned = train_q_learning(env, selected, seed)
        recorded.append(learned[1].copy())
    var curve = List[Float64]()
    for episode in range(episodes):
        var total = Float64(0.0)
        for seed_index in range(len(recorded)):
            total += recorded[seed_index][episode]
        curve.append(total / Float64(len(recorded)))

    var detail = String("config selected on seeds 1-3; reported on unseen seeds 101-105")
    return RLExperiment(
        "q" + String(best_index), selected.alpha, selected.gamma,
        selected.epsilon_start, selected.epsilon_min, test_mean, test_std,
        CI_Z * test_std / sqrt(Float64(len(holdout))),
        random_mean, optimal_mean, test_mean - random_mean,
        episodes, len(holdout), detail, curve^,
    )
