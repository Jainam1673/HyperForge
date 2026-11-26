# Handoff

## Current state

- M00 and M01 are VERIFIED and pushed. M01 commit:
  `fe06b843f203d29320b71c06a769146870cd817d`.
- Git remote: `https://github.com/Jainam1673/HyperForge.git`, branch `main`.
- GitHub MCP is working (`get_me`, `opencode mcp list`).
- Tests: `pixi run test` → 26 tests pass; `pixi run test-cli` → 24 pass;
  `pixi run test-experiment` → 17 pass. Clean-copy reproduction passes.

## What M01 added

```
src/hyperforge/core/hash.mojo
src/hyperforge/core/rng.mojo
src/hyperforge/core/state_machine.mojo
src/hyperforge/experiment/__init__.mojo
src/hyperforge/experiment/spec.mojo
src/hyperforge/evidence/__init__.mojo
src/hyperforge/evidence/record.mojo
src/hyperforge/evidence/journal.mojo
src/hyperforge/cli/experiment_cmd.mojo
src/main.mojo                  (experiment dispatch)
src/hyperforge/cli/args.mojo  (experiment grammar)
src/hyperforge/cli/help.mojo
src/hyperforge/core/version.mojo (M01 label)
tests/test_m01.mojo
tests/integration_m01.sh
pixi.toml                     (test tasks)
docs/engineering/*            (M01 evidence)
```

## Known limitations

- No `rename`/`truncate` in installed Mojo 1.2.0: journal recovery rewrites the
  validated prefix with a plain full-file write, not an atomic replacement.
- FNV-1a is an integrity check, not a security hash.
- `experiment replay` verifies inputs only; execution is M02.
- Candidate/metric/budget/acceptance structs are deferred until M02 needs them.

## Next exact actions

1. Re-read the three authoritative documents (required after each milestone).
2. Start M02: CSV loading, leakage-safe split, baseline plus at least two real
   regression models, metrics from predictions, durable trial records, and a
   report. Introduce candidate/metric/budget types when trials need them.

## Resume commands

```bash
cd /home/jack/Projects/HyperForge
pixi run build
pixi run test
pixi run test-cli
pixi run test-experiment
```
