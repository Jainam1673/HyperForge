# HyperForge

> A single, native Mojo CLI for reproducible AutoML, scientific discovery, and
> **bounded reciprocal search** — no frontend, no server, no database, and no
> Python application code.

**Status:** roadmap M00–M21 complete; M22 AutoML, M23 AutoLLM, M24 MAX readiness, M25 full AutoDL, M26 full AutoRL monoliths complete · Mojo `1.2.0` · MAX `26.7.0` ·
`139` unit tests · `446` integration checks · CLI-only · offline core

---

## Why HyperForge

Most AutoML and "self-improving" demos are notebooks with hard-coded numbers.
HyperForge is built on the opposite rule: **every reported improvement is a
measured result from a real execution, stored with its inputs, checksums, and
baseline.** The long-term thesis is *Reciprocal Meta-Discovery* — AI discovers
better AI, computing systems discover better computing systems, and a third
loop learns which experiments are worth running. This repository implements the
control structure and evidence ledger for that thesis, one verified slice at a
time.

Three properties make it unusual:

- **Native and deterministic.** First-party logic is `.mojo` only. Runs are
  seeded, replayable, and persist to a versioned local journal.
- **Evidence over narrative.** Candidates are evaluated against explicit
  baselines and held-out data. Negative results are kept, not hidden.
- **Guarded self-improvement.** The RSI loop can only propose configuration
  values; it cannot rewrite its evaluator, run generated code, or accept a
  change without explicit authorization.

## What it is not

- Not a web app, dashboard, REST API, or database service.
- Not a Python application, even though some upstream MAX tooling uses Python.
- Not a claim of local MAX model inference — that boundary is currently
  `BLOCKED_BY_MAX_INTERFACE` and is reported as such by `hyperforge autollm status`.
- Not a benchmark suite with fabricated numbers: GPU timings come from compiled
  kernels on detected hardware, with warm-up and repeated measurements.

---

## Quick start

From a clean checkout:

```bash
pixi install
pixi run build                       # produces ./hyperforge
./hyperforge doctor                  # see what this machine can actually do
./hyperforge init ./workspace
cd ./workspace
../hyperforge automl run ../examples/regression_linear.csv y 4 42
```

The fixture is synthetic and linear: `y = 2*x1 - 3*x2 + 5`. A real run looks
like this:

```text
experiment: exp-b6fd492fc432a53e
best:       linear_gd (cand-9f9fb9862f185705)
validation: rmse=3.1452039735002787e-08
test:       rmse=2.2272160351028695e-08 mae=1.9664427715800532e-08 r2=1.0
```

Inspect and verify it:

```bash
../hyperforge automl show exp-b6fd492fc432a53e   # trial-by-trial evidence
../hyperforge report exp-b6fd492fc432a53e        # terminal report
../hyperforge automl replay exp-b6fd492fc432a53e # recompute a recorded result
../hyperforge experiment replay exp-b6fd492fc432a53e # verify inputs only
```

Candidate selection uses validation only; the test split is evaluated once at
the end.

---

## Guided workflows

### 1. Native AutoML regression

Load a numeric CSV, run a baseline plus two or more real candidates, and
persist every trial.

```bash
./hyperforge automl inspect examples/regression_linear.csv y
./hyperforge automl run examples/regression_linear.csv y 8 42
./hyperforge automl compare <exp-a> <exp-b>
```

Models are genuinely trained in Mojo (mean baseline, linear GD, ridge GD, kNN);
metrics come from predictions, never literals.

### 2. Adaptive optimization with a fair baseline

```bash
./hyperforge optimize run examples/regression_linear.csv y 8 42
```

The adaptive policy proposes, measures, persists, and feeds results back into
the next proposal. It is compared against a matched-budget random search. A
regression test fails if the feedback loop is disconnected.

### 3. Reciprocal discovery

```bash
./hyperforge discover run 8 42          # AI × compute search comparison
./hyperforge systems search 4 42        # measured GPU launch configurations
./hyperforge meta run 4 42              # matched-budget allocation policies
./hyperforge meta graph                 # causal evidence edges
```

