"""M04 SINN tests: differentiation, network, solver, and training gate.

Run with: pixi run mojo run -I src tests/test_m04.mojo
"""

from std.math import abs
from std.testing import assert_equal, assert_true, assert_false, TestSuite
from std.os import remove
from std.pathlib import Path
from hyperforge.sinn.jet import (
    Jet,
    constant,
    x_variable,
    parameter,
    jet_add,
    jet_mul,
    jet_scale,
    jet_tanh,
)
from hyperforge.sinn.network import (
    init_network,
    forward,
    forward_jet,
    get_param,
    set_param,
    serialize_network,
    deserialize_network,
)
from hyperforge.sinn.problem import (
    poisson_1d,
    exact_solution,
    collocation_points,
    validation_points,
    finite_difference_solution,
)
from hyperforge.sinn.solver import train, residual_at

comptime TOL = 1e-4


def make_workspace(path: String) raises -> None:
    from std.os import mkdir
    if Path(path).exists():
        return
    mkdir(path)
    mkdir(path + "/experiments")
    mkdir(path + "/artifacts")
    var f = open(path + "/hyperforge.toml", "w")
    f.write("schema=\"hyperforge-workspace-v1\"\n")
    f.close()


def test_tanh_jet_matches_finite_difference() raises:
    var x = 0.4
    var scale = Float64(1.7)
    var jet = jet_tanh(jet_scale(x_variable(x), scale))
    var h = 1e-5
    var f0 = __tanh_ref(scale * x)
    var f1 = __tanh_ref(scale * (x + h))
    var fm = __tanh_ref(scale * (x - h))
    assert_true(abs(jet.v - f0) < TOL)
    assert_true(abs(jet.vx - (f1 - fm) / (2.0 * h)) < TOL)
    assert_true(abs(jet.vxx - (f1 - 2.0 * f0 + fm) / (h * h)) < TOL)


def __tanh_ref(x: Float64) raises -> Float64:
    from std.math import tanh
    return tanh(x)


def test_product_rule_mixed_derivative() raises:
    var a = x_variable(0.5)
    var b = jet_tanh(jet_scale(x_variable(0.5), 2.0))
    var product = jet_mul(a, b)
    assert_true(abs(product.vxx - (2.0 * b.vx + 0.5 * b.vxx)) < TOL)
    var parameter_jet = jet_mul(
        parameter(3.0, True), constant(2.0)
    )
    assert_true(abs(parameter_jet.vp - 2.0) < TOL)
    assert_true(abs(parameter_jet.vxxp) < TOL)


def test_network_boundary_and_derivatives() raises:
    var net = init_network(UInt64(42), 4)
    assert_true(abs(forward(net, 0.0)) < 1e-15)
    assert_true(abs(forward(net, 1.0)) < 1e-15)
    var x = 0.37
    var jet = forward_jet(net, x_variable(x), -1)
    var h = 1e-5
    var d1 = (forward(net, x + h) - forward(net, x - h)) / (2.0 * h)
    var d2 = (
        forward(net, x + h) - 2.0 * forward(net, x) + forward(net, x - h)
    ) / (h * h)
    assert_true(abs(jet.vx - d1) < TOL)
    assert_true(abs(jet.vxx - d2) < TOL)


def test_parameter_gradient_matches_finite_difference() raises:
    var net = init_network(UInt64(7), 4)
    var x = 0.31
    var index = 0
    var jet = forward_jet(net, x_variable(x), index)
    var epsilon = 1e-5
    var original = get_param(net, index)
    var residual_a = residual_at(net, x, 2.0)
    set_param(net, index, original + epsilon)
    var residual_b = residual_at(net, x, 2.0)
    set_param(net, index, original)
    var numeric = (residual_b - residual_a) / epsilon
    assert_true(abs(-jet.vxxp - numeric) < 1e-3)


def test_finite_difference_solver_matches_exact() raises:
    var problem = poisson_1d(UInt64(1))
    var points = validation_points(problem)
    var solution = finite_difference_solution(problem, points)
    var worst = Float64(0.0)
    for i in range(len(points)):
        var error = abs(solution[i] - exact_solution(points[i]))
        if error > worst:
            worst = error
    assert_true(worst < 1e-3)
    assert_equal(len(collocation_points(problem)), problem.collocation_count)


def test_network_serialization_roundtrip() raises:
    var net = init_network(UInt64(9), 4)
    var restored = deserialize_network(serialize_network(net))
    for x in [Float64(0.1), 0.45, 0.9]:
        assert_true(abs(forward(net, x) - forward(restored, x)) < 1e-12)


def test_training_is_reproducible_and_honest() raises:
    var problem = poisson_1d(UInt64(42))
    var first = train(problem, UInt64(42), 250)
    var second = train(problem, UInt64(42), 250)
    var a = first[1].copy()
    var b = second[1].copy()
    assert_equal(a.state, "CONVERGED")
    assert_true(abs(a.final_loss - b.final_loss) < 1e-12)
    assert_true(abs(a.exact_l2 - b.exact_l2) < 1e-12)
    assert_true(a.boundary_abs < 1e-14)
    var different = train(problem, UInt64(43), 250)
    var c = different[1].copy()
    assert_true(abs(a.final_loss - c.final_loss) > 1e-9)

    var short = train(problem, UInt64(42), 5)
    var poor = short[1].copy()
    assert_false(poor.state == "CONVERGED")
    assert_true(poor.exact_l2 > a.exact_l2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
