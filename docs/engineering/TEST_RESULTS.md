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

## M09 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m09.mojo` | 5 tests pass |
| `pixi run test-autorl` | `autorl integration: 17 passed, 0 failed` |
| `autorl run 60 20` | Q-learning held-out return 5.0, random -19.46, DP optimum 5.0, improvement 24.46, five seeds |
| `autorl show/replay` | config verified, `REPLAY_READY` |
| learning curve artifact | 60 per-episode mean returns, -24.0 → 5.0 |

The first implementation called `step` on the goal state inside Q derivation;
fixed by assigning zero Q-values for terminal states. Seed arrays were comptime
and could not materialize at runtime; converted to runtime lists.

## M10 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m10.mojo` | 4 tests pass |
| `pixi run test-autotrans` | `autotrans integration: 14 passed, 0 failed` |
| `autotransformers run 3 42` | default 133 params 0.01605 test MSE 0.00064s; random 857 params 0.00216 MSE 0.00406s; adaptive default-like |

Defects found and fixed during M10: embedding, QKV, FFN, and output-head weights
were initially allocated per token instead of once per layer, causing parameter
index overflows; history gene was overridden by the task contract; task index
sets were derived from TaskSpec counts rather than nonexistent split fields.

## M11 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m11.mojo` | 4 tests pass |
| `pixi run test-autollm` | `autollm integration: 16 passed, 0 failed` |
| `autollm evaluate examples/autollm/prompts.txt examples/autollm/responses.txt` | 3 cases, 2 matched, 1 missing, accuracy 0.6667 |
| `autollm discover <synthetic artifact dir>` | 1 artifact, checksum, `license=DECLARED`, `BLOCKED_BY_MAX_INTERFACE` |
| `autollm status` with no artifacts | `UNAVAILABLE`, remedy printed |

A parser collision made `discover` ambiguous between the top-level command and
the `autollm` subcommand; command tokens are now accepted only when no command
is set. An integration expectation was corrected: missing input files return
exit 1 (operation failure), not exit 2 (usage). The artifact-discovery test was
not idempotent on a reused temp directory and is now guarded by existence
checks; the full 85-test suite passed after the fix.

## M12 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m12.mojo` | 4 tests pass |
| `pixi run test-sciml` | `sciml integration: 16 passed, 0 failed` |
| `sciml solve 42` | k=0.989, error 0.011, std 0.03698, inverse L2 0.000905 vs constant 0.044053 |

The finite-difference solver initially assumed the supplied points spanned the
whole domain; subset observation points truncated the boundary and biased the
inverse estimate to the search upper bound. Fixed by solving the full interior
grid then sampling observations. A missing `Path` import in M11's idempotency
edit was also found by the full suite and fixed. Full suite: 89 unit tests and
221 integration checks pass.

## M13 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m13.mojo` | 4 tests pass |
| `pixi run test-scidl` | `scidl integration: 9 passed, 0 failed` |
| `scidl run 42` | train RMSE 0.02322; held-out MLP RMSE 0.08675; linear 7.42e-18; FD 0.00398 |

A test assumed `u(0.5;1)=0.25`; the analytic value is `1/pi^2`, and the test was
corrected. Full suite: 93 unit tests and 230 integration checks pass.

## M14 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m14.mojo` | 4 tests pass |
| `pixi run test-scirl` | `scirl integration: 12 passed, 0 failed` |
| `scirl run 40 10` | learned -0.01421, random -0.02233, heuristic -0.02114 |

Two simulator defects were found: `m=6` aliased to zero forcing on the `n=2`
mesh, and training originally covered only the smooth frequency band while
held-out conditions covered only the high band, leaving one set of Q-states
untrained. Both were fixed and are covered by tests. Full suite: 97 unit tests
and 242 integration checks pass.

## M15 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m15.mojo` | 4 tests pass |
| `pixi run test-looper` | `looper integration: 11 passed, 0 failed` |
| `looper run linear-beats-mean 4` | baseline 4.841229, candidate 9.97e-05, ACCEPTED, 10 events |