`systems search` and `meta` require an accelerator. The causal graph labels
relations `observed`, `experimentally_supported`, or `hypothesized`; shared
history alone never becomes a causal claim.

### 4. Joint AI×compute benchmark

```bash
./hyperforge joint run 6 42 7 123       # nine policies, three seeds
./hyperforge joint show
```

Compares fixed, AI-only, compute-only, independent, sequential, joint, and
three ablations under the same budget. In the documented fixture joint led mean
discoveries — reported as a small-fixture observation, not a general law.

### 5. Bounded, config-only RSI

```bash
./hyperforge rsi run 12                 # report-only: passing candidates deferred
./hyperforge rsi show
./hyperforge rsi run 12 --apply         # explicit authorization required to accept
./hyperforge rsi rollback --apply       # recover to the protected baseline
```

Candidates are config values only. The baseline and evaluator protocol are
write-once, checksummed records with no candidate-facing mutation path; a
protected holdout and an independent verifier gate every acceptance.

### 6. AutoLLM end-to-end lifecycle

```bash
./hyperforge autollm pretrain examples/autollm/corpus_pre.txt 6
./hyperforge autollm midtrain examples/autollm/corpus_mid.txt 6
./hyperforge autollm posttrain examples/autollm/pairs.tsv 6
./hyperforge autollm infer "the " 8 1.0
./hyperforge autollm status
./hyperforge serve status
```

A tiny first-party byte-level model is genuinely trained with reverse-mode
gradients at each stage. Every stage writes a checksummed checkpoint and a
lineage record; inference names the exact checkpoint chain that produced the
response. This is **not** MAX model inference — that boundary stays
`BLOCKED_BY_MAX_INTERFACE` and is reported separately.

---

## Command reference

Run `./hyperforge --help` for the authoritative command list; subcommands with
optional arguments document their usage in the error message.

| Family | Commands | Purpose |
|---|---|---|
| Diagnostics | `doctor [--json] [--gpu]`, `hardware probe\|catalogue`, `benchmark kernel` | Report capabilities, detect devices, benchmark GPU kernels |
| Workspace | `init <path>`, `experiment create\|list\|show\|replay`, `report <id>` | Create and inspect versioned local records |
| AutoML | `automl full\|inspect\|run\|show\|replay\|compare` | 18 algorithms, regression + classification, k-fold CV |
| Optimization | `optimize run` | Adaptive search vs matched random baseline |
| Scientific ML | `sinn list-problems\|solve\|show`, `sci-transformers train\|show\|predict`, `sciml list-problems\|solve\|show`, `scidl run\|show`, `scirl run\|show` | PDE, sequence, field, and simulated-control experiments |
| AutoAI slices | `autodl run\|show\|replay`, `autorl list-envs\|run\|show\|replay`, `autotransformers run\|show\|replay`, `autollm pretrain\|midtrain\|posttrain\|infer\|discover\|evaluate\|status` | Architecture, RL, transformer, and full first-party LLM lifecycle |
| Discovery loops | `discover run`, `systems search\|show`, `meta run\|graph`, `joint run\|show` | Fixed/independent/sequential/joint search, economy, causal evidence |
| Self-improvement | `rsi run\|show\|rollback` | Guarded config-only propose-evaluate-accept loop |
| Scientific Looper | `looper run\|show` | Validated experiment-loop transitions |

Exit codes: `0` success · `1` failure · `2` usage · `3` unavailable ·
`70` internal · `130` interrupted. Machine-readable output is available where
documented in `docs/engineering/CLI_SPEC.md`.

---

## Architecture

```text
hyperforge (native Mojo executable)
├── src/main.mojo + cli/          argument parsing, dispatch, help, exit codes
├── core/                         version, hashes, RNG, numeric primitives
├── experiment/ + automl/         spec → candidate → trial → metrics
├── evidence/                     versioned HFJ1 journal and record validation
├── optimization/ + autodiff/     adaptive search and gradient tape
├── discovery/ + meta/ + joint/   genome v2, allocation policy, joint benchmark
├── rsi/                          protected baseline/protocol, config-only loop
├── gpu/ + looper/                compiled kernels; validated experiment loop
└── sinn/, scit/, sciml/, scidl/, scirl/, autodl/, autorl/, autotrans/, autollm/
                                  scientific and AutoAI capability slices
```

