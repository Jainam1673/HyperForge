"""HyperForge native CLI entry point (M00)."""

from std.sys import argv, stderr, exit
from hyperforge.cli.args import parse_args
from hyperforge.cli.help import print_help, print_version
from hyperforge.doctor import run_doctor
from hyperforge.workspace import init_workspace
from hyperforge.cli.experiment_cmd import (
    create_experiment,
    list_experiments,
    show_experiment,
    replay_experiment,
)
from hyperforge.core.exit_codes import EXIT_OK, EXIT_USAGE, EXIT_INTERNAL


def main() raises:
    var parsed = parse_args()
    var code = EXIT_OK

    if parsed.error != "":
        var err = stderr
        err.write("hyperforge: " + parsed.error + "\n")
        code = EXIT_USAGE
    elif parsed.help:
        print_help()
    elif parsed.version:
        print_version()
    elif parsed.command == "doctor":
        var args = argv()
        code = run_doctor(String(args[0]), parsed.json)
    elif parsed.command == "init":
        code = init_workspace(parsed.target)
    elif parsed.command == "experiment":
        if parsed.subcommand == "create":
            code = create_experiment(".", parsed.target, parsed.extra)
        elif parsed.subcommand == "list":
            code = list_experiments(".", parsed.json)
        elif parsed.subcommand == "show":
            code = show_experiment(".", parsed.target, parsed.json)
        elif parsed.subcommand == "replay":
            code = replay_experiment(".", parsed.target)
        else:
            code = EXIT_USAGE
    else:
        print_help()

    if code != EXIT_OK:
        exit(code)
