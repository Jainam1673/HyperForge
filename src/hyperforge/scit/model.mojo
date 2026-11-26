"""Tiny scientific transformer: two-head attention encoder with residual FFN.

The reference kernel is plain scalar attention over tape nodes; no fused or
GPU implementation is claimed. Shapes are explicit and validated at runtime.
"""

from std.math import sqrt
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.autodiff.tape import Tape
from hyperforge.scit.attention import attention_tape
from hyperforge.scit.task import TaskSpec, coordinate_encoding

comptime MODEL_SCHEMA = "hyperforge-scit-model-v1"
comptime D_MODEL = 4
comptime HEADS = 2
comptime HEAD_DIM = 2
comptime HIDDEN = 4
comptime PARAM_COUNT = 128
comptime NORM_EPS = 1e-5


struct SciTransformer(Copyable, Movable):
    var parameters: List[Float64]
    var grid_points: Int

    def __init__(out self, var parameters: List[Float64], grid_points: Int):
        self.parameters = parameters^
        self.grid_points = grid_points


def init_model(seed: UInt64, grid_points: Int) raises -> SciTransformer:
    var rng = SplitMix64(derive_seed(seed, "scit-init", UInt64(0)))
    var parameters = List[Float64]()
    for _ in range(PARAM_COUNT):
        parameters.append(Float64(Int(rng.next_below(UInt64(1001))) - 500) / 1000.0)
    return SciTransformer(parameters^, grid_points)


def p_embed_value(d: Int) raises -> Int:
    return d


def p_embed_coord(c: Int, d: Int) raises -> Int:
    return 4 + c * D_MODEL + d


def p_attention(head: Int, kind: Int, out_d: Int, in_d: Int) raises -> Int:
    return 20 + head * 24 + kind * 8 + out_d * D_MODEL + in_d


def p_attention_output(head: Int, out_d: Int, in_d: Int) raises -> Int:
    return 68 + head * 8 + out_d * HEAD_DIM + in_d


def p_ffn1(j: Int, d: Int) raises -> Int:
    return 84 + j * D_MODEL + d


def p_ffn1_bias(j: Int) raises -> Int:
    return 100 + j


def p_ffn2(j: Int, d: Int) raises -> Int:
    return 104 + j * D_MODEL + d


def p_ffn2_bias(d: Int) raises -> Int:
    return 120 + d


def p_output(d: Int) raises -> Int:
    return 124 + d


def rms_norm(mut tape: Tape, nodes: List[Int]) raises -> List[Int]:
    var sum_squares = tape.constant(0.0)
    for node in nodes:
        sum_squares = tape.add(sum_squares, tape.mul(node, node))
    var mean_square = tape.scale(sum_squares, 1.0 / Float64(len(nodes)))
    var root = tape.sqrt(tape.add(mean_square, tape.constant(NORM_EPS)))
    var out = List[Int]()
    for node in nodes:
        out.append(tape.divide(node, root))
    return out^


def project(
    mut tape: Tape,
    model: SciTransformer,
    nodes: List[Int],
    head: Int,
    kind: Int,
) raises -> List[Int]:
    """Project D_MODEL inputs to HEAD_DIM outputs for one head and role."""
    var out = List[Int]()
    for d in range(HEAD_DIM):
        var total = tape.constant(0.0)
        for source in range(D_MODEL):
            var index = p_attention(head, kind, d, source)
            total = tape.add(
                total,
                tape.mul(nodes[source], tape.parameter(model.parameters[index], index)),
            )
        out.append(total)
    return out^


