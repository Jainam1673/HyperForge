# AutoLLM validation (M11)

## What is implemented (offline core)

- **Local artifact discovery**: scans a user-provided directory for model-like
  files (`.gguf`, `.safetensors`, `.bin`, `.onnx`, `.json`), records size,
  FNV-1a checksum, and whether `LICENSE.txt`/`license.txt` is declared. No
  network access, no downloads, no implicit execution. Oversized files are
  skipped with an explicit status.
- **Versioned prompt suite** (`hyperforge-autollm-suite-v1`): local line format
  `HFPS1|<id>|<prompt>|<expected>|<metric>` with escaping, checksum, and two
  metrics (`exact`, `contains`). Example suite and recorded responses are in
  `examples/autollm/`.
- **Offline evaluation**: scores a recorded response file
  (`HFRSP1|<id>|<response>`). Missing responses count as failures; no response
  is fabricated. The suite checksum and counts are persisted.
- **Honest backend status** (`hyperforge-autollm-backend-v1`): `UNAVAILABLE`
  when no artifacts exist; `BLOCKED_BY_MAX_INTERFACE` when artifacts exist but
  no validated native Mojo inference boundary has been established.
- CLI: `autollm discover [dir]`, `autollm evaluate <suite> <responses>`,
  `autollm status`. All results are recorded in the local journal.

## Acceptance status

| Requirement | Status |
|---|---|
| Experiment specs and versioned prompt/eval suite | PASS |
| Local artifact discovery with checksums and license declaration | PASS |
| Inference parameters / latency / throughput capture | BLOCKED (no backend) |
| Reproducible evaluation suite | PASS (recorded responses scored offline) |
| Model unavailable gives a clear actionable result | PASS (`UNAVAILABLE` + remedy) |
| No external inference API or Python bridge invoked | PASS (no such code path exists) |
| Real local MAX inference for a user-supplied model | BLOCKED_BY_MAX_INTERFACE |
| No implied training/fine-tuning | PASS (no training code exists here) |

## Blocker: MAX inference boundary

MAX 26.7 is installed and the `max` CLI is available inside the pixi
environment, but a native Mojo entry point for model inference was **not
validated**. MAX's documented model pipelines and serving include Python-based
components, and no compatible local model artifact is provided in this
environment. Therefore `autollm` does not claim inference, throughput, or
latency measurement, and does not fabricate responses. This follows the master
directive's rule to expose `UNAVAILABLE`/`BLOCKED_BY_MAX_INTERFACE` and continue
with other work rather than fake model execution.

## Observed offline evaluation

Example suite: 3 cases; recorded responses cover 2. Result: matched 2,
missing 1, accuracy 0.6667, state `EVALUATED`. A synthetic artifact directory
with `LICENSE.txt` produced `artifact_count=1`, `license=DECLARED`, and backend
`BLOCKED_BY_MAX_INTERFACE`. Without artifacts, status is `UNAVAILABLE`.

## Out of scope

No prompt execution, tokenization metrics, model serving, adapters/LoRA,
retrieval, or generation. AutoGenAI depends on a verified AutoLLM/local MAX
interface and is therefore not started.
