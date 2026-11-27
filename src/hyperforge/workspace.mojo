"""Minimal `hyperforge init` workspace creation (M00 scope)."""

from std.os import mkdir
from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.version import VERSION, MILESTONE, WORKSPACE_SCHEMA
from hyperforge.core.exit_codes import EXIT_OK, EXIT_USAGE, EXIT_FAILURE
from hyperforge.hardening import validate_path


def has_parent_segment(path: String) raises -> Bool:
    """Reject any path containing `..` to avoid parent-directory traversal."""
    var previous_was_dot = False
    for i in range(path.byte_length()):
        var is_dot = String(path[byte=i]) == "."
        if is_dot and previous_was_dot:
            return True
        previous_was_dot = is_dot
    return False


def init_workspace(target: String) raises -> Int:
    """Create a versioned workspace. Returns an exit code; errors go to stderr."""
    var err = stderr

    if target == "":
        err.write("hyperforge: init requires a target directory\n")
        err.write("Usage: hyperforge init <path>\n")
        return EXIT_USAGE

    if has_parent_segment(target):
        err.write("hyperforge: invalid workspace path: '..' is not allowed\n")
        return EXIT_USAGE

    if not validate_path(target):
        err.write("hyperforge: invalid workspace path: traversal, NUL, or length limit\n")
        return EXIT_USAGE

    var root = Path(target)
    if root.exists() and not root.is_dir():
        err.write("hyperforge: target exists and is not a directory: " + target + "\n")
        return EXIT_USAGE

    var config_path = target + "/hyperforge.toml"
    if Path(config_path).exists():
        err.write("hyperforge: workspace already initialized: " + target + "\n")
        return EXIT_USAGE

    try:
        if not root.exists():
            mkdir(target)
        mkdir(target + "/experiments")
        mkdir(target + "/artifacts")
        mkdir(target + "/logs")

        var config = open(config_path, "w")
        config.write(
            "# HyperForge workspace configuration\n"
            + "schema = \"" + WORKSPACE_SCHEMA + "\"\n"
            + "version = 1\n"
            + "created_by = \"hyperforge " + VERSION + " (" + MILESTONE + ")\"\n"
        )
        config.close()
    except e:
        _ = e
        err.write("hyperforge: failed to create workspace at " + target + "\n")
        return EXIT_FAILURE

    print("Initialized HyperForge workspace at " + target)
    print("  config:     " + config_path)
    print("  experiments:" + target + "/experiments")
    print("  artifacts:  " + target + "/artifacts")
    print("  logs:       " + target + "/logs")
    return EXIT_OK
