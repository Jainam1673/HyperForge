"""Configurable transformer for AutoTransformers configuration search.

This is a plain CPU reference implementation over the verified reverse-mode
tape and attention kernel. No FlashAttention, fused kernel, GPU inference, or
MAX-serving capability is implied by this module.
"""

from std.math import sqrt
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.autodiff.tape import Tape
from hyperforge.scit.attention import attention_tape
from hyperforge.scit.task import TaskSpec, coordinate_encoding

comptime MODEL_SCHEMA = "hyperforge-autotrans-model-v1"
comptime INPUT_FEATURES = 5


struct TransformerConfig(Copyable, Movable):
    var d_model: Int
    var heads: Int
    var ff_hidden: Int
    var layers: Int
    var history: Int
    var seed: UInt64

    def __init__(out self, d_model: Int, heads: Int, ff_hidden: Int, layers: Int, history: Int, seed: UInt64):
        self.d_model = d_model
        self.heads = heads
        self.ff_hidden = ff_hidden
        self.layers = layers
        self.history = history
        self.seed = seed


struct TransformerModel(Copyable, Movable):
    var parameters: List[Float64]
    var config: TransformerConfig

    def __init__(out self, var parameters: List[Float64], config: TransformerConfig):
        self.parameters = parameters^
        self.config = config.copy()


def valid_config(config: TransformerConfig) raises -> Bool:
    if config.d_model != 4 and config.d_model != 8:
        return False
    if config.heads < 1 or config.heads > 2 or config.d_model % config.heads != 0:
        return False
    if config.ff_hidden != 4 and config.ff_hidden != 8 and config.ff_hidden != 16:
        return False
    if config.layers < 1 or config.layers > 2:
        return False
    if config.history != 2 and config.history != 3:
        return False
    return True


def parameter_count(config: TransformerConfig) raises -> Int:
    var per_layer = 3 * config.d_model * config.d_model + config.d_model * config.d_model
    per_layer += config.d_model * config.ff_hidden + config.ff_hidden
    per_layer += config.ff_hidden * config.d_model + config.d_model
    return INPUT_FEATURES * config.d_model + config.d_model + config.layers * per_layer + config.d_model + 1


def init_model(config: TransformerConfig) raises -> TransformerModel:
    if not valid_config(config):
        raise Error("invalid transformer configuration")
    var rng = SplitMix64(derive_seed(config.seed, "autotrans-init", UInt64(0)))
    var parameters = List[Float64]()
    for _ in range(parameter_count(config)):
        parameters.append(Float64(Int(rng.next_below(UInt64(1001))) - 500) / 1000.0)
    return TransformerModel(parameters^, config)


def rms_norm(mut tape: Tape, nodes: List[Int]) raises -> List[Int]:
    var sum_squares = tape.constant(0.0)
    for node in nodes:
        sum_squares = tape.add(sum_squares, tape.mul(node, node))
    var mean_square = tape.scale(sum_squares, 1.0 / Float64(len(nodes)))
    var root = tape.sqrt(tape.add(mean_square, tape.constant(1e-5)))
    var out = List[Int]()
    for node in nodes:
        out.append(tape.divide(node, root))
    return out^


