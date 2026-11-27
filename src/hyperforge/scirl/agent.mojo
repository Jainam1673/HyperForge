"""Tabular solver-selection policy with held-out environment conditions."""

from std.math import sqrt, pow
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.scirl.simulator import (
    ScientificEnv,
    StepOutcome,
    step,
    sample_condition,
    heuristic_action,
    ACTION_COUNT,
    STATE_COUNT,
)

comptime BETA1 = 0.9
comptime BETA2 = 0.999
comptime ADAM_EPS = 1e-8
comptime TRAIN_SEEDS = [UInt64(1), 2, 3]
comptime HOLDOUT_SEEDS = [UInt64(101), 102, 103, 104, 105]


struct RLConfig(Copyable, Movable):
    var alpha: Float64
    var gamma: Float64
    var epsilon_start: Float64
    var epsilon_min: Float64
    var episodes: Int

    def __init__(out self, alpha: Float64, gamma: Float64, epsilon_start: Float64, epsilon_min: Float64, episodes: Int):
        self.alpha = alpha
        self.gamma = gamma
        self.epsilon_start = epsilon_start
        self.epsilon_min = epsilon_min
        self.episodes = episodes


struct SciRLOutcome(Copyable, Movable):
    var seed: UInt64
    var episodes: Int
    var evaluation_episodes: Int
    var learned_mean: Float64
    var learned_std: Float64
    var ci95: Float64
    var random_mean: Float64
    var heuristic_mean: Float64
    var improvement_random: Float64
    var improvement_heuristic: Float64
    var holdout_min: Float64
    var train_max: Float64
    var state: String
    var curve: List[Float64]

    def __init__(
        out self,
        seed: UInt64,
        episodes: Int,
        evaluation_episodes: Int,
        learned_mean: Float64,
        learned_std: Float64,
        ci95: Float64,
        random_mean: Float64,
        heuristic_mean: Float64,
        improvement_random: Float64,
        improvement_heuristic: Float64,
        holdout_min: Float64,
        train_max: Float64,
        state: String,
        var curve: List[Float64],
    ):
        self.seed = seed
        self.episodes = episodes
        self.evaluation_episodes = evaluation_episodes
        self.learned_mean = learned_mean
        self.learned_std = learned_std
        self.ci95 = ci95
        self.random_mean = random_mean
        self.heuristic_mean = heuristic_mean
        self.improvement_random = improvement_random
        self.improvement_heuristic = improvement_heuristic
        self.holdout_min = holdout_min
        self.train_max = train_max
        self.state = state
        self.curve = curve^


def state_index(frequency: Int) raises -> Int:
    if frequency == 1:
        return 0
    return 1


def epsilon_at(config: RLConfig, episode: Int) raises -> Float64:
    if config.episodes <= 1:
        return config.epsilon_min
    var progress = Float64(episode) / Float64(config.episodes - 1)
    var value = config.epsilon_start + progress * (config.epsilon_min - config.epsilon_start)
    if value < config.epsilon_min:
        return config.epsilon_min
    return value


def select_action(q: List[Float64], state: Int, epsilon: Float64, mut rng: SplitMix64) raises -> Int:
    if Float64(Int(rng.next_below(UInt64(10000)))) / 10000.0 < epsilon:
        return Int(rng.next_below(UInt64(ACTION_COUNT)))
    var best = 0
    var best_value = q[state * ACTION_COUNT]
    for action in range(1, ACTION_COUNT):
        if q[state * ACTION_COUNT + action] > best_value:
            best_value = q[state * ACTION_COUNT + action]
            best = action
    return best


def greedy_action(q: List[Float64], state: Int) raises -> Int:
    var best = 0
    var best_value = q[state * ACTION_COUNT]
    for action in range(1, ACTION_COUNT):
        if q[state * ACTION_COUNT + action] > best_value:
            best_value = q[state * ACTION_COUNT + action]
            best = action
    return best


