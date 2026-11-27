# Release engineering notes (M21)

## Toolchain (pinned, declared not probed)

| Item | Pin |
|---|---|
| Mojo | 1.2.0 |
| MAX | 26.7.0 |
| pixi | 0.85.0 |
| Target used for GPU evidence | NVIDIA MX230, `sm_61`, driver 580.178.04 |

`doctor` labels pins as declared facts and prints the commands to verify live
versions (`pixi run mojo --version`, `pixi run max --version`). GPU runs on the
pre-Turing device require `source scripts/gpu-env.sh` to select the cached CUDA
12 `ptxas`; the bundled CUDA 13 toolchain rejects `sm_61`.

## Clean-checkout reproduction

```bash
cd /home/jack/Projects/HyperForge
pixi install                 # uses pixi.lock
pixi run build
pixi run test
pixi run test-cli
pixi run test-hardening
# GPU-dependent suites (accelerator required):
source scripts/gpu-env.sh
pixi run test-gpu-catalogue
pixi run test-systems
pixi run test-meta
pixi run test-joint
pixi run test-rsi
```

No network access is required for the core CLI, AutoML, evidence, or config-only
RSI paths. No checkpoints or datasets are downloaded automatically. The only
optional external interaction is the MAX CLI probe in `doctor`, which looks for
a local executable on `PATH`; it does not contact a remote endpoint. `doctor`
also probes filesystem writability with a temporary local file.

## Security and reliability posture

- Config-only RSI candidates; no generated code is compiled or executed.
- Protected RSI baseline and evaluator are write-once, checksum-verified, and
  have no candidate-facing mutation path. Acceptance requires `--apply`.
- Path validation rejects empty, over-long, NUL-bearing, and `..`-traversing
  paths before workspace creation.
- CSV loading enforces 16 MiB / 100000 rows / 256 columns before full parsing.
- Journal records are versioned and checksummed; a corrupt or truncated tail is
  recovered as a validated prefix, while middle corruption fails loudly.
- Writes are not atomic: the installed Mojo release does not expose a verified
  atomic rename/truncate path, so recovery rewrites a validated prefix with a
  plain file write. No transaction is claimed.
- Ctrl-C interception is **not implemented** in the installed Mojo release;
  interrupted runs are not automatically marked. This is a known limitation,
  not a claimed capability.
- No telemetry or outbound network calls in the core.

## Licensing / assets

- Source is project-owned Mojo; dependencies are the pinned Mojo/MAX toolchain.
- MAX components are governed by Modular's license terms; verify the installed
  release before redistribution.
- `examples/regression_linear.csv` is a project-owned synthetic fixture.
- No third-party model artifacts or benchmark datasets are bundled.

## Evidence

Full verification on M21: 123 unit tests and 348 integration checks pass.
See `TEST_RESULTS.md` for exact commands and outcomes, and `CAPABILITY_MATRIX.md`
for the authoritative status of every capability keyword.
