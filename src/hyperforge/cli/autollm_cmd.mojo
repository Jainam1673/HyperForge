"""CLI for AutoLLM substrate with explicit UNAVAILABLE/BLOCKED statuses."""

from std.pathlib import Path
from std.sys import stderr
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE, EXIT_UNAVAILABLE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.autollm.registry import (
    ModelArtifact,
    discover_models,
    REGISTRY_SCHEMA,
)
from hyperforge.autollm.prompt_suite import load_suite, load_responses, evaluate, SUITE_SCHEMA, PromptSuite, ResponseRecord
from hyperforge.autollm.backend import probe_backend, BackendStatus, BACKEND_SCHEMA


def workspace_ready(workspace: String) raises -> Bool:
    return Path(workspace + "/hyperforge.toml").exists() and Path(
        workspace + "/experiments"
    ).is_dir()


def discover_command(workspace: String, path: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized; run 'hyperforge init .'\n")
        return EXIT_USAGE
    var artifacts: List[ModelArtifact]
    try:
        artifacts = discover_models(path)
    except e:
        err.write("hyperforge: discovery failed: " + String(e) + "\n")
        return EXIT_FAILURE
    print("model_registry_schema: " + REGISTRY_SCHEMA)
    print("path:           " + path)
    print("artifact_count: " + String(len(artifacts)))
    for artifact in artifacts:
        print(
            "artifact: " + artifact.name + " format=" + artifact.format
            + " bytes=" + String(artifact.size) + " checksum=" + artifact.checksum
            + " license=" + artifact.license_status
        )
    var status = probe_backend(len(artifacts))
    print("backend_status: " + status.status)
    print("max_cli:        " + (status.max_cli if status.max_cli != "" else "NOT_FOUND"))
    print("note:           " + status.detail)
    var fields = List[Field]()
    fields.append(Field("kind", "discover"))
    fields.append(Field("path", path))
    fields.append(Field("artifact_count", String(len(artifacts))))
    fields.append(Field("backend_status", status.status))
    append_record(journal_path(workspace), next_sequence(read_journal(journal_path(workspace)).records), "autollm", fields)
    return EXIT_OK


def evaluate_command(workspace: String, suite_path: String, responses_path: String) raises -> Int:
    var err = stderr
    if not workspace_ready(workspace):
        err.write("hyperforge: workspace is not initialized\n")
        return EXIT_USAGE
    var suite: PromptSuite
    var responses: List[ResponseRecord]
    try:
        suite = load_suite(suite_path)
        responses = load_responses(responses_path)
    except e:
        err.write("hyperforge: evaluation input error: " + String(e) + "\n")
        return EXIT_FAILURE
    var result = evaluate(suite, responses)
    print("suite_schema:   " + SUITE_SCHEMA)
    print("suite_checksum: " + suite.checksum)
    print("cases:          " + String(result.total))
    print("matched:        " + String(result.matched))
    print("missing:        " + String(result.missing))
    print("accuracy:       " + String(result.accuracy))
    print("state:          " + result.state)
    print("note:           recorded responses scored offline; no model was invoked")
    var fields = List[Field]()
    fields.append(Field("kind", "evaluate"))
    fields.append(Field("suite_checksum", suite.checksum))
    fields.append(Field("cases", String(result.total)))
    fields.append(Field("matched", String(result.matched)))
    fields.append(Field("accuracy", String(result.accuracy)))
    fields.append(Field("state", result.state))
    append_record(journal_path(workspace), next_sequence(read_journal(journal_path(workspace)).records), "autollm", fields)
    return EXIT_OK


def status_command(workspace: String) raises -> Int:
    var journal = read_journal(journal_path(workspace))
    var count = 0
    for i in range(len(journal.records)):
        if journal.records[i].kind == "autollm" and journal.records[i].fields["kind"] == "discover":
            count = Int(journal.records[i].fields["artifact_count"])
    var status = probe_backend(count)
    print("backend_schema: " + BACKEND_SCHEMA)
    print("status:         " + status.status)
    print("known_artifacts:" + String(count))
    print("max_cli:        " + (status.max_cli if status.max_cli != "" else "NOT_FOUND"))
    print("detail:         " + status.detail)
    print("offline_core:   AVAILABLE (discovery, versioned suites, recorded evaluation)")
    return EXIT_OK
