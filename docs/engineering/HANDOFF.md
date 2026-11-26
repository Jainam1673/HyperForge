# Handoff

## Current state

- M00–M03 are VERIFIED and pushed. M04 (SINN) implementation and evidence are
  VERIFIED; commit/push is the remaining workflow action.
- Git remote: `https://github.com/Jainam1673/HyperForge.git`, branch `main`.
- GitHub MCP is working (`get_me`, `opencode mcp list`).
- Tests: `pixi run test` → 49 unit tests; integration totals 24+17+21+14+17 = 93 checks.
- Numbering: master prompt calls SINN M03; this chronological ledger calls it M04
  because repository M03 was adaptive optimization. This is recorded in MILESTONES.md.

## What M04 added

```
src/hyperforge/sinn/{__init__,jet,network,problem,solver}.mojo
src/hyperforge/cli/sinn_cmd.mojo
tests/test_m04.mojo
tests/integration_m04.sh
docs/engineering/SCIENTIFIC_VALIDATION.md
src/main.mojo, args.mojo, help.mojo, version.mojo, pixi.toml (wiring)
evidence/journal.mojo, evidence/record.mojo (scientific record type)
```

## Known limitations

- One analytic Poisson problem, fixed 4-unit network, no adaptive collocation,
  no uncertainty quantification, no GPU execution, no second benchmark.
- Adaptive search (M03) lost to random search on the small fixture; negative
  result retained.
- No multi-fidelity racing, classification, CV, trees, ensembles.
- Atomic rename/truncate unavailable; journal recovery rewrites a validated
  prefix with a plain file write. FNV-1a is integrity, not authenticity.

## Next exact actions

1. Commit and push M04 as its own milestone.
2. Re-read the three authoritative documents (required after each milestone).
3. Start SciTransformers (master prompt M04): a deterministic, locally specified
   scientific sequence/field task with a reference solution, real train/evaluate/
   predict, masked attention with numerical tests, held-out generalization, and
   at least two non-transformer baselines. Do not claim a foundation model or
   FlashAttention. Close M04 evidence/replay gaps from AGENTS.md along the way.

## Resume commands

```bash
cd /home/jack/Projects/HyperForge
pixi run build
pixi run test
pixi run test-cli
pixi run test-experiment
pixi run test-automl
pixi run test-optimize
pixi run test-sinn
```
