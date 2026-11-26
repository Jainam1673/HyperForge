#!/usr/bin/env bash
# Mojo launcher used by every HyperForge build/test task. Selects the detected
# accelerator target and an external ptxas when the device is pre-Turing. If
# none is available, the CPU core still builds and GPU commands report BLOCKED.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=gpu-env.sh
source "$SCRIPT_DIR/gpu-env.sh"

MOJO_BIN="${MOJO_BIN:-mojo}"
TARGET_FLAG=()
if [ -n "$HF_TARGET_ARCH" ]; then
  TARGET_FLAG=(--target-accelerator "$HF_TARGET_ARCH")
fi

if [ "$#" -eq 0 ]; then
  exec "$MOJO_BIN"
fi
subcommand="$1"
shift
exec "$MOJO_BIN" "$subcommand" "${TARGET_FLAG[@]}" "$@"
