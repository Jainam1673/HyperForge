"""M19 joint AI x compute benchmark tests."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.sys import has_accelerator
from max.gpu.host import DeviceContext
from hyperforge.joint.benchmark import (
    JointGenome,
    JointMeasurement,
    default_genome,
    valid_genome,
    mutate,
    joint_id,
    relative_gain,
    contains_id,
    run_joint,
)
from hyperforge.automl.models import MODEL_KNN


def test_genome_constraints_and_identity() raises:
    var genome = default_genome(UInt64(42))
    assert_true(valid_genome(genome))
    assert_false(valid_genome(JointGenome(MODEL_KNN, 200, 7, UInt64(1))))
    assert_false(valid_genome(JointGenome("bogus", 200, 256, UInt64(1))))
    assert_false(valid_genome(JointGenome("linear_gd", 10, 256, UInt64(1))))
    assert_equal(joint_id(genome), joint_id(default_genome(UInt64(42))))
    var other = genome.copy()
    other.iterations = 800
    assert_true(joint_id(genome) != joint_id(other))


def test_mutation_preserves_constraints() raises:
    var genome = default_genome(UInt64(42))
    for index in range(8):
        var ai_child = mutate(genome, "ai", UInt64(42), index)
        assert_true(valid_genome(ai_child))
        var compute_child = mutate(genome, "compute", UInt64(42), index)
        assert_true(valid_genome(compute_child))


def test_relative_gain_normalizes_each_side() raises:
    var history = List[JointMeasurement]()
    # AI: first 0.2 then 0.1 -> relative gain 0.5 regardless of absolute scale.
    history.append(JointMeasurement("a", "linear_gd", 200, 256, 0.2, 0.00002, True))
    history.append(JointMeasurement("b", "linear_gd", 400, 256, 0.1, 0.00001, True))
    # Compute: first 100 then 50 -> relative gain 0.5.
    history.append(JointMeasurement("c", "linear_gd", 200, 256, 0.2, 100.0, True))
    history.append(JointMeasurement("d", "linear_gd", 200, 256, 0.2, 50.0, True))
    assert_true(relative_gain(history, "ai") > 0.0)
    assert_true(relative_gain(history, "compute") > 0.0)


def test_duplicate_ids_are_not_discoveries() raises:
    var seen = List[String]()
    assert_false(contains_id(seen, "joint-abc"))
    seen.append("joint-abc")
    assert_true(contains_id(seen, "joint-abc"))


def test_matched_budget_and_repeated_config() raises:
    comptime if not has_accelerator():
        return
    else:
        var ctx = DeviceContext()
        var fixed = run_joint(ctx, "fixed", 6, UInt64(42))
        var joint = run_joint(ctx, "joint", 6, UInt64(42))
        assert_equal(fixed.budget, 6)
        assert_equal(joint.budget, 6)
        assert_equal(fixed.ai_evaluations + fixed.compute_evaluations, 6)
        assert_equal(joint.ai_evaluations + joint.compute_evaluations, 6)
        # A fixed genome is evaluated repeatedly; latency noise must not be
        # counted as repeated discoveries.
        assert_true(fixed.discoveries <= 2)
        assert_true(joint.discoveries >= 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
