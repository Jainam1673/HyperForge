# Capability status matrix (M21)

Statuses describe **verified repository evidence**, not intent. `PARTIAL` and
`PLANNED` items remain visible and are never reported as complete.

| Capability | Status | Evidence / boundary |
|---|---|---|
| Native Mojo CLI (`doctor`, `init`, `experiment`) | COMPLETE | M00–M01; CLI_SPEC.md |
| AutoML (full declared algorithm suite) | COMPLETE | M02–M03 + M22: 18 model kinds, classification+regression, full metric suite, k-fold CV, grid/random/adaptive; `AUTOML_FULL.md` |
| SINN (scientific neural networks) | COMPLETE | M05 |
| SciTransformers | COMPLETE | M06 |
| Reciprocal discovery proof | COMPLETE | M07; joint search lost in that fixture (negative result retained) |
| AutoDL | COMPLETE | M10 |
| AutoRL | COMPLETE | M11 |
| AutoTransformers | COMPLETE | M12 |
| AutoLLM (full first-party lifecycle) | COMPLETE | M23: tiny trained byte model, PreTrain/MidTrain/PostTrain/Infer, checkpoint lineage, honest MAX boundary; `AUTOLLM_LIFECYCLE.md` |
| AutoGenAI | BLOCKED | depends on a verified local MAX inference boundary; no command registered |
| SciML | COMPLETE | M13 |
| SciDL | COMPLETE | M14; MLP underperformed linear/FD baselines (negative result) |
| SciRL | COMPLETE | M15; bounded simulator, no real-world control |
| Scientific Looper | COMPLETE | M15; monotonic sequence, no verified wall-clock timestamps |
| Specialist roles / bounded swarm | PARTIAL | sequential specialist passes; no parallel agents |
| GPU kernel catalogue | COMPLETE | M16; MX230 sm_61, benchmark protocol in GPU_CATALOGUE.md |
| DiscoveryGenome v2 | PARTIAL | M17; compute/runtime genes measured, AI gene carried but unmeasured |
| Meta economy and causal graph | PARTIAL | M18; coupling edge remains hypothesized |
| Joint AI×compute benchmark | PARTIAL | M19; joint led mean discoveries on a small fixture, no general claim |
| Bounded RSI | PARTIAL | M20; config-only, protected evaluator, no code rewriting or runtime consumer |
| MAX model inference | BLOCKED | `BLOCKED_BY_MAX_INTERFACE`; no `max serve` dependency claimed |
| SciLLM / SciGenAI | BLOCKED | require verified MAX inference; not started |
| World models | PLANNED | no implementation |
| Broad HPC / HyperComputers | PLANNED | GPU kernels are reference infrastructure, not a broad HPC stack |
| Application kernel migration to GPU | PLANNED | deferred until profiling proves a bottleneck |

## Interpretation

- `COMPLETE` means behavior works, tests detect defects, evidence persists,
  and documentation matches implementation.
- `PARTIAL` means a real slice exists with an explicit, documented boundary.
- `BLOCKED` means prerequisites are unavailable; no command is registered.
- `PLANNED` means no implementation exists.

Negative results (adaptive search losing to random, joint search losing in M07,
SciDL MLP underperforming baselines) are retained in the engineering docs and
are not silently removed when later milestones report different outcomes.
