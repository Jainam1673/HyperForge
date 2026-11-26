"""Deterministic non-cryptographic integrity hash (FNV-1a 64-bit).

Used for journal record checksums and artifact fingerprints. It detects
accidental corruption and truncation; it is not a security hash.
"""

comptime FNV_OFFSET: UInt64 = 14695981039346656037
comptime FNV_PRIME: UInt64 = 1099511628211


def fnv1a64(value: String) raises -> UInt64:
    var hash = FNV_OFFSET
    for byte in value.as_bytes():
        hash = (hash ^ UInt64(byte)) * FNV_PRIME
    return hash


def hex64(value: UInt64) raises -> String:
    """Render a UInt64 as 16 lowercase hex digits, big-endian."""
    comptime digits = "0123456789abcdef"
    var out = String("")
    for i in range(16):
        var shift = UInt64(60 - 4 * i)
        var nibble = Int((value >> shift) & UInt64(15))
        out += String(digits[byte=nibble])
    return out
