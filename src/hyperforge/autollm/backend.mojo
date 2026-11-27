"""Capability detection for local MAX model execution.

This module deliberately does not fabricate a backend. A validated native Mojo
boundary to MAX model inference was not established in this environment; MAX's
documented model pipelines/serving include Python-based components. Local model
artifacts alone do not make inference available.
"""

from std.os import getenv
from std.pathlib import Path

comptime BACKEND_SCHEMA = "hyperforge-autollm-backend-v1"
comptime STATUS_BLOCKED = "BLOCKED_BY_MAX_INTERFACE"
comptime STATUS_UNAVAILABLE = "UNAVAILABLE"


struct BackendStatus(Copyable, Movable):
    var status: String
    var max_cli: String
    var detail: String

    def __init__(out self, status: String, max_cli: String, detail: String):
        self.status = status
        self.max_cli = max_cli
        self.detail = detail


def find_max_cli() raises -> String:
    var env_path: Optional[String] = getenv("PATH")
    if case .Some(path_value) = env_path:
        for entry in path_value.split(":"):
            var directory = String(entry)
            if directory == "":
                continue
            var candidate = directory + "/max"
            if Path(candidate).exists():
                return candidate
    return ""


def probe_backend(artifact_count: Int) raises -> BackendStatus:
    var max_cli = find_max_cli()
    if artifact_count == 0:
        return BackendStatus(
            STATUS_UNAVAILABLE, max_cli,
            "no local model artifacts discovered; supply a user-provided model directory",
        )
    var detail = String("no validated native Mojo inference boundary; no inference claim is made")
    if max_cli != "":
        detail = "MAX CLI presence does not imply a validated native Mojo inference boundary; no inference claim is made"
    return BackendStatus(STATUS_BLOCKED, max_cli, detail)
