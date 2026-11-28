"""Portability contract for Mojo across NVIDIA, AMD, and Apple Silicon.

Mojo source is portable in principle; runtime correctness and performance are
hardware facts. This module records what is verified, what is not, and the
source-level rules that keep the engine portable.
"""

from std.sys import has_accelerator

comptime PORTABILITY_SCHEMA = "hyperforge-portability-v1"
comptime VERIFIED_TARGET = "nvidia_sm_61"
comptime UNVERIFIED_VENDOR = "UNKNOWN_VENDOR"


struct TargetStatus(Copyable, Movable):
    var target: String
    var status: String
    var evidence: String

    def __init__(out self, target: String, status: String, evidence: String):
        self.target = target
        self.status = status
        self.evidence = evidence


def target_matrix() raises -> List[TargetStatus]:
    var targets = List[TargetStatus]()
    targets.append(TargetStatus(
        VERIFIED_TARGET, "VERIFIED",
        "GPU catalogue kernel passed correctness and median benchmarks on MX230",
    ))
    targets.append(TargetStatus(
        "nvidia_other", "NOT_TESTED",
        "Mojo source is portable; no runs recorded on other NVIDIA targets",
    ))
    targets.append(TargetStatus(
        "amd", "NOT_TESTED",
        "no AMD target available on this host; no claim of correctness or speed",
    ))
    targets.append(TargetStatus(
        "apple_silicon", "NOT_TESTED",
        "no Apple Silicon target available on this host; no claim of correctness or speed",
    ))
    targets.append(TargetStatus(
        "cpu", "VERIFIED",
        "all core CLI, evidence, AutoML, AutoLLM, and RSI paths run on CPU",
    ))
    return targets^


def source_rules() raises -> List[String]:
    var rules = List[String]()
    rules.append("first_party_logic_is_mojo_only")
    rules.append("no_vendor_specific_application_calls")
    rules.append("accelerator_paths_gated_by_runtime_detection")
    rules.append("pre_turing_ptxas_selected_by_scripts/gpu-env.sh")
    rules.append("no_performance_claim_without_target_driver_and_version")
    return rules^


def current_target() raises -> String:
    if has_accelerator():
        return UNVERIFIED_VENDOR
    return "cpu"


def portability_summary() raises -> String:
    return (
        "portable_source=yes; verified=" + VERIFIED_TARGET
        + "+cpu; amd=NOT_TESTED; apple_silicon=NOT_TESTED"
    )
