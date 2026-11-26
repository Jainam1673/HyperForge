"""Capability detection for `hyperforge doctor`.

Detection and execution are kept separate: this module only reports what can be
observed in the current process/environment. It never launches a GPU kernel or
a model, and it does not infer device capability from a device name alone.
"""

from std.os import getenv, remove
from std.pathlib import Path
from std.sys import has_accelerator
from hyperforge.core.version import VERSION, MILESTONE, MOJO_PIN, MAX_PIN, DOCTOR_SCHEMA
from hyperforge.core.exit_codes import EXIT_OK, EXIT_UNAVAILABLE


struct Probe(Copyable, Movable):
    var name: String
    var status: String
    var detail: String

    def __init__(out self, name: String, status: String, detail: String):
        self.name = name
        self.status = status
        self.detail = detail


def find_on_path(name: String) raises -> String:
    """Return the first path entry containing `name`, or an empty string."""
    var path_value: String
    var env_path: Optional[String] = getenv("PATH")
    if case .Some(found) = env_path:
        path_value = found
    else:
        return ""
    var dirs = path_value.split(":")
    for d in dirs:
        var dir = String(d)
        if dir == "":
            continue
        var candidate = dir + "/" + name
        if Path(candidate).exists():
            return candidate
    return ""


def probe_workspace() raises -> Probe:
    """Verify that the current directory accepts a small temporary write."""
    var probe_path = ".hyperforge-doctor.tmp"
    try:
        var handle = open(probe_path, "w")
        handle.write("workspace probe\n")
        handle.close()
        remove(probe_path)
    except e:
        _ = e
        return Probe("workspace", "UNAVAILABLE", "current directory is not writable")
    return Probe("workspace", "OK", "current directory is writable")


def collect_probes(executable: String) raises -> List[Probe]:
    """Collect every M00 capability probe in a fixed, deterministic order."""
    var probes = List[Probe]()

    probes.append(
        Probe(
            "executable",
            "OK",
            "hyperforge " + VERSION + " (" + MILESTONE + ") invoked as " + executable,
        )
    )
    probes.append(
        Probe(
            "toolchain_pin",
            "PINNED",
            "Mojo " + MOJO_PIN + ", MAX " + MAX_PIN
            + " (verify: pixi run mojo --version; pixi run max --version)",
        )
    )

    var max_path = find_on_path("max")
    if max_path == "":
        probes.append(Probe("max_cli", "UNAVAILABLE", "max executable not found on PATH"))
    else:
        probes.append(Probe("max_cli", "OK", "max executable found at " + max_path))

    if has_accelerator():
        probes.append(
            Probe(
                "accelerator",
                "OK",
                "runtime reports an accelerator; device capability not tested in M00",
            )
        )
    else:
        probes.append(
            Probe("accelerator", "UNAVAILABLE", "runtime reports no accelerator")
        )

    probes.append(probe_workspace())
    probes.append(
        Probe(
            "model_artifacts",
            "NOT_TESTED",
            "local model probing is not part of M00; core CLI is offline-capable",
        )
    )
    return probes^


def json_escape(value: String) raises -> String:
    """Minimal JSON string escaping for doctor's machine-readable output."""
    var out = String("")
    for i in range(value.byte_length()):
        var ch = value[byte=i]
        if ch == '"':
            out += "\\\""
        elif ch == "\\":
            out += "\\\\"
        elif ch == "\n":
            out += "\\n"
        else:
            out += String(ch)
    return out


def render_json(probes: List[Probe]) raises -> String:
    var out = String(
        "{\"schema\":\"" + DOCTOR_SCHEMA + "\",\"version\":\"" + VERSION
        + "\",\"milestone\":\"" + MILESTONE + "\",\"probes\":["
    )
    for i in range(len(probes)):
        if i > 0:
            out += ","
        var p = probes[i].copy()
        out += (
            "{\"name\":\"" + json_escape(p.name) + "\",\"status\":\""
            + json_escape(p.status) + "\",\"detail\":\""
            + json_escape(p.detail) + "\"}"
        )
    out += "]}"
    return out


def render_human(probes: List[Probe]) raises -> String:
    var out = String("hyperforge doctor (" + MILESTONE + ")\n")
    for p in probes:
        out += "  " + p.name + "  [" + p.status + "]  " + p.detail + "\n"
    return out


def run_doctor(executable: String, as_json: Bool) raises -> Int:
    """Run M00 doctor. Returns an exit code; writes only to stdout."""
    var probes = collect_probes(executable)
    if as_json:
        print(render_json(probes))
    else:
        print(render_human(probes), end="")

    for p in probes:
        if p.name == "workspace" and p.status == "UNAVAILABLE":
            return EXIT_UNAVAILABLE
    return EXIT_OK
