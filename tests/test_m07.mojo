"""M07 reciprocal discovery tests.

Run with: pixi run mojo run -I src tests/test_m07.mojo (through scripts/mojo.sh).
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.sys import has_accelerator
from max.gpu.host import DeviceContext
from hyperforge.discovery.genome import (
    DiscoveryGenome,
    genome_id,
    canonical_genome,
    is_valid_genome,
    mutate,
)
from hyperforge.discovery.reciprocal import (
    Observation,
    PolicyOutcome,
    pareto_count,
    next_genome,
    run_policy,
)

comptime DATASET = "/home/jack/Projects/HyperForge/examples/regression_linear.csv"


def test_genome_validation_and_identity() raises:
    var genome = DiscoveryGenome("linear_gd", 256)
    assert_true(is_valid_genome(genome))
    assert_false(is_valid_genome(DiscoveryGenome("unknown", 256)))
    assert_false(is_valid_genome(DiscoveryGenome("linear_gd", 999)))
    assert_equal(genome_id(genome), genome_id(DiscoveryGenome("linear_gd", 256)))
    assert_false(genome_id(genome) == genome_id(DiscoveryGenome("ridge_gd", 256)))
    assert_equal(canonical_genome(genome), "linear_gd|block=256")


def test_mutation_preserves_validity() raises:
    var genome = DiscoveryGenome("linear_gd", 256)
    var ai = mutate(genome, "ai", 1)
    assert_true(is_valid_genome(ai))
    assert_true(ai.block_size == 256)
    var compute = mutate(genome, "compute", 1)
    assert_true(is_valid_genome(compute))
    assert_true(compute.model_kind == "linear_gd")
    assert_false(compute.block_size == 256)


def test_adaptive_allocation_uses_evidence() raises:
    var observations = List[Observation]()
    observations.append(Observation(DiscoveryGenome("linear_gd", 256), 0.1, 0.001, True))
    var ai_focus = next_genome("joint_reciprocal", observations, 1, UInt64(1), 1.0, 0.0)
    var compute_focus = next_genome("joint_reciprocal", observations, 1, UInt64(1), 0.0, 1.0)
    assert_true(ai_focus.block_size == 256)
    assert_false(ai_focus.model_kind == "linear_gd")
    assert_true(compute_focus.model_kind == "linear_gd")
    assert_false(compute_focus.block_size == 256)


def test_pareto_counting() raises:
    var observations = List[Observation]()
    observations.append(Observation(DiscoveryGenome("linear_gd", 256), 1.0, 2.0, True))
    observations.append(Observation(DiscoveryGenome("ridge_gd", 128), 0.5, 1.0, True))
    observations.append(Observation(DiscoveryGenome("knn_regressor", 64), 0.8, 0.5, True))
    assert_equal(pareto_count(observations), 2)


def test_policies_use_matched_budget() raises:
    comptime if not has_accelerator():
        return
    else:
        var ctx = DeviceContext()
        var fixed = run_policy("fixed", UInt64(42), 3, DATASET, ctx, True)
        var joint = run_policy("joint_reciprocal", UInt64(42), 3, DATASET, ctx, True)
        assert_equal(fixed.evaluations, joint.evaluations)
        assert_equal(fixed.budget, 3)
        assert_true(fixed.best_rmse > 0.0)
        assert_true(joint.best_rmse > 0.0)
        assert_true(fixed.best_latency > 0.0)
        assert_true(joint.best_latency > 0.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
