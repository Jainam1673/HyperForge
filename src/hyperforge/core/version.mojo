"""Build identity for HyperForge.

These constants are build-time facts, not runtime observations. `doctor` labels
them as pinned values and directs the user to the installed toolchain commands
for live versions.
"""

comptime VERSION = "0.1.0"
comptime MILESTONE = "M20"
comptime WORKSPACE_SCHEMA = "hyperforge-workspace-v1"

# Pinned versions from pixi.toml/pixi.lock. These are declared facts, not live
# probes; `doctor` prints the commands that verify them at runtime.
comptime MOJO_PIN = "1.2.0"
comptime MAX_PIN = "26.7.0"
comptime DOCTOR_SCHEMA = "hyperforge-doctor-v1"
