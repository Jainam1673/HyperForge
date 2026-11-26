#!/usr/bin/env bash
# M09 integration checks: AutoRL contracts, training, and held-out reporting.
# Run with: pixi run test-autorl
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-autorl-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "list envs" "$BIN" autorl list-envs
check_output "grid_4x4_two_walls" "environment listed"
check_status 0 "run" "$BIN" autorl run 50 15
check_output "test_mean_return:" "test return"
check_output "random_mean:" "random baseline"
check_output "optimal_mean:" "optimal reference"
check_output "ci95_half_width:" "uncertainty summary"
check_output "improvement:" "improvement"
check_output "state:            IMPROVED" "honest state"
ID=$(grep -o 'rl-[0-9a-f]*' "$TMPD/stdout" | head -1)

check_status 0 "show" "$BIN" autorl show "$ID"
check_output "selected:" "show selected"
check_status 0 "replay" "$BIN" autorl replay "$ID"
check_output "REPLAY_READY" "replay ready"

record_count=$(grep -c '|autorl|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$record_count" -eq 1 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 1 autorl record, got $record_count"
  fail=$((fail + 1))
fi
if grep -q 'episode,mean_training_return' "$TMPD/workspace/artifacts/$ID.returns.txt"; then
  pass=$((pass + 1))
else
  echo "FAIL [curve]: learning curve missing"
  fail=$((fail + 1))
fi

check_status 2 "bad episodes" "$BIN" autorl run 2 15
check_status 2 "bad subcommand" "$BIN" autorl nonsense

echo "autorl integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
