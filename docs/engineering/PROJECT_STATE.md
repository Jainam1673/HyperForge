# Project state — verified truth only

Truth order: observed execution and tests > source/configuration > this file >
design documents. A plan is not an implementation.

Status labels: `PLANNED`, `IN_PROGRESS`, `IMPLEMENTED_NOT_VERIFIED`, `PARTIAL`,
`BLOCKED`, `VERIFIED`, `DEFERRED`.

## Capability status

| Capability | Milestone | Status | Evidence |
|---|---|---|---|
| Pinned Mojo/MAX environment | M00 | VERIFIED | `ENVIRONMENT.md`; `pixi run mojo --version` → 1.2.0; `pixi run max --version` → 26.7.0 |
| Native `hyperforge` executable | M00 | VERIFIED | `pixi run build`; integration checks |
| `--help`, `--version`, `doctor [--json]` | M00 | VERIFIED | 24 CLI integration checks |
| `init <path>` with versioned workspace | M00 | VERIFIED | integration checks |
| Typed experiment records and derived seeds | M01 | VERIFIED | 13 M01 unit tests; experiment integration |
| Trial/experiment state machine | M01 | VERIFIED | unit tests reject invalid transitions |
| Seeded RNG and seed derivation | M01 | VERIFIED | deterministic known-value tests |
| Append-only HFJ1 journal with checksums | M01 | VERIFIED | round-trip and tamper tests |
| Tail recovery for corrupt/truncated records | M01 | VERIFIED | unit + integration recovery tests |
| Replay input verification (no execution) | M01 | VERIFIED | missing and tampered artifact refusals |
| Experiment CLI `create/list/show/replay` | M01 | VERIFIED | 17 experiment integration checks |
| AutoML execution / real replay | M02 | PLANNED | no source yet |
| SINN, SciTransformers | M03/M04 | PLANNED | no source yet |
| MAX GPU kernel, model inference | M12/M16 | PLANNED | no source yet |
| Scientific Looper / discovery loops | M15+ | PLANNED | no source yet |

## What is explicitly not implemented

No experiment *execution* exists: `experiment replay` only verifies that
recorded inputs are present and unchanged. No model training, metrics,
benchmarks, or discovery logic exists. No frontend, server, database, Python
application, or external queue exists.

## Known limitations

- Atomic rename/truncate is unavailable in installed Mojo 1.2.0 stdlib. Journal
  recovery rewrites the validated prefix with a plain full-file write; this is
  documented in `DECISIONS.md`.
- FNV-1a is a non-cryptographic integrity check, not a security hash.

## Repository and workflow

Public remote: `https://github.com/Jainam1673/HyperForge.git`, branch `main`.
GitHub MCP is working (verified with `get_me` and `opencode mcp list`).
