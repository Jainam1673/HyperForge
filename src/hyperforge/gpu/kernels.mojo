"""Official-example-derived Mojo/MAX GPU kernel and CPU reference.

Vector addition is the smallest meaningful accelerator proof: it exercises
device allocation, host mapping, launch configuration, bounds handling, and
device-to-host result verification. No model execution or fused kernel is
claimed.
"""

from std.math import ceildiv
from std.time import perf_counter
from max.gpu import global_idx
from max.gpu.host import DeviceContext
from layout import (
    TileTensor,
    ImmTileTensor,
    MutTileTensor,
    TensorLayout,
    row_major,
)

comptime GPU_DTYPE = DType.float32
comptime BLOCK_SIZE = 256
comptime KERNEL_SCHEMA = "hyperforge-gpu-vector-add-v1"


def vector_add_kernel[LT: TensorLayout](
    a: ImmTileTensor[GPU_DTYPE, LT, ImmUntrackedOrigin],
    b: ImmTileTensor[GPU_DTYPE, LT, ImmUntrackedOrigin],
    c: MutTileTensor[GPU_DTYPE, LT, MutUntrackedOrigin],
    size: Int32,
):
    comptime assert a.flat_rank == 1, "vector add expects a 1D tensor"
    var index = global_idx.x
    if index < Int(size):
        c[index] = a[index] + b[index]


def time_vector_add(
    mut ctx: DeviceContext, block_size: Int, repetitions: Int
) raises -> Float64:
    """Median kernel time for a runtime-selected launch configuration."""
    if block_size < 1:
        raise Error("block size must be positive")
    comptime N = 1024
    comptime layout = row_major[N]()
    comptime kernel = vector_add_kernel[type_of(layout)]
    var a_buffer = ctx.enqueue_create_buffer[GPU_DTYPE](N)
    var b_buffer = ctx.enqueue_create_buffer[GPU_DTYPE](N)
    var c_buffer = ctx.enqueue_create_buffer[GPU_DTYPE](N)
    a_buffer.enqueue_fill(1.0)
    b_buffer.enqueue_fill(2.0)

    # Warm-up launch, then repeated timed launches.
    ctx.enqueue_function[kernel](
        TileTensor(a_buffer, layout).as_imm(),
        TileTensor(b_buffer, layout).as_imm(),
        TileTensor(c_buffer, layout),
        Int32(N),
        grid_dim=ceildiv(N, block_size),
        block_dim=block_size,
    )
    ctx.synchronize()
    var times = List[Float64]()
    for _ in range(repetitions):
        var started = perf_counter()
        ctx.enqueue_function[kernel](
            TileTensor(a_buffer, layout).as_imm(),
            TileTensor(b_buffer, layout).as_imm(),
            TileTensor(c_buffer, layout),
            Int32(N),
            grid_dim=ceildiv(N, block_size),
            block_dim=block_size,
        )
        ctx.synchronize()
        times.append(perf_counter() - started)
    return median(times)


def cpu_vector_add(left: List[Float32], right: List[Float32]) raises -> List[Float32]:
    if len(left) != len(right):
        raise Error("vector add length mismatch")
    var out = List[Float32]()
    for i in range(len(left)):
        out.append(left[i] + right[i])
    return out^


def max_abs_error(left: List[Float32], right: List[Float32]) raises -> Float32:
    if len(left) != len(right):
        raise Error("error length mismatch")
    var worst = Float32(0.0)
    for i in range(len(left)):
        var delta = left[i] - right[i]
        if delta < 0.0:
            delta = -delta
        if delta > worst:
            worst = delta
    return worst


