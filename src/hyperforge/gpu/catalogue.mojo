"""GPU kernel catalogue with reproducible benchmark dispatch."""

from max.gpu.host import DeviceContext
from hyperforge.gpu.kernels import (
    GPUResult,
    run_vector_add,
    run_vector_axpy,
)

comptime CATALOGUE_SCHEMA = "hyperforge-gpu-catalogue-v1"
comptime SUPPORTED_SIZES = "7, 255, 256, 1024, 4097"


struct KernelEntry(Copyable, Movable):
    var name: String
    var description: String
    var cpu_reference: String

    def __init__(out self, name: String, description: String, cpu_reference: String):
        self.name = name
        self.description = description
        self.cpu_reference = cpu_reference


def catalogue() raises -> List[KernelEntry]:
    var entries = List[KernelEntry]()
    entries.append(KernelEntry(
        "vector_add", "c[i] = a[i] + b[i]", "cpu_vector_add"
    ))
    entries.append(KernelEntry(
        "vector_axpy", "c[i] = alpha*a[i] + b[i]", "cpu_vector_axpy"
    ))
    return entries^


def kernel_names() raises -> List[String]:
    var entries = catalogue()
    var names = List[String]()
    for entry in entries:
        names.append(entry.name)
    return names^


def run_catalogue_kernel(
    mut ctx: DeviceContext, name: String, size: Int, repetitions: Int
) raises -> GPUResult:
    if name == "vector_add":
        if size == 7:
            return run_vector_add[7](ctx, repetitions)
        if size == 255:
            return run_vector_add[255](ctx, repetitions)
        if size == 256:
            return run_vector_add[256](ctx, repetitions)
        if size == 1024:
            return run_vector_add[1024](ctx, repetitions)
        if size == 4097:
            return run_vector_add[4097](ctx, repetitions)
        raise Error("unsupported benchmark size: " + String(size))
    if name == "vector_axpy":
        var alpha = Float32(0.5)
        if size == 7:
            return run_vector_axpy[7](ctx, alpha, repetitions)
        if size == 255:
            return run_vector_axpy[255](ctx, alpha, repetitions)
        if size == 256:
            return run_vector_axpy[256](ctx, alpha, repetitions)
        if size == 1024:
            return run_vector_axpy[1024](ctx, alpha, repetitions)
        if size == 4097:
            return run_vector_axpy[4097](ctx, alpha, repetitions)
        raise Error("unsupported benchmark size: " + String(size))
    raise Error("unknown catalogue kernel: " + name)
