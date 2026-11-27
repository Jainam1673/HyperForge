"""CLI for SciRL solver-selection decisions."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.scirl.simulator import default_env
from hyperforge.scirl.agent import SciRLOutcome, run_experiment

comptime CONFIG_MAGIC = "HSCIRL1"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def run_scirl(workspace: String, episodes: Int, evaluation_episodes: Int) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if episodes < 4 or evaluation_episodes < 2:
        err.write("hyperforge: episodes must be >=4 and evaluation episodes >=2\n")
        return EXIT_USAGE
    var env = default_env()
    var outcome = run_experiment(env, episodes, evaluation_episodes)
    var id = "scirl-" + hex64(fnv1a64(
        "solver-selection|" + String(episodes) + "|" + String(evaluation_episodes)
    ))
    var config = (
        CONFIG_MAGIC + "|env=solver_selection_1d|episodes=" + String(episodes)
        + "|eval=" + String(evaluation_episodes) + "\n"
    )
    var checksum = hex64(fnv1a64(config))
    var config_path = workspace + "/artifacts/" + id + ".config.txt"
    var config_file = open(config_path, "w")
    config_file.write(config)
    config_file.close()
    var curve_path = workspace + "/artifacts/" + id + ".returns.txt"
    var curve_file = open(curve_path, "w")
    curve_file.write("episode,mean_training_return\n")
    for i in range(len(outcome.curve)):
        curve_file.write(String(i) + "," + String(outcome.curve[i]) + "\n")
    curve_file.close()

    var fields = List[Field]()
    fields.append(Field("episodes", String(episodes)))
    fields.append(Field("learned_mean", String(outcome.learned_mean)))
    fields.append(Field("learned_std", String(outcome.learned_std)))
    fields.append(Field("ci95", String(outcome.ci95)))
    fields.append(Field("random_mean", String(outcome.random_mean)))
    fields.append(Field("heuristic_mean", String(outcome.heuristic_mean)))
    fields.append(Field("improvement_random", String(outcome.improvement_random)))
    fields.append(Field("improvement_heuristic", String(outcome.improvement_heuristic)))
    fields.append(Field("state", outcome.state))
    fields.append(Field("config_checksum", checksum))
    append_record(journal_path(workspace), next_sequence(read_journal(journal_path(workspace)).records), "scirl", fields)

    print("experiment:          " + id)
    print("environment:         solver_selection_1d (validated Poisson simulator)")
    print("conditions:          train k grid [0.50,1.49]; held-out offset grid [0.505,1.495]")
    print("learned mean return: " + String(outcome.learned_mean))
    print("learned std:         " + String(outcome.learned_std))
    print("ci95 half-width:     " + String(outcome.ci95))
    print("random mean:         " + String(outcome.random_mean))
    print("heuristic mean:      " + String(outcome.heuristic_mean))
    print("improvement random:  " + String(outcome.improvement_random))
    print("improvement heur:    " + String(outcome.improvement_heuristic))
    print("state:               " + outcome.state)
    print("learning_curve:      " + curve_path)
    return EXIT_OK


def show_scirl(workspace: String, id: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    for i in range(len(journal.records)):
        ref record = journal.records[i]
        if record.kind == "scirl":
            print("learned_mean:        " + record.fields["learned_mean"])
            print("random_mean:         " + record.fields["random_mean"])
            print("heuristic_mean:      " + record.fields["heuristic_mean"])
            print("state:               " + record.fields["state"])
            return EXIT_OK
    err.write("hyperforge: SciRL result not found: " + id + "\n")
    return EXIT_FAILURE