def forward_tape(
    mut tape: Tape, model: SciTransformer, spec: TaskSpec, inputs: List[List[Float64]]
) raises -> List[Int]:
    if len(inputs) != spec.history:
        raise Error("input history length mismatch")
    for frame in inputs:
        if len(frame) != spec.grid_points:
            raise Error("input grid shape mismatch")

    var tokens = List[List[Int]]()
    for cell in range(spec.grid_points):
        var encoding = coordinate_encoding(spec, cell, spec.history - 1)
        var embedded = List[Int]()
        for d in range(D_MODEL):
            var accumulator = tape.constant(0.0)
            var value_index = p_embed_value(d)
            accumulator = tape.add(
                accumulator,
                tape.mul(
                    tape.constant(inputs[spec.history - 1][cell]),
                    tape.parameter(model.parameters[value_index], value_index),
                ),
            )
            for c in range(len(encoding)):
                var index = p_embed_coord(c, d)
                accumulator = tape.add(
                    accumulator,
                    tape.mul(
                        tape.constant(encoding[c]),
                        tape.parameter(model.parameters[index], index),
                    ),
                )
            embedded.append(accumulator)
        tokens.append(embedded^)

    var mask = List[Bool]()
    for _ in range(spec.grid_points):
        mask.append(False)

    var normalized_tokens = List[List[Int]]()
    for cell in range(spec.grid_points):
        normalized_tokens.append(rms_norm(tape, tokens[cell].copy()))

    var keys_per_head = List[List[List[Int]]]()
    var values_per_head = List[List[List[Int]]]()
    for head in range(HEADS):
        var head_keys = List[List[Int]]()
        var head_values = List[List[Int]]()
        for token in range(spec.grid_points):
            head_keys.append(project(tape, model, normalized_tokens[token], head, 1))
            head_values.append(project(tape, model, normalized_tokens[token], head, 2))
        keys_per_head.append(head_keys^)
        values_per_head.append(head_values^)

    var attended = List[List[Int]]()
    for token in range(spec.grid_points):
        var combined = List[Int]()
        for _ in range(D_MODEL):
            combined.append(tape.constant(0.0))
        for head in range(HEADS):
            var query = project(tape, model, normalized_tokens[token], head, 0)
            var scale = 1.0 / sqrt(Float64(HEAD_DIM))
            var attended_head = attention_tape(
                tape, query, keys_per_head[head], values_per_head[head], mask, scale
            )
            for out_d in range(D_MODEL):
                for in_d in range(HEAD_DIM):
                    var index = p_attention_output(head, out_d, in_d)
                    combined[out_d] = tape.add(
                        combined[out_d],
                        tape.mul(
                            attended_head[in_d],
                            tape.parameter(model.parameters[index], index),
                        ),
                    )
        attended.append(combined^)

    var residual = List[List[Int]]()
    for cell in range(spec.grid_points):
        var row = List[Int]()
        for d in range(D_MODEL):
            row.append(tape.add(tokens[cell][d], attended[cell][d]))
        residual.append(row^)

    var second_norms = List[List[Int]]()
    for cell in range(spec.grid_points):
        second_norms.append(rms_norm(tape, residual[cell].copy()))

    var fed = List[List[Int]]()
    for cell in range(spec.grid_points):
        var hidden = List[Int]()
        for j in range(HIDDEN):
            var activation = tape.constant(0.0)
            for d in range(D_MODEL):
                var index = p_ffn1(j, d)
                activation = tape.add(
                    activation,
                    tape.mul(
                        second_norms[cell][d],
                        tape.parameter(model.parameters[index], index),
                    ),
                )
            var bias = p_ffn1_bias(j)
            activation = tape.tanh(
                tape.add(activation, tape.parameter(model.parameters[bias], bias))
            )
            hidden.append(activation)

        var output_row = List[Int]()
        for d in range(D_MODEL):
            var bias = p_ffn2_bias(d)
            var value = tape.parameter(model.parameters[bias], bias)
            for j in range(HIDDEN):
                var index = p_ffn2(j, d)
                value = tape.add(
                    value,
                    tape.mul(hidden[j], tape.parameter(model.parameters[index], index)),
                )
            output_row.append(value)
        fed.append(output_row^)

    var predictions = List[Int]()
    for cell in range(spec.grid_points):
        var value = tape.constant(0.0)
        for d in range(D_MODEL):
            var index = p_output(d)
            value = tape.add(
                value,
                tape.mul(fed[cell][d], tape.parameter(model.parameters[index], index)),
            )
        predictions.append(value)
    return predictions^


def predict(model: SciTransformer, spec: TaskSpec, inputs: List[List[Float64]]) raises -> List[Float64]:
    var tape = Tape()
    var nodes = forward_tape(tape, model, spec, inputs)
    var out = List[Float64]()
    for node in nodes:
        out.append(tape.value(node))
    return out^


def serialize_model(model: SciTransformer) raises -> String:
    var out = String(MODEL_SCHEMA + "|grid=" + String(model.grid_points) + "|params=")
    for i in range(len(model.parameters)):
        if i > 0:
            out += ","
        out += String(model.parameters[i])
    return out + "\n"


def deserialize_model(text: String) raises -> SciTransformer:
    var clean = String("")
    var limit = text.byte_length()
    if text.endswith("\n"):
        limit -= 1
    for i in range(limit):
        clean += String(text[byte=i])
    var parts = clean.split("|")
    if len(parts) != 3:
        raise Error("invalid model artifact")
    var grid = Int(String(parts[1]).replace("grid=", ""))
    var values = List[Float64]()
    for cell in String(parts[2]).replace("params=", "").split(","):
        values.append(Float64(String(cell)))
    if len(values) != PARAM_COUNT:
        raise Error("model parameter count mismatch")
    return SciTransformer(values^, grid)
