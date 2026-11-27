"""CLI for the SciML forward/inverse problem registry."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.sciml.problem import registered_problem, PROBLEM_SCHEMA
from hyperforge.sciml.inverse import SciMLOutcome, run_experiment

comptime CONFIG_MAGIC = "HSCIML1"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def list_problems() raises -> Int:
    var problem = registered_problem()
    print("Scientific problem registry (" + PROBLEM_SCHEMA + ")")
    print("  " + problem.name)
    print("    equation:   " + problem.equation)
    print("    domain:     " + problem.domain)
    print("    boundary:   " + problem.boundary)
    print("    units:      " + problem.units + "; scaling: " + problem.scaling)
    print("    assumptions:" + problem.assumptions)
    print("    reference:  " + problem.reference)
    print("    parameter range: [" + String(problem.parameter_lower) + ", "
        + String(problem.parameter_upper) + "]")
    print("Status: VERIFIED for this single registry entry; no other problem is supported.")
    return EXIT_OK


def outcome_fields(outcome: SciMLOutcome) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("problem", outcome.problem))
    fields.append(Field("seed", String(outcome.seed)))
    fields.append(Field("observations", String(outcome.observations)))
    fields.append(Field("train_count", String(outcome.train_count)))
    fields.append(Field("heldout_count", String(outcome.heldout_count)))
    fields.append(Field("estimated_parameter", String(outcome.estimated_parameter)))
    fields.append(Field("parameter_error", String(outcome.parameter_error)))
    fields.append(Field("parameter_std", String(outcome.parameter_std)))
    fields.append(Field("inverse_exact_l2", String(outcome.inverse_exact_l2)))
    fields.append(Field("hybrid_exact_l2", String(outcome.hybrid_exact_l2)))
    fields.append(Field("constant_exact_l2", String(outcome.constant_exact_l2)))
    fields.append(Field("finite_difference_l2", String(outcome.finite_difference_l2)))
    fields.append(Field("detail", outcome.detail))
    return fields^


def solve_problem(workspace: String, seed: UInt64) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    var problem = registered_problem()
    var outcome = run_experiment(problem, seed)
    var id = "sciml-" + hex64(fnv1a64(problem.name + "|" + String(seed)))
    var config = (
        CONFIG_MAGIC + "|problem=" + problem.name + "|seed=" + String(seed)
        + "|schema=" + PROBLEM_SCHEMA + "\n"
    )
    var checksum = hex64(fnv1a64(config))
    var config_path = workspace + "/artifacts/" + id + ".config.txt"
    var config_file = open(config_path, "w")
    config_file.write(config)
    config_file.close()
    var fields = outcome_fields(outcome)
    fields.append(Field("config_checksum", checksum))
    append_record(journal_path(workspace), next_sequence(read_journal(journal_path(workspace)).records), "sciml", fields)

    print("experiment:        " + id)
    print("problem:           " + problem.name)
    print("observations:      " + String(outcome.observations))
    print("train / held-out:  " + String(outcome.train_count) + " / " + String(outcome.heldout_count))
    print("estimated k:       " + String(outcome.estimated_parameter))
    print("true k:            " + String(problem.true_parameter))
    print("parameter error:   " + String(outcome.parameter_error))
    print("parameter std:     " + String(outcome.parameter_std) + " (" + String(5) + " noise seeds)")
    print("inverse exact L2:  " + String(outcome.inverse_exact_l2))
    print("hybrid exact L2:   " + String(outcome.hybrid_exact_l2))
    print("constant exact L2: " + String(outcome.constant_exact_l2))
    print("FD reference L2:   " + String(outcome.finite_difference_l2))
    print("config:            " + config_path)
    return EXIT_OK


def show_result(workspace: String, id: String) raises -> Int:
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
        if record.kind == "sciml":
            print("problem:           " + record.fields["problem"])
            print("estimated k:       " + record.fields["estimated_parameter"])
            print("parameter error:   " + record.fields["parameter_error"])
            print("inverse exact L2:  " + record.fields["inverse_exact_l2"])
            print("constant exact L2: " + record.fields["constant_exact_l2"])
            return EXIT_OK
    err.write("hyperforge: SciML result not found: " + id + "\n")
    return EXIT_FAILURE
