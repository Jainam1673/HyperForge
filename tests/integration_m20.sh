#!/usr/bin/env bash
# M20 integration checks: bounded config-only RSI with protected evaluator.
# Run with: pixi run test-rsi
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-rsi-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "dry run" "$BIN" rsi run 12
check_output "state:           AWAITING_AUTHORIZATION" "dry state"
check_output "authorization:   report-only" "dry authorization"
check_output "candidate scope: config only; no generated code execution" "config-only scope"
check_output "evaluator:       protected thresholds and checksums; holdout gate" "protected evaluator"
check_output "note:            passing candidates are deferred until --apply" "defer note"

check_status 0 "authorized run" "$BIN" rsi run 12 --apply
check_output "state:           ACCEPTED" "applied state"
check_output "authorization:   --apply" "applied authorization"

check_status 0 "budget ceiling" "$BIN" rsi run 100 --apply
check_output "budget:          12" "clamped budget"
check_output "trials:          12" "clamped trials"

check_status 0 "show" "$BIN" rsi show
check_output "baseline:        linear_gd iterations=200 checksum=" "protected baseline"
check_output "protocol:        min_gain=0.01" "protected protocol"
check_output "ACCEPT" "accepted decisions"

check_status 0 "rollback dry" "$BIN" rsi rollback
check_output "decision:        DEFER" "unauthorized rollback"
check_status 0 "rollback applied" "$BIN" rsi rollback --apply
check_output "decision:        ROLLBACK" "authorized rollback"
check_output "restored_config: linear_gd|200|0.0|0" "baseline restored"

check_status 2 "misplaced apply flag" "$BIN" systems search --apply
check_status 2 "bad subcommand" "$BIN" rsi nonsense

baseline_count=$(grep -c '|rsi_baseline|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
protocol_count=$(grep -c '|rsi_protocol|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
decision_count=$(grep -c '|rsi_decision|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$baseline_count" -eq 1 ] && [ "$protocol_count" -eq 1 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 1 baseline and 1 protocol, got $baseline_count/$protocol_count"
  fail=$((fail + 1))
fi
if [ "$decision_count" -eq 38 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 38 decisions, got $decision_count"
  fail=$((fail + 1))
fi

echo "rsi integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
