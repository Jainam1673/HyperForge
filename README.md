# HyperForge

A native Mojo, CLI-first research and discovery engine. The initial release is
a command-line application only: no frontend, server, database, or Python
application logic. MAX is a platform dependency used only where its documented
interfaces are needed; it is not required for the core CLI.

Current milestone: **M21 — system hardening and release verification**.
M00–M20 (CLI, evidence, regression AutoML, adaptive optimization, SINN,
SciTransformers, reciprocal discovery, AutoDL, AutoRL, AutoTransformers, AutoLLM
substrate, SciML, SciDL, SciRL, Scientific Looper, GPU catalogue, DiscoveryGenome
v2, meta economy and causal graph, joint AI×compute benchmark, bounded RSI) are
complete. M21 adds centralized path/CSV input limits, a doctor hardening probe,
and the authoritative capability matrix and release notes. Local MAX inference
remains `BLOCKED_BY_MAX_INTERFACE` rather than faked.

## Requirements

- pixi (tested with 0.85.0)
- A C linker (`gcc` on Linux)
- Mojo 1.2.0 and MAX 26.7.0, resolved from the pinned `pixi.toml`/`pixi.lock`

## Setup, build, test

```bash
pixi install
pixi run build       # produces ./hyperforge
pixi run test             # 123 unit tests
pixi run test-cli         # build + 24 CLI integration checks
pixi run test-experiment  # 17 experiment/journal checks
pixi run test-automl      # 21 AutoML integration checks
pixi run test-optimize    # 14 adaptive optimization checks
pixi run test-sinn        # 17 SINN / PDE checks
pixi run test-scit        # 20 SciTransformers checks
pixi run test-gpu         # 17 GPU kernel / benchmark checks
pixi run test-discover    # 15 reciprocal discovery checks
pixi run test-autodl      # 13 AutoDL checks
pixi run test-autorl      # 17 AutoRL checks
pixi run test-autotrans   # 14 AutoTransformers checks
pixi run test-autollm     # 16 AutoLLM substrate checks
pixi run test-sciml       # 16 SciML checks
pixi run test-scidl       # 9 SciDL checks
pixi run test-scirl       # 12 SciRL checks
pixi run test-looper      # 11 Scientific Looper checks
pixi run test-gpu-catalogue # 15 GPU catalogue checks
pixi run test-systems     # 11 systems-search checks
pixi run test-meta        # 14 meta-economy checks
pixi run test-joint       # 21 joint-benchmark checks
pixi run test-rsi         # 25 bounded-RSI checks
pixi run test-hardening   # 9 hardening checks
```

On pre-Turing NVIDIA devices, source `scripts/gpu-env.sh` before invoking GPU
commands directly so a compatible `ptxas` is selected. All pixi tasks use
`scripts/mojo.sh`, which does this automatically. See
`docs/engineering/GPU_BENCHMARK.md` for the measured protocol and limitations.

## Implemented commands

```bash
./hyperforge --help
./hyperforge --version
./hyperforge doctor [--json]
./hyperforge init <path>
./hyperforge experiment create <name> [seed]
./hyperforge experiment list [--json]
./hyperforge experiment show <id> [--json]
./hyperforge experiment replay <id>
./hyperforge automl inspect <data.csv> <target>
./hyperforge automl run <data.csv> <target> [budget] [seed]
./hyperforge automl show <id>
./hyperforge automl replay <id>
./hyperforge automl compare <id-a> <id-b>
./hyperforge report <id>
./hyperforge optimize run <data.csv> <target> [budget] [seed]
./hyperforge sinn list-problems
./hyperforge sinn solve poisson_1d [seed] [iterations]
./hyperforge sinn show <experiment-id>
./hyperforge sci-transformers train [seed] [epochs]
./hyperforge sci-transformers show <experiment-id>
./hyperforge sci-transformers predict <experiment-id> [sample]
./hyperforge hardware probe
./hyperforge benchmark kernel
./hyperforge discover run [budget] [seed]
./hyperforge autodl run [budget] [seed]
./hyperforge autodl show <id>
./hyperforge autodl replay <id>
./hyperforge autorl list-envs
./hyperforge autorl run [episodes] [eval-episodes]
./hyperforge autorl show <id>
./hyperforge autorl replay <id>
./hyperforge autotransformers run [budget] [seed]
./hyperforge autotransformers show <policy>
./hyperforge autotransformers replay <policy>
./hyperforge autollm discover [dir]
./hyperforge autollm evaluate <suite> <responses>
./hyperforge autollm status
./hyperforge sciml list-problems
./hyperforge sciml solve [seed]
./hyperforge sciml show <id>
./hyperforge scidl run [seed]
./hyperforge scidl show <id>
./hyperforge scirl run [episodes] [eval-episodes]
./hyperforge scirl show <id>
./hyperforge looper run <hypothesis> [budget]
./hyperforge looper show <run-id>
./hyperforge hardware catalogue
./hyperforge benchmark kernel [name] [size] [repetitions]
./hyperforge systems search [budget] [seed]
./hyperforge systems show
./hyperforge meta run [budget] [seed]
./hyperforge meta graph
./hyperforge joint run [budget] [seed...]
./hyperforge joint show
./hyperforge rsi run [trials] [--apply]
./hyperforge rsi show
./hyperforge rsi rollback [--apply]
```

`doctor` reports toolchain pin, MAX CLI, accelerator visibility, workspace
write access, and model-artifact probing status separately. Unavailable or
untested capabilities are reported honestly and do not block CPU-only use.
`init` creates a versioned workspace with `hyperforge.toml`, `experiments/`,
`artifacts/`, and `logs/`. Experiment commands operate on the workspace in the
current directory. Records are stored in a versioned append-only `HFJ1` journal
with checksums and tail recovery. `experiment replay` only verifies recorded
inputs; it does not execute an experiment.

Exit codes and machine-readable output are specified in
`docs/engineering/CLI_SPEC.md`.

## Example

`examples/regression_linear.csv` is a synthetic fixture with
`y = 2*x1 - 3*x2 + 5`. From a fresh workspace:

```bash
./hyperforge init ./workspace
cd ./workspace
../hyperforge automl run ../examples/regression_linear.csv y 5 42
../hyperforge automl show <experiment-id>
../hyperforge report <experiment-id>
../hyperforge automl replay <experiment-id>
```

## Scope and limitations

- AutoML is a regression-only, deterministic random-search slice on numeric
  CSV. No SINN, transformer, benchmark, or discovery command exists yet;
  `--help` labels them as planned.
- Journal recovery rewrites a validated prefix with a plain file write because
  installed Mojo 1.2.0 has no atomic rename; FNV-1a is an integrity check, not
  a security hash.
- No model is executed and no GPU kernel is compiled by M00.
- The pinned Mojo 1.2.0 differs from the newest skills in a few syntax points;
  observed deltas are recorded in `docs/engineering/DECISIONS.md`.

## Documentation

- `docs/INDEX.md` — documentation index
- `AGENTS.md` — durable agent contract
- `docs/HYPERFORGE_MOJO_MAX_MASTER_BUILD_PROMPT.md` — authoritative build directive
- `docs/MOJO_MAX_BOOTSTRAP_BLUEPRINT.md` — architecture blueprint
- `docs/engineering/CAPABILITY_MATRIX.md` — authoritative status of every capability
- `docs/engineering/RELEASE.md` — pinned toolchain, reproduction, licensing, limits
- `docs/engineering/` — observed environment, state, decisions, tests, and handoff
