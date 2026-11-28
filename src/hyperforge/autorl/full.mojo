"""Full AutoRL breadth: algorithms, environments, safety, held-out evaluation."""

from std.math import sqrt
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.autorl.environment import (
    GridWorld, StepResult, ACTION_COUNT, GOAL_REWARD,
    grid_4x4, step, state_count,
)
from hyperforge.autorl.tabular import (
    RLConfig, value_iteration, q_from_values, greedy_action, epsilon_greedy,
    epsilon_at, train_q_learning, evaluate_policy, random_policy,
)

comptime FULL_RL_SCHEMA = "hyperforge-autorl-full-v1"


struct FullRLOutcome(Copyable, Movable):
    var algorithm: String
    var environment: String
    var seed: UInt64
    var episodes: Int
    var mean_return: Float64
    var return_std: Float64
    var success_rate: Float64
    var holdout_return: Float64
    var optimal_return: Float64
    var regret: Float64
    var safety_violations: Int
    var detail: String

    def __init__(
        out self,
        algorithm: String,
        environment: String,
        seed: UInt64,
        episodes: Int,
        mean_return: Float64,
        return_std: Float64,
        success_rate: Float64,
        holdout_return: Float64,
        optimal_return: Float64,
        regret: Float64,
        safety_violations: Int,
        detail: String,
    ):
        self.algorithm = algorithm
        self.environment = environment
        self.seed = seed
        self.episodes = episodes
        self.mean_return = mean_return
        self.return_std = return_std
        self.success_rate = success_rate
        self.holdout_return = holdout_return
        self.optimal_return = optimal_return
        self.regret = regret
        self.safety_violations = safety_violations
        self.detail = detail


def grid_5x5() raises -> GridWorld:
    var walls: List[Int] = [6, 7, 12, 17]
    return GridWorld(5, 5, 0, 24, walls^, 32)


def grid_4x4_holdout() raises -> GridWorld:
    # Different wall layout: never used for training or selection.
    var walls: List[Int] = [4, 6, 11]
    return GridWorld(4, 4, 0, 15, walls^, 24)


def make_environment(name: String) raises -> GridWorld:
    if name == "grid_4x4":
        return grid_4x4()
    if name == "grid_5x5":
        return grid_5x5()
    raise Error("unknown environment: " + name)


def forbidden_action(env: GridWorld, state: Int) raises -> Int:
    """Safety constraint: never choose an action that would enter a wall."""
    var x = state % env.width
    var y = state / env.width
    for action in range(ACTION_COUNT):
        var nx = x
        var ny = y
        if action == 0:
            ny -= 1
        elif action == 1:
            nx += 1
        elif action == 2:
            ny += 1
        else:
            nx -= 1
        if nx >= 0 and nx < env.width and ny >= 0 and ny < env.height:
            var candidate = ny * env.width + nx
            for wall in env.walls:
                if wall == candidate:
                    return action
    return -1


def safe_action(
    env: GridWorld, q: List[Float64], state: Int, epsilon: Float64, mut rng: SplitMix64
) raises -> Int:
    var action = epsilon_greedy(q, state, epsilon, rng)
    var forbidden = forbidden_action(env, state)
    if forbidden >= 0 and action == forbidden:
        # Choose the best remaining action; deterministic tie-break.
        var best = -1
        var best_value = -1e300
        for candidate in range(ACTION_COUNT):
            if candidate == forbidden:
                continue
            var value = q[state * ACTION_COUNT + candidate]
            if value > best_value:
                best_value = value
                best = candidate
        action = best
    return action


def train_sarsa(
    env: GridWorld, config: RLConfig, seed: UInt64
) raises -> Tuple[List[Float64], List[Float64]]:
    var states = state_count(env)
    var q = List[Float64]()
    for _ in range(states * ACTION_COUNT):
        q.append(0.0)
    var returns = List[Float64]()
    var rng = SplitMix64(derive_seed(seed, "autorl-sarsa", UInt64(0)))
    for episode in range(config.episodes):
        var epsilon = epsilon_at(config, episode)
        var state = env.start
        var action = safe_action(env, q, state, epsilon, rng)
        var total = 0.0
        var steps = 0
        while steps < env.max_steps:
            var result = step(env, state, action, steps)
            var next_action = safe_action(env, q, result.next_state, epsilon, rng)
            var next_value = q[result.next_state * ACTION_COUNT + next_action]
            if result.terminated:
                next_value = 0.0
            var index = state * ACTION_COUNT + action
            q[index] += config.alpha * (
                result.reward + config.gamma * next_value - q[index]
            )
            total += result.reward
            state = result.next_state
            action = next_action
            steps += 1
            if result.terminated:
                break
        returns.append(total)
    return (q^, returns^)


