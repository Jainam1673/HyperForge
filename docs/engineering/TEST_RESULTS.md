# Test results — exact commands and observed outcomes

Environment: see `ENVIRONMENT.md`. Dates: 2026-11-26.

## M00/M01 results (summary)

- `pixi run build` → native `hyperforge` ELF.
- `pixi run test` → M00 13 tests, M01 13 tests, all passed.
- `pixi run test-cli` → 24 passed, 0 failed.
- `pixi run test-experiment` → 17 passed, 0 failed.
- `opencode mcp list` → github connected; `get_me` → `Jainam1673`.

## M02 probe commands

| Command | Outcome |
|---|---|
| `pixi run mojo run /tmp/opencode/m02_probe.mojo` | `sqrt`, `abs`, `pow`, `Float64("3.25")`, `str.split` work |
| import `is_finite` from `std.math` | not available |
| `Float64.is_finite()` | not available; implemented via NaN self-comparison and magnitude bound |
| dataset probe on `examples/regression_linear.csv` | 24 rows, 3 cols, fingerprint `286357448ec34b94` |
| module probe: split → preprocess → linear fit → predict | prediction `2.5000084572741623` for actual `2.5` |

## M02 build and test commands

| Command | Outcome |
|---|---|
| `pixi run build` | exit 0 |
| `pixi run test` | 36 tests total (13 CLI + 13 M01 + 10 M02), all passed |
| `pixi run test-cli` | `integration: 24 passed, 0 failed` |
| `pixi run test-experiment` | `experiment integration: 17 passed, 0 failed` |
| `pixi run test-automl` | `automl integration: 21 passed, 0 failed` |

## M02 observed experiment

Command: `hyperforge automl run examples/regression_linear.csv y 5 42`

- experiment ID: `exp-b6fd492fc432a53e`
- baseline validation RMSE: `4.841229182759271`, R² `-0.7142857142857142`
- best candidate: `linear_gd`, validation RMSE `3.1452039735002787e-08`
- held-out test: RMSE `2.2272160351028695e-08`, MAE `1.9664427715800532e-08`, R² `1.0`
- `automl replay <id>` → `REPLAY_OK` with the same held-out RMSE.

## M02 independent verification

| Check | Outcome |
|---|---|
| same config run in two workspaces | identical ID and identical validation/test metrics |
| dataset with an empty feature cell | inspect reports 1 missing cell; run succeeds via train-mean imputation |
| config artifact appended to | replay exit 3: checksum mismatch |
| recorded dataset file appended to | replay exit 3: dataset fingerprint changed |
| missing dataset / bad target | exit 1 with `dataset error` on stderr |
| budget 1 | exit 2 with `budget must be at least 2` |
| clean source copy (no `.pixi`) with pinned env | build + 36 unit tests + 62 integration checks pass |

Two real defects were found and fixed during M02: kNN indexed an empty
neighbor list (assert crash), and kNN insertion assumed a full list. Both are
covered by tests now. Two test expectations were also corrected: the train-only
target mean must be computed from the train subset, and k=1 must be checked on
a training row (the nearest training point is not necessarily a test target).

## M03 results

| Command | Outcome |
|---|---|
| `pixi run test` | 42 unit tests total (13+13+10+6), all passed |
| `pixi run test-cli` | 24 passed, 0 failed |
| `pixi run test-experiment` | 17 passed, 0 failed |
| `pixi run test-automl` | 21 passed, 0 failed |
| `pixi run test-optimize` | 14 passed, 0 failed |
| `optimize run examples/regression_linear.csv y 6 42` | adaptive test RMSE `1.9183755652814585`; random baseline `2.2272160351028695e-08`; adaptive did not win |
| two workspaces, same config | identical ID and adaptive validation/test metrics |
| optimizer state records | observed counts 1,2,3,4,5 for budget 5 |

Defects found and fixed during M03: kNN candidates were rejected because the
validator required `k == 0` for that kind; the baseline was incorrectly used as
a TPE parent, producing invalid baseline-with-iterations candidates. Both were
reproduced with probes and covered by unit tests.

## M04 results

