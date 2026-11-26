# Project state — verified truth only

Truth order: observed execution and tests > source/configuration > this file >
design documents. A plan is not an implementation.

Status labels: `PLANNED`, `IN_PROGRESS`, `VERIFIED`, `PARTIAL`,
`BLOCKED`, `VERIFIED`, `DEFERRED`.

## Capability status

| Capability | Milestone | Status | Evidence |
|---|---|---|---|
| Pinned Mojo/MAX environment | M00 | VERIFIED | `ENVIRONMENT.md`; `pixi run mojo --version`, `pixi run max --version` |
| Native `hyperforge` executable | M00 | VERIFIED | `pixi run build` produces `hyperforge`; integration checks pass |
| `--help`, `--version` | M00 | VERIFIED | 13 unit + 24 integration checks pass |
| `doctor [--json]` with separate probes | M00 | VERIFIED | integration checks; JSON schema `hyperforge-doctor-v1` |
| `init <path>` with versioned workspace | M00 | VERIFIED | integration checks; creates config + 3 directories |
| Stable exit codes and stderr errors | M00 | VERIFIED | integration checks for codes 0 and 2 |
| Experiment core / event log | M01 | PLANNED | no source yet |
| AutoML | M02 | PLANNED | no source yet |
| SINN, SciTransformers | M03/M04 | PLANNED | no source yet |
| MAX GPU kernel, model inference | M12/M16 | PLANNED | no source yet |
| Scientific Looper / discovery loops | M15+ | PLANNED | no source yet |

## What is explicitly not implemented

No frontend, server, database, Python application, external queue, generated
candidates, model execution, experiment persistence, or scientific method is
implemented. `--help` labels these as planned and no such commands are
registered.

## Current blocker

The workspace is not yet a Git repository and no GitHub remote exists. GitHub
MCP is working (verified with `get_me`), but a destination repository and its
visibility must be confirmed before M00 can be pushed.
