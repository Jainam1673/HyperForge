"""CLI for full SciAI breadth across analytic problem families."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.exit_codes import EXIT_OK, EXIT_USAGE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.sciai.full import SCIA_FULL_SCHEMA, problems, run_problem


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def run_sciai_full(workspace: String, seed: UInt64) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    var sequence = next_sequence(read_journal(journal_path(workspace)).records)
    print("schema:          " + SCIA_FULL_SCHEMA)
    var families = problems()
    for i in range(len(families)):
        var problem = families[i].copy()
        var outcome = run_problem(problem, seed, 1.0)
        var fields = List[Field]()
        fields.append(Field("schema", SCIA_FULL_SCHEMA))
        fields.append(Field("problem", outcome.problem))
        fields.append(Field("seed", String(seed)))
        fields.append(Field("true_parameter", String(outcome.true_parameter)))
        fields.append(Field("estimated_parameter", String(outcome.estimated_parameter)))
        fields.append(Field("parameter_std", String(outcome.parameter_std)))
        fields.append(Field("interval_low", String(outcome.interval_low)))
        fields.append(Field("interval_high", String(outcome.interval_high)))
        fields.append(Field("field_rmse", String(outcome.field_rmse)))
        fields.append(Field("linear_rmse", String(outcome.linear_rmse)))
        fields.append(Field("analytic_gradient_error", String(outcome.analytic_gradient_error)))
        fields.append(Field("jet_gradient_error", String(outcome.jet_gradient_error)))
        fields.append(Field("bandit_return", String(outcome.bandit_return)))
        fields.append(Field("random_return", String(outcome.random_return)))
        fields.append(Field("operator_error", String(outcome.operator_error)))
        append_record(journal_path(workspace), sequence, "sciai_outcome", fields)
        sequence += 1
        print("problem:         " + outcome.problem)
        print("  estimate:      " + String(outcome.estimated_parameter)
            + " +/- " + String(outcome.parameter_std))
        print("  ci95:          [" + String(outcome.interval_low) + ", "
            + String(outcome.interval_high) + "]")
        print("  field_rmse:    " + String(outcome.field_rmse))
        print("  linear_rmse:   " + String(outcome.linear_rmse))
        print("  bandit_return: " + String(outcome.bandit_return)
            + " random=" + String(outcome.random_return))
        print("  jet_grad_err:  " + String(outcome.jet_gradient_error))
        print("  operator_err:  " + String(outcome.operator_error))
    print("families:        SciML + UQ, SciDL baselines, SciRL selection, differentiable simulation, neural operator")
    print("note:            UQ intervals are bootstrap ensembles with stated noise assumptions")
    print("note:            neural operator is an affine parameter-to-solution spike, not a DeepONet/FNO")
    return EXIT_OK
