"""Minimal reverse-mode tape over scalar nodes.

Each node stores its value, a list of parent node indices, and the local
derivative with respect to each parent. `backward` accumulates gradients in
reverse topological order. This is a straightforward reference implementation:
no fusion, no FlashAttention, no GPU claims.
"""

from std.math import exp, sqrt, tanh

struct Tape:
    var values: List[Float64]
    var grads: List[Float64]
    var parents: List[List[Int]]
    var locals: List[List[Float64]]
    var parameter_ids: List[Int]

    def __init__(out self):
        self.values = List[Float64]()
        self.grads = List[Float64]()
        self.parents = List[List[Int]]()
        self.locals = List[List[Float64]]()
        self.parameter_ids = List[Int]()

    def value(self, node: Int) raises -> Float64:
        return self.values[node]

    def constant(mut self, value: Float64) raises -> Int:
        self.values.append(value)
        self.grads.append(0.0)
        self.parents.append(List[Int]())
        self.locals.append(List[Float64]())
        self.parameter_ids.append(-1)
        return len(self.values) - 1

    def parameter(mut self, value: Float64, id: Int) raises -> Int:
        var node = self.constant(value)
        self.parameter_ids[node] = id
        return node

    def add(mut self, left: Int, right: Int) raises -> Int:
        self.values.append(self.values[left] + self.values[right])
        self.grads.append(0.0)
        var p = List[Int]()
        p.append(left)
        p.append(right)
        self.parents.append(p^)
        var l = List[Float64]()
        l.append(1.0)
        l.append(1.0)
        self.locals.append(l^)
        self.parameter_ids.append(-1)
        return len(self.values) - 1

    def sub(mut self, left: Int, right: Int) raises -> Int:
        self.values.append(self.values[left] - self.values[right])
        self.grads.append(0.0)
        var p = List[Int]()
        p.append(left)
        p.append(right)
        self.parents.append(p^)
        var l = List[Float64]()
        l.append(1.0)
        l.append(-1.0)
        self.locals.append(l^)
        self.parameter_ids.append(-1)
        return len(self.values) - 1

    def mul(mut self, left: Int, right: Int) raises -> Int:
        self.values.append(self.values[left] * self.values[right])
        self.grads.append(0.0)
        var p = List[Int]()
        p.append(left)
        p.append(right)
        self.parents.append(p^)
        var l = List[Float64]()
        l.append(self.values[right])
        l.append(self.values[left])
        self.locals.append(l^)
        self.parameter_ids.append(-1)
        return len(self.values) - 1

    def scale(mut self, node: Int, factor: Float64) raises -> Int:
        self.values.append(self.values[node] * factor)
        self.grads.append(0.0)
        var p = List[Int]()
        p.append(node)
        self.parents.append(p^)
        var l = List[Float64]()
        l.append(factor)
        self.locals.append(l^)
        self.parameter_ids.append(-1)
        return len(self.values) - 1

    def tanh(mut self, node: Int) raises -> Int:
        var t = tanh(self.values[node])
        self.values.append(t)
        self.grads.append(0.0)
        var p = List[Int]()
        p.append(node)
        self.parents.append(p^)
        var l = List[Float64]()
        l.append(1.0 - t * t)
        self.locals.append(l^)
        self.parameter_ids.append(-1)
        return len(self.values) - 1

    def exp(mut self, node: Int) raises -> Int:
        var e = exp(self.values[node])
        self.values.append(e)
        self.grads.append(0.0)
        var p = List[Int]()
        p.append(node)
        self.parents.append(p^)
        var l = List[Float64]()
        l.append(e)
        self.locals.append(l^)
        self.parameter_ids.append(-1)
        return len(self.values) - 1

    def sqrt(mut self, node: Int) raises -> Int:
        var root = sqrt(self.values[node])
        self.values.append(root)
        self.grads.append(0.0)
        var p = List[Int]()
        p.append(node)
        self.parents.append(p^)
        var l = List[Float64]()
        if root > 0.0:
            l.append(0.5 / root)
        else:
            l.append(0.0)
        self.locals.append(l^)
        self.parameter_ids.append(-1)
        return len(self.values) - 1

    def divide(mut self, numerator: Int, denominator: Int) raises -> Int:
        var d = self.values[denominator]
        self.values.append(self.values[numerator] / d)
        self.grads.append(0.0)
        var p = List[Int]()
        p.append(numerator)
        p.append(denominator)
        self.parents.append(p^)
        var l = List[Float64]()
        l.append(1.0 / d)
        l.append(-self.values[numerator] / (d * d))
        self.locals.append(l^)
        self.parameter_ids.append(-1)
        return len(self.values) - 1

    def backward(mut self, node: Int) raises -> None:
        self.grads[node] = 1.0
        var i = len(self.values) - 1
        while i >= 0:
            var contribution = self.grads[i]
            if contribution != 0.0:
                for j in range(len(self.parents[i])):
                    var parent = self.parents[i][j]
                    self.grads[parent] += contribution * self.locals[i][j]
            i -= 1

    def grad_of(self, node: Int) raises -> Float64:
        return self.grads[node]

    def accumulated(self, parameter_index: Int) raises -> Float64:
        var total = Float64(0.0)
        for i in range(len(self.parameter_ids)):
            if self.parameter_ids[i] == parameter_index:
                total += self.grads[i]
        return total