**Workspace layout** after `init`:

```text
workspace/
├── hyperforge.toml        versioned configuration
├── experiments/hf-journal.hfj
├── artifacts/             large outputs referenced by relative path + checksum
└── logs/
```

**Evidence format.** Records use one versioned line format:
`HFJ1|<seq>|<type>|<checksum>|<payload>`. Payloads use unambiguous escaping;
the checksum is FNV-1a over `seq|type|payload`. A corrupt or truncated tail is
recovered as a validated prefix; corruption in the middle fails loudly.
Large artifacts stay out of the journal and are referenced by path and hash.

**Three loops, one ledger.** AI-side choices, systems-side choices, and the
meta-policy all write into the same evidence model. Coupling is only credited
when ablations isolate it — never because two records share a workspace.

See [`docs/engineering/ARCHITECTURE.md`](docs/engineering/ARCHITECTURE.md) for
the implemented module map and invariants, and
`docs/MOJO_MAX_BOOTSTRAP_BLUEPRINT.md` for the original design intent.

---

## Status and honesty

The authoritative, always-current status of every capability keyword is in
[`docs/engineering/CAPABILITY_MATRIX.md`](docs/engineering/CAPABILITY_MATRIX.md).
In short:

- **Complete:** CLI/evidence, full AutoML (M22), full AutoLLM lifecycle (M23), MAX readiness (M24), full AutoDL (M25), full AutoRL (M26), adaptive optimization, SINN,
  SciTransformers, reciprocal discovery proof, AutoDL, AutoRL,
  AutoTransformers, SciML, SciDL, SciRL, Scientific Looper, GPU kernel
  catalogue, bounded RSI.
- **Partial with explicit boundaries:** AutoLLM offline substrate,
  DiscoveryGenome v2 (AI gene carried, not measured), meta causal graph
  (coupling still hypothesized), joint benchmark (small fixture), RSI
  (config-only, no runtime consumer).
- **Blocked / not registered:** local MAX model inference, AutoGenAI, SciLLM,
  SciGenAI. No command exists for a capability that has no execution path.
- **Planned:** world models, broad HPC/HyperComputers, application-kernel
  migration to GPU.

Negative results are deliberately retained: adaptive search did not beat random
search in one fixture, joint reciprocal search lost in the original discovery
proof, and the SciDL MLP underperformed linear/FD baselines.

---

## Verification

```bash
pixi run build                 # native Mojo build
pixi run test                  # 139 unit tests
pixi run test-cli              # 24 checks
pixi run test-experiment       # 17 checks
pixi run test-automl           # 21 checks
pixi run test-optimize         # 14 checks
pixi run test-sinn             # 17 checks
pixi run test-scit             # 20 checks
pixi run test-gpu              # 17 checks
pixi run test-discover         # 15 checks
pixi run test-autodl           # 13 checks
pixi run test-autorl           # 17 checks
pixi run test-autotrans        # 14 checks
pixi run test-autollm          # 16 checks
pixi run test-autollm-lifecycle # 30 full-AutoLLM checks
pixi run test-serve            # 13 MAX-readiness checks
pixi run test-autodl-full      # 17 full-AutoDL checks
pixi run test-autorl-full      # 21 full-AutoRL checks
pixi run test-sciml            # 16 checks
pixi run test-scidl            # 9 checks
pixi run test-scirl            # 12 checks
pixi run test-looper           # 11 checks
pixi run test-gpu-catalogue    # 15 checks
pixi run test-systems          # 11 checks
pixi run test-meta             # 14 checks
pixi run test-joint            # 21 checks
pixi run test-rsi              # 25 checks
pixi run test-hardening        # 9 checks
pixi run test-automl-full      # 17 full-AutoML checks
```

