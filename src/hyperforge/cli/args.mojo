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
    var target: String
    var json: Bool
    var help: Bool
    var version: Bool
    var error: String

    def __init__(out self):
        self.command = ""
        self.target = ""
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
        elif token.startswith("-"):
            result.error = "unknown option: " + token
            return result^
        elif result.command == "init" and result.target == "":
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
    if result.json and result.command != "doctor":
        result.error = "--json is only valid with 'doctor'"

    return result^


def parse_args() raises -> CliArgs:
    """Parse the process arguments into `CliArgs`. Never exits the process."""
    var tokens = List[String]()
    for arg in argv():
        tokens.append(String(arg))
    return parse_tokens(tokens)