def forward_tape(
    mut tape: Tape, model: TransformerModel, spec: TaskSpec, inputs: List[List[Float64]]
) raises -> List[Int]:
    var config = model.config.copy()
    var position = 0

    # Shared embedding parameters: one bias, one value weight, and one weight
    # per coordinate feature for each model dimension.
    var embed_bias = List[Int]()
    var embed_value = List[Int]()
    var embed_coord = List[List[Int]]()
    for _ in range(config.d_model):
        embed_bias.append(tape.parameter(model.parameters[position], position))
        position += 1
        embed_value.append(tape.parameter(model.parameters[position], position))
        position += 1
        var weights = List[Int]()
        for _ in range(INPUT_FEATURES - 1):
            weights.append(tape.parameter(model.parameters[position], position))
            position += 1
        embed_coord.append(weights^)

    var tokens = List[List[Int]]()
    for cell in range(spec.grid_points):
        var encoding = coordinate_encoding(spec, cell, config.history - 1)
        var embedded = List[Int]()
        for d in range(config.d_model):
            var total = tape.add(
                embed_bias[d],
                tape.mul(
                    tape.constant(inputs[config.history - 1][cell]), embed_value[d]
                ),
            )
            for c in range(len(encoding)):
                total = tape.add(
                    total,
                    tape.mul(tape.constant(encoding[c]), embed_coord[d][c]),
                )
            embedded.append(total)
        tokens.append(embedded^)

    var mask = List[Bool]()
    for _ in range(spec.grid_points):
        mask.append(False)

    var normalized = List[List[Int]]()
    for cell in range(spec.grid_points):
        normalized.append(rms_norm(tape, tokens[cell].copy()))

    for _ in range(config.layers):
        var head_dim = config.d_model // config.heads
        # Shared Q/K/V weights for this layer: [head][role * head_dim * d + out * d + in]
        var qkv = List[List[Int]]()
        for _ in range(config.heads):
            var weights = List[Int]()
            for _ in range(3 * head_dim * config.d_model):
                weights.append(tape.parameter(model.parameters[position], position))
                position += 1
            qkv.append(weights^)

        var keys = List[List[List[Int]]]()
        var values = List[List[List[Int]]]()
        for head in range(config.heads):
            var head_keys = List[List[Int]]()
            var head_values = List[List[Int]]()
            for cell in range(spec.grid_points):
                var key_part = List[Int]()
                var value_part = List[Int]()
                for out_d in range(head_dim):
                    var key_projection = tape.constant(0.0)
                    var value_projection = tape.constant(0.0)
                    for source in range(config.d_model):
                        var key_index = (head_dim + out_d) * config.d_model + source
                        var value_index = (2 * head_dim + out_d) * config.d_model + source
                        key_projection = tape.add(
                            key_projection,
                            tape.mul(normalized[cell][source], qkv[head][key_index]),
                        )
                        value_projection = tape.add(
                            value_projection,
                            tape.mul(normalized[cell][source], qkv[head][value_index]),
                        )
                    key_part.append(key_projection)
                    value_part.append(value_projection)
                head_keys.append(key_part^)
                head_values.append(value_part^)
            keys.append(head_keys^)
            values.append(head_values^)

        # Shared attention output projection: [flat_input][out].
        var out_weights = List[List[Int]]()
        for _ in range(config.d_model):
            var row = List[Int]()
            for _ in range(config.d_model):
                row.append(tape.parameter(model.parameters[position], position))
                position += 1
            out_weights.append(row^)

        var attended = List[List[Int]]()
        for cell in range(spec.grid_points):
            var combined = List[Int]()
            for _ in range(config.d_model):
                combined.append(tape.constant(0.0))
            for head in range(config.heads):
                var query = List[Int]()
                for out_d in range(head_dim):
                    var projection = tape.constant(0.0)
                    for source in range(config.d_model):
                        var index = out_d * config.d_model + source
                        projection = tape.add(
                            projection,
                            tape.mul(normalized[cell][source], qkv[head][index]),
                        )
                    query.append(projection)
                var scale = 1.0 / sqrt(Float64(head_dim))
                var head_output = attention_tape(
                    tape, query, keys[head], values[head], mask, scale
                )
                for in_d in range(head_dim):
                    for out_d in range(config.d_model):
                        combined[out_d] = tape.add(
                            combined[out_d],
                            tape.mul(
                                head_output[in_d],
                                out_weights[head * head_dim + in_d][out_d],
                            ),
                        )
            attended.append(combined^)

        var residual = List[List[Int]]()
        for cell in range(spec.grid_points):
            var row = List[Int]()
            for d in range(config.d_model):
                row.append(tape.add(tokens[cell][d], attended[cell][d]))
            residual.append(row^)
        var second_norm = List[List[Int]]()
        for cell in range(spec.grid_points):
            second_norm.append(rms_norm(tape, residual[cell].copy()))

        # Shared FFN weights.
        var w1 = List[List[Int]]()
        for _ in range(config.ff_hidden):
            var row = List[Int]()
            for _ in range(config.d_model):
                row.append(tape.parameter(model.parameters[position], position))
                position += 1
            w1.append(row^)
        var b1 = List[Int]()
        for _ in range(config.ff_hidden):
            b1.append(tape.parameter(model.parameters[position], position))
            position += 1
        var w2 = List[List[Int]]()
        for _ in range(config.d_model):
            var row = List[Int]()
            for _ in range(config.ff_hidden):
                row.append(tape.parameter(model.parameters[position], position))
                position += 1
            w2.append(row^)
        var b2 = List[Int]()
        for _ in range(config.d_model):
            b2.append(tape.parameter(model.parameters[position], position))
            position += 1

        var hidden = List[List[Int]]()
        for cell in range(spec.grid_points):
            var activations = List[Int]()
            for j in range(config.ff_hidden):
                var value = b1[j]
                for d in range(config.d_model):
                    value = tape.add(
                        value,
                        tape.mul(second_norm[cell][d], w1[j][d]),
                    )
                activations.append(tape.tanh(value))
            hidden.append(activations^)

        var fed = List[List[Int]]()
        for cell in range(spec.grid_points):
            var row = List[Int]()
            for d in range(config.d_model):
                var value = b2[d]
                for j in range(config.ff_hidden):
                    value = tape.add(value, tape.mul(hidden[cell][j], w2[d][j]))
                row.append(value)
            fed.append(row^)

        tokens = List[List[Int]]()
        for cell in range(spec.grid_points):
            var row = List[Int]()
            for d in range(config.d_model):
                row.append(tape.add(residual[cell][d], fed[cell][d]))
            tokens.append(row^)

    var output_bias = tape.parameter(model.parameters[position], position)
    position += 1
    var output_weights = List[Int]()
    for _ in range(config.d_model):
        output_weights.append(tape.parameter(model.parameters[position], position))
        position += 1
    var predictions = List[Int]()
    for cell in range(spec.grid_points):
        var value = output_bias
        for d in range(config.d_model):
            value = tape.add(value, tape.mul(tokens[cell][d], output_weights[d]))
        predictions.append(value)
    return predictions^