**GPU note.** On pre-Turing NVIDIA devices (e.g. MX230 / `sm_61`), the bundled
CUDA 13 `ptxas` rejects the target. Source `scripts/gpu-env.sh` before invoking
GPU commands directly; all pixi tasks already do this through
`scripts/mojo.sh`. GPU claims are always accompanied by device, driver, kernel,
shape, precision, warm-up, repetition count, and aggregation details in
`docs/engineering/GPU_CATALOGUE.md`.

Core CPU paths need no network, account, model download, or external service.

---

## Known limitations

- Installed Mojo `1.2.0` has no verified atomic rename/truncate: journal
  recovery rewrites a validated prefix with a plain file write. No transaction
  is claimed. FNV-1a is an integrity check, not a security hash.
- Ctrl-C interception is not implemented; interrupted runs are not
  automatically marked. Failures and partial state are preserved, never
  promoted to success.
- No verified wall-clock timestamp or memory API is available; some loops use
  monotonic sequences, and memory is reported `NOT_TESTED` where relevant.
- MAX model inference is unavailable in this environment. It is reported, not
  faked or hidden behind a mock command.
- `experiment replay` verifies recorded inputs; it does not re-execute an
  experiment. `automl replay` recomputes and checks a recorded result.
- Input hardening rejects empty, over-long, NUL-bearing, and `..`-traversing
  paths, and caps CSVs at 16 MiB / 100000 rows / 256 columns. It does not
  resolve symlinks.

---

## Documentation

| Document | What it answers |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Durable agent contract and non-negotiables |
| [`docs/INDEX.md`](docs/INDEX.md) | Documentation index |
| [`docs/HYPERFORGE_MOJO_MAX_MASTER_BUILD_PROMPT.md`](docs/HYPERFORGE_MOJO_MAX_MASTER_BUILD_PROMPT.md) | Authoritative build directive M00–M21 |
| [`docs/MOJO_MAX_BOOTSTRAP_BLUEPRINT.md`](docs/MOJO_MAX_BOOTSTRAP_BLUEPRINT.md) | Architecture blueprint |
| [`docs/engineering/AUTOML_FULL.md`](docs/engineering/AUTOML_FULL.md) | Complete AutoML inventory and results |
| [`docs/engineering/MAX_READINESS.md`](docs/engineering/MAX_READINESS.md) | Honest MAX adapter and portability matrix |
| [`docs/engineering/OWNER_SCOPE.md`](docs/engineering/OWNER_SCOPE.md) | Full-breadth directive and honest constraints |
| [`docs/engineering/AUTOLLM_LIFECYCLE.md`](docs/engineering/AUTOLLM_LIFECYCLE.md) | Full first-party LLM lifecycle and MAX boundary |
| [`docs/engineering/ARCHITECTURE.md`](docs/engineering/ARCHITECTURE.md) | Implemented module map and invariants |
| [`docs/engineering/EXPANSION_ROADMAP.md`](docs/engineering/EXPANSION_ROADMAP.md) | Post-M21 scope: broader algorithms, full AutoLLM lifecycle, interconnection |
| [`docs/engineering/TECH_INVENTORY.md`](docs/engineering/TECH_INVENTORY.md) | Every tech name, its full scope, status, and boundary |
| [`docs/engineering/CAPABILITY_MATRIX.md`](docs/engineering/CAPABILITY_MATRIX.md) | Verified status of every capability |
| [`docs/engineering/RELEASE.md`](docs/engineering/RELEASE.md) | Pins, reproduction, licensing, reliability posture |
| [`docs/engineering/TEST_RESULTS.md`](docs/engineering/TEST_RESULTS.md) | Exact commands, outcomes, and fixes |
| [`docs/engineering/DECISIONS.md`](docs/engineering/DECISIONS.md) | Why each dependency/scope decision was made |
| [`docs/engineering/HANDOFF.md`](docs/engineering/HANDOFF.md) | Current state, blockers, and exact next action |
| [`docs/engineering/CLI_SPEC.md`](docs/engineering/CLI_SPEC.md) | Full CLI contract and exit codes |

Project source is Mojo; dependencies are the pinned Mojo/MAX toolchain. MAX
components are governed by Modular's license terms. The bundled dataset is a
project-owned synthetic fixture; no third-party model artifacts are downloaded.
