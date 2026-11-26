#!/usr/bin/env bash
# Select an external ptxas for pre-Turing NVIDIA devices when one is available.
# Source this file before building or running HyperForge GPU commands.
HF_TARGET_ARCH=""
HF_PTXAS=""
if command -v nvidia-smi >/dev/null 2>&1; then
  HF_CAPABILITY="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d ' ' || true)"
  if [ -n "$HF_CAPABILITY" ]; then
    HF_TARGET_ARCH="sm_${HF_CAPABILITY//./}"
  fi
fi
case "$HF_TARGET_ARCH" in
  sm_52|sm_60|sm_61)
    for candidate in \
      /home/jack/.cache/rattler/cache/pkgs/cuda-nvcc-tools-*/bin/ptxas \
      /usr/bin/ptxas; do
      if [ -x "$candidate" ] && "$candidate" --version 2>/dev/null | grep -qE '202[0-5]'; then
        HF_PTXAS="$candidate"
        break
      fi
    done
    ;;
esac
if [ -n "$HF_PTXAS" ]; then
  export MODULAR_NVPTX_COMPILER_PATH="$HF_PTXAS"
fi
