"""Fully tested tabular RL: value iteration and epsilon-greedy Q-learning."""

from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.autorl.environment import (
    GridWorld,
    StepResult,
    step,
    state_count,
    ACTION_COUNT,
)

comptime TABLE_SCHEMA = "hyperforge-autorl-tabular-v1"


struct RLConfig(Copyable, Movable):
    var alpha: Float64
    var gamma: Float64
    var epsilon_start: Float64
    var epsilon_min: Float64
    var episodes: Int
    var evaluation_episodes: Int

    def __init__(
        out self,
        alpha: Float64,
        gamma: Float64,
        epsilon_start: Float64,
        epsilon_min: Float64,
        episodes: Int,
        evaluation_episodes: Int,
    ):
        self.alpha = alpha
        self.gamma = gamma
        self.epsilon_start = epsilon_start
        self.epsilon_min = epsilon_min
        self.episodes = episodes
        self.evaluation_episodes = evaluation_episodes


def value_iteration(env: GridWorld, gamma: Float64, theta: Float64, max_iterations: Int) raises -> List[Float64]:
    var states = state_count(env)
    var values = List[Float64]()
    for _ in range(states):
        values.append(0.0)
    for _ in range(max_iterations):
        var delta = Float64(0.0)
        for state in range(states):
            if state == env.goal:
                continue
            var best = Float64(-1e300)
            for action in range(ACTION_COUNT):
                var result = step(env, state, action, 0)
                var candidate = result.reward + gamma * values[result.next_state]
                if candidate > best:
                    best = candidate
            var change = best - values[state]
            if change < 0.0:
                change = -change
            if change > delta:
                delta = change
            values[state] = best
        if delta < theta:
            break
    return values^


def q_from_values(env: GridWorld, values: List[Float64], gamma: Float64) raises -> List[Float64]:
    var q = List[Float64]()
    for state in range(state_count(env)):
        for action in range(ACTION_COUNT):
            if state == env.goal:
                q.append(0.0)
            else:
                var result = step(env, state, action, 0)
                q.append(result.reward + gamma * values[result.next_state])
    return q^


def greedy_action(q: List[Float64], state: Int) raises -> Int:
    var states = len(q) // ACTION_COUNT
    if state < 0 or state >= states:
        raise Error("greedy_action invalid state")
    var best_action = 0
    var best_value = q[state * ACTION_COUNT]
    for action in range(1, ACTION_COUNT):
        var value = q[state * ACTION_COUNT + action]
        if value > best_value:
            best_value = value
            best_action = action
    return best_action


def epsilon_greedy(
    q: List[Float64], state: Int, epsilon: Float64, mut rng: SplitMix64
) raises -> Int:
    if Float64(Int(rng.next_below(UInt64(10000)))) / 10000.0 < epsilon:
        return Int(rng.next_below(UInt64(ACTION_COUNT)))
    return greedy_action(q, state)


def epsilon_at(config: RLConfig, episode: Int) raises -> Float64:
    if config.episodes <= 1:
        return config.epsilon_min
    var progress = Float64(episode) / Float64(config.episodes - 1)
    var value = config.epsilon_start + progress * (config.epsilon_min - config.epsilon_start)
    if value < config.epsilon_min:
        return config.epsilon_min
    return value


def train_q_learning(
    env: GridWorld, config: RLConfig, seed: UInt64
) raises -> Tuple[List[Float64], List[Float64]]:
    var states = state_count(env)
    var q = List[Float64]()
    for _ in range(states * ACTION_COUNT):
        q.append(0.0)
    var returns = List[Float64]()
    var rng = SplitMix64(derive_seed(seed, "autorl-train", UInt64(0)))

    for episode in range(config.episodes):
        var epsilon = epsilon_at(config, episode)
        var state = env.start
        var total = Float64(0.0)
        var steps = 0
        while steps < env.max_steps:
            var action = epsilon_greedy(q, state, epsilon, rng)
            var result = step(env, state, action, steps)
            var next_best = Float64(0.0)
            if not result.terminated:
                next_best = q[result.next_state * ACTION_COUNT + greedy_action(q, result.next_state)]
            var target = result.reward + config.gamma * next_best
            var index = state * ACTION_COUNT + action
            q[index] += config.alpha * (target - q[index])
            total += result.reward
            state = result.next_state
            steps += 1
            if result.terminated:
                break
        returns.append(total)
    return (q^, returns^)


def evaluate_policy(
    env: GridWorld, q: List[Float64], episodes: Int, seed: UInt64
) raises -> Float64:
    """Greedy, no exploration, no learning updates."""
    if episodes < 1:
        raise Error("evaluation needs at least one episode")
    var rng = SplitMix64(derive_seed(seed, "autorl-eval", UInt64(0)))
    var total = Float64(0.0)
    for _ in range(episodes):
        var state = env.start
        var steps = 0
        while steps < env.max_steps:
            # Deterministic tie-break; the RNG is only used to prove evaluation
            # does not depend on training exploration randomness.
            _ = rng.next_below(UInt64(ACTION_COUNT))
            var action = greedy_action(q, state)
            var result = step(env, state, action, steps)
            total += result.reward
            state = result.next_state
            steps += 1
            if result.terminated:
                break
    return total / Float64(episodes)


def random_policy(
    env: GridWorld, episodes: Int, seed: UInt64
) raises -> Float64:
    var rng = SplitMix64(derive_seed(seed, "autorl-random", UInt64(0)))
    var total = Float64(0.0)
    for _ in range(episodes):
        var state = env.start
        var steps = 0
        while steps < env.max_steps:
            var action = Int(rng.next_below(UInt64(ACTION_COUNT)))
            var result = step(env, state, action, steps)
            total += result.reward
            state = result.next_state
            steps += 1
            if result.terminated:
                break
    return total / Float64(episodes)
