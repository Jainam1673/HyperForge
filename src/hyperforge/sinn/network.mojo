"""Explicit tiny tanh network with exact Dirichlet boundary enforcement.

For Poisson on [0,1] with u(0)=u(1)=0, the learned field is

    u(x) = x(1-x) * N(x)

so boundary conditions are satisfied by construction, not by a penalty.
"""

from std.math import tanh
from hyperforge.core.rng import SplitMix64, derive_seed
from hyperforge.sinn.jet import Jet, constant, parameter, jet_add, jet_mul, jet_scale, jet_tanh

comptime NETWORK_SCHEMA = "hyperforge-sinn-network-v1"


struct SmallNet(Copyable, Movable):
    var width: Int
    var w1: List[Float64]
    var b1: List[Float64]
    var v: List[Float64]
    var b2: Float64

    def __init__(
        out self,
        width: Int,
        var w1: List[Float64],
        var b1: List[Float64],
        var v: List[Float64],
        b2: Float64,
    ):
        self.width = width
        self.w1 = w1^
        self.b1 = b1^
        self.v = v^
        self.b2 = b2


def init_network(seed: UInt64, width: Int) raises -> SmallNet:
    if width < 1:
        raise Error("network width must be positive")
    var rng = SplitMix64(derive_seed(seed, "sinn-init", UInt64(0)))
    var w1 = List[Float64]()
    var b1 = List[Float64]()
    var v = List[Float64]()
    for _ in range(width):
        w1.append(Float64(Int(rng.next_below(UInt64(1001))) - 500) / 1000.0)
        b1.append(Float64(Int(rng.next_below(UInt64(201)) - 100)) / 1000.0)
        v.append(Float64(Int(rng.next_below(UInt64(1001))) - 500) / 1000.0)
    var b2 = Float64(Int(rng.next_below(UInt64(201)) - 100)) / 1000.0
    return SmallNet(width, w1^, b1^, v^, b2)


def param_count(net: SmallNet) raises -> Int:
    return 3 * net.width + 1


def get_param(net: SmallNet, index: Int) raises -> Float64:
    if index < net.width:
        return net.w1[index]
    if index < 2 * net.width:
        return net.b1[index - net.width]
    if index < 3 * net.width:
        return net.v[index - 2 * net.width]
    if index == 3 * net.width:
        return net.b2
    raise Error("parameter index out of range")


def set_param(mut net: SmallNet, index: Int, value: Float64) raises -> None:
    if index < net.width:
        net.w1[index] = value
    elif index < 2 * net.width:
        net.b1[index - net.width] = value
    elif index < 3 * net.width:
        net.v[index - 2 * net.width] = value
    elif index == 3 * net.width:
        net.b2 = value
    else:
        raise Error("parameter index out of range")


def raw_network(net: SmallNet, x: Float64) raises -> Float64:
    var hidden = Float64(0.0)
    for j in range(net.width):
        hidden += net.v[j] * tanh(net.w1[j] * x + net.b1[j])
    return tanh(hidden + net.b2)


def forward(net: SmallNet, x: Float64) raises -> Float64:
    return x * (1.0 - x) * raw_network(net, x)


def forward_jet(net: SmallNet, x_jet: Jet, param_index: Int) raises -> Jet:
    var hidden = constant(0.0)
    for j in range(net.width):
        var z = jet_add(
            jet_mul(parameter(net.w1[j], param_index == j), x_jet),
            parameter(net.b1[j], param_index == net.width + j),
        )
        hidden = jet_add(
            hidden,
            jet_mul(jet_tanh(z), parameter(net.v[j], param_index == 2 * net.width + j)),
        )
    var output = jet_tanh(
        jet_add(hidden, parameter(net.b2, param_index == 3 * net.width))
    )
    var g = jet_mul(x_jet, jet_add(constant(1.0), jet_scale(x_jet, -1.0)))
    return jet_mul(g, output)


def serialize_network(net: SmallNet) raises -> String:
    var out = String(NETWORK_SCHEMA + "|width=" + String(net.width) + "|params=")
    for i in range(param_count(net)):
        if i > 0:
            out += ","
        out += String(get_param(net, i))
    return out + "\n"


def deserialize_network(text: String) raises -> SmallNet:
    var clean = String("")
    var limit = text.byte_length()
    if text.endswith("\n"):
        limit -= 1
    for i in range(limit):
        clean += String(text[byte=i])
    var parts = clean.split("|")
    if len(parts) != 3:
        raise Error("invalid network artifact")
    var width = Int(String(parts[1]).replace("width=", ""))
    var payload = String(parts[2]).replace("params=", "")
    var values = List[Float64]()
    for cell in payload.split(","):
        values.append(Float64(String(cell)))
    if len(values) != 3 * width + 1:
        raise Error("network artifact parameter count mismatch")
    var net = init_network(UInt64(0), width)
    for i in range(len(values)):
        set_param(net, i, values[i])
    return net^
