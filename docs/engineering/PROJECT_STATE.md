# Project state — verified truth only

Truth order: observed execution and tests > source/configuration > this file >
design documents. A plan is not an implementation.

Status labels: `PLANNED`, `IN_PROGRESS`, `IMPLEMENTED_NOT_VERIFIED`, `PARTIAL`,
`BLOCKED`, `VERIFIED`, `DEFERRED`.

## Capability status

| Capability | Milestone | Status | Evidence |
|---|---|---|---|
| Pinned Mojo/MAX environment and CLI shell | M00 | VERIFIED | `ENVIRONMENT.md`; CLI integration checks |
| Experiment/journal substrate and tail recovery | M01 | VERIFIED | 13 M01 unit tests, 17 integration checks |
| Strict numeric CSV loading with fingerprint | M02 | VERIFIED | unit tests; `automl inspect` |
| Deterministic 60/20/20 split | M02 | VERIFIED | determinism and disjointness tests |
| Train-only imputation and standardization | M02 | VERIFIED | preprocessing tests |
| MAE/MSE/RMSE/R² with defined edge cases | M02 | VERIFIED | metrics tests |
| Mean baseline, linear GD, ridge GD, kNN | M02 | VERIFIED | known-relation recovery tests |
| Bounded deterministic random search | M02 | VERIFIED | determinism across workspaces |
| Durable validation and single test trials | M02 | VERIFIED | journal records; `automl show` |
| Held-out isolation | M02 | VERIFIED | protocol; code review; test evaluated once |
| `automl inspect/run/show/replay/compare`, `report` | M02 | VERIFIED | 21 integration checks |
| Real replay recomputation | M02 | VERIFIED | REPLAY_OK; refusal on tampered config/dataset |
| Typed search space with conditional validation | M03 | VERIFIED | validation unit tests |
| TPE-style adaptive sampler with connected feedback | M03 | VERIFIED | feedback regression test; deterministic runs |
| Propose → evaluate → persist → feedback loop | M03 | VERIFIED | 5 optimizer state records for budget 5 |
| Invalid and failed trial handling | M03 | VERIFIED | validation rules; FAILED trial path; tests |
| Matched-budget comparison vs random search | M03 | VERIFIED | `optimize run` output; 14 integration checks |
| Multi-fidelity racing | M03 | DEFERRED | no source yet |
| Classification | M03 | PLANNED | no source yet |
| SINN, SciTransformers | M03/M04 master numbering | PLANNED | no source yet |
| MAX GPU kernel and model inference | M12/M16 | PLANNED | no source yet |
| Scientific Looper / discovery loops | M15+ | PLANNED | no source yet |

## What is explicitly not implemented

No classification, cross-validation, adaptive sampler, tree model, ensemble,
neural model, benchmark suite, GPU execution, or scientific method exists.
`--help` labels these as planned. M02 is a regression-only AutoML slice on a
documented synthetic dataset; it makes no general-AutoML or SOTA claim.

## Known limitations

- Atomic rename/truncate is unavailable in installed Mojo 1.2.0; journal
  recovery rewrites a validated prefix with a plain full-file write.
- FNV-1a is an integrity check, not a security hash.
- A fresh `pixi install` into a new directory hit a disk quota during M02
  verification; clean-source build and all tests were verified using the
  already installed pinned environment instead (see `TEST_RESULTS.md`).
- Linear/ridge gradient descent is a straightforward reference implementation,
  not an optimized solver.

## Repository and workflow

Public remote: `https://github.com/Jainam1673/HyperForge.git`, branch `main`.
M02 commit: `18bcfde9ec3b5dc86264b737b738f5237a8d5224`.
M03 commit: `faac647d8389acd39231ef754351d0af16fb76fd`.
GitHub MCP is working (verified with `get_me` and `opencode mcp list`).
