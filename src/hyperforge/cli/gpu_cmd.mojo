"""CLI probes and benchmark for the MAX/Mojo accelerator path."""

from std.sys import stderr
from std.pathlib import Path
from std.sys import has_accelerator
from max.gpu.host import DeviceContext
from hyperforge.gpu.kernels import GPUResult, run_vector_add, KERNEL_SCHEMA

comptime REPETITIONS = 9


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
    from std.os import getenv
    return getenv("PATH")


def hardware_probe() raises -> Int:
    print("HyperForge hardware probe")
    print("  kernel_schema:    " + KERNEL_SCHEMA)
    print("  runtime reports accelerator: " + String(has_accelerator()))
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
            result = run_vector_add[1024](ctx, REPETITIONS)
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
        print("  gpu_path:         compiled and executed on detected device")
        if result.state == "PASS":
            return 0
        return 1


def benchmark_kernel(workspace: String) raises -> Int:
    var err = stderr
    comptime if not has_accelerator():
        err.write("hyperforge: GPU benchmark blocked; no accelerator reported\n")
        return 3
    else:
        var ctx: DeviceContext
        try:
            ctx = DeviceContext()
        except e:
            err.write("hyperforge: GPU benchmark blocked: " + String(e) + "\n")
            return 3
        var lines = List[String]()
        lines.append(
            "schema=" + KERNEL_SCHEMA
            + " dtype=float32 block=" + String(256)
            + " repetitions=" + String(REPETITIONS)
            + " warmup=first_launch median=repeated"
        )
        var all_pass = True
        var sizes: List[Int] = [7, 255, 256, 1024, 4097]
        for size in sizes:
            var result: GPUResult
            if size == 7:
                result = run_vector_add[7](ctx, REPETITIONS)
            elif size == 255:
                result = run_vector_add[255](ctx, REPETITIONS)
            elif size == 256:
                result = run_vector_add[256](ctx, REPETITIONS)
            elif size == 1024:
                result = run_vector_add[1024](ctx, REPETITIONS)
            else:
                result = run_vector_add[4097](ctx, REPETITIONS)
            if result.state != "PASS":
                all_pass = False
            var line = (
                "size=" + String(result.size) + " error=" + String(result.max_error)
                + " warmup_s=" + String(result.warmup_seconds)
                + " kernel_median_s=" + String(result.kernel_median_seconds)
                + " e2e_median_s=" + String(result.end_to_end_median_seconds)
                + " bytes_per_s=" + String(result.bytes_per_second)
                + " state=" + result.state
            )
            lines.append(line)
            print(line)

        if Path(workspace + "/benchmarks").exists():
            var report = open(workspace + "/benchmarks/gpu-vector-add.txt", "w")
            for line in lines:
                report.write(line + "\n")
            report.close()
            print("report: " + workspace + "/benchmarks/gpu-vector-add.txt")
        if all_pass:
            return 0
        return 1
