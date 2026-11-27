#!/usr/bin/env bash
# M16 integration checks: GPU catalogue, reproducible benchmark, evidence.
# Run with: pixi run test-gpu-catalogue
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-gpu-cat-test.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
# shellcheck source=/dev/null
source "$ROOT/scripts/gpu-env.sh"

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

check_status 0 "catalogue" "$BIN" hardware catalogue
check_output "vector_add" "vector add entry"
check_output "vector_axpy" "axpy entry"
check_output "supported_sizes" "size policy"
check_status 0 "probe" "$BIN" hardware probe
check_output "mojo_pin:" "toolchain capture"
check_output "external_ptxas_configured:" "compiler capture"

check_status 0 "benchmark add" "$BIN" benchmark kernel vector_add 255 3
check_output "state=PASS" "add correctness"
check_status 0 "benchmark axpy" "$BIN" benchmark kernel vector_axpy 1024 3
check_output "state=PASS" "axpy correctness"
if grep -qE 'schema=hyperforge-gpu-catalogue-v1.*mojo=.*max=.*repetitions=' "$TMPD/workspace/benchmarks/gpu-vector_add-255.txt"; then
  pass=$((pass + 1))
else
  echo "FAIL [report]: environment fields missing"
  fail=$((fail + 1))
fi

record_count=$(grep -c '|gpu_bench|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$record_count" -eq 2 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 2 gpu_bench records, got $record_count"
  fail=$((fail + 1))
fi

check_status 2 "unknown kernel" "$BIN" benchmark kernel nonsense 255 3
check_status 2 "bad subcommand" "$BIN" hardware bogus

echo "gpu catalogue integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
