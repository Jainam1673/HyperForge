#!/usr/bin/env bash
# M06 integration checks: GPU probe, kernel benchmark, CPU-core regression.
# Run with: pixi run test-gpu
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
# shellcheck source=/dev/null
source "$ROOT/scripts/gpu-env.sh"
TMPD="$(mktemp -d /tmp/opencode/hf-gpu-test.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

pass=0
fail=0

check_status() {
  local expected="$1"
  local label="$2"
  shift 2
  set +e
  (cd "$TMPD/workspace" && "$@") >"$TMPD/stdout" 2>"$TMPD/stderr"
  local got=$?
  set -e
  if [ "$got" -ne "$expected" ]; then
    echo "FAIL [$label]: expected exit $expected, got $got"
    cat "$TMPD/stdout" "$TMPD/stderr"
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

check_output() {
  local pattern="$1"
  local label="$2"
  if grep -qF "$pattern" "$TMPD/stdout"; then
    pass=$((pass + 1))
  else
    echo "FAIL [$label]: stdout missing '$pattern'"
    fail=$((fail + 1))
  fi
}

bash "$ROOT/scripts/mojo.sh" build -I "$ROOT/src" "$ROOT/src/main.mojo" -o "$BIN"
"$BIN" init "$TMPD/workspace" >/dev/null
mkdir -p "$TMPD/workspace/benchmarks"

check_status 0 "hardware probe" "$BIN" hardware probe
check_output "gpu_kernel:       PASS" "kernel status"
check_output "max_abs_error:    0.0" "numeric correctness"
check_output "gpu_kernel:" "executed on device"

check_status 0 "benchmark tiny" "$BIN" benchmark kernel vector_add 7 3
check_output "state=PASS" "edge size 7"
check_status 0 "benchmark large" "$BIN" benchmark kernel vector_add 4097 3
check_output "state=PASS" "non-multiple block size"
if grep -q 'report: ' "$TMPD/stdout"; then
  pass=$((pass + 1))
else
  echo "FAIL [report]: no benchmark report path"
  fail=$((fail + 1))
fi
if [ -f "$TMPD/workspace/benchmarks/gpu-vector_add-4097.txt" ]; then
  pass=$((pass + 1))
else
  echo "FAIL [report]: benchmark report missing"
  fail=$((fail + 1))
fi

check_status 0 "doctor gpu" "$BIN" doctor --gpu
check_output "gpu_kernel" "doctor gpu probe"

# CPU core must remain intact.
check_status 0 "version" "$BIN" --version
check_output "hyperforge 0.1.0 (M21)" "version text"
check_status 0 "experiment list" "$BIN" experiment list
check_status 2 "bad hardware" "$BIN" hardware nonsense
check_status 2 "bad benchmark" "$BIN" benchmark nonsense

echo "gpu integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
