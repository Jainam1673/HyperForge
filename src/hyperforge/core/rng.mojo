"""Deterministic pseudo-random substrate for experiments.

SplitMix64 is small, reproducible, and has known good statistical behavior for
seeding. Seed derivation is a pure function of (base seed, namespace, index),
so a recorded seed plus an index always reproduces the same value.
"""

from hyperforge.core.hash import fnv1a64


struct SplitMix64:
    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def next_u64(mut self) -> UInt64:
        self.state += UInt64(0x9E3779B97F4A7C15)
        var z = self.state
        z = (z ^ (z >> 30)) * UInt64(0xBF58476D1CE4E5B9)
        z = (z ^ (z >> 27)) * UInt64(0x94D049BB133111EB)
        return z ^ (z >> 31)

    def next_below(mut self, upper: UInt64) -> UInt64:
        if upper == 0:
            return 0
        return self.next_u64() % upper


def derive_seed(base: UInt64, namespace: String, index: UInt64) raises -> UInt64:
    """Derive a named sub-seed deterministically from a base seed."""
    var key = String(base) + "|" + namespace + "|" + String(index)
    return fnv1a64(key)
