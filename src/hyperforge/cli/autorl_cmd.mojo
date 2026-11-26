"""CLI for the tabular AutoRL slice."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE, EXIT_UNAVAILABLE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal, rewrite_journal
from hyperforge.autorl.environment import grid_4x4, ENV_NAME, ENV_SCHEMA, state_count
from hyperforge.autorl.experiment import RLExperiment, run_rl_experiment

comptime CONFIG_MAGIC = "HAUTORL1"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def list_environments() raises -> Int:
    print("Supported deterministic environments:")
    print("  grid_4x4_two_walls  4x4 grid, start=(0,0), goal=(3,3), walls=[5,9]")
    print("  Actions: 0=up 1=right 2=down 3=left; reward -1 per step, +10 at goal")
    print("  Termination: goal or 24-step budget; step after terminal is rejected")
    print("Status: VERIFIED for tabular methods; no real-world actions exist.")
    return EXIT_OK


def outcome_fields(outcome: RLExperiment, checksum: String, state: String) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("env", ENV_NAME))
    fields.append(Field("episodes", String(outcome.episodes)))
    fields.append(Field("selected", outcome.selected))
    fields.append(Field("test_mean", String(outcome.test_mean)))
    fields.append(Field("test_std", String(outcome.test_std)))
    fields.append(Field("ci95", String(outcome.ci95)))
    fields.append(Field("random_mean", String(outcome.random_mean)))
    fields.append(Field("optimal_mean", String(outcome.optimal_mean)))
    fields.append(Field("improvement", String(outcome.improvement)))
    fields.append(Field("seeds", String(outcome.seeds)))
    fields.append(Field("state", state))
    fields.append(Field("config_checksum", checksum))
    fields.append(Field("alpha", String(outcome.alpha)))
    fields.append(Field("gamma", String(outcome.gamma)))
    fields.append(Field("epsilon_start", String(outcome.epsilon_start)))
    fields.append(Field("epsilon_min", String(outcome.epsilon_min)))
    fields.append(Field("detail", outcome.detail))
    return fields^


def run_autorl(workspace: String, episodes: Int, evaluation_episodes: Int) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if episodes < 4 or evaluation_episodes < 2:
        err.write("hyperforge: episodes must be >=4 and evaluation episodes >=2\n")
        return EXIT_USAGE

    var env = grid_4x4()
    var outcome = run_rl_experiment(env, episodes, evaluation_episodes)
    var state = String("IMPROVED")
    if outcome.improvement <= 0.0:
        state = "NO_IMPROVEMENT"

    var id = "rl-" + hex64(fnv1a64(
        "autorl|" + ENV_NAME + "|" + String(episodes) + "|" + String(evaluation_episodes)
    ))
    var config = (
        CONFIG_MAGIC + "|env=" + ENV_NAME + "|schema=" + ENV_SCHEMA
        + "|episodes=" + String(episodes) + "|eval=" + String(evaluation_episodes)
        + "|selected=" + outcome.selected + "\n"
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

    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    if journal.status == "RECOVERED":
        rewrite_journal(journal_path(workspace), journal.good_content)
    append_record(
        journal_path(workspace), next_sequence(journal.records), "autorl",
        outcome_fields(outcome, checksum, state),
    )

    print("experiment:       " + id)
    print("environment:      " + ENV_NAME)
    print("states:           " + String(state_count(env)))
    print("selected:         " + outcome.selected)
    print("test_mean_return: " + String(outcome.test_mean))
    print("test_std:         " + String(outcome.test_std))
    print("ci95_half_width:  " + String(outcome.ci95))
    print("random_mean:      " + String(outcome.random_mean))
    print("optimal_mean:     " + String(outcome.optimal_mean))
    print("improvement:      " + String(outcome.improvement))
    print("seeds:            " + String(outcome.seeds))
    print("state:            " + state)
    print("config:           " + config_path)
    print("learning_curve:   " + curve_path)
    return EXIT_OK


def show_autorl(workspace: String, id: String) raises -> Int:
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
        if record.kind == "autorl" and record.fields["env"] == ENV_NAME:
            print("id:               " + id)
            print("selected:         " + record.fields["selected"])
            print("test_mean_return: " + record.fields["test_mean"])
            print("random_mean:      " + record.fields["random_mean"])
            print("improvement:      " + record.fields["improvement"])
            print("state:            " + record.fields["state"])
            return EXIT_OK
    err.write("hyperforge: AutoRL result not found: " + id + "\n")
    return EXIT_FAILURE


def replay_autorl(workspace: String, id: String) raises -> Int:
    var err = stderr
    var config_path = workspace + "/artifacts/" + id + ".config.txt"
    if not Path(config_path).exists():
        err.write("hyperforge: replay refused; config artifact missing\n")
        return EXIT_UNAVAILABLE
    var content = open(config_path, "r").read()
    var checksum = hex64(fnv1a64(content))
    var journal = read_journal(journal_path(workspace))
    for i in range(len(journal.records)):
        ref record = journal.records[i]
        if record.kind == "autorl" and record.fields["config_checksum"] == checksum:
            print("REPLAY_READY " + id)
            print("config verified; recorded returns remain original evidence")
            return EXIT_OK
    err.write("hyperforge: replay refused; no matching config record\n")
    return EXIT_FAILURE
