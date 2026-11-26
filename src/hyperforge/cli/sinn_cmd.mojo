"""M04 CLI: the first SciAI capability (SINN) on a typed 1D Poisson problem."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import (
    append_record,
    journal_path,
    next_sequence,
    read_journal,
    rewrite_journal,
)
from hyperforge.sinn.problem import poisson_1d, PROBLEM_POISSON_1D, PROBLEM_SCHEMA
from hyperforge.sinn.solver import train, SinnOutcome
from hyperforge.sinn.network import serialize_network

comptime SINN_CONFIG_MAGIC = "HSINN1"


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def list_problems() raises -> Int:
    print("Supported scientific problems:")
    print(
        "  poisson_1d  -u''=2 on [0,1], u(0)=u(1)=0, exact u=x(1-x), "
        + "finite-difference reference"
    )
    print("Status: VERIFIED for the documented CPU slice; no other PDE is supported.")
    return EXIT_OK


def experiment_id(problem: String, seed: UInt64) raises -> String:
    return "sinn-" + hex64(fnv1a64("sinn|" + problem + "|" + String(seed)))


def scientific_fields(
    id: String, outcome: SinnOutcome, total_iterations: Int
) raises -> List[Field]:
    var fields = List[Field]()
    fields.append(Field("exp_id", id))
    fields.append(Field("problem", outcome.problem))
    fields.append(Field("seed", String(outcome.seed)))
    fields.append(Field("iters", String(total_iterations)))
    fields.append(Field("initial_loss", String(outcome.initial_loss)))
    fields.append(Field("final_loss", String(outcome.final_loss)))
    fields.append(Field("residual", String(outcome.residual_rmse)))
    fields.append(Field("boundary", String(outcome.boundary_abs)))
    fields.append(Field("exact_l2", String(outcome.exact_l2)))
    fields.append(Field("fd_l2", String(outcome.fd_l2)))
    fields.append(Field("state", outcome.state))
    fields.append(Field("detail", outcome.detail))
    fields.append(Field("runtime", String(outcome.runtime_seconds)))
    return fields^


def solve_problem(
    workspace: String, problem_name: String, seed: UInt64, iterations: Int
) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    if problem_name != PROBLEM_POISSON_1D:
        err.write("hyperforge: unsupported problem: " + problem_name + "\n")
        err.write("Run 'hyperforge sinn list-problems' for supported problems.\n")
        return EXIT_USAGE
    if iterations < 1:
        err.write("hyperforge: iterations must be positive\n")
        return EXIT_USAGE

    var problem = poisson_1d(seed)
    var result = train(problem, seed, iterations)
    var net = result[0].copy()
    var outcome = result[1].copy()

    var id = experiment_id(problem_name, seed)
    var config = (
        SINN_CONFIG_MAGIC + "|problem=" + problem_name + "|seed=" + String(seed)
        + "|iters=" + String(iterations) + "|width=4|forcing=2"
        + "|domain=0,1|bc=dirichlet_zero|schema=" + PROBLEM_SCHEMA + "\n"
    )
    var checksum = hex64(fnv1a64(config))
    var artifact_path = workspace + "/artifacts/" + id + ".config.txt"
    var config_file = open(artifact_path, "w")
    config_file.write(config)
    config_file.close()
    var model_path = workspace + "/artifacts/" + id + ".model.txt"
    var model_file = open(model_path, "w")
    model_file.write(serialize_network(net))
    model_file.close()

    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    if journal.status == "RECOVERED":
        rewrite_journal(journal_path(workspace), journal.good_content)
        err.write("hyperforge: recovered journal tail: " + journal.reason + "\n")
    for i in range(len(journal.records)):
        if (
            journal.records[i].kind == "experiment"
            and journal.records[i].fields["id"] == id
        ):
            err.write("hyperforge: experiment already exists: " + id + "\n")
            return EXIT_USAGE

    var seq = next_sequence(journal.records)
    var experiment_fields = List[Field]()
    experiment_fields.append(Field("id", id))
    experiment_fields.append(Field("name", "sinn:" + problem_name))
    experiment_fields.append(Field("seed", String(seed)))
    experiment_fields.append(Field("state", outcome.state))
    experiment_fields.append(Field("config_artifact", "artifacts/" + id + ".config.txt"))
    experiment_fields.append(Field("config_checksum", checksum))
    experiment_fields.append(Field("trial_seeds", ""))
    experiment_fields.append(Field("task", "poisson_1d_sinn"))
    experiment_fields.append(Field("dataset", "analytic:u=x(1-x)"))
    experiment_fields.append(Field("target", "u"))
    experiment_fields.append(Field("budget", String(iterations)))
    experiment_fields.append(Field("fingerprint", checksum))
    append_record(journal_path(workspace), seq, "experiment", experiment_fields)
    seq += 1
    append_record(
        journal_path(workspace), seq, "scientific",
        scientific_fields(id, outcome, iterations),
    )
    seq += 1
    var event = List[Field]()
    event.append(Field("exp_id", id))
    event.append(Field("kind", outcome.state))
    event.append(Field("detail", outcome.detail))
    event.append(Field("state", outcome.state))
    append_record(journal_path(workspace), seq, "event", event)

    print("experiment:  " + id)
    print("problem:     " + problem_name)
    print("state:       " + outcome.state)
    print("loss:        " + String(outcome.initial_loss) + " -> " + String(outcome.final_loss))
    print("residual:    " + String(outcome.residual_rmse))
    print("boundary:    " + String(outcome.boundary_abs))
    print("exact_l2:    " + String(outcome.exact_l2))
    print("fd_l2:       " + String(outcome.fd_l2))
    print("runtime_s:   " + String(outcome.runtime_seconds))
    print("config:      " + artifact_path)
    print("model:       " + model_path)

    if outcome.state == "CONVERGED":
        return EXIT_OK
    err.write("hyperforge: SINN run did not meet the convergence gate: " + outcome.state + "\n")
    return EXIT_FAILURE


def show_result(workspace: String, id: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    var journal = read_journal(journal_path(workspace))
    if journal.status == "ERROR":
        err.write("hyperforge: journal error: " + journal.reason + "\n")
        return EXIT_FAILURE
    var found = False
    for i in range(len(journal.records)):
        ref record = journal.records[i]
        if record.kind == "scientific" and record.fields["exp_id"] == id:
            found = True
            print("problem:     " + record.fields["problem"])
            print("seed:        " + record.fields["seed"])
            print("state:       " + record.fields["state"])
            print("residual:    " + record.fields["residual"])
            print("boundary:    " + record.fields["boundary"])
            print("exact_l2:    " + record.fields["exact_l2"])
            print("fd_l2:       " + record.fields["fd_l2"])
    if not found:
        err.write("hyperforge: SINN result not found: " + id + "\n")
        return EXIT_FAILURE
    return EXIT_OK
