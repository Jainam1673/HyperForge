# GPU kernel catalogue and benchmark infrastructure (M16)

## Catalogue

| Kernel | Operation | CPU reference |
|---|---|---|
| `vector_add` | `c[i] = a[i] + b[i]` | `cpu_vector_add` |
| `vector_axpy` | `c[i] = alpha*a[i] + b[i]` | `cpu_vector_axpy` |

Both are plain Mojo functions launched with `ctx.enqueue_function`, derived
from the documented vector-add pattern. No CUDA syntax, fused kernel, or
FlashAttention is used or claimed. Supported benchmark sizes are
`7, 255, 256, 1024, 4097`, including partial-block and non-multiple cases.

## Reproducible protocol

- First launch is a warm-up and is timed separately from measured launches.
- Correctness is checked against a CPU reference with tolerance `1e-5` before
  timing; the constant-input reference uses the same arithmetic path as the
  kernel inputs.
- Kernel timing: repeated launches with `ctx.synchronize()` after each; median
  reported. Throughput is `3*N*4 / kernel_median_seconds` (two inputs, one
  output, Float32).
- End-to-end timing includes the device-to-host map-back when exercised by the
  vector-add benchmark.
- Each report records schema, kernel, size, Mojo/MAX pins, block size,
  repetitions, warm-up policy, aggregation, and whether an external ptxas was
  configured. A checksum is stored with the `gpu_bench` journal record.
- Invalid kernel names and sizes are rejected; no blocked run is reported as a
  pass.

## Device and compatibility

Observed on NVIDIA MX230 (`sm_61`, driver 580.178.04) with Mojo 1.2.0 and
MAX 26.7.0. MAX's bundled CUDA 13 `ptxas` rejects `sm_61`; `scripts/gpu-env.sh`
selects a cached CUDA 12 `ptxas` when available. Without it, GPU commands report
`BLOCKED` with a remedy and the CPU core remains fully tested.

## Application kernels

No AutoML/SINN/SciTransformers computation was moved to the GPU. The directive
requires profiling evidence before such a move, and this milestone only
establishes the catalogue, correctness gates, and measurement infrastructure.
MAX model inference remains separately blocked.

## Observed measurements

At size 255, `vector_add` reported zero error and a kernel median around
`7.1e-6 s` on this device; at size 1024, `vector_axpy` reported zero error and
a kernel median around `8.9e-6 s`. These numbers are device-specific and are
not comparisons against a tuned CPU implementation.
