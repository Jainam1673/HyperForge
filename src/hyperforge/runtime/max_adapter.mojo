"""MAX serving adapter boundary — honest readiness, never fake inference.

The installed MAX build does not expose a validated native Mojo model-inference
interface. This module implements the detection, readiness checklist, and
refusal path. `serve` is enabled only when every checklist item has recorded
evidence; absent that, the status is BLOCKED_BY_MAX_INTERFACE.
"""

from hyperforge.autollm.backend import find_max_cli, STATUS_BLOCKED

comptime ADAPTER_SCHEMA = "hyperforge-max-adapter-v1"
comptime SERVE_DISABLED = "REFUSED_UNVERIFIED_INTERFACE"


struct AdapterStatus(Copyable, Movable):
    var status: String
    var max_cli: String
    var serve_enabled: Bool
    var decision: String
    var reason: String

    def __init__(
        out self, status: String, max_cli: String, serve_enabled: Bool,
        decision: String, reason: String,
    ):
        self.status = status
        self.max_cli = max_cli
        self.serve_enabled = serve_enabled
        self.decision = decision
        self.reason = reason


def verification_checklist() raises -> List[String]:
    var items = List[String]()
    items.append("native_mojo_model_load_api_verified")
    items.append("native_mojo_tokenizer_api_verified")
    items.append("native_mojo_forward_and_decode_api_verified")
    items.append("target_matrix_verified_nvidia_amd_apple")
    items.append("version_pin_and_device_driver_recorded")
    items.append("failure_replay_and_holdout_evidence_recorded")
    return items^


def probe_adapter(artifact_count: Int) raises -> AdapterStatus:
    var max_cli = find_max_cli()
    var reason = String(
        "no validated native Mojo model-inference interface; MAX CLI presence "
        "or local model artifacts do not establish one"
    )
    return AdapterStatus(
        STATUS_BLOCKED, max_cli, False, SERVE_DISABLED, reason,
    )


def serve_decision(status: AdapterStatus) raises -> String:
    if status.serve_enabled:
        return "ALLOW"
    return status.decision
