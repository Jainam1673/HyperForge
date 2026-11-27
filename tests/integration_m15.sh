#!/usr/bin/env bash
# M15 integration checks: validated Scientific Looper with real evidence.
# Run with: pixi run test-looper
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-looper-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "run loop" "$BIN" looper run linear-beats-mean 4
check_output "decision:        ACCEPTED" "accepted decision"
check_output "baseline_rmse:" "baseline metric"
check_output "candidate_rmse:" "candidate metric"
check_output "verified_rmse:" "verified metric"
check_output "no parallel agents claimed" "honest roles"
ID=$(grep -o 'loop-[0-9a-f]*' "$TMPD/stdout" | head -1)
check_status 0 "show" "$BIN" looper show "$ID"
check_output "OBSERVE -> FORMULATE" "transition history"

record_count=$(grep -c '|looper|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$record_count" -eq 10 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 10 loop events, got $record_count"
  fail=$((fail + 1))
fi
check_status 2 "bad budget" "$BIN" looper run claim 1
check_status 2 "bad subcommand" "$BIN" looper nonsense

echo "looper integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
