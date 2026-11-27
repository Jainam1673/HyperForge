# AutoTransformers validation (M10)

## Distinction from SciTransformers

SciTransformers is a scientific-task architecture family. AutoTransformers is
the system that **searches transformer configurations** on verified attention
infrastructure. This slice uses the same synthetic sequence benchmark but
varies architecture/attention/FFN configuration and measures both quality and
latency by execution.

## Search genes and constraints

| Gene | Values | Constraint |
|---|---|---|
| `d_model` | 4, 8 | must be divisible by heads |
| `heads` | 1, 2 | `d_model % heads == 0` |
| `ff_hidden` | 4, 8, 16 | validated |
| `layers` | 1, 2 | validated |
| `history` | task-fixed at 2 | task contract; not varied |

Cache and precision genes are **not** implemented and are not registered. No
MAX inference or serving configuration is claimed: this is CPU reference code
over the verified reverse-mode tape.

## Execution and measurement

- Every candidate is initialized from its seed, trained for three epochs with
  Adam on the same synthetic decaying-mode task, and evaluated on validation.
- Selection uses **validation MSE only**; test MSE is measured once for the
  selected config. Test indices are offset from training/validation indices.
- Inference latency is the median of seven `predict` calls after a warm-up,
  measured with `std.time.perf_counter`.
- Parameter count is computed from the config and verified against the model.

## Observed results (budget 3, seed 42)

| Policy | config | params | validation MSE | test MSE | median latency s |
|---|---|---:|---:|---:|---:|
| default | 4x2/ff4/L1 | 133 | 0.01370 | 0.01605 | 0.00064 |
| random | 8x2/ff8/L2 | 857 | 0.00165 | 0.00216 | 0.00406 |
| adaptive | 4x2/ff4/L1 | 133 | 0.01370 | 0.01605 | 0.00070 |

The random policy found a more accurate configuration, but it has ~6.4x the
parameters and ~6x the latency. This is why selection is benchmark-based: a
smaller or theoretically cheaper configuration is not assumed to be faster.
The adaptive policy stayed at the default at this tiny budget; no advantage is
claimed.

## Persistence and replay

Each policy writes a versioned config artifact, a serialized checkpoint, and an
`autotrans` journal record with genes, parameter count, validation/test MSE,
latency, and config checksum. `autotransformers replay <policy>` verifies the
checksum and reports readiness; it does not claim re-execution.

## Limits

No FlashAttention, fused kernels, GPU inference, MAX serving, cache/precision
search, or large benchmark suite. No claim that random or adaptive search is
generally better. Latency is from this CPU build and task only.
