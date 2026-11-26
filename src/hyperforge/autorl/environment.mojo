"""Small deterministic grid-world environment with explicit contracts.

Observation: integer state index `y * width + x`.
Actions: 0=up, 1=right, 2=down, 3=left.
Reward: -1 per non-terminal step, +10 on reaching the goal.
Termination: `terminated` only at the goal; `truncated` when the step budget
is exhausted. Calling `step` after either is an invalid transition.
No real-world actions or unsafe side effects exist.
"""

comptime ENV_SCHEMA = "hyperforge-autorl-grid-v1"
comptime ENV_NAME = "grid_4x4_two_walls"
comptime ACTION_COUNT = 4
comptime GOAL_REWARD = 10.0
comptime STEP_REWARD = -1.0


struct StepResult(Copyable, Movable):
    var next_state: Int
    var reward: Float64
    var terminated: Bool
    var truncated: Bool

    def __init__(out self, next_state: Int, reward: Float64, terminated: Bool, truncated: Bool):
        self.next_state = next_state
        self.reward = reward
        self.terminated = terminated
        self.truncated = truncated


struct GridWorld(Copyable, Movable):
    var width: Int
    var height: Int
    var start: Int
    var goal: Int
    var walls: List[Int]
    var max_steps: Int

    def __init__(
        out self,
        width: Int,
        height: Int,
        start: Int,
        goal: Int,
        var walls: List[Int],
        max_steps: Int,
    ):
        self.width = width
        self.height = height
        self.start = start
        self.goal = goal
        self.walls = walls^
        self.max_steps = max_steps


def grid_4x4() raises -> GridWorld:
    var walls: List[Int] = [5, 9]
    return GridWorld(4, 4, 0, 15, walls^, 24)


def state_count(env: GridWorld) raises -> Int:
    return env.width * env.height


def valid_state(env: GridWorld, state: Int) raises -> Bool:
    return state >= 0 and state < state_count(env)


def is_wall(env: GridWorld, state: Int) raises -> Bool:
    for wall in env.walls:
        if wall == state:
            return True
    return False


def step(env: GridWorld, state: Int, action: Int, elapsed_steps: Int) raises -> StepResult:
    if not valid_state(env, state):
        raise Error("invalid state")
    if action < 0 or action >= ACTION_COUNT:
        raise Error("invalid action")
    if state == env.goal:
        raise Error("step called after termination")
    if elapsed_steps >= env.max_steps:
        raise Error("step called after truncation")

    var x = state % env.width
    var y = state / env.width
    if action == 0:
        y -= 1
    elif action == 1:
        x += 1
    elif action == 2:
        y += 1
    else:
        x -= 1

    var next_state = state
    if x >= 0 and x < env.width and y >= 0 and y < env.height:
        var candidate = y * env.width + x
        if not is_wall(env, candidate):
            next_state = candidate

    var terminated = next_state == env.goal
    var reward = GOAL_REWARD if terminated else STEP_REWARD
    var truncated = (not terminated) and (elapsed_steps + 1 >= env.max_steps)
    return StepResult(next_state, reward, terminated, truncated)