def median(values: List[Float64]) raises -> Float64:
    if len(values) == 0:
        raise Error("median of empty list")
    var sorted_values = List[Float64]()
    for value in values:
        var inserted = False
        for i in range(len(sorted_values)):
            if value < sorted_values[i]:
                sorted_values.insert(i, value)
                inserted = True
                break
        if not inserted:
            sorted_values.append(value)
    return sorted_values[(len(sorted_values) - 1) // 2]


struct GPUResult(Copyable, Movable):
    var size: Int
    var max_error: Float32
    var warmup_seconds: Float64
    var kernel_median_seconds: Float64
    var end_to_end_median_seconds: Float64
    var bytes_per_second: Float64
    var state: String

    def __init__(
        out self,
        size: Int,
        max_error: Float32,
        warmup_seconds: Float64,
        kernel_median_seconds: Float64,
        end_to_end_median_seconds: Float64,
        bytes_per_second: Float64,
        state: String,
    ):
        self.size = size
        self.max_error = max_error
        self.warmup_seconds = warmup_seconds
        self.kernel_median_seconds = kernel_median_seconds
        self.end_to_end_median_seconds = end_to_end_median_seconds
        self.bytes_per_second = bytes_per_second
        self.state = state


def run_vector_add[N: Int](mut ctx: DeviceContext, repetitions: Int) raises -> GPUResult:
    """Run one size with warm-up, correctness check, and repeated timing."""
    if N < 1:
        raise Error("vector size must be positive")
    comptime layout = row_major[N]()
    comptime kernel = vector_add_kernel[type_of(layout)]

    var a_buffer = ctx.enqueue_create_buffer[GPU_DTYPE](N)
    var b_buffer = ctx.enqueue_create_buffer[GPU_DTYPE](N)
    var c_buffer = ctx.enqueue_create_buffer[GPU_DTYPE](N)

    var expected_left = List[Float32]()
    var expected_right = List[Float32]()
    with a_buffer.map_to_host() as mapped_a:
        var view_a = TileTensor(mapped_a, layout)
        with b_buffer.map_to_host() as mapped_b:
            var view_b = TileTensor(mapped_b, layout)
            for i in range(N):
                var value_a = Float32(i + 1)
                var value_b = Float32(2 * (i + 1))
                view_a[i] = value_a
                view_b[i] = value_b
                expected_left.append(value_a)
                expected_right.append(value_b)

    var expected = cpu_vector_add(expected_left, expected_right)
    var grid = ceildiv(N, BLOCK_SIZE)

    var warmup_start = perf_counter()
    ctx.enqueue_function[kernel](
        TileTensor(a_buffer, layout).as_imm(),
        TileTensor(b_buffer, layout).as_imm(),
        TileTensor(c_buffer, layout),
        Int32(N),
        grid_dim=grid,
        block_dim=BLOCK_SIZE,
    )
    ctx.synchronize()
    var warmup_seconds = perf_counter() - warmup_start

    var observed = List[Float32]()
    with c_buffer.map_to_host() as mapped_c:
        var view_c = TileTensor(mapped_c, layout)
        for i in range(N):
            observed.append(view_c[i])
    var error = max_abs_error(observed, expected)

    var kernel_times = List[Float64]()
    var end_to_end_times = List[Float64]()
    for _ in range(repetitions):
        var kernel_start = perf_counter()
        ctx.enqueue_function[kernel](
            TileTensor(a_buffer, layout).as_imm(),
            TileTensor(b_buffer, layout).as_imm(),
            TileTensor(c_buffer, layout),
            Int32(N),
            grid_dim=grid,
            block_dim=BLOCK_SIZE,
        )
        ctx.synchronize()
        kernel_times.append(perf_counter() - kernel_start)

        var total_start = perf_counter()
        ctx.enqueue_function[kernel](
            TileTensor(a_buffer, layout).as_imm(),
            TileTensor(b_buffer, layout).as_imm(),
            TileTensor(c_buffer, layout),
            Int32(N),
            grid_dim=grid,
            block_dim=BLOCK_SIZE,
        )
        ctx.synchronize()
        with c_buffer.map_to_host() as mapped_c:
            var view_c = TileTensor(mapped_c, layout)
            observed[0] = view_c[0]
        end_to_end_times.append(perf_counter() - total_start)

    var kernel_median = median(kernel_times)
    var total_median = median(end_to_end_times)
    var bytes_per_second = Float64(3 * N * 4) / kernel_median
    var state = String("PASS")
    if error > Float32(1e-5):
        state = "INCORRECT"
    return GPUResult(
        N, error, warmup_seconds, kernel_median, total_median,
        bytes_per_second, state,
    )
