#!/usr/bin/env bash
# M07 integration checks: matched-budget reciprocal comparison and evidence.
# Run with: pixi run test-discover
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
# shellcheck source=/dev/null
source "$ROOT/scripts/gpu-env.sh"
TMPD="$(mktemp -d /tmp/opencode/hf-discover-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "discover run" "$BIN" discover run 4 42
for policy in fixed ai_only compute_only independent joint_reciprocal ablation_no_history; do
  check_output "$policy " "policy $policy"
done
check_output "matched_budget:" "matched budget"
check_output "memory:" "memory reported honestly"
check_output "joint_vs_independent:" "comparison verdict"
check_output "note: coupling is not assumed to help" "negative-result statement"

record_count=$(grep -c '|discovery|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$record_count" -eq 6 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 6 discovery records, got $record_count"
  fail=$((fail + 1))
fi

# A second seed exercises repeatability and must succeed.
check_status 0 "second seed" "$BIN" discover run 4 43
check_status 2 "bad budget" "$BIN" discover run 1 42
check_status 2 "bad subcommand" "$BIN" discover nonsense

echo "discover integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
