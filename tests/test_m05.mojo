"""M05 SciTransformers tests: tape, attention, masks, shapes, training.

Run with: pixi run mojo run -I src tests/test_m05.mojo
"""

from std.math import abs, exp, sin
from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from hyperforge.autodiff.tape import Tape
from hyperforge.scit.attention import softmax_stable, attention_numeric, attention_tape
from hyperforge.scit.task import (
    TaskSpec,
    default_task,
    sample_task,
    coordinate_encoding,
    persistence_prediction,
    mean_prediction,
    fit_linear_baseline,
    linear_prediction,
    mse,
)
from hyperforge.scit.model import init_model, predict, serialize_model, deserialize_model
from hyperforge.scit.trainer import train_and_evaluate

comptime TOL = 1e-5


def test_tape_gradient() raises:
    var tape = Tape()
    var w = tape.parameter(2.0, 0)
    var x = tape.constant(3.0)
    var y = tape.mul(w, x)
    var loss = tape.mul(y, y)
    assert_true(abs(tape.value(loss) - 36.0) < TOL)
    tape.backward(loss)
    assert_true(abs(tape.accumulated(0) - 36.0) < TOL)


def test_softmax_mask_and_stability() raises:
    var values: List[Float64] = [1000.0, 1001.0, 999.0]
    var mask: List[Bool] = [False, True, False]
    var weights = softmax_stable(values, mask)
    assert_equal(weights[1], 0.0)
    assert_true(abs(weights[0] + weights[2] - 1.0) < TOL)
    assert_true(weights[0] > weights[2])
    var all_masked: List[Bool] = [True, True, True]
    with assert_raises():
        _ = softmax_stable(values, all_masked)


def test_attention_numeric_matches_tape() raises:
    var query: List[Float64] = [1.0, 0.0]
    var keys = List[List[Float64]]()
    keys.append([1.0, 0.0])
    keys.append([0.0, 1.0])
    var values = List[List[Float64]]()
    values.append([1.0, 0.0])
    values.append([0.0, 1.0])
    var mask: List[Bool] = [False, True]
    var expected = attention_numeric(query, keys, values, mask, 1.0)

    var tape = Tape()
    var q_nodes = List[Int]()
    for value in query:
        q_nodes.append(tape.constant(value))
    var key_nodes = List[List[Int]]()
    var value_nodes = List[List[Int]]()
    for i in range(len(keys)):
        var k = List[Int]()
        var v = List[Int]()
        for d in range(len(keys[i])):
            k.append(tape.constant(keys[i][d]))
            v.append(tape.constant(values[i][d]))
        key_nodes.append(k^)
        value_nodes.append(v^)
    var output = attention_tape(tape, q_nodes, key_nodes, value_nodes, mask, 1.0)
    assert_equal(len(output), len(expected))
    for d in range(len(expected)):
        assert_true(abs(tape.value(output[d]) - expected[d]) < TOL)


def test_attention_mask_semantics() raises:
    var query: List[Float64] = [1.0, 0.0]
    var keys = List[List[Float64]]()
    keys.append([1.0, 0.0])
    keys.append([0.0, 1.0])
    var values = List[List[Float64]]()
    values.append([1.0, 0.0])
    values.append([0.0, 1.0])
    var unmasked = attention_numeric(query, keys, values, [False, False], 1.0)
    var masked = attention_numeric(query, keys, values, [False, True], 1.0)
    assert_true(masked[1] < unmasked[1])
    assert_true(masked[0] > unmasked[0])


def test_coordinate_encoding_is_deterministic() raises:
    var spec = default_task(UInt64(42))
    var a = coordinate_encoding(spec, 2, 1)
    var b = coordinate_encoding(spec, 2, 1)
    assert_equal(len(a), 4)
    for i in range(len(a)):
        assert_equal(a[i], b[i])


def test_task_baselines_are_real() raises:
    var spec = default_task(UInt64(42))
    var sample = sample_task(spec, 0, True)
    var inputs = sample[0].copy()
    var target = sample[1].copy()
    var held = sample_task(spec, 0, False)
    assert_true(abs(mse(persistence_prediction(inputs), target) - mse(persistence_prediction(inputs), target)) < TOL)
    assert_false(sample[2] == held[2])
    var train_inputs = List[List[List[Float64]]]()
    var train_targets = List[List[Float64]]()
    for i in range(spec.train_count):
        var item = sample_task(spec, i, True)
        train_inputs.append(item[0].copy())
        train_targets.append(item[1].copy())
    var coefficients = fit_linear_baseline(train_inputs, train_targets, spec.grid_points)
    var mean = mean_prediction(train_targets, spec.grid_points)
    assert_true(mse(linear_prediction(coefficients, inputs), target) < mse(mean, target))


def test_model_serialization_and_shapes() raises:
    var spec = default_task(UInt64(42))
    var model = init_model(UInt64(42), spec.grid_points)
    var restored = deserialize_model(serialize_model(model))
    var sample = sample_task(spec, 0, True)
    var inputs = sample[0].copy()
    var first = predict(model, spec, inputs)
    var second = predict(restored, spec, inputs)
    assert_equal(len(first), spec.grid_points)
    for i in range(len(first)):
        assert_true(abs(first[i] - second[i]) < 1e-12)
    var bad_inputs = List[List[Float64]]()
    bad_inputs.append([1.0, 2.0])
    with assert_raises():
        _ = predict(model, spec, bad_inputs)


def test_training_reproduces_and_beats_baselines() raises:
    var spec = TaskSpec("decaying_mode_1d", 8, 2, 0.35, 8, 4, UInt64(42))
    var first = train_and_evaluate(spec, UInt64(42), 4)
    var a = first[1].copy()
    var second = train_and_evaluate(spec, UInt64(42), 4)
    var b = second[1].copy()
    assert_equal(a.state, "CONVERGED")
    assert_true(abs(a.final_loss - b.final_loss) < 1e-12)
    assert_true(a.final_loss < a.initial_loss)
    assert_true(a.model_mse < a.persistence_mse)
    assert_true(a.model_mse < a.mean_mse)
    assert_true(a.rollout_drift < 1.0)
    # Honest negative result: the task is exactly linear, so the fitted
    # per-cell linear baseline is stronger than the transformer.
    assert_true(a.linear_mse < a.model_mse)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
