#!/usr/bin/env bash
# M02 integration checks: inspect, run, show, report, replay, compare, failures.
# Run with: pixi run test-automl
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
DATA="$ROOT/examples/regression_linear.csv"
TMPD="$(mktemp -d /tmp/opencode/hf-automl-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_stderr() {
  local pattern="$1"
  local label="$2"
  if grep -qF "$pattern" "$TMPD/stderr"; then
    pass=$((pass + 1))
  else
    echo "FAIL [$label]: stderr missing '$pattern'"
    fail=$((fail + 1))
  fi
}

bash "$ROOT/scripts/mojo.sh" build -I "$ROOT/src" "$ROOT/src/main.mojo" -o "$BIN"
"$BIN" init "$TMPD/workspace" >/dev/null

check_status 0 "inspect" "$BIN" automl inspect "$DATA" y
check_output "fingerprint:" "inspect fingerprint"
check_output "rows:           24" "inspect rows"

check_status 0 "run" "$BIN" automl run "$DATA" y 5 42
check_output "experiment:" "run experiment id"
check_output "test:" "run test metrics"
ID=$(grep -o 'exp-[0-9a-f]*' "$TMPD/stdout" | head -1)

check_status 0 "show" "$BIN" automl show "$ID"
check_output "  test  " "show includes held-out trial"
check_status 0 "report" "$BIN" report "$ID"
check_output "HyperForge AutoML report" "report header"
check_status 0 "replay" "$BIN" automl replay "$ID"
check_output "REPLAY_OK" "replay ok"

# A second experiment with a different seed allows a real comparison.
check_status 0 "run seed 43" "$BIN" automl run "$DATA" y 4 43
ID2=$(grep -o 'exp-[0-9a-f]*' "$TMPD/stdout" | head -1)
check_status 0 "compare" "$BIN" automl compare "$ID" "$ID2"
check_output "lower_test_rmse:" "compare result"

# Invalid inputs must fail clearly.
check_status 1 "missing dataset" "$BIN" automl inspect /tmp/opencode/no-such.csv y
check_stderr "dataset error" "missing dataset error"
check_status 1 "bad target" "$BIN" automl run "$DATA" nope 5 42
check_stderr "dataset error" "bad target error"
check_status 2 "budget too small" "$BIN" automl run "$DATA" y 1 42
check_stderr "budget must be at least 2" "budget validation"

echo "automl integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
