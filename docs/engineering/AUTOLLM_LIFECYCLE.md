# M23 — AutoLLM full PreTrain→MidTrain→PostTrain→Infer lifecycle

The owner required AutoLLM to be an end-to-end process, not just an offline
substrate. This milestone implements all four stages monolithically with a
**tiny first-party model** trained by genuine reverse-mode gradients.

## Honest scope

The model is a byte-level maximum-entropy context model: it predicts the next
byte from the previous `LM_CONTEXT = 3` tokens using a softmax over a learned
weight matrix. Gradients come from the project's `autodiff/tape.mojo`; loss is
softmax cross-entropy. This is a **real trainable language model**, but it is
not a transformer, not a frontier LLM, and not MAX model inference. Every
stage prints that boundary, and the MAX boundary remains
`BLOCKED_BY_MAX_INTERFACE` in `autollm status`.

## Lifecycle state machine

| Stage | Command | Requirement |
|---|---|---|
| PreTrain | `autollm pretrain <corpus> [epochs]` | always allowed; builds a deterministic sorted vocabulary and initializes weights from a seed |
| MidTrain | `autollm midtrain <corpus> [epochs]` | requires PreTrain checkpoint; continues training with a lower learning rate |
| PostTrain | `autollm posttrain <pairs.tsv> [epochs]` | requires MidTrain checkpoint; trains on `prompt<TAB>response` pairs joined with a separator |
| Infer | `autollm infer <prompt> [max_tokens] [temperature]` | requires PostTrain checkpoint; autoregressive deterministic sampling |

Invalid transitions are rejected with a precise error and exit code 1. Each
stage writes a checksummed checkpoint into `artifacts/autollm/` and appends an
`autollm_stage` journal record carrying stage, epochs, corpus fingerprint,
checkpoint checksum, loss, and the full lineage chain. Inference appends an
`autollm_response` record carrying prompt, response, seed, decoding parameters,
model checksum, and lineage — so a generated response always names the exact
checkpoint chain that produced it.

`autollm status` now reports per-stage state, the checkpoint chain, the model
scope, the next action, and the separate MAX boundary. The original substrate
lines (`backend_schema`, `status`, `offline_core`) remain unchanged.

## Observed result

Using the bundled tiny fixtures and 4 epochs per stage:

| Stage | Tokens | Final loss | Checksum |
|---|---:|---:|---|
| PreTrain | 209 | 2.57 | `6f40317d011d9ecd` |
| MidTrain | 110 | 2.11 | `16461b87ccda2091` |
| PostTrain | 120 | 1.37 | `4d75601ebcc877a1` |

Loss falls across the chain, demonstrating genuine training rather than a
staged mock. Inference for prompt `"the "` produced a decoded byte sequence
from the PostTrain checkpoint with lineage naming all three checkpoints.

## Verification

- `test_m23`: 5 tests — deterministic vocab/init, loss reduction across
  epochs, checkpoint round-trip and checksum rejection, bounded deterministic
  sampling, and all lifecycle transitions.
- `test-autollm-lifecycle`: 30 integration checks including invalid transitions,
  staged outputs, journal records, and final status.

## Limits

- Tiny vocabulary and context; no BPE, no attention, no multi-head transformer.
- PostTrain is next-token fine-tuning on recorded pairs, not RLHF/DPO.
- Inference is greedy/temperature/top-k byte sampling from a first-party
  checkpoint; it does not use MAX, and no MAX inference claim is made.
- No external corpus is downloaded; all fixtures are project-owned.
