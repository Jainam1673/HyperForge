#!/usr/bin/env bash
# M27 integration checks: MAX serving readiness and portability contract.
# Run with: pixi run test-serve
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-serve-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "serve status" "$BIN" serve status
check_output "adapter_schema:  hyperforge-max-adapter-v1" "adapter schema"
check_output "boundary_status: BLOCKED_BY_MAX_INTERFACE" "honest boundary"
check_output "serve_enabled:   false" "serving disabled"
check_output "serve_decision:  REFUSED_UNVERIFIED_INTERFACE" "refusal decision"
check_output "amd  [NOT_TESTED]" "amd honesty"
check_output "apple_silicon  [NOT_TESTED]" "apple honesty"
check_output "nvidia_sm_61  [VERIFIED]" "nvidia evidence"
check_output "no_performance_claim_without_target_driver_and_version" "source rule"

record_count=$(grep -c '|serve_status|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$record_count" -eq 1 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 1 serve_status record, got $record_count"
  fail=$((fail + 1))
fi
check_status 0 "version" "$BIN" --version
check_output "hyperforge 0.1.0 (M27)" "version text"
check_status 2 "bad subcommand" "$BIN" serve nonsense

echo "serve integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
