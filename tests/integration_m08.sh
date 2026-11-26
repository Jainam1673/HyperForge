#!/usr/bin/env bash
# M08 integration checks: AutoDL training, search, checkpoint, replay.
# Run with: pixi run test-autodl
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-autodl-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "autodl run" "$BIN" autodl run 4 42
check_output "AutoDL search" "header"
check_output "random:" "random result"
check_output "adaptive:" "adaptive result"
check_output "validation loss only" "holdout discipline"
check_output "candidates differ in depth/width" "structural claim"
ID=$(grep -o 'candidate_id=arch-[0-9a-f]*' "$TMPD/workspace/experiments/hf-journal.hfj" | head -1 | cut -d= -f2)

check_status 0 "show" "$BIN" autodl show "$ID"
check_output "architecture:" "show architecture"
check_status 0 "replay" "$BIN" autodl replay "$ID"
check_output "REPLAY_READY" "checkpoint replay"

record_count=$(grep -c '|autodl|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$record_count" -eq 2 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 2 autodl records, got $record_count"
  fail=$((fail + 1))
fi

check_status 2 "bad budget" "$BIN" autodl run 1 42
check_status 2 "bad subcommand" "$BIN" autodl nonsense

echo "autodl integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
