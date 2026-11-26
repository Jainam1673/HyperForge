#!/usr/bin/env bash
# M03 integration checks: adaptive loop, persisted state, matched comparison.
# Run with: pixi run test-optimize
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
DATA="$ROOT/examples/regression_linear.csv"
TMPD="$(mktemp -d /tmp/opencode/hf-optimize-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "optimize run" "$BIN" optimize run "$DATA" y 5 42
check_output "adaptive policy:" "adaptive policy"
check_output "baseline policy:" "baseline policy"
check_output "matched_budget:" "matched budget"
check_output "matched_seed:" "matched seed"
check_output "matched_split:" "matched split"
check_output "lower_test_rmse:" "comparison verdict"
check_output "adaptive trials:" "trial counts"

ID=$(grep -o 'exp-[0-9a-f]*' "$TMPD/stdout" | head -1)
if [ -n "$ID" ]; then
  pass=$((pass + 1))
else
  echo "FAIL [id]: no experiment id printed"
  fail=$((fail + 1))
fi

J="$TMPD/workspace/experiments/hf-journal.hfj"
state_lines=$(grep -c '|optimizer|' "$J" || true)
if [ "$state_lines" -eq 5 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [state]: expected 5 optimizer records, got $state_lines"
  fail=$((fail + 1))
fi

trial_lines=$(grep -c '|trial|' "$J" || true)
if [ "$trial_lines" -eq 6 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [trials]: expected 5 validation + 1 test = 6, got $trial_lines"
  fail=$((fail + 1))
fi

if grep -q '|trial|.*split=test' "$J"; then
  pass=$((pass + 1))
else
  echo "FAIL [test]: missing held-out test trial"
  fail=$((fail + 1))
fi

check_status 2 "bad budget" "$BIN" optimize run "$DATA" y 1 42
check_status 2 "bad subcommand" "$BIN" optimize nonsense

echo "optimize integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
