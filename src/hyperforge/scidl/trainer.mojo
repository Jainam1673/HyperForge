"""Training and evaluation for supervised scientific field regression."""

from std.math import sqrt, pow
from hyperforge.autodiff.tape import Tape
from hyperforge.autodl.model import (
    ArchCandidate,
    MLP,
    init_model,
    forward_tape,
    predict,
    serialize_model,
)
from hyperforge.scidl.task import SciDLTask, make_task, features, target
from hyperforge.sciml.problem import (
    registered_problem,
    finite_difference_solution,
)

comptime BETA1 = 0.9
comptime BETA2 = 0.999
comptime ADAM_EPS = 1e-8
comptime EPOCHS = 6
comptime LEARNING_RATE = 0.02
comptime WIDTH = 8


struct SciDLOutcome(Copyable, Movable):
    var seed: UInt64
    var epochs: Int
    var train_rmse: Float64
    var learned_rmse: Float64
    var learned_max_error: Float64
    var linear_rmse: Float64
    var fd_rmse: Float64
    var train_parameter_max: Float64
    var test_parameter_min: Float64
    var state: String
    var checkpoint: String

    def __init__(
        out self,
        seed: UInt64,
        epochs: Int,
        train_rmse: Float64,
        learned_rmse: Float64,
        learned_max_error: Float64,
        linear_rmse: Float64,
        fd_rmse: Float64,
        train_parameter_max: Float64,
        test_parameter_min: Float64,
        state: String,
        checkpoint: String,
    ):
        self.seed = seed
        self.epochs = epochs
        self.train_rmse = train_rmse
        self.learned_rmse = learned_rmse
        self.learned_max_error = learned_max_error
        self.linear_rmse = linear_rmse
        self.fd_rmse = fd_rmse
        self.train_parameter_max = train_parameter_max
        self.test_parameter_min = test_parameter_min
        self.state = state
        self.checkpoint = checkpoint


def train_field_model(
    mut model: MLP, task: SciDLTask, epochs: Int, learning_rate: Float64
) raises -> List[Float64]:
    var total = len(model.parameters)
    var momentum = List[Float64]()
    var velocity = List[Float64]()
    for _ in range(total):
        momentum.append(0.0)
        velocity.append(0.0)
    var losses = List[Float64]()

    for epoch in range(epochs):
        var epoch_loss = Float64(0.0)
        var samples = 0
        for parameter in task.train_parameters:
            for grid_x in task.grid:
                var input = features(grid_x, parameter)
                var expected = target(grid_x, parameter)
                var tape = Tape()
                var output = forward_tape(tape, model, input)
                var delta = tape.sub(output, tape.constant(expected))
                var loss_node = tape.mul(delta, delta)
                var loss_value = tape.value(loss_node)
                if loss_value != loss_value:
                    raise Error("non-finite SciDL loss")
                epoch_loss += loss_value
                samples += 1
                tape.backward(loss_node)
                var step = Float64(epoch * len(task.train_parameters) * len(task.grid) + samples)
                var correction1 = 1.0 - pow(BETA1, step)
                var correction2 = 1.0 - pow(BETA2, step)
                for p in range(total):
                    var gradient = tape.accumulated(p)
                    momentum[p] = BETA1 * momentum[p] + (1.0 - BETA1) * gradient
                    velocity[p] = BETA2 * velocity[p] + (1.0 - BETA2) * gradient * gradient
                    model.parameters[p] -= learning_rate * (
                        momentum[p] / correction1 / (sqrt(velocity[p] / correction2) + ADAM_EPS)
                    )
        losses.append(epoch_loss / Float64(samples))
    return losses^


def field_errors(
    model: MLP, task: SciDLTask, parameters: List[Float64]
) raises -> List[Float64]:
    var errors = List[Float64]()
    for parameter in parameters:
        for grid_x in task.grid:
            var input = features(grid_x, parameter)
            var prediction = predict(model, input)
            errors.append(prediction - target(grid_x, parameter))
    return errors^


def rmse(values: List[Float64]) raises -> Float64:
    var total = Float64(0.0)
    for value in values:
        total += value * value
    return sqrt(total / Float64(len(values)))


def max_absolute(values: List[Float64]) raises -> Float64:
    var worst = Float64(0.0)
    for value in values:
        var magnitude = value
        if magnitude < 0.0:
            magnitude = -magnitude
        if magnitude > worst:
            worst = magnitude
    return worst


def linear_coefficient(task: SciDLTask) raises -> Float64:
    var numerator = Float64(0.0)
    var denominator = Float64(0.0)
    for parameter in task.train_parameters:
        for grid_x in task.grid:
            var basis = parameter * target(grid_x, 1.0)
            numerator += basis * target(grid_x, parameter)
            denominator += basis * basis
    return numerator / denominator


def linear_errors(
    coefficient: Float64, task: SciDLTask, parameters: List[Float64]
) raises -> List[Float64]:
    var errors = List[Float64]()
    for parameter in parameters:
        for grid_x in task.grid:
            errors.append(coefficient * parameter * target(grid_x, 1.0) - target(grid_x, parameter))
    return errors^


def finite_difference_errors(
    task: SciDLTask, parameters: List[Float64]
) raises -> List[Float64]:
    var problem = registered_problem()
    var errors = List[Float64]()
    for parameter in parameters:
        var solution = finite_difference_solution(problem, parameter, task.grid)
        for i in range(len(task.grid)):
            errors.append(solution[i] - target(task.grid[i], parameter))
    return errors^


def run_experiment(seed: UInt64) raises -> SciDLOutcome:
    var task = make_task(seed)
    var candidate = ArchCandidate(
        "scidl", 2, WIDTH, LEARNING_RATE, len(task.grid), "tanh", seed
    )
    var model = init_model(candidate)
    var losses = train_field_model(model, task, EPOCHS, LEARNING_RATE)
    var learned = field_errors(model, task, task.test_parameters)
    var train = field_errors(model, task, task.train_parameters)
    var coefficient = linear_coefficient(task)
    var linear = linear_errors(coefficient, task, task.test_parameters)
    var fd = finite_difference_errors(task, task.test_parameters)

    var state = String("TRAINED")
    if losses[EPOCHS - 1] >= losses[0]:
        state = "NO_IMPROVEMENT"
    return SciDLOutcome(
        seed, EPOCHS, rmse(train), rmse(learned), max_absolute(learned),
        rmse(linear), rmse(fd), task.train_parameters[len(task.train_parameters) - 1],
        task.test_parameters[0], state, serialize_model(model),
    )
