"""M17 DiscoveryGenome v2 and systems-side search tests."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.sys import has_accelerator
from max.gpu.host import DeviceContext
from hyperforge.discovery.genome_v2 import (
    GenomeV2,
    valid_genome,
    genome_id,
    canonical,
    mutate_genome,
    prior_genome,
)
from hyperforge.discovery.systems_search import (
    SystemsTrial,
    run_systems_search,
    pareto_count,
    default_genome,
)


def test_genome_validation_and_identity() raises:
    var genome = default_genome(UInt64(42))
    assert_true(valid_genome(genome))
    assert_false(valid_genome(GenomeV2("bad", "vector_add", 256, 1024, UInt64(1))))
    assert_false(valid_genome(GenomeV2("linear_gd", "bad", 256, 1024, UInt64(1))))
    assert_false(valid_genome(GenomeV2("linear_gd", "vector_add", 7, 1024, UInt64(1))))
    assert_equal(genome_id(genome), genome_id(default_genome(UInt64(42))))
    assert_true(canonical(genome).byte_length() > 0)


def test_mutation_preserves_constraints() raises:
    var genome = default_genome(UInt64(42))
    for side in ["compute", "runtime", "ai", "experiment"]:
        var child = mutate_genome(genome, side, UInt64(42), 1)
        assert_true(valid_genome(child))
    var prior = prior_genome(UInt64(42), 0)
    assert_true(valid_genome(prior))


def test_pareto_dominance() raises:
    var records = List[SystemsTrial]()
    records.append(SystemsTrial("a", 256, 0.0, 2.0, 4.0, 1.0, "PASS"))
    records.append(SystemsTrial("b", 128, 0.0, 1.0, 3.0, 2.0, "PASS"))
    records.append(SystemsTrial("c", 64, 0.0, 3.0, 5.0, 0.5, "PASS"))
    assert_equal(pareto_count(records), 1)
    records.append(SystemsTrial("d", 512, 0.0, 1.0, 3.0, 2.0, "FAIL"))
    assert_equal(pareto_count(records), 1)


def test_systems_search_is_measured() raises:
    comptime if not has_accelerator():
        return
    else:
        var ctx = DeviceContext()
        var fixed = run_systems_search(ctx, "fixed", 1, UInt64(42))
        var random = run_systems_search(ctx, "random", 3, UInt64(42))
        assert_equal(fixed.trials, 1)
        assert_equal(random.trials, 3)
        assert_true(fixed.best_kernel_median > 0.0)
        assert_true(random.best_kernel_median > 0.0)
        assert_true(random.pareto_count >= 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
