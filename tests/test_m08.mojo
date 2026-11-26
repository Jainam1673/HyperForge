"""M08 AutoDL tests: tape ops, MLP, training, and architecture search.

Run with: pixi run bash scripts/mojo.sh run -I src tests/test_m08.mojo
"""

from std.math import abs
from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from hyperforge.autodiff.tape import Tape
from hyperforge.autodl.task import make_task
from hyperforge.autodl.model import (
    ArchCandidate,
    parameter_count,
    valid_candidate,
    init_model,
    predict,
    serialize_model,
    deserialize_model,
)
from hyperforge.autodl.trainer import train_model, evaluate_indices
from hyperforge.autodl.search import run_search, random_candidate, mutate_candidate

comptime TOL = 1e-4


def test_tape_log_relu() raises:
    var tape = Tape()
    var x = tape.parameter(2.0, 0)
    var logged = tape.log(x)
    var relu = tape.relu(x)
    assert_true(abs(tape.value(logged) - 0.693147) < TOL)
    assert_equal(tape.value(relu), 2.0)
    tape.backward(logged)
    assert_true(abs(tape.accumulated(0) - 0.5) < TOL)
    var negative = Tape()
    var n = negative.parameter(-1.0, 0)
    var relu_n = negative.relu(n)
    negative.backward(relu_n)
    assert_equal(negative.value(relu_n), 0.0)
    assert_equal(negative.accumulated(0), 0.0)


def test_task_splits_are_disjoint_and_reproducible() raises:
    var a = make_task(UInt64(42))
    var b = make_task(UInt64(42))
    assert_equal(len(a.train), 72)
    assert_equal(len(a.validation), 24)
    assert_equal(len(a.test), 24)
    assert_equal(a.labels[a.train[0]], b.labels[b.train[0]])
    var seen = List[Int]()
    for index in a.train:
        seen.append(index)
    for index in a.validation:
        seen.append(index)
    for index in a.test:
        seen.append(index)
    assert_equal(len(seen), 120)


def test_architecture_shapes_and_serialization() raises:
    var candidate = ArchCandidate("c", 2, 4, 0.01, 8, "tanh", UInt64(42))
    assert_true(valid_candidate(candidate))
    assert_equal(parameter_count(2, 4), 17)
    assert_false(valid_candidate(ArchCandidate("bad", 4, 4, 0.01, 8, "tanh", UInt64(1))))
    var model = init_model(candidate)
    var task = make_task(UInt64(42))
    var prediction = predict(model, task.features[task.train[0]])
    assert_true(prediction >= 0.0 and prediction <= 1.0)
    var restored = deserialize_model(serialize_model(model))
    assert_true(abs(predict(restored, task.features[task.train[0]]) - prediction) < 1e-12)


def test_training_updates_parameters_and_keeps_test_locked() raises:
    var task = make_task(UInt64(42))
    var candidate = ArchCandidate("c", 1, 4, 0.03, 8, "relu", UInt64(42))
    var result = train_model(candidate, task, 8, 2)
    var report = result[1].copy()
    assert_true(report.parameters_changed)
    assert_true(report.max_parameter_delta > 0.0)
    assert_true(report.final_train_loss < report.initial_loss)
    assert_true(report.test_loss == 0.0)
    assert_true(report.test_accuracy == 0.0)
    assert_equal(report.state, "TRAINED")


def test_search_trains_structurally_distinct_architectures() raises:
    var task = make_task(UInt64(42))
    var random_outcome = run_search("random", task, 3, UInt64(42))
    assert_true(random_outcome.trained >= 2)
    assert_true(random_outcome.distinct_architectures >= 2)
    assert_true(random_outcome.test_accuracy >= 0.0)
    var mutated = mutate_candidate(random_candidate(UInt64(42), 0), UInt64(42), 1)
    assert_true(valid_candidate(mutated))
    assert_false(mutated.id == random_candidate(UInt64(42), 0).id)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
