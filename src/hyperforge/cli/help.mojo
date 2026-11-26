"""Human-readable CLI help. Rendered to stdout only."""

from hyperforge.core.version import VERSION, MILESTONE


def print_help() raises:
    print(
        "hyperforge " + VERSION + " (" + MILESTONE + ")\n"
        + "Native Mojo CLI for reproducible research and discovery.\n"
        + "\n"
        + "USAGE\n"
        + "  hyperforge <command> [options]\n"
        + "\n"
        + "IMPLEMENTED COMMANDS\n"
        + "  --help, -h              Show this help and exit\n"
        + "  --version, -V           Print version and exit\n"
        + "  doctor [--json]         Report toolchain and capability status\n"
        + "  init <path>             Initialize a versioned local workspace\n"
        + "  experiment create <name> [seed]\n"
        + "                          Create a versioned experiment record\n"
        + "  experiment list [--json]\n"
        + "                          List local experiment records\n"
        + "  experiment show <id> [--json]\n"
        + "                          Inspect one experiment and its events\n"
        + "  experiment replay <id>  Verify inputs before replay (execution in M02)\n"
        + "\n"
        + "PLANNED COMMANDS (not registered; no behavior yet)\n"
        + "  experiment compare, automl run|inspect, benchmark run,\n"
        + "  verify, report, discover, sinn, sci-transformers\n"
        + "\n"
        + "EXIT CODES\n"
        + "  0 success    1 failure    2 usage error    3 unavailable\n"
        + "  70 internal error    130 interrupted\n"
        + "\n"
        + "EXAMPLES\n"
        + "  hyperforge doctor\n"
        + "  hyperforge init ./workspace\n"
    )


def print_version() raises:
    print("hyperforge " + VERSION + " (" + MILESTONE + ")")