def train_double_q(
    env: GridWorld, config: RLConfig, seed: UInt64
) raises -> Tuple[List[Float64], List[Float64]]:
    var states = state_count(env)
    var q1 = List[Float64]()
    var q2 = List[Float64]()
    for _ in range(states * ACTION_COUNT):
        q1.append(0.0)
        q2.append(0.0)
    var returns = List[Float64]()
    var rng = SplitMix64(derive_seed(seed, "autorl-doubleq", UInt64(0)))
    for episode in range(config.episodes):
        var epsilon = epsilon_at(config, episode)
        var state = env.start
        var total = 0.0
        var steps = 0
        while steps < env.max_steps:
            var combined = List[Float64]()
            for i in range(len(q1)):
                combined.append(q1[i] + q2[i])
            var action = safe_action(env, combined, state, epsilon, rng)
            var result = step(env, state, action, steps)
            var next_best_action = greedy_action(combined, result.next_state)
            var next_value = 0.0
            if not result.terminated:
                if Int(rng.next_below(UInt64(2))) == 0:
                    next_value = q2[result.next_state * ACTION_COUNT + next_best_action]
                else:
                    next_value = q1[result.next_state * ACTION_COUNT + next_best_action]
            var index = state * ACTION_COUNT + action
            if Int(rng.next_below(UInt64(2))) == 0:
                q1[index] += config.alpha * (
                    result.reward + config.gamma * next_value - q1[index]
                )
            else:
                q2[index] += config.alpha * (
                    result.reward + config.gamma * next_value - q2[index]
                )
            total += result.reward
            state = result.next_state
            steps += 1
            if result.terminated:
                break
        returns.append(total)
    for i in range(len(q1)):
        q1[i] = (q1[i] + q2[i]) / 2.0
    return (q1^, returns^)


def train_from_values(
    env: GridWorld, config: RLConfig, seed: UInt64
) raises -> Tuple[List[Float64], List[Float64]]:
    var values = value_iteration(env, config.gamma, 1e-8, 200)
    var q = q_from_values(env, values, config.gamma)
    var returns = List[Float64]()
    var rng = SplitMix64(derive_seed(seed, "autorl-vi", UInt64(0)))
    for _ in range(config.episodes):
        var total = 0.0
        var state = env.start
        var steps = 0
        while steps < env.max_steps:
            var action = safe_action(env, q, state, 0.0, rng)
            var result = step(env, state, action, steps)
            total += result.reward
            state = result.next_state
            steps += 1
            if result.terminated:
                break
        returns.append(total)
    return (q^, returns^)


def mean_of(values: List[Float64]) raises -> Float64:
    if len(values) == 0:
        return 0.0
    var total = 0.0
    for i in range(len(values)):
        total += values[i]
    return total / Float64(len(values))


def std_of(values: List[Float64], mean: Float64) raises -> Float64:
    if len(values) < 2:
        return 0.0
    var total = 0.0
    for i in range(len(values)):
        var delta = values[i] - mean
        total += delta * delta
    return sqrt(total / Float64(len(values) - 1))


def run_full_rl(
    algorithm: String,
    environment: String,
    episodes: Int,
    evaluation_episodes: Int,
    seed: UInt64,
    seeds: Int,
) raises -> FullRLOutcome:
    if episodes < 1 or evaluation_episodes < 1 or seeds < 1:
        raise Error("episodes, evaluation_episodes and seeds must be positive")
    var env = make_environment(environment)
    var holdout = grid_4x4_holdout()
    var config = RLConfig(0.2, 0.95, 1.0, 0.05, episodes, evaluation_episodes)
    var best_q = List[Float64]()
    var all_returns = List[Float64]()
    var successes = 0
    var violations = 0

    for s in range(seeds):
        var seed_value = derive_seed(seed, "autorl-seed", UInt64(s))
        var q: List[Float64]
        var returns: List[Float64]
        if algorithm == "q_learning":
            var pair = train_q_learning(env, config, seed_value)
            q = pair[0].copy()
            returns = pair[1].copy()
        elif algorithm == "sarsa":
            var pair = train_sarsa(env, config, seed_value)
            q = pair[0].copy()
            returns = pair[1].copy()
        elif algorithm == "double_q":
            var pair = train_double_q(env, config, seed_value)
            q = pair[0].copy()
            returns = pair[1].copy()
        elif algorithm == "value_iteration":
            var pair = train_from_values(env, config, seed_value)
            q = pair[0].copy()
            returns = pair[1].copy()
        elif algorithm == "random":
            q = List[Float64]()
            for _ in range(state_count(env) * ACTION_COUNT):
                q.append(0.0)
            returns = List[Float64]()
            for _ in range(episodes):
                returns.append(random_policy(env, 1, seed_value))
        else:
            raise Error("unknown AutoRL algorithm: " + algorithm)

        best_q = q.copy()
        for i in range(len(returns)):
            all_returns.append(returns[i])
            if returns[i] > 0.0:
                successes += 1
        var rng = SplitMix64(derive_seed(seed_value, "autorl-safety", UInt64(0)))
        for _ in range(evaluation_episodes):
            var state = env.start
            var steps = 0
            while steps < env.max_steps:
                var action = safe_action(env, q, state, 0.0, rng)
                if forbidden_action(env, state) == action:
                    violations += 1
                var result = step(env, state, action, steps)
                state = result.next_state
                steps += 1
                if result.terminated:
                    break

    var mean_return = mean_of(all_returns)
    var success_rate = Float64(successes) / Float64(len(all_returns)) if len(all_returns) > 0 else 0.0
    var holdout_return = evaluate_policy(holdout, best_q, evaluation_episodes, seed)
    var optimal_values = value_iteration(env, config.gamma, 1e-8, 200)
    var q_star = q_from_values(env, optimal_values, config.gamma)
    var optimal_return = evaluate_policy(env, q_star, evaluation_episodes, seed)

    return FullRLOutcome(
        algorithm, environment, seed, episodes, mean_return,
        std_of(all_returns, mean_return), success_rate, holdout_return,
        optimal_return, optimal_return - holdout_return, violations,
        "safe action constraints; held-out wall layout; repeated seeds",
    )
