"""M10 AutoTransformers tests: config genes, training, measured search."""

from std.math import abs
from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from hyperforge.scit.task import TaskSpec
from hyperforge.autotrans.model import (
    TransformerConfig,
    TransformerModel,
    valid_config,
    parameter_count,
    init_model,
    predict,
    serialize_model,
    deserialize_model,
)
from hyperforge.autotrans.trainer import train, evaluate, range_indices, inference_latency
from hyperforge.autotrans.search import (
    run_search,
    default_config,
    random_config,
    mutate_config,
)

comptime TOL = 1e-6


def small_spec() raises -> TaskSpec:
    return TaskSpec("decaying_mode_1d", 6, 2, 0.35, 8, 4, UInt64(42))


def test_config_validation_and_counts() raises:
    assert_true(valid_config(TransformerConfig(4, 2, 4, 1, 2, UInt64(1))))
    assert_true(valid_config(TransformerConfig(8, 2, 8, 2, 2, UInt64(1))))
    assert_false(valid_config(TransformerConfig(4, 3, 4, 1, 2, UInt64(1))))
    assert_false(valid_config(TransformerConfig(4, 2, 6, 1, 2, UInt64(1))))
    assert_true(parameter_count(TransformerConfig(8, 2, 8, 2, 2, UInt64(1))) > parameter_count(TransformerConfig(4, 2, 4, 1, 2, UInt64(1))))


def test_config_forward_and_serialization() raises:
    var spec = small_spec()
    var config = TransformerConfig(4, 2, 4, 1, 2, UInt64(42))
    var model = init_model(config)
    var inputs = List[List[Float64]]()
    var row1: List[Float64] = [0.1, 0.3, 0.5, 0.7, 0.9, 0.7]
    var row2: List[Float64] = [0.09, 0.28, 0.46, 0.64, 0.82, 0.64]
    inputs.append(row1^)
    inputs.append(row2^)
    var prediction = predict(model, spec, inputs)
    assert_equal(len(prediction), spec.grid_points)
    var restored = deserialize_model(serialize_model(model))
    var again = predict(restored, spec, inputs)
    for i in range(len(prediction)):
        assert_true(abs(prediction[i] - again[i]) < 1e-12)


def test_training_and_gene_mutation() raises:
    var spec = small_spec()
    var config = TransformerConfig(4, 2, 4, 1, 2, UInt64(42))
    var model = init_model(config)
    var before = copy_parameters(model)
    var losses = train(model, spec, range_indices(spec.train_count), 2, 0.03)
    assert_true(losses[1] < losses[0])
    assert_false(same_parameters(before, model.parameters))
    var mutated = mutate_config(config, UInt64(42), 1)
    assert_true(valid_config(mutated))


def copy_parameters(model: TransformerModel) raises -> List[Float64]:
    return model.parameters.copy()


def same_parameters(a: List[Float64], b: List[Float64]) raises -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if abs(a[i] - b[i]) > TOL:
            return False
    return True


def test_measured_search_executions() raises:
    var spec = small_spec()
    var default = run_search("default", spec, 1, UInt64(42))
    var random = run_search("random", spec, 2, UInt64(42))
    assert_equal(default.parameters, parameter_count(default_config(UInt64(42))))
    assert_true(default.validation_mse > 0.0)
    assert_true(random.validation_mse > 0.0)
    assert_true(default.latency > 0.0)
    assert_true(random.latency > 0.0)
    assert_true(random_config(UInt64(42), 0).seed == UInt64(42))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
