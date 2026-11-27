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
from hyperforge.cli.automl_cmd import (
    inspect_dataset,
    run_experiment,
    show_experiment as automl_show,
    replay_experiment as automl_replay,
    report_experiment,
    compare_experiments,
)
from hyperforge.cli.optimize_cmd import run_optimize
from hyperforge.cli.sinn_cmd import list_problems, solve_problem, show_result
from hyperforge.cli.scit_cmd import train_scit, show_scit, predict_scit
from hyperforge.cli.gpu_cmd import hardware_probe, benchmark_kernel
from hyperforge.cli.discover_cmd import run_discovery
from hyperforge.cli.autodl_cmd import run_autodl, show_autodl, replay_autodl
from hyperforge.cli.autorl_cmd import (
    list_environments,
    run_autorl,
    show_autorl,
    replay_autorl,
)
from hyperforge.cli.autotrans_cmd import (
    run_autotrans,
    show_autotrans,
    replay_autotrans,
)
from hyperforge.cli.autollm_cmd import (
    discover_command,
    evaluate_command,
    status_command,
)
from hyperforge.cli.sciml_cmd import (
    list_problems as sciml_list,
    solve_problem as sciml_solve,
    show_result as sciml_show,
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
        if code == EXIT_OK and parsed.gpu:
            code = hardware_probe()
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
    elif parsed.command == "automl":
        ref a = parsed.args
        if a[0] == "inspect":
            code = inspect_dataset(a[1], a[2])
        elif a[0] == "run":
            var budget = 5
            var seed: UInt64 = 42
            if len(a) >= 4:
                budget = Int(a[3])
            if len(a) >= 5:
                seed = UInt64(Int(a[4]))
            code = run_experiment(".", a[1], a[2], budget, seed)
        elif a[0] == "show":
            code = automl_show(".", a[1])
        elif a[0] == "replay":
            code = automl_replay(".", a[1])
        elif a[0] == "compare":
            code = compare_experiments(".", a[1], a[2])
        else:
            code = EXIT_USAGE
    elif parsed.command == "report":
        code = report_experiment(".", parsed.args[0])
    elif parsed.command == "optimize":
        ref oa = parsed.args
        var budget = 5
        var seed: UInt64 = 42
        if len(oa) >= 4:
            budget = Int(oa[3])
        if len(oa) >= 5:
            seed = UInt64(Int(oa[4]))
        code = run_optimize(oa[1], oa[2], budget, seed)
    elif parsed.command == "sinn":
        ref sa = parsed.args
        var seed: UInt64 = 42
        var iterations = 800
        if len(sa) >= 3:
            seed = UInt64(Int(sa[2]))
        if len(sa) >= 4:
            iterations = Int(sa[3])
        if sa[0] == "list-problems":
            code = list_problems()
        elif sa[0] == "solve":
            code = solve_problem(".", sa[1], seed, iterations)
        elif sa[0] == "show":
            code = show_result(".", sa[1])
        else:
            code = EXIT_USAGE
    elif parsed.command == "sci-transformers":
        ref ca = parsed.args
        if ca[0] == "train":
            var seed: UInt64 = 42
            var epochs = 5
            if len(ca) >= 2:
                seed = UInt64(Int(ca[1]))
            if len(ca) >= 3:
                epochs = Int(ca[2])
            code = train_scit(".", seed, epochs)
        elif ca[0] == "show":
            code = show_scit(".", ca[1])
        elif ca[0] == "predict":
            var sample_index = 0
            if len(ca) >= 3:
                sample_index = Int(ca[2])
            code = predict_scit(".", ca[1], sample_index)
        else:
            code = EXIT_USAGE
    elif parsed.command == "hardware":
        code = hardware_probe()
    elif parsed.command == "benchmark":
        code = benchmark_kernel(".")
    elif parsed.command == "discover":
        ref da = parsed.args
        var budget = 6
        var seed: UInt64 = 42
        if len(da) >= 2:
            budget = Int(da[1])
        if len(da) >= 3:
            seed = UInt64(Int(da[2]))
        code = run_discovery(".", budget, seed)
    elif parsed.command == "autodl":
        ref aa = parsed.args
        if aa[0] == "run":
            var budget = 4
            var seed: UInt64 = 42
            if len(aa) >= 2:
                budget = Int(aa[1])
            if len(aa) >= 3:
                seed = UInt64(Int(aa[2]))
            code = run_autodl(".", budget, seed)
        elif aa[0] == "show":
            code = show_autodl(".", aa[1])
        elif aa[0] == "replay":
            code = replay_autodl(".", aa[1])
        else:
            code = EXIT_USAGE
    elif parsed.command == "autorl":
        ref ra = parsed.args
        if ra[0] == "list-envs":
            code = list_environments()
        elif ra[0] == "run":
            var episodes = 60
            var evaluation_episodes = 20
            if len(ra) >= 2:
                episodes = Int(ra[1])
            if len(ra) >= 3:
                evaluation_episodes = Int(ra[2])
            code = run_autorl(".", episodes, evaluation_episodes)
        elif ra[0] == "show":
            code = show_autorl(".", ra[1])
        elif ra[0] == "replay":
            code = replay_autorl(".", ra[1])
        else:
            code = EXIT_USAGE
    elif parsed.command == "autotransformers":
        ref ta = parsed.args
        if ta[0] == "run":
            var budget = 3
            var seed: UInt64 = 42
            if len(ta) >= 2:
                budget = Int(ta[1])
            if len(ta) >= 3:
                seed = UInt64(Int(ta[2]))
            code = run_autotrans(".", budget, seed)
        elif ta[0] == "show":
            code = show_autotrans(".", ta[1])
        elif ta[0] == "replay":
            code = replay_autotrans(".", ta[1])
        else:
            code = EXIT_USAGE
    elif parsed.command == "autollm":
        ref la = parsed.args
        if la[0] == "discover":
            var path = String(".")
            if len(la) >= 2:
                path = la[1]
            code = discover_command(".", path)
        elif la[0] == "evaluate":
            code = evaluate_command(".", la[1], la[2])
        elif la[0] == "status":
            code = status_command(".")
        else:
            code = EXIT_USAGE
    elif parsed.command == "sciml":
        ref sa = parsed.args
        if sa[0] == "list-problems":
            code = sciml_list()
        elif sa[0] == "solve":
            var seed: UInt64 = 42
            if len(sa) >= 2:
                seed = UInt64(Int(sa[1]))
            code = sciml_solve(".", seed)
        elif sa[0] == "show":
            code = sciml_show(".", sa[1])
        else:
            code = EXIT_USAGE
    else:
        print_help()

    if code != EXIT_OK:
        exit(code)
