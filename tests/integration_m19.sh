#!/usr/bin/env bash
# M19 integration checks: joint AI x compute benchmark with ablations.
# Run with: pixi run test-joint
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-joint-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "joint run" "$BIN" joint run 6 42 7 123
for policy in fixed ai_only compute_only independent sequential joint ablation_no_shared_history ablation_no_adaptive ablation_no_meta; do
  check_output "  $policy  rmse=" "policy $policy"
done
check_output "matched_budget: 6" "matched budget"
check_output "seeds_tested:   3" "seed repetition"
check_output "memory:         NOT_TESTED" "memory honesty"
check_output "experiment cost: matched evaluation count" "experiment cost"
check_output "mean discoveries per policy:" "aggregate reporting"
check_output "ablations constrain but do not prove general coupling" "coupling honesty"
check_output "small fixture; 3 seeds" "generalization honesty"
check_status 0 "joint show" "$BIN" joint show
check_output "seed=42  fixed  discoveries=" "recorded outcomes"

outcome_count=$(grep -c '|joint_outcome|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$outcome_count" -eq 27 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 27 joint outcomes, got $outcome_count"
  fail=$((fail + 1))
fi
check_status 2 "bad subcommand" "$BIN" joint nonsense

echo "joint integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
