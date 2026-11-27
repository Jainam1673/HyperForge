"""M16 GPU catalogue tests: CPU references, kernel correctness, catalogue."""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.sys import has_accelerator
from max.gpu.host import DeviceContext
from hyperforge.gpu.kernels import (
    cpu_vector_add,
    cpu_vector_axpy,
    max_abs_error,
    run_vector_add,
    run_vector_axpy,
)
from hyperforge.gpu.catalogue import catalogue, kernel_names, run_catalogue_kernel

comptime TOL = 1e-6


def test_cpu_references() raises:
    var a: List[Float32] = [1.0, 2.0, 3.0]
    var b: List[Float32] = [4.0, 5.0, 6.0]
    var sum = cpu_vector_add(a, b)
    assert_equal(sum[0], Float32(5.0))
    var axpy = cpu_vector_axpy(Float32(0.5), a, b)
    assert_true(abs32(axpy[0] - Float32(4.5)) < TOL)
    assert_true(max_abs_error(sum, sum) == Float32(0.0))


def abs32(value: Float32) raises -> Float32:
    if value < 0.0:
        return -value
    return value


def test_catalogue_entries() raises:
    var entries = catalogue()
    assert_equal(len(entries), 2)
    var names = kernel_names()
    assert_true(names[0] == "vector_add")
    assert_true(names[1] == "vector_axpy")


def test_gpu_kernels_are_correct() raises:
    comptime if not has_accelerator():
        return
    else:
        var ctx = DeviceContext()
        var add = run_vector_add[7](ctx, 1)
        assert_true(add.state == "PASS")
        assert_true(add.max_error < Float32(1e-5))
        var axpy = run_vector_axpy[255](ctx, Float32(0.5), 1)
        assert_true(axpy.state == "PASS")
        var dispatched = run_catalogue_kernel(ctx, "vector_axpy", 1024, 1)
        assert_true(dispatched.state == "PASS")
        assert_true(dispatched.size == 1024)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
