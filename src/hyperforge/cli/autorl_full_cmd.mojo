"""CLI for full AutoRL breadth."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.autorl.full import FULL_RL_SCHEMA, run_full_rl

comptime ALGORITHMS = "q_learning, sarsa, double_q, value_iteration, random"
comptime ENVIRONMENTS = "grid_4x4, grid_5x5"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def run_autorl_full(
    workspace: String,
    algorithm: String,
    environment: String,
    episodes: Int,
    evaluation_episodes: Int,
    seed: UInt64,
    seeds: Int,
) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if episodes < 1 or evaluation_episodes < 1 or seeds < 1:
        err.write("hyperforge: episodes, eval and seeds must be positive\n")
        return EXIT_USAGE
    try:
        var outcome = run_full_rl(
            algorithm, environment, episodes, evaluation_episodes, seed, seeds
        )
        var fields = List[Field]()
        fields.append(Field("schema", FULL_RL_SCHEMA))
        fields.append(Field("algorithm", algorithm))
        fields.append(Field("environment", environment))
        fields.append(Field("seed", String(seed)))
        fields.append(Field("episodes", String(episodes)))
        fields.append(Field("seeds", String(seeds)))
        fields.append(Field("mean_return", String(outcome.mean_return)))
        fields.append(Field("return_std", String(outcome.return_std)))
        fields.append(Field("success_rate", String(outcome.success_rate)))
        fields.append(Field("holdout_return", String(outcome.holdout_return)))
        fields.append(Field("optimal_return", String(outcome.optimal_return)))
        fields.append(Field("regret", String(outcome.regret)))
        fields.append(Field("safety_violations", String(outcome.safety_violations)))
        fields.append(Field("detail", outcome.detail))
        append_record(
            journal_path(workspace),
            next_sequence(read_journal(journal_path(workspace)).records),
            "autorl_full", fields,
        )
        print("schema:            " + FULL_RL_SCHEMA)
        print("algorithm:         " + algorithm)
        print("algorithms:        " + ALGORITHMS)
        print("environment:       " + environment)
        print("environments:      " + ENVIRONMENTS)
        print("episodes:          " + String(episodes))
        print("seeds:             " + String(seeds))
        print("mean_return:       " + String(outcome.mean_return))
        print("return_std:        " + String(outcome.return_std))
        print("success_rate:      " + String(outcome.success_rate))
        print("holdout_return:    " + String(outcome.holdout_return))
        print("optimal_return:    " + String(outcome.optimal_return))
        print("regret:            " + String(outcome.regret))
        print("safety_violations: " + String(outcome.safety_violations))
        print("note:              " + outcome.detail)
        print("note:              holdout wall layout never used for training or selection")
        return EXIT_OK
    except e:
        err.write("hyperforge: autorl full failed: " + String(e) + "\n")
        return EXIT_FAILURE
