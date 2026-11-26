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

## Environment limitation

A fresh `pixi install --frozen` into `/tmp/opencode/cleanhf3` failed with
`Quota exceeded (os error 122)`. The clean source tree was therefore built and
tested with `pixi run --manifest-path /home/jack/Projects/HyperForge/pixi.toml`
from the clean directory, which uses the already-installed pinned environment.
This is an environment limitation, not a reproducibility failure of the source.
