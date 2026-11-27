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
| SINN 1D Poisson with verified jets and exact BC | M04 | VERIFIED | 7 unit tests; 17 integration checks; `SCIENTIFIC_VALIDATION.md` |
| Independent finite-difference reference solver | M04 | VERIFIED | agrees with analytic solution <1e-3 |
| Honest divergent/non-converged state | M04 | VERIFIED | 3-iteration run exits 1 with reason |
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
M04 commit: `8694384f87a8251cf64a5d133c51b326bf51d13c`.
SciTransformers 1D sequence task with two-head attention: M05, VERIFIED
(8 unit tests, 20 integration checks, `SCIENTIFIC_VALIDATION.md`). Reverse-mode
tape and masked attention are numerically verified. Three non-transformer
baselines and rollout drift are reported; the linear baseline is stronger on
this exact-linear task (honest negative result). M05 commit:
`cc95061b4ea1171a27691d86540d45ae240b6510`.
MAX/GPU kernel proof: M06, VERIFIED (5 unit tests, 17 integration checks,
`GPU_BENCHMARK.md`). Five sizes pass with zero error on NVIDIA sm_61 using an
external ptxas; CPU core remains green. M06 commit:
`1e27e4333411f95b2b68315df21be2adcd325c52`.
Reciprocal Meta-Discovery proof: M07, VERIFIED (5 unit tests, 15 integration
checks, `RECIPROCAL_DISCOVERY.md`). Six matched-budget policies run; joint
search did not beat fixed/independent and the negative result is recorded.
M07 commit: `d9d2f91f47d72ec52921b65186811d359fc4d930`.
AutoDL: M08, VERIFIED (5 unit tests, 13 integration checks,
`AUTODL_VALIDATION.md`). Real MLPs are trained with tape gradients; four
structurally distinct architectures were trained in the observed search;
test is locked until final selection. M08 commit:
`f0456e7ee978dcdff2c4f181c1712dd3dc4ea71c`.
AutoRL: M09, VERIFIED (5 unit tests, 17 integration checks,
`AUTORL_VALIDATION.md`). Q-learning reaches the DP optimum and beats the random
baseline on unseen seeds; learning curves and config checksums persist.
M09 commit: `4fb11369fe12f8e01fab27e8a1d54542b9fbe36e`.
AutoTransformers: M10, VERIFIED (4 unit tests, 14 integration checks,
`AUTOTRANS_VALIDATION.md`). Configs differ behaviorally; quality and latency are
measured by execution; random found a more accurate but slower config. No MAX
inference claim. M10 commit: `20c0454ccf1d56bb93730aeeb2470d0059199e43`.
AutoLLM substrate: M11, VERIFIED offline core (4 unit tests, 16 integration
checks, `AUTOLLM_VALIDATION.md`). Local MAX inference is BLOCKED_BY_MAX_INTERFACE
with no fabricated responses; no training implied. M11 commit: `ecbc58104e43ee1cd3243917a2ca4a544cbb8081`.
SciML: M12, VERIFIED (4 unit tests, 16 integration checks,
`SCIML_VALIDATION.md`). Forward FD solver, inverse parameter identification,
hybrid correction, and data-only baseline evaluated on held-out points.
M12 commit: `9122944002c24f7a657b5875c3f9398587760fb3`.
SciDL: M13, VERIFIED (4 unit tests, 9 integration checks,
`SCIDL_VALIDATION.md`). Supervised field MLP trained on lower PDE parameters and
evaluated on unseen higher parameters; linear and FD baselines outperform it.
M13 commit: `83b9f320f935db6a008e941f42365c6da8385fd8`.
SciRL: M14, VERIFIED (4 unit tests, 12 integration checks,
`SCIRL_VALIDATION.md`). Learned solver-selection policy beats random and
finest-mesh heuristic on held-out conditions. M14 commit: `254a587bfad159b4bfd5defce9dc12b18c820554`.
Scientific Looper: M15, VERIFIED (4 unit tests, 11 integration checks,
`LOOPER_VALIDATION.md`). Validated state machine, idempotent events, bounded
trials, sequential specialist roles, real measured evidence. M15 commit: `7b361b2f6246c48fec85441729b1067589a6d016`.
GPU catalogue: M16, VERIFIED (3 unit tests, 15 integration checks,
`GPU_CATALOGUE.md`). Two catalogued kernels with CPU references, warm-up/median
protocol, environment capture, and checksummed evidence. M16 commit: `21b339c8c65e42ac94a03fd0e7a732f234365793`.
DiscoveryGenome v2 / systems search: M17, VERIFIED (4 unit tests, 11 integration
checks, `SYSTEMS_SEARCH.md`). Real measured launch-configuration search with
Pareto handling; AI gene carried but not measured. M17 commit: `b4ee584726901c312c19be58a4a475a743b8ca85`.
GitHub MCP is working (verified with `get_me` and `opencode mcp list`).
