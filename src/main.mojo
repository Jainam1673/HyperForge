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
from hyperforge.cli.gpu_cmd import (
    hardware_probe,
    list_catalogue,
    benchmark_catalogue,
)
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
from hyperforge.cli.autollm_lifecycle_cmd import (
    pretrain_command,
    continue_command,
    infer_command,
    lifecycle_status,
)
from hyperforge.cli.serve_cmd import status_command as serve_status_command
from hyperforge.cli.autodl_full_cmd import run_autodl_full
from hyperforge.cli.sciml_cmd import (
    list_problems as sciml_list,
    solve_problem as sciml_solve,
    show_result as sciml_show,
)
from hyperforge.cli.scidl_cmd import run_scidl, show_scidl
from hyperforge.cli.scirl_cmd import run_scirl, show_scirl
from hyperforge.cli.looper_cmd import run_looper, show_looper
from hyperforge.cli.systems_cmd import run_systems, show_systems
from hyperforge.cli.meta_cmd import run_meta, show_graph
from hyperforge.cli.joint_cmd import run_joint_benchmark, show_joint
from hyperforge.cli.rsi_cmd import run_rsi_cmd, show_rsi, rollback_rsi, DEFAULT_TRIALS
from hyperforge.cli.automl_full_cmd import run_full
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
        elif a[0] == "full":
            var budget = 8
            var seed: UInt64 = 42
            var folds = 3
            var use_grid = False
            if len(a) >= 4:
                budget = Int(a[3])
            if len(a) >= 5:
                seed = UInt64(Int(a[4]))
            if len(a) >= 6:
                folds = Int(a[5])
            if len(a) >= 7 and a[6] == "grid":
                use_grid = True
            code = run_full(".", a[1], a[2], budget, seed, folds, use_grid)
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
        ref ha = parsed.args
        if ha[0] == "catalogue":
            code = list_catalogue()
        else:
            code = hardware_probe()
    elif parsed.command == "benchmark":
        ref ba = parsed.args
        var kernel_name = String("vector_add")
        var size = 1024
        var repetitions = 9
        if len(ba) >= 2:
            kernel_name = ba[1]
        if len(ba) >= 3:
            size = Int(ba[2])
        if len(ba) >= 4:
            repetitions = Int(ba[3])
        code = benchmark_catalogue(".", kernel_name, size, repetitions)
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
        if aa[0] == "full":
            var policy = aa[1]
            var budget = 4
            var seed: UInt64 = 42
            var seeds = 2
            if len(aa) >= 3:
                budget = Int(aa[2])
            if len(aa) >= 4:
                seed = UInt64(Int(aa[3]))
            if len(aa) >= 5:
                seeds = Int(aa[4])
            code = run_autodl_full(".", policy, budget, seed, seeds)
        elif aa[0] == "run":
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
        if la[0] == "pretrain":
            var epochs = 6
            if len(la) >= 3:
                epochs = Int(la[2])
            code = pretrain_command(".", la[1], epochs)
        elif la[0] == "midtrain":
            var epochs = 6
            if len(la) >= 3:
                epochs = Int(la[2])
            code = continue_command(".", "midtrain", la[1], epochs)
        elif la[0] == "posttrain":
            var epochs = 6
            if len(la) >= 3:
                epochs = Int(la[2])
            code = continue_command(".", "posttrain", la[1], epochs)
        elif la[0] == "infer":
            var max_tokens = 12
            var temperature = 1.0
            if len(la) >= 3:
                max_tokens = Int(la[2])
            if len(la) >= 4:
                temperature = Float64(la[3])
            code = infer_command(".", la[1], max_tokens, temperature)
        elif la[0] == "discover":
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
    elif parsed.command == "scidl":
        ref sd = parsed.args
        if sd[0] == "run":
            var seed: UInt64 = 42
            if len(sd) >= 2:
                seed = UInt64(Int(sd[1]))
            code = run_scidl(".", seed)
        elif sd[0] == "show":
            code = show_scidl(".", sd[1])
        else:
            code = EXIT_USAGE
    elif parsed.command == "scirl":
        ref rl = parsed.args
        if rl[0] == "run":
            var episodes = 40
            var evaluation_episodes = 10
            if len(rl) >= 2:
                episodes = Int(rl[1])
            if len(rl) >= 3:
                evaluation_episodes = Int(rl[2])
            code = run_scirl(".", episodes, evaluation_episodes)
        elif rl[0] == "show":
            code = show_scirl(".", rl[1])
        else:
            code = EXIT_USAGE
    elif parsed.command == "looper":
        ref lp = parsed.args
        if lp[0] == "run":
            var budget = 4
            if len(lp) >= 3:
                budget = Int(lp[2])
            code = run_looper(".", lp[1], budget)
        elif lp[0] == "show":
            code = show_looper(".", lp[1])
        else:
            code = EXIT_USAGE
    elif parsed.command == "systems":
        ref sy = parsed.args
        if sy[0] == "search":
            var budget = 3
            var seed: UInt64 = 42
            if len(sy) >= 2:
                budget = Int(sy[1])
            if len(sy) >= 3:
                seed = UInt64(Int(sy[2]))
            code = run_systems(".", budget, seed)
        elif sy[0] == "show":
            code = show_systems(".")
        else:
            code = EXIT_USAGE
    elif parsed.command == "meta":
        ref me = parsed.args
        if me[0] == "run":
            var budget = 4
            var seed: UInt64 = 42
            if len(me) >= 2:
                budget = Int(me[1])
            if len(me) >= 3:
                seed = UInt64(Int(me[2]))
            code = run_meta(".", budget, seed)
        elif me[0] == "graph":
            code = show_graph(".")
        else:
            code = EXIT_USAGE
    elif parsed.command == "joint":
        ref jo = parsed.args
        if jo[0] == "run":
            var budget = 6
            var seeds = List[UInt64]()
            if len(jo) >= 2:
                budget = Int(jo[1])
            if len(jo) >= 3:
                for i in range(2, len(jo)):
                    seeds.append(UInt64(Int(jo[i])))
            if len(seeds) == 0:
                seeds.append(UInt64(42))
            code = run_joint_benchmark(".", budget, seeds)
        elif jo[0] == "show":
            code = show_joint(".")
        else:
            code = EXIT_USAGE
    elif parsed.command == "serve":
        code = serve_status_command(".")
    elif parsed.command == "rsi":
        ref rs = parsed.args
        var trials = DEFAULT_TRIALS
        if len(rs) >= 2:
            trials = Int(rs[1])
        if rs[0] == "run":
            code = run_rsi_cmd(".", trials, parsed.apply)
        elif rs[0] == "show":
            code = show_rsi(".")
        elif rs[0] == "rollback":
            code = rollback_rsi(".", parsed.apply)
        else:
            code = EXIT_USAGE
    else:
        print_help()

    if code != EXIT_OK:
        exit(code)
