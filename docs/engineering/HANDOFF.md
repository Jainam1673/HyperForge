# Handoff

## Current state

- M00–M17 are VERIFIED and pushed. M17 commit:
  `b4ee584726901c312c19be58a4a475a743b8ca85`.
- Git remote: `https://github.com/Jainam1673/HyperForge.git`, branch `main`.
- GitHub MCP is working (`get_me`, `opencode mcp list`).
- Tests: `pixi run test` → 108 unit tests; integration totals
  24+17+21+14+17+20+17+15+13+17+14+16+16+9+12+11+15+11 = 279 checks. All pass.
- Systems search measured real launch configurations with Pareto handling.

## What M17 added

```
src/hyperforge/discovery/{genome_v2,systems_search}.mojo
src/hyperforge/cli/systems_cmd.mojo
tests/test_m17.mojo
tests/integration_m17.sh
docs/engineering/SYSTEMS_SEARCH.md
src/main.mojo, args.mojo, help.mojo, version.mojo, pixi.toml (wiring)
evidence/journal.mojo, evidence/record.mojo (systems_trial record type)
src/hyperforge/gpu/kernels.mojo (runtime block launch helper)
```

## Known limitations / blockers

- AutoLLM MAX inference is BLOCKED_BY_MAX_INTERFACE; AutoGenAI/SciLLM/SciGenAI
  not started.
- No application kernel moved to GPU; no MAX model inference adapter.
- Genome v2 AI gene is carried, not measured in systems search.
- Causal evidence graph and adaptive experiment economy are deferred to M18.
- Looper has no wall-clock timestamps and no parallel workers.
- Memory is `NOT_TESTED` in reciprocal discovery.
- Atomic rename/truncate unavailable; journal recovery rewrites a validated
  prefix with a plain file write.

## Next exact actions

1. Re-read the three authoritative documents (required after each milestone).
2. Next: M18 meta-discovery experiment economy with a typed causal evidence
   graph (observed/hypothesized/supported labels, ablations before causal
   claims), then M19 joint AI×compute benchmark and M20 bounded RSI.

## Resume commands

```bash
cd /home/jack/Projects/HyperForge
pixi run build
pixi run test
pixi run test-systems
```