The idempotency check initially ran after transition validation, so replaying an
already-applied state was rejected; it now runs first and compares the last
event's target state. Full suite: 101 unit tests and 253 integration checks pass.

## M16 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m16.mojo` | 3 tests pass |
| `pixi run test-gpu-catalogue` | `gpu catalogue integration: 15 passed, 0 failed` |
| `benchmark kernel vector_add 255 3` | zero error, kernel median ~7.1e-6 s, state PASS |
| `benchmark kernel vector_axpy 1024 3` | zero error, kernel median ~8.9e-6 s, state PASS |

The earlier GPU integration script depended on the old single-kernel text
format; it was updated to the catalogue dispatch and report naming. Full suite:
104 unit tests and 268 integration checks pass.

## M17 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m17.mojo` | 4 tests pass |
| `pixi run test-systems` | `systems integration: 11 passed, 0 failed` |
| `systems search 3 42` | fixed 1.11e-5s, random 7.54e-6s, adaptive 7.58e-6s kernel medians |

Full suite: 108 unit tests and 279 integration checks pass. Objective handling
uses two measured latency values rather than a weighted score; no causal claim
is made at this stage.

## M18 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m18.mojo` | 3 tests pass |
| `pixi run test-meta` | `meta integration: 14 passed, 0 failed` |
| `meta run 4 42` | fixed 0.03592, random 0.01796, adaptive 0.07183, ai_only 0.07183 total gain |

A replay assertion initially compared total gains from GPU-timing-inclusive
runs and failed due to timing variance; it now compares deterministic AI-only
runs. A `meta graph` expectation was corrected to check the graph's own
honesty note. Full suite: 111 unit tests and 293 integration checks pass.

## M19 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m19.mojo` | 5 tests pass |
| `pixi run test-joint` | `joint integration: 21 passed, 0 failed` |
| `joint run 6 42 7 123` | joint led mean discoveries (4.00) vs fixed 2.00 and ablations 2.67–3.67 |

Three defects were found and fixed during development: raw RMSE/latency gain
comparison funneled all budget to one side (now normalized relative gains with
an exploration floor); repeated identical configurations counted latency noise
as discoveries (now gated by genome ID); and an unused loop index warning.
Full suite: 116 unit tests and 314 integration checks pass.

## M20 results

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m20.mojo` | 4 tests pass |
| `pixi run test-rsi` | `rsi integration: 25 passed, 0 failed` |
| `rsi run 12` | 0 accepted, 8 rejected, 4 deferred, AWAITING_AUTHORIZATION |
| `rsi run 12 --apply` | 4 accepted, 8 rejected, 0 deferred, ACCEPTED |

Two defects were found and fixed during development: the protected protocol
record lacked the `canonical` field needed for re-read (breaking the second
run), and RSI journal kinds were unregistered in journal validation. Both were
corrected and the full 120-unit/339-integration suite passes.

## M21 final verification

| Command | Outcome |
|---|---|
| `pixi run bash scripts/mojo.sh run -I src tests/test_m21.mojo` | 3 tests pass |
| `pixi run test-hardening` | `hardening integration: 9 passed, 0 failed` |
| `pixi run build` | clean build |
| all 22 `test-*` integration tasks | 348 checks pass |
| `pixi run test` | 123 unit tests pass, exit 0 |

One defect was found and fixed: byte comparison used an integer literal against
Mojo's byte-as-StringSpan indexing; the check now compares String values.
Full verification is recorded in `RELEASE.md`.

## Environment limitation

A fresh `pixi install --frozen` into `/tmp/opencode/cleanhf3` failed with
`Quota exceeded (os error 122)`. The clean source tree was therefore built and
tested with `pixi run --manifest-path /home/jack/Projects/HyperForge/pixi.toml`
from the clean directory, which uses the already-installed pinned environment.
This is an environment limitation, not a reproducibility failure of the source.