def predict(model: TransformerModel, spec: TaskSpec, inputs: List[List[Float64]]) raises -> List[Float64]:
    var tape = Tape()
    var nodes = forward_tape(tape, model, spec, inputs)
    var out = List[Float64]()
    for node in nodes:
        out.append(tape.value(node))
    return out^


def serialize_model(model: TransformerModel) raises -> String:
    var config = model.config.copy()
    var out = String(
        MODEL_SCHEMA + "|d=" + String(config.d_model) + "|h=" + String(config.heads)
        + "|ff=" + String(config.ff_hidden) + "|layers=" + String(config.layers)
        + "|history=" + String(config.history) + "|params="
    )
    for i in range(len(model.parameters)):
        if i > 0:
            out += ","
        out += String(model.parameters[i])
    return out + "\n"


def deserialize_model(text: String) raises -> TransformerModel:
    var clean = String("")
    var limit = text.byte_length()
    if text.endswith("\n"):
        limit -= 1
    for i in range(limit):
        clean += String(text[byte=i])
    var parts = clean.split("|")
    if len(parts) != 7:
        raise Error("invalid transformer artifact")
    var config = TransformerConfig(
        Int(String(parts[1]).replace("d=", "")),
        Int(String(parts[2]).replace("h=", "")),
        Int(String(parts[3]).replace("ff=", "")),
        Int(String(parts[4]).replace("layers=", "")),
        Int(String(parts[5]).replace("history=", "")),
        UInt64(0),
    )
    var values = List[Float64]()
    for cell in String(parts[6]).replace("params=", "").split(","):
        values.append(Float64(String(cell)))
    if len(values) != parameter_count(config):
        raise Error("transformer parameter count mismatch")
    return TransformerModel(values^, config)
