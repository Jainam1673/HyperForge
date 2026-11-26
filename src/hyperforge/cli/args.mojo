"""First-party CLI argument parsing.

No third-party parser. The grammar is intentionally small and deterministic:

    hyperforge [--help|--version]
    hyperforge doctor [--json]
    hyperforge init <path>
"""

from std.sys import argv


struct CliArgs:
    """Parsed command line. `error` is non-empty for usage failures."""

    var command: String
    var subcommand: String
    var target: String
    var extra: String
    var args: List[String]
    var json: Bool
    var help: Bool
    var version: Bool
    var error: String

    def __init__(out self):
        self.command = ""
        self.subcommand = ""
        self.target = ""
        self.extra = ""
        self.args = List[String]()
        self.json = False
        self.help = False
        self.version = False
        self.error = ""


def parse_tokens(args: List[String]) raises -> CliArgs:
    """Parse explicit tokens into `CliArgs`. `args[0]` is the program name."""
    var result = CliArgs()

    if len(args) < 2:
        result.help = True
        return result^

    var i = 1
    while i < len(args):
        var token = args[i]

        if token == "--help" or token == "-h":
            result.help = True
        elif token == "--version" or token == "-V":
            result.version = True
        elif token == "--json":
            result.json = True
        elif token == "doctor":
            if result.command != "":
                result.error = "unexpected command: " + token
                return result^
            result.command = "doctor"
        elif token == "init":
            if result.command != "":
                result.error = "unexpected command: " + token
                return result^
            result.command = "init"
        elif token == "experiment":
            if result.command != "":
                result.error = "unexpected command: " + token
                return result^
            result.command = "experiment"
        elif (
            token == "automl"
            or token == "report"
            or token == "optimize"
            or token == "sinn"
            or token == "sci-transformers"
        ):
            if result.command != "":
                result.error = "unexpected command: " + token
                return result^
            result.command = token
        elif token.startswith("-"):
            result.error = "unknown option: " + token
            return result^
        elif (
            result.command == "automl"
            or result.command == "report"
            or result.command == "optimize"
            or result.command == "sinn"
            or result.command == "sci-transformers"
        ):
            result.args.append(token)
        elif result.command == "init" and result.target == "":
            result.target = token
        elif result.command == "experiment" and result.subcommand == "":
            if (
                token != "create"
                and token != "list"
                and token != "show"
                and token != "replay"
            ):
                result.error = "unknown experiment subcommand: " + token
                return result^
            result.subcommand = token
        elif (
            result.command == "experiment"
            and result.subcommand == "create"
            and result.target == ""
        ):
            result.target = token
        elif (
            result.command == "experiment"
            and result.subcommand == "create"
            and result.extra == ""
        ):
            result.extra = token
        elif (
            result.command == "experiment"
            and (result.subcommand == "show" or result.subcommand == "replay")
            and result.target == ""
        ):
            result.target = token
        elif result.command == "":
            result.error = (
                "unknown command: " + token + "\nRun 'hyperforge --help' for usage."
            )
            return result^
        else:
            result.error = "unexpected argument: " + token
            return result^

        i += 1

    if result.command == "init" and result.target == "":
        result.error = "init requires a target directory\nUsage: hyperforge init <path>"
    if result.command == "experiment" and result.subcommand == "":
        result.error = (
            "experiment requires a subcommand: create|list|show|replay"
        )
    if (
        result.command == "experiment"
        and result.subcommand == "create"
        and result.target == ""
    ):
        result.error = "experiment create requires a name"
    if (
        result.command == "experiment"
        and (result.subcommand == "show" or result.subcommand == "replay")
        and result.target == ""
    ):
        result.error = "experiment " + result.subcommand + " requires an id"

    var machine_ok = result.command == "doctor"
    if (
        result.command == "experiment"
        and (result.subcommand == "list" or result.subcommand == "show")
    ):
        machine_ok = True
    if result.json and not machine_ok:
        result.error = "--json is only valid with 'doctor' or 'experiment list|show'"

    if result.command == "sci-transformers":
        if len(result.args) == 0:
            result.error = "sci-transformers requires: train|show|predict"
        elif result.args[0] == "train" and (len(result.args) < 1 or len(result.args) > 3):
            result.error = "usage: hyperforge sci-transformers train [seed] [epochs]"
        elif result.args[0] == "show" and len(result.args) != 2:
            result.error = "usage: hyperforge sci-transformers show <experiment-id>"
        elif result.args[0] == "predict" and (len(result.args) < 2 or len(result.args) > 3):
            result.error = "usage: hyperforge sci-transformers predict <id> [sample]"
        elif (
            result.args[0] != "train"
            and result.args[0] != "show"
            and result.args[0] != "predict"
        ):
            result.error = "unknown sci-transformers subcommand: " + result.args[0]
    if result.command == "sinn":
        if len(result.args) == 0:
            result.error = "sinn requires: list-problems|solve|show"
        elif result.args[0] == "list-problems" and len(result.args) != 1:
            result.error = "usage: hyperforge sinn list-problems"
        elif result.args[0] == "solve" and (len(result.args) < 2 or len(result.args) > 4):
            result.error = "usage: hyperforge sinn solve <problem> [seed] [iterations]"
        elif result.args[0] == "show" and len(result.args) != 2:
            result.error = "usage: hyperforge sinn show <experiment-id>"
        elif (
            result.args[0] != "list-problems"
            and result.args[0] != "solve"
            and result.args[0] != "show"
        ):
            result.error = "unknown sinn subcommand: " + result.args[0]
    if result.command == "optimize":
        if len(result.args) == 0:
            result.error = "optimize requires a subcommand: run"
        elif result.args[0] != "run":
            result.error = "unknown optimize subcommand: " + result.args[0]
        elif len(result.args) < 3 or len(result.args) > 5:
            result.error = "usage: hyperforge optimize run <data.csv> <target> [budget] [seed]"
    if result.command == "report" and len(result.args) != 1:
        result.error = "usage: hyperforge report <experiment-id>"
    if result.command == "automl":
        if len(result.args) == 0:
            result.error = "automl requires: inspect|run|show|replay|compare"
        elif result.args[0] == "inspect" and len(result.args) != 3:
            result.error = "usage: hyperforge automl inspect <data.csv> <target>"
        elif result.args[0] == "run" and (len(result.args) < 3 or len(result.args) > 5):
            result.error = "usage: hyperforge automl run <data.csv> <target> [budget] [seed]"
        elif (
            (result.args[0] == "show" or result.args[0] == "replay")
            and len(result.args) != 2
        ):
            result.error = "usage: hyperforge automl " + result.args[0] + " <experiment-id>"
        elif result.args[0] == "compare" and len(result.args) != 3:
            result.error = "usage: hyperforge automl compare <id-a> <id-b>"
        elif (
            result.args[0] != "inspect"
            and result.args[0] != "run"
            and result.args[0] != "show"
            and result.args[0] != "replay"
            and result.args[0] != "compare"
        ):
            result.error = "unknown automl subcommand: " + result.args[0]

    return result^


def parse_args() raises -> CliArgs:
    """Parse the process arguments into `CliArgs`. Never exits the process."""
    var tokens = List[String]()
    for arg in argv():
        tokens.append(String(arg))
    return parse_tokens(tokens)
