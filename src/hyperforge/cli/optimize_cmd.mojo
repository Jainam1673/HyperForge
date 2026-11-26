"""CLI entry point for M03 adaptive optimization."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.optimization.loop import (
    SearchOutcome,
    run_adaptive,
    run_random_baseline,
)


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def run_optimize(
    dataset_path: String, target: String, budget: Int, seed: UInt64
) raises -> Int:
    var err = stderr
    if not workspace_ready("."):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if budget < 2:
        err.write("hyperforge: budget must be at least 2\n")
        return EXIT_USAGE

    var adaptive: SearchOutcome
    try:
        adaptive = run_adaptive(".", dataset_path, target, budget, seed)
    except e:
        err.write("hyperforge: adaptive run failed: " + String(e) + "\n")
        return EXIT_FAILURE

    var baseline: SearchOutcome
    try:
        baseline = run_random_baseline(dataset_path, target, budget, seed)
    except e:
        err.write("hyperforge: baseline run failed: " + String(e) + "\n")
        return EXIT_FAILURE

    print("adaptive experiment: " + adaptive.experiment_id)
    print("adaptive policy:     tpe_density_ratio_v1")
    print("adaptive best:       " + adaptive.best_kind + " (" + adaptive.best_id + ")")
    print("adaptive validation: rmse=" + String(adaptive.validation_rmse))
    print("adaptive test:       rmse=" + String(adaptive.test_rmse))
    print(
        "adaptive trials:     succeeded=" + String(adaptive.succeeded)
        + " failed=" + String(adaptive.failed) + " invalid=" + String(adaptive.invalid)
    )
    print("adaptive search_s:   " + String(adaptive.search_seconds))
    print("baseline policy:     random_search_v1")
    print("baseline best:       " + baseline.best_kind + " (" + baseline.best_id + ")")
    print("baseline validation: rmse=" + String(baseline.validation_rmse))
    print("baseline test:       rmse=" + String(baseline.test_rmse))
    print("baseline search_s:   " + String(baseline.search_seconds))
    print("matched_budget:      " + String(budget))
    print("matched_seed:        " + String(seed))
    print("matched_split:       yes")
    if adaptive.test_rmse < baseline.test_rmse:
        print("lower_test_rmse:     adaptive")
    elif baseline.test_rmse < adaptive.test_rmse:
        print("lower_test_rmse:     baseline")
    else:
        print("lower_test_rmse:     tie")
    return EXIT_OK
