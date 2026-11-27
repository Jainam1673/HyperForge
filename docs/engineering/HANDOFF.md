# Handoff

## Current state

- M00–M21 are VERIFIED. M21 commit/push is the remaining workflow action.
- Git remote: `https://github.com/Jainam1673/HyperForge.git`, branch `main`.
- GitHub MCP is working (`get_me`, `opencode mcp list`).
- Final verification: `pixi run test` → 123 unit tests; 22 integration suites →
  348 checks. All pass. Build is clean.
- Roadmap milestone sequence is closed by M21; further growth is incremental.

## What M21 added

```
src/hyperforge/hardening.mojo
tests/test_m21.mojo
tests/integration_m21.sh
docs/engineering/CAPABILITY_MATRIX.md
docs/engineering/RELEASE.md
src/hyperforge/workspace.mojo, automl/dataset.mojo, doctor.mojo (wiring)
src/hyperforge/core/version.mojo, pixi.toml, README.md (version/tasks)
```

## Known limitations / blockers

- AutoLLM MAX inference is BLOCKED_BY_MAX_INTERFACE; AutoGenAI/SciLLM/SciGenAI
  blocked; no commands registered for them.
- RSI is config-only; no code rewriting or runtime consumer of applied configs.
- Atomic rename/truncate and Ctrl-C interception are unavailable in installed
  Mojo and are reported honestly as limitations.
- Memory is NOT_TESTED in several capabilities.
- World models, broad HPC/HyperComputers, and application kernel migration are
  PLANNED, not implemented.

## Next exact actions

1. Commit and push M21 as its own milestone.
2. Re-read the three authoritative documents (required after each milestone).
3. Work from `CAPABILITY_MATRIX.md`: only expand a PARTIAL/BLOCKED item after its
   prerequisite is verified (notably local MAX inference before SciLLM/SciGenAI).

## Resume commands

```bash
cd /home/jack/Projects/HyperForge
pixi run build
pixi run test
pixi run test-hardening
```
