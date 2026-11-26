"""Reference scaled dot-product attention with explicit mask semantics.

This is a straightforward CPU kernel over tape node indices. No FlashAttention,
fused kernel, or GPU claim is made. Softmax is stabilized by subtracting the
maximum score before exponentiation.
"""

from std.math import exp
from hyperforge.autodiff.tape import Tape

comptime ATTENTION_SCHEMA = "hyperforge-scit-attention-v1"


def softmax_stable(values: List[Float64], mask: List[Bool]) raises -> List[Float64]:
    if len(values) != len(mask):
        raise Error("softmax mask length mismatch")
    if len(values) == 0:
        raise Error("softmax requires at least one value")
    var maximum = values[0]
    for value in values:
        if value > maximum:
            maximum = value
    var unnormalized = List[Float64]()
    var total = Float64(0.0)
    for i in range(len(values)):
        var weight = Float64(0.0)
        if not mask[i]:
            weight = exp(values[i] - maximum)
        unnormalized.append(weight)
        total += weight
    if total == 0.0:
        raise Error("softmax has no unmasked positions")
    var out = List[Float64]()
    for weight in unnormalized:
        out.append(weight / total)
    return out^


def attention_numeric(
    query: List[Float64],
    keys: List[List[Float64]],
    values: List[List[Float64]],
    mask: List[Bool],
    scale: Float64,
) raises -> List[Float64]:
    """Plain numeric attention used as an independent test reference."""
    if len(keys) != len(values) or len(keys) != len(mask):
        raise Error("attention length mismatch")
    var scores = List[Float64]()
    for j in range(len(keys)):
        var score = Float64(0.0)
        for d in range(len(query)):
            score += query[d] * keys[j][d]
        scores.append(score * scale)
    var weights = softmax_stable(scores, mask)
    var output = List[Float64]()
    for d in range(len(values[0])):
        var accumulated = Float64(0.0)
        for j in range(len(values)):
            accumulated += weights[j] * values[j][d]
        output.append(accumulated)
    return output^


def dot_nodes(mut tape: Tape, left: List[Int], right: List[Int]) raises -> Int:
    if len(left) != len(right):
        raise Error("dot length mismatch")
    var total = tape.constant(0.0)
    for i in range(len(left)):
        total = tape.add(total, tape.mul(left[i], right[i]))
    return total


def attention_tape(
    mut tape: Tape,
    query: List[Int],
    keys: List[List[Int]],
    values: List[List[Int]],
    mask: List[Bool],
    scale: Float64,
) raises -> List[Int]:
    """Tape-based attention; returns output node indices per value dimension."""
    if len(keys) != len(values) or len(keys) != len(mask):
        raise Error("attention length mismatch")
    var scores = List[Int]()
    for j in range(len(keys)):
        var dot = dot_nodes(tape, query, keys[j])
        scores.append(tape.scale(dot, scale))

    var maximum = tape.value(scores[0])
    for score in scores:
        if tape.value(score) > maximum:
            maximum = tape.value(score)
    var shifted = List[Int]()
    for score in scores:
        shifted.append(tape.sub(score, tape.constant(maximum)))

    var exponentials = List[Int]()
    for node in shifted:
        var e = tape.exp(node)
        if mask[len(exponentials)]:
            e = tape.scale(e, 0.0)
        exponentials.append(e)

    var total = tape.constant(0.0)
    for node in exponentials:
        total = tape.add(total, node)
    var weights = List[Int]()
    for node in exponentials:
        weights.append(tape.divide(node, total))

    var output = List[Int]()
    for d in range(len(values[0])):
        var accumulated = tape.constant(0.0)
        for j in range(len(values)):
            accumulated = tape.add(
                accumulated, tape.mul(weights[j], values[j][d])
            )
        output.append(accumulated)
    return output^
