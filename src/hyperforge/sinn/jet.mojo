"""Higher-order forward-mode jet for 1D PINN differentiation.

A Jet carries a value, its first and second derivatives with respect to x,
and the same derivatives along one parameter direction p. The mixed component
`vxxp` is d/dx(d/dx(dv/dp)), i.e. the parameter derivative of u''.

This is a real forward-mode AD path, not a finite-difference approximation.
It is verified against analytical and central-difference references in tests.
"""

from std.math import exp

struct Jet(Copyable, Movable):
    var v: Float64
    var vx: Float64
    var vxx: Float64
    var vp: Float64
    var vxp: Float64
    var vxxp: Float64

    def __init__(
        out self,
        v: Float64,
        vx: Float64,
        vxx: Float64,
        vp: Float64,
        vxp: Float64,
        vxxp: Float64,
    ):
        self.v = v
        self.vx = vx
        self.vxx = vxx
        self.vp = vp
        self.vxp = vxp
        self.vxxp = vxxp


def constant(value: Float64) raises -> Jet:
    return Jet(value, 0.0, 0.0, 0.0, 0.0, 0.0)


def x_variable(x: Float64) raises -> Jet:
    return Jet(x, 1.0, 0.0, 0.0, 0.0, 0.0)


def parameter(value: Float64, selected: Bool) raises -> Jet:
    var seed = Float64(0.0)
    if selected:
        seed = 1.0
    return Jet(value, 0.0, 0.0, seed, 0.0, 0.0)


def jet_add(left: Jet, right: Jet) raises -> Jet:
    return Jet(
        left.v + right.v,
        left.vx + right.vx,
        left.vxx + right.vxx,
        left.vp + right.vp,
        left.vxp + right.vxp,
        left.vxxp + right.vxxp,
    )


def jet_mul(left: Jet, right: Jet) raises -> Jet:
    return Jet(
        left.v * right.v,
        left.vx * right.v + left.v * right.vx,
        left.vxx * right.v + 2.0 * left.vx * right.vx + left.v * right.vxx,
        left.vp * right.v + left.v * right.vp,
        left.vxp * right.v + left.vx * right.vp + left.vp * right.vx + left.v * right.vxp,
        left.vxxp * right.v + left.vxx * right.vp
            + 2.0 * (left.vxp * right.vx + left.vx * right.vxp)
            + left.vp * right.vxx + left.v * right.vxxp,
    )


def jet_scale(value: Jet, factor: Float64) raises -> Jet:
    return Jet(
        value.v * factor,
        value.vx * factor,
        value.vxx * factor,
        value.vp * factor,
        value.vxp * factor,
        value.vxxp * factor,
    )


def jet_tanh(value: Jet) raises -> Jet:
    var t: Float64
    var denominator: Float64
    # tanh via exponentials stable enough for |value| < 20 in this benchmark.
    if value.v > 20.0:
        t = 1.0
        denominator = 0.0
    elif value.v < -20.0:
        t = -1.0
        denominator = 0.0
    else:
        var e = exp(value.v)
        var em = 1.0 / e
        t = (e - em) / (e + em)
        denominator = 1.0 - t * t
    var k1 = denominator
    var k2 = -2.0 * t * k1
    var k2p = (-2.0 * k1 - 2.0 * t * k2) * value.vp
    return Jet(
        t,
        k1 * value.vx,
        k1 * value.vxx + k2 * value.vx * value.vx,
        k1 * value.vp,
        k1 * value.vxp + k2 * value.vx * value.vp,
        k1 * value.vxxp
            + k2p * value.vx * value.vx
            + 2.0 * k2 * value.vx * value.vxp
            + (k2 * value.vp) * value.vxx,
    )
