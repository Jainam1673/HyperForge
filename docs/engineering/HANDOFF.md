# Handoff

## Current state

- M00–M16 are VERIFIED. M16 commit/push is the remaining workflow action.
- Git remote: `https://github.com/Jainam1673/HyperForge.git`, branch `main`.
- GitHub MCP is working (`get_me`, `opencode mcp list`).
- Tests: `pixi run test` → 104 unit tests; integration totals
  24+17+21+14+17+20+17+15+13+17+14+16+16+9+12+11+15 = 268 checks. All pass.
- GPU catalogue has two correct kernels with reproducible benchmark evidence.

## What M16 added

```
src/hyperforge/gpu/catalogue.mojo
src/hyperforge/cli/gpu_cmd.mojo (catalogue + parameterized benchmark)
tests/test_m16.mojo
tests/integration_m16.sh
docs/engineering/GPU_CATALOGUE.md
src/main.mojo, args.mojo, help.mojo, version.mojo, pixi.toml (wiring)
evidence/journal.mojo, evidence/record.mojo (gpu_bench record type)
```

## Known limitations / blockers

- AutoLLM MAX inference is BLOCKED_BY_MAX_INTERFACE; AutoGenAI/SciLLM/SciGenAI
  not started.
- No application workload moved to GPU; requires profiling evidence first.
- Looper has no wall-clock timestamps and no parallel workers.
- SciDL MLP underperformed linear/FD baselines; recorded honestly.
- Adaptive search showed no advantage in M08/M10; joint coupling lost in M07.
- Memory is `NOT_TESTED` in reciprocal discovery.
- Atomic rename/truncate unavailable; journal recovery rewrites a validated
  prefix with a plain file write.

## Next exact actions

1. Commit and push M16 as its own milestone.
2. Re-read the three authoritative documents (required after each milestone).
3. Next: bounded RSI/evaluator hardening (protected baseline, isolated
   candidate workspace, independent verifier, immutable evidence) followed by
   system-wide hardening and release verification. Do not register commands
   without real execution paths.

## Resume commands

```bash
cd /home/jack/Projects/HyperForge
pixi run build
pixi run test
pixi run test-gpu-catalogue
```
