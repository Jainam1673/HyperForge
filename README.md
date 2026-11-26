# HyperForge

A native Mojo, CLI-first research and discovery engine. The initial release is
a command-line application only: no frontend, server, database, or Python
application logic. MAX is a platform dependency used only where its documented
interfaces are needed; it is not required for the core CLI.

Current milestone: **M01 — core experiment and evidence substrate**.
M00 (toolchain and CLI shell) is complete. Nothing beyond the commands listed
below is implemented; experiment execution is not yet implemented.

## Requirements

- pixi (tested with 0.85.0)
- A C linker (`gcc` on Linux)
- Mojo 1.2.0 and MAX 26.7.0, resolved from the pinned `pixi.toml`/`pixi.lock`

## Setup, build, test

```bash
pixi install
pixi run build       # produces ./hyperforge
pixi run test             # 26 unit tests
pixi run test-cli         # build + 24 CLI integration checks
pixi run test-experiment  # 17 experiment/journal checks
```

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

## Scope and limitations

- No AutoML, SINN, transformer, benchmark, or discovery command exists yet;
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
- `docs/engineering/` — observed environment, state, decisions, tests, and handoff
