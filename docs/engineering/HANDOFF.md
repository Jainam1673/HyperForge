# Handoff

## Current state

- M00–M06 are VERIFIED and pushed. M06 commit:
  `1e27e4333411f95b2b68315df21be2adcd325c52`.
- Git remote: `https://github.com/Jainam1673/HyperForge.git`, branch `main`.
- GitHub MCP is working (`get_me`, `opencode mcp list`).
- Tests: `pixi run test` → 62 unit tests; integration totals
  24+17+21+14+17+20+17 = 130 checks. All pass.
- GPU: MX230 sm_61 works via external CUDA 12 ptxas selected by
  `scripts/gpu-env.sh`; without it, GPU commands report BLOCKED and CPU core is
  unaffected.

## What M06 added

```
src/hyperforge/gpu/{__init__,kernels}.mojo
src/hyperforge/cli/gpu_cmd.mojo
tests/test_m06.mojo
tests/integration_m06.sh
scripts/gpu-env.sh
scripts/mojo.sh (all build/test tasks now use it)
docs/engineering/GPU_BENCHMARK.md
src/main.mojo, args.mojo, help.mojo, version.mojo, pixi.toml (wiring)
```

## Known limitations

- No useful application kernel was moved to GPU; that requires profiling.
- MAX model serving remains optional and untested.
- Pascal compatibility depends on a locally cached CUDA 12 ptxas.
- Adaptive search (M03) lost to random search; linear baseline beat the
  transformer on the synthetic task. Both negative results are retained.
- Atomic rename/truncate unavailable; journal recovery rewrites a validated
  prefix with a plain file write. FNV-1a is integrity, not authenticity.

## Next exact actions

1. Re-read the three authoritative documents (required after each milestone).
2. Next capability: Reciprocal Meta-Discovery proof. Define a `DiscoveryGenome`
   with one AI choice and one compute/runtime choice; compare fixed,
   independent, sequential, and joint search under a matched budget, measuring
   quality, latency, memory, and experimental cost. Keep the meta-loop evidence
   based and publish ablations including negative results. Before claiming any
   GPU-backed application improvement, profile a real CPU bottleneck first.

## Resume commands

```bash
cd /home/jack/Projects/HyperForge
pixi run build
pixi run test
pixi run test-gpu
```
