#!/usr/bin/env bash
# M17 integration checks: DiscoveryGenome v2 and systems-side measured search.
# Run with: pixi run test-systems
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-systems-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "systems search" "$BIN" systems search 3 42
for policy in fixed random adaptive; do
  check_output "policy:           $policy" "policy $policy"
done
check_output "pareto_count:" "pareto reporting"
check_output "AI genome gene carried but not measured" "honest gene scope"
check_output "no weighted score" "objective handling"
check_status 0 "show" "$BIN" systems show
check_output "state=PASS" "recorded trials"

record_count=$(grep -c '|systems_trial|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$record_count" -eq 7 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 7 systems trials, got $record_count"
  fail=$((fail + 1))
fi
check_status 2 "bad subcommand" "$BIN" systems nonsense

echo "systems integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
