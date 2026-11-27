"""Local model-artifact discovery with checksums and license declarations.

No network access, no downloads, and no implicit model execution. Artifacts are
user-provided files in a local directory. `LICENSE.txt` in that directory is
recorded as a declared license; its absence is reported, not guessed.
"""

from std.pathlib import Path
from std.os import listdir
from hyperforge.core.hash import fnv1a64, hex64

comptime REGISTRY_SCHEMA = "hyperforge-autollm-registry-v1"
comptime MAX_ARTIFACT_BYTES = 268435456


struct ModelArtifact(Copyable, Movable):
    var name: String
    var checksum: String
    var size: Int
    var format: String
    var license_status: String

    def __init__(out self, name: String, checksum: String, size: Int, format: String, license_status: String):
        self.name = name
        self.checksum = checksum
        self.size = size
        self.format = format
        self.license_status = license_status


def model_format(name: String) raises -> String:
    for suffix in [".gguf", ".safetensors", ".bin", ".onnx", ".json"]:
        if name.endswith(suffix):
            return String(suffix)
    return ""


def license_declared(path: String) raises -> Bool:
    return Path(path + "/LICENSE.txt").exists() or Path(path + "/license.txt").exists()


def discover_models(path: String) raises -> List[ModelArtifact]:
    var out = List[ModelArtifact]()
    if not Path(path).is_dir():
        raise Error("model directory does not exist or is not a directory")
    var declared = license_declared(path)
    var entries = listdir(path)
    for entry in entries:
        var name = String(entry)
        var format = model_format(name)
        if format == "":
            continue
        var full_path = path + "/" + name
        var content = open(full_path, "r").read()
        var size = content.byte_length()
        var license_status = String("DECLARED") if declared else String("MISSING")
        if size > MAX_ARTIFACT_BYTES:
            license_status = "SKIPPED_TOO_LARGE"
        out.append(ModelArtifact(
            name, hex64(fnv1a64(content)), size, format, license_status
        ))
    return out^
