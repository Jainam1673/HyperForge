# Handoff

## Current state

- M00–M18 are VERIFIED and pushed. M18 commit:
  `8b2b6089591dff85364c73b67b366d657dc93b51`.
- Git remote: `https://github.com/Jainam1673/HyperForge.git`, branch `main`.
- GitHub MCP is working (`get_me`, `opencode mcp list`).
- Tests: `pixi run test` → 111 unit tests; integration totals
  24+17+21+14+17+20+17+15+13+17+14+16+16+9+12+11+15+11+14 = 293 checks. All pass.
- Meta economy compared four policies; causal graph labels kept conservative.

## What M18 added

```
src/hyperforge/meta/{__init__,causal,economy}.mojo
src/hyperforge/cli/meta_cmd.mojo
tests/test_m18.mojo
tests/integration_m18.sh
docs/engineering/META_ECONOMY.md
src/main.mojo, args.mojo, help.mojo, version.mojo, pixi.toml (wiring)
evidence/journal.mojo, evidence/record.mojo (meta_economy, causal_edge)
```

## Known limitations / blockers

- AutoLLM MAX inference is BLOCKED_BY_MAX_INTERFACE; AutoGenAI/SciLLM/SciGenAI
  not started.
- Multi-fidelity ordering and formal confidence intervals are deferred.
- Coupling edge remains hypothesized; no causal claim from shared history.
- No application kernel moved to GPU; no MAX model inference adapter.
- Looper has no wall-clock timestamps and no parallel workers.
- Memory is `NOT_TESTED` in reciprocal discovery.
- Atomic rename/truncate unavailable; journal recovery rewrites a validated
  prefix with a plain file write.

## Next exact actions

1. Re-read the three authoritative documents (required after each milestone).
2. Next: M19 joint AI×compute discovery benchmark with equal budgets, ablations
   (shared history, adaptive budgeting, meta-policy), repeated seeds, and
   negative results. Then M20 bounded RSI and M21 final verification.

## Resume commands

```bash
cd /home/jack/Projects/HyperForge
pixi run build
pixi run test
pixi run test-meta
```