| Command | Outcome |
|---|---|
| `pixi run mojo run -I src tests/test_m04.mojo` | 7 tests pass (jet derivatives, network BC, parameter gradient, FD solver, serialization, reproducibility, honest failure) |
| `pixi run test-sinn` | `sinn integration: 17 passed, 0 failed` |
| `sinn solve poisson_1d 42 800` | CONVERGED; loss 5.6308 → 0.000838; residual 0.0287; boundary 0.0; exact_l2 0.00200; fd_l2 0.00200 |
| `sinn solve poisson_1d 43 3` | exit 1, `did not meet the convergence gate` |
| `sinn solve heat_2d 42 800` | exit 2, unsupported problem |

Defects found and fixed during M04: `w1` and `v` entered the jet graph via
constant scaling, making their parameter derivatives silently zero; after the
fix, parameter gradients matched finite differences and final loss improved from
0.0107 to 0.00084 at 800 iterations. Tuple return syntax required `Tuple[...]`
and `mut` call-site syntax was rejected.

## M05 results

| Command | Outcome |
|---|---|
| `pixi run mojo run -I src tests/test_m05.mojo` | 8 tests pass (tape, softmax, attention, masks, task, serialization, training) |
| `pixi run test-scit` | `scit integration: 20 passed, 0 failed` |
| `sci-transformers train 42 10` | CONVERGED; loss 0.0435 → 0.000353; model MSE 0.000266; persistence 0.02165; mean 0.13300; linear 8.19e-33; drift 0.00179 |
| two workspaces, same seed | identical reported metrics |
| `sci-transformers train 42 0` | exit 2 (usage validation) |
| `sci-transformers predict <id> 0` | prediction and actual held-out frame printed |

Defect found and fixed during M05: per-head query/key/value projections used
inconsistent dimensions, producing a dot-product length mismatch; offsets were
redesigned to 128 parameters with explicit `HEAD_DIM=2` projections. Training
tests initially used a workload too large for debug-mode `mojo run`; the test
uses a declared smaller spec (8 train, 4 test, 4 epochs) with the same assertions.

## M06 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m06.mojo` | 5 tests pass |
| `pixi run test-gpu` | `gpu integration: 17 passed, 0 failed` |
| all six prior integration suites | unchanged, all pass |
| `source scripts/gpu-env.sh && ./hyperforge benchmark kernel` | five PASS rows, max error 0.0 |
| `./hyperforge benchmark kernel` without env | exit 3 with BLOCKED and remedy |

Defects fixed during M06: kernel scalar argument `Int` is not `DevicePassable`
in Mojo 1.2.0 (changed to `Int32`); `ptxas` from CUDA 13 rejects `sm_61` (external
CUDA 12 ptxas selected by wrapper); the Mojo wrapper originally placed the
target flag before the subcommand; even-length median returned the upper
element (changed to lower median).

## M07 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m07.mojo` | 5 tests pass |
| `pixi run test-discover` | `discover integration: 15 passed, 0 failed` |
| `discover run 6 42` | six policies, 6 discovery records, joint RMSE 0.0435 vs fixed/independent 8.81e-7 |
| `discover run 6 43` | same ordering; negative result reproduced |
| `discover run 1 42` | exit 2 (budget validation) |

Integration initially failed because the GPU runtime env was not sourced; fixed
by sourcing `scripts/gpu-env.sh` in the test script, matching M06.

## M08 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m08.mojo` | 5 tests pass |
| `pixi run test-autodl` | `autodl integration: 13 passed, 0 failed` |
| `autodl run 4 42` | random 1x4 relu val 0.5549 test acc 0.875, 4 distinct architectures; adaptive 3x8 val 0.5634 test acc 0.875 |
| `autodl show/replay` | checkpoint restored, `REPLAY_READY` |

Two defects were found and fixed in M08: `show`/`replay` parsed the candidate ID
as an integer in the main dispatcher; and artifacts lacked a policy suffix, so
replay could not locate checkpoints. Both are covered by integration checks.
Adding an `artifact_id` field to the `autodl` record changed the record schema;
records created before that change are intentionally rejected as missing-field
errors, documented as a within-milestone schema migration.

## Environment limitation

A fresh `pixi install --frozen` into `/tmp/opencode/cleanhf3` failed with
`Quota exceeded (os error 122)`. The clean source tree was therefore built and
tested with `pixi run --manifest-path /home/jack/Projects/HyperForge/pixi.toml`
from the clean directory, which uses the already-installed pinned environment.
This is an environment limitation, not a reproducibility failure of the source.
