"""CLI for honest MAX serving readiness and portability reporting."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.exit_codes import EXIT_OK, EXIT_USAGE
from hyperforge.core.version import MOJO_PIN, MAX_PIN
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.runtime.max_adapter import (
    ADAPTER_SCHEMA,
    AdapterStatus,
    probe_adapter,
    serve_decision,
    verification_checklist,
)
from hyperforge.runtime.portability import (
    PORTABILITY_SCHEMA,
    current_target,
    portability_summary,
    source_rules,
    target_matrix,
)


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def artifact_count(workspace: String) raises -> Int:
    var journal = read_journal(journal_path(workspace))
    var count = 0
    for i in range(len(journal.records)):
        ref record = journal.records[i]
        if record.kind == "autollm" and "artifact_count" in record.fields:
            count = Int(record.fields["artifact_count"])
    return count


def status_command(workspace: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE

    var status = probe_adapter(artifact_count(workspace))
    print("adapter_schema:  " + ADAPTER_SCHEMA)
    print("portability:     " + PORTABILITY_SCHEMA)
    print("mojo_pin:        " + MOJO_PIN)
    print("max_pin:         " + MAX_PIN)
    print("boundary_status: " + status.status)
    print("serve_enabled:   " + String(status.serve_enabled).lower())
    print("serve_decision:  " + serve_decision(status))
    print("max_cli:         " + (status.max_cli if status.max_cli != "" else "NOT_FOUND"))
    print("reason:          " + status.reason)
    print("current_target:  " + current_target())
    print("portability:     " + portability_summary())

    print("verification_checklist:")
    var items = verification_checklist()
    for i in range(len(items)):
        print("  [UNVERIFIED] " + items[i])
    print("verified_targets:")
    var targets = target_matrix()
    for i in range(len(targets)):
        print("  " + targets[i].target + "  [" + targets[i].status + "]  " + targets[i].evidence)
    print("source_rules:")
    var rules = source_rules()
    for i in range(len(rules)):
        print("  " + rules[i])

    var fields = List[Field]()
    fields.append(Field("adapter_schema", ADAPTER_SCHEMA))
    fields.append(Field("portability_schema", PORTABILITY_SCHEMA))
    fields.append(Field("boundary_status", status.status))
    fields.append(Field("serve_enabled", String(status.serve_enabled).lower()))
    fields.append(Field("serve_decision", serve_decision(status)))
    fields.append(Field("current_target", current_target()))
    fields.append(Field("portability", portability_summary()))
    append_record(
        journal_path(workspace),
        next_sequence(read_journal(journal_path(workspace)).records),
        "serve_status", fields,
    )
    return EXIT_OK
