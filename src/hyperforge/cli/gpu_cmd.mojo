"""CLI probes and reproducible benchmark for the MAX/Mojo kernel catalogue."""

from std.os import getenv
from std.pathlib import Path
from std.sys import stderr
from std.sys import has_accelerator
from max.gpu.host import DeviceContext
from hyperforge.core.hash import fnv1a64, hex64
from hyperforge.core.version import MOJO_PIN, MAX_PIN
from hyperforge.core.exit_codes import EXIT_OK, EXIT_FAILURE, EXIT_USAGE, EXIT_UNAVAILABLE
from hyperforge.evidence.record import Field
from hyperforge.evidence.journal import append_record, journal_path, next_sequence, read_journal
from hyperforge.gpu.kernels import GPUResult
from hyperforge.gpu.catalogue import (
    catalogue,
    kernel_names,
    run_catalogue_kernel,
    CATALOGUE_SCHEMA,
    SUPPORTED_SIZES,
)

comptime DEFAULT_REPETITIONS = 9


def max_on_path() raises -> String:
    var path_value: String
    var env_path: Optional[String] = __get_path()
    if case .Some(found) = env_path:
        path_value = found
    else:
        return ""
    for entry in path_value.split(":"):
        var directory = String(entry)
        if directory == "":
            continue
        var candidate = directory + "/max"
        if Path(candidate).exists():
            return candidate
    return ""


def __get_path() raises -> Optional[String]:
    return getenv("PATH")


def external_ptxas_configured() raises -> Bool:
    var value: Optional[String] = getenv("MODULAR_NVPTX_COMPILER_PATH")
    if case .Some(_) = value:
        return True
    return False


def hardware_probe() raises -> Int:
    print("HyperForge hardware probe")
    print("  catalogue_schema: " + CATALOGUE_SCHEMA)
    print("  mojo_pin:         " + MOJO_PIN)
    print("  max_pin:          " + MAX_PIN)
    print("  runtime reports accelerator: " + String(has_accelerator()))
    print("  external_ptxas_configured:   " + String(external_ptxas_configured()))
    var max_path = max_on_path()
    if max_path == "":
        print("  max_cli:          UNAVAILABLE on PATH")
    else:
        print("  max_cli:          " + max_path)

    comptime if not has_accelerator():
        print("  gpu_kernel:       BLOCKED (no accelerator reported)")
        return 3
    else:
        var result: GPUResult
        try:
            var ctx = DeviceContext()
            result = run_catalogue_kernel(ctx, "vector_add", 1024, DEFAULT_REPETITIONS)
        except e:
            print("  gpu_kernel:       BLOCKED")
            print("  reason:           " + String(e))
            print("  remedy:           source scripts/gpu-env.sh on pre-Turing NVIDIA devices")
            return 3
        print("  gpu_kernel:       " + result.state)
        print("  vector_size:      " + String(result.size))
        print("  max_abs_error:    " + String(result.max_error))
        print("  warmup_seconds:   " + String(result.warmup_seconds))
        print("  kernel_median_s:  " + String(result.kernel_median_seconds))
        if result.state == "PASS":
            return 0
        return 1


def list_catalogue() raises -> Int:
    print("GPU kernel catalogue (" + CATALOGUE_SCHEMA + ")")
    var entries = catalogue()
    for entry in entries:
        print("  " + entry.name + "  " + entry.description + "  CPU reference: " + entry.cpu_reference)
    print("  supported_sizes: " + SUPPORTED_SIZES)
    print("  protocol: warm-up + repeated median + integer reference tolerance 1e-5")
    print("  note: no claim that all MAX models or devices are supported")
    return EXIT_OK


def benchmark_catalogue(
    workspace: String, name: String, size: Int, repetitions: Int
) raises -> Int:
    var err = stderr
    var names = kernel_names()
    var known = False
    for candidate in names:
        if candidate == name:
            known = True
            break
    if not known:
        err.write("hyperforge: unknown kernel: " + name + "\n")
        return EXIT_USAGE
    if size < 1:
        err.write("hyperforge: size must be positive\n")
        return EXIT_USAGE

    comptime if not has_accelerator():
        err.write("hyperforge: GPU benchmark blocked; no accelerator reported\n")
        return EXIT_UNAVAILABLE
    else:
        var ctx: DeviceContext
        try:
            ctx = DeviceContext()
        except e:
            err.write("hyperforge: GPU context blocked: " + String(e) + "\n")
            return EXIT_UNAVAILABLE
        var result: GPUResult
        try:
            result = run_catalogue_kernel(ctx, name, size, repetitions)
        except e:
            err.write("hyperforge: benchmark failed: " + String(e) + "\n")
            return EXIT_FAILURE

        var header = (
            "schema=" + CATALOGUE_SCHEMA + " kernel=" + name + " size=" + String(size)
            + " mojo=" + MOJO_PIN + " max=" + MAX_PIN
            + " block=256 repetitions=" + String(repetitions)
            + " warmup=first_launch aggregation=median"
            + " external_ptxas=" + String(external_ptxas_configured())
        )
        var line = (
            "error=" + String(result.max_error)
            + " warmup_s=" + String(result.warmup_seconds)
            + " kernel_median_s=" + String(result.kernel_median_seconds)
            + " e2e_median_s=" + String(result.end_to_end_median_seconds)
            + " bytes_per_s=" + String(result.bytes_per_second)
            + " state=" + result.state
        )
        var report = header + "\n" + line + "\n"
        var checksum = hex64(fnv1a64(report))
        if Path(workspace + "/benchmarks").exists():
            var report_path = workspace + "/benchmarks/gpu-" + name + "-" + String(size) + ".txt"
            var report_file = open(report_path, "w")
            report_file.write(report)
            report_file.close()
            print("report: " + report_path)
        print(line)

        var fields = List[Field]()
        fields.append(Field("kernel", name))
        fields.append(Field("size", String(size)))
        fields.append(Field("error", String(result.max_error)))
        fields.append(Field("warmup", String(result.warmup_seconds)))
        fields.append(Field("median", String(result.kernel_median_seconds)))
        fields.append(Field("bytes_per_s", String(result.bytes_per_second)))
        fields.append(Field("state", result.state))
        fields.append(Field("checksum", checksum))
        append_record(
            journal_path(workspace),
            next_sequence(read_journal(journal_path(workspace)).records),
            "gpu_bench",
            fields,
        )
        if result.state != "PASS":
            return EXIT_FAILURE
        return EXIT_OK
