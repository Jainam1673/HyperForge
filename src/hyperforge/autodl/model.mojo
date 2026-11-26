"""Explicit multi-layer perceptron over the verified reverse-mode tape.

Architectures differ structurally in depth and width; this is not merely
hyperparameter tuning. Every parameter is a tape parameter node, so gradients
cannot be silently detached.
"""

from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.autodiff.tape import Tape

comptime MODEL_SCHEMA = "hyperforge-autodl-mlp-v1"
comptime ACTIVATION_TANH = "tanh"
comptime ACTIVATION_RELU = "relu"


struct ArchCandidate(Copyable, Movable):
    var id: String
    var depth: Int
    var width: Int
    var learning_rate: Float64
    var batch_size: Int
    var activation: String
    var seed: UInt64

    def __init__(
        out self,
        id: String,
        depth: Int,
        width: Int,
        learning_rate: Float64,
        batch_size: Int,
        activation: String,
        seed: UInt64,
    ):
        self.id = id
        self.depth = depth
        self.width = width
        self.learning_rate = learning_rate
        self.batch_size = batch_size
        self.activation = activation
        self.seed = seed


struct MLP(Copyable, Movable):
    var parameters: List[Float64]
    var depth: Int
    var width: Int
    var activation: String

    def __init__(out self, var parameters: List[Float64], depth: Int, width: Int, activation: String):
        self.parameters = parameters^
        self.depth = depth
        self.width = width
        self.activation = activation


def valid_candidate(candidate: ArchCandidate) raises -> Bool:
    if candidate.depth < 1 or candidate.depth > 3:
        return False
    if candidate.width != 4 and candidate.width != 8 and candidate.width != 16:
        return False
    if candidate.learning_rate <= 0.0 or candidate.learning_rate > 0.1:
        return False
    if candidate.batch_size != 4 and candidate.batch_size != 8 and candidate.batch_size != 16:
        return False
    return candidate.activation == ACTIVATION_TANH or candidate.activation == ACTIVATION_RELU


def parameter_count(depth: Int, width: Int) raises -> Int:
    if depth == 1:
        return 3 * width + 1
    return 3 * width + (depth - 2) * width * (width + 1) + width + 1


def layer_offset(layer: Int, depth: Int, width: Int) raises -> Int:
    if layer == 0:
        return 0
    return 3 * width + (layer - 1) * width * (width + 1)


def init_model(candidate: ArchCandidate) raises -> MLP:
    if not valid_candidate(candidate):
        raise Error("invalid architecture candidate")
    var rng = SplitMix64(derive_seed(candidate.seed, "autodl-init", UInt64(0)))
    var parameters = List[Float64]()
    for _ in range(parameter_count(candidate.depth, candidate.width)):
        parameters.append(Float64(Int(rng.next_below(UInt64(1001))) - 500) / 1000.0)
    return MLP(parameters^, candidate.depth, candidate.width, candidate.activation)


def forward_tape(
    mut tape: Tape, model: MLP, features: List[Float64]
) raises -> Int:
    var inputs = List[Int]()
    for value in features:
        inputs.append(tape.constant(value))

    for layer in range(model.depth):
        var in_dim = len(inputs)
        var out_dim = model.width
        var is_output = layer == model.depth - 1
        if is_output:
            out_dim = 1
        var offset = layer_offset(layer, model.depth, model.width)
        var outputs = List[Int]()
        for out in range(out_dim):
            var z = tape.constant(0.0)
            for input_index in range(in_dim):
                var weight_index = offset + out * in_dim + input_index
                z = tape.add(
                    z,
                    tape.mul(
                        inputs[input_index],
                        tape.parameter(model.parameters[weight_index], weight_index),
                    ),
                )
            var bias_index = offset + out * in_dim + in_dim
            z = tape.add(z, tape.parameter(model.parameters[bias_index], bias_index))
            if is_output:
                var negated = tape.scale(z, -1.0)
                var denominator = tape.add(tape.constant(1.0), tape.exp(negated))
                outputs.append(tape.divide(tape.constant(1.0), denominator))
            elif model.activation == ACTIVATION_RELU:
                outputs.append(tape.relu(z))
            else:
                outputs.append(tape.tanh(z))
        inputs = outputs^
    return inputs[0]


def predict(model: MLP, features: List[Float64]) raises -> Float64:
    var tape = Tape()
    var node = forward_tape(tape, model, features)
    return tape.value(node)


def serialize_model(model: MLP) raises -> String:
    var out = String(
        MODEL_SCHEMA + "|depth=" + String(model.depth) + "|width=" + String(model.width)
        + "|activation=" + model.activation + "|params="
    )
    for i in range(len(model.parameters)):
        if i > 0:
            out += ","
        out += String(model.parameters[i])
    return out + "\n"


def deserialize_model(text: String) raises -> MLP:
    var clean = String("")
    var limit = text.byte_length()
    if text.endswith("\n"):
        limit -= 1
    for i in range(limit):
        clean += String(text[byte=i])
    var parts = clean.split("|")
    if len(parts) != 5:
        raise Error("invalid MLP artifact")
    var depth = Int(String(parts[1]).replace("depth=", ""))
    var width = Int(String(parts[2]).replace("width=", ""))
    var activation = String(parts[3]).replace("activation=", "")
    var values = List[Float64]()
    for cell in String(parts[4]).replace("params=", "").split(","):
        values.append(Float64(String(cell)))
    if len(values) != parameter_count(depth, width):
        raise Error("MLP artifact parameter count mismatch")
    return MLP(values^, depth, width, activation)
