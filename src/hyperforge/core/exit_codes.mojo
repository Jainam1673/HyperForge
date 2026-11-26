"""Stable process exit codes.

Kept as named constants so CLI dispatch and tests agree on the contract.
Documented in `docs/engineering/CLI_SPEC.md`.
"""

comptime EXIT_OK = 0
comptime EXIT_FAILURE = 1
comptime EXIT_USAGE = 2
comptime EXIT_UNAVAILABLE = 3
comptime EXIT_INTERNAL = 70
comptime EXIT_INTERRUPTED = 130
