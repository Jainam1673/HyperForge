"""Small numeric primitives needed by the regression slice.

Every helper is testable without GPU or MAX. `is_finite` uses NaN's
self-inequality and a magnitude bound because installed Mojo 1.2.0 has no
`is_finite` in `std.math` or on `Float64`.
"""

from std.math import abs

comptime MAX_FINITE_MAGNITUDE = 1.7976931348623157e308


def is_finite(value: Float64) raises -> Bool:
    return value == value and abs(value) < MAX_FINITE_MAGNITUDE


def finite_mean(values: List[Float64]) raises -> Float64:
    if len(values) == 0:
        raise Error("mean of empty list")
    var total = Float64(0.0)
    for value in values:
        if not is_finite(value):
            raise Error("non-finite value in mean")
        total += value
    return total / Float64(len(values))


def finite_variance(values: List[Float64], average: Float64) raises -> Float64:
    if len(values) == 0:
        raise Error("variance of empty list")
    var total = Float64(0.0)
    for value in values:
        var delta = value - average
        total += delta * delta
    return total / Float64(len(values))


def dot_product(left: List[Float64], right: List[Float64]) raises -> Float64:
    if len(left) != len(right):
        raise Error("dot product length mismatch")
    var total = Float64(0.0)
    for i in range(len(left)):
        total += left[i] * right[i]
    return total
