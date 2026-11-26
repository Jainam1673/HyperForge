"""M06 GPU kernel and CPU reference tests.

Run with: pixi run mojo run -I src tests/test_m06.mojo (use scripts/mojo.sh
through the pixi task so the detected accelerator target is selected).
"""

from std.testing import assert_equal, assert_true, assert_false, assert_raises, TestSuite
from std.sys import has_accelerator
from max.gpu.host import DeviceContext
from hyperforge.gpu.kernels import (
    cpu_vector_add,
    max_abs_error,
    median,
    run_vector_add,
)


def test_cpu_reference() raises:
    var left: List[Float32] = [1.0, 2.0, 3.0]
    var right: List[Float32] = [4.0, 5.0, 6.0]
    var result = cpu_vector_add(left, right)
    assert_equal(result[0], Float32(5.0))
    assert_equal(result[2], Float32(9.0))
    var wrong: List[Float32] = [1.0]
    with assert_raises():
        _ = cpu_vector_add(left, wrong)


def test_error_detector() raises:
    var a: List[Float32] = [1.0, 2.0]
    var b: List[Float32] = [1.0, 2.5]
    assert_true(max_abs_error(a, b) > 0.4)
    assert_equal(max_abs_error(a, a), Float32(0.0))


def test_median() raises:
    var odd: List[Float64] = [3.0, 1.0, 2.0]
    assert_equal(median(odd), 2.0)
    var even: List[Float64] = [4.0, 1.0, 3.0, 2.0]
    assert_equal(median(even), 2.0)


def test_gpu_kernel_small_and_edge() raises:
    comptime if not has_accelerator():
        return
    else:
        var ctx = DeviceContext()
        var small = run_vector_add[7](ctx, 1)
        assert_equal(small.state, "PASS")
        assert_equal(small.max_error, Float32(0.0))
        var edge = run_vector_add[255](ctx, 1)
        assert_equal(edge.state, "PASS")
        assert_true(edge.kernel_median_seconds > 0.0)
        assert_true(edge.bytes_per_second > 0.0)


def test_gpu_kernel_full_block() raises:
    comptime if not has_accelerator():
        return
    else:
        var ctx = DeviceContext()
        var result = run_vector_add[256](ctx, 1)
        assert_equal(result.state, "PASS")
        assert_equal(result.max_error, Float32(0.0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