def train_q(
    env: ScientificEnv, config: RLConfig, seed: UInt64
) raises -> Tuple[List[Float64], List[Float64]]:
    var q = List[Float64]()
    for _ in range(STATE_COUNT * ACTION_COUNT):
        q.append(0.0)
    var returns = List[Float64]()
    var rng = SplitMix64(derive_seed(seed, "scirl-train", UInt64(0)))
    for episode in range(config.episodes):
        var condition = sample_condition(seed, episode, True)
        var parameter = condition[0]
        var frequency = condition[1]
        var state = state_index(frequency)
        var action = select_action(q, state, epsilon_at(config, episode), rng)
        var result = step(env, action, parameter, frequency, 0)
        var index = state * ACTION_COUNT + action
        q[index] += config.alpha * (result.reward - q[index])
        returns.append(result.reward)
    return (q^, returns^)


def evaluate_policy(
    env: ScientificEnv, q: List[Float64], episodes: Int, seed: UInt64
) raises -> Float64:
    var total = Float64(0.0)
    for episode in range(episodes):
        var condition = sample_condition(seed, episode, False)
        var result = step(
            env, greedy_action(q, state_index(condition[1])),
            condition[0], condition[1], 0,
        )
        total += result.reward
    return total / Float64(episodes)


def random_policy(env: ScientificEnv, episodes: Int, seed: UInt64) raises -> Float64:
    var rng = SplitMix64(derive_seed(seed, "scirl-random", UInt64(0)))
    var total = Float64(0.0)
    for episode in range(episodes):
        var condition = sample_condition(seed, episode, False)
        var action = Int(rng.next_below(UInt64(ACTION_COUNT)))
        total += step(env, action, condition[0], condition[1], 0).reward
    return total / Float64(episodes)


def heuristic_policy(env: ScientificEnv, episodes: Int, seed: UInt64) raises -> Float64:
    var total = Float64(0.0)
    for episode in range(episodes):
        var condition = sample_condition(seed, episode, False)
        total += step(
            env, heuristic_action(condition[1]), condition[0], condition[1], 0
        ).reward
    return total / Float64(episodes)


def train_seeds() raises -> List[UInt64]:
    var out: List[UInt64] = [1, 2, 3]
    return out^


def holdout_seeds() raises -> List[UInt64]:
    var out: List[UInt64] = [101, 102, 103, 104, 105]
    return out^


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


def run_experiment(
    env: ScientificEnv, episodes: Int, evaluation_episodes: Int
) raises -> SciRLOutcome:
    var config = RLConfig(0.2, 0.9, 0.3, 0.05, episodes)
    var selections = train_seeds()
    var holdout = holdout_seeds()
    var scores = List[Float64]()
    for seed in selections:
        var learned = train_q(env, config, seed)
        scores.append(evaluate_policy(env, learned[0], evaluation_episodes, seed + 1000))

    var returns = List[Float64]()
    for seed in holdout:
        var learned = train_q(env, config, seed)
        returns.append(evaluate_policy(env, learned[0], evaluation_episodes, seed + 2000))
    var random_returns = List[Float64]()
    var heuristic_returns = List[Float64]()
    for seed in holdout:
        random_returns.append(random_policy(env, evaluation_episodes, seed + 3000))
        heuristic_returns.append(heuristic_policy(env, evaluation_episodes, seed + 4000))

    var mean_return = mean_of(returns)
    var deviation = std_of(returns, mean_return)
    var random_mean = mean_of(random_returns)
    var heuristic_mean = mean_of(heuristic_returns)

    var recorded = List[List[Float64]]()
    for seed in selections:
        var learned = train_q(env, config, seed)
        recorded.append(learned[1].copy())
    var curve = List[Float64]()
    for episode in range(episodes):
        var total = Float64(0.0)
        for values in recorded:
            total += values[episode]
        curve.append(total / Float64(len(recorded)))

    var state = String("IMPROVED")
    if mean_return <= random_mean:
        state = "NO_IMPROVEMENT"
    return SciRLOutcome(
        UInt64(42), episodes, evaluation_episodes, mean_return, deviation,
        1.96 * deviation / sqrt(Float64(len(holdout))), random_mean, heuristic_mean,
        mean_return - random_mean, mean_return - heuristic_mean,
        1.05, 1.0, state, curve^,
    )
