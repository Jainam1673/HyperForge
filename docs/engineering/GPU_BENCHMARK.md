# GPU kernel proof and benchmark protocol (M06)

## Device and toolchain

| Item | Observed value |
|---|---|
| GPU | NVIDIA GeForce MX230 |
| Compute capability | 6.1 (Pascal, `sm_61`) |
| Driver | 580.178.04 |
| Mojo | 1.2.0 (2016d0cd) |
| MAX | 26.7.0 |
| Kernel schema | `hyperforge-gpu-vector-add-v1` |
| Data type | `Float32` |
| Block size | 256 threads |

`has_accelerator()` reports `True`; capability is not inferred from the device
name alone. The kernel is a plain `def` launched with
`ctx.enqueue_function[...]`; there is no CUDA syntax and no fused/Flash kernel.

## Compatibility issue and remedy

MAX 26.7 rejects `sm_61` with its bundled CUDA 13 `ptxas` ("Value 'sm_61' is
not defined"). Verified remedy: use a locally cached CUDA 12.x `ptxas` via
`MODULAR_NVPTX_COMPILER_PATH`. `scripts/gpu-env.sh` discovers such a compiler
and `scripts/mojo.sh` applies it together with `--target-accelerator sm_61`.
If no compatible compiler exists, `hardware probe` and `benchmark kernel`
report `BLOCKED` with a remedy and return exit 3; the CPU core still builds and
passes every test.

## Correctness protocol

- Inputs written through `map_to_host`: `a[i] = i+1`, `b[i] = 2*(i+1)`.
- CPU reference: `cpu_vector_add` in `src/hyperforge/gpu/kernels.mojo`.
- Output mapped back and compared element-wise; `max_abs_error` must be 0 for
  `Float32` in these cases.
- Sizes include a tiny case (7, one partial block), a just-under-block case
  (255), an exact block (256), and larger non-multiples (1024, 4097). Out-of-
  range threads are guarded by `index < size`.
- Kernel scalar argument is `Int32`, not `Int`: installed Mojo 1.2.0 requires a
  fixed-width type for `DevicePassable` scalar arguments.

## Timing protocol

- Warm-up: first launch and synchronize, timed separately.
- Correctness check: performed after warm-up, before measured launches.
- Kernel timing: 9 launches, each followed by `ctx.synchronize()`; median
  reported.
- End-to-end timing: launch + synchronize + device-to-host map back; median
  reported separately from kernel time.
- Throughput: `3 * N * 4 bytes / kernel_median_seconds` (two inputs, one output).
- No call to a model or AutoML path occurs in this benchmark.

## Observed results (release binary, nine repetitions)

| Size | max error | warm-up s | kernel median s | e2e median s | bytes/s | state |
|---:|---:|---:|---:|---:|---:|---|
| 7 | 0.0 | 5.74e-4 | 3.21e-5 | 6.33e-5 | 2.61e6 | PASS |
| 255 | 0.0 | 2.78e-4 | 1.88e-5 | 4.44e-5 | 1.63e8 | PASS |
| 256 | 0.0 | 2.28e-4 | 1.26e-5 | 3.29e-5 | 2.44e8 | PASS |
| 1024 | 0.0 | 3.08e-4 | 1.06e-5 | 3.14e-5 | 1.16e9 | PASS |
| 4097 | 0.0 | 2.80e-4 | 4.82e-5 | 1.08e-4 | 1.02e9 | PASS |

These numbers describe this device and build only. A tiny kernel is launch-
dominated; the 7-element throughput is not comparable to the large sizes. No
comparison against a CPU vector-add implementation is claimed as a speedup:
the CPU reference is used for correctness, not as a tuned performance baseline.

## Scope limits

No useful AutoML/SINN/SciTransformers computation was moved to the GPU. The
acceptance gate for this milestone is a correct, measured, hardware-backed
kernel; application kernels require profiling evidence first. MAX model
serving remains optional and untested here.
