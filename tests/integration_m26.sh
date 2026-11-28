#!/usr/bin/env bash
# M27 integration: full AutoRL algorithms and held-out evaluation.
# Run with: pixi run test-autorl-full
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-autorl-full.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
pass=0; fail=0

check_status() {
  local expected="$1"; local label="$2"; shift 2
  set +e
  (cd "$TMPD/workspace" && "$@") >"$TMPD/stdout" 2>"$TMPD/stderr"
  local got=$?; set -e
  if [ "$got" -ne "$expected" ]; then
    echo "FAIL [$label]: expected $expected, got $got"; cat "$TMPD/stdout" "$TMPD/stderr"; fail=$((fail+1))
  else pass=$((pass+1)); fi
}
check_output() {
  local pattern="$1"; local label="$2"
  if grep -qF "$pattern" "$TMPD/stdout"; then pass=$((pass+1)); else
    echo "FAIL [$label]: missing '$pattern'"; fail=$((fail+1)); fi
}
bash "$ROOT/scripts/mojo.sh" build -I "$ROOT/src" "$ROOT/src/main.mojo" -o "$BIN"
"$BIN" init "$TMPD/workspace" >/dev/null
for a in q_learning sarsa double_q value_iteration random; do
  check_status 0 "$a" "$BIN" autorl full "$a" grid_4x4 40 8 42 2
  check_output "algorithm:         $a" "algorithm $a"
done
check_output "algorithms:        q_learning, sarsa, double_q, value_iteration, random" "algorithm list"
check_output "environments:      grid_4x4, grid_5x5" "environment list"
check_output "holdout_return:" "held-out evaluation"
check_output "safety_violations: 0" "safety constraints"
check_output "holdout wall layout never used for training or selection" "leakage honesty"
check_status 0 "grid_5x5" "$BIN" autorl full sarsa grid_5x5 30 6 42 2
check_output "environment:       grid_5x5" "second environment"
check_status 0 "version" "$BIN" --version
check_output "hyperforge 0.1.0 (M27)" "version text"
check_status 1 "bad algorithm" "$BIN" autorl full nonsense grid_4x4 10 4 42 1
count=$(grep -c '|autorl_full|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$count" -eq 6 ]; then pass=$((pass+1)); else echo "FAIL [journal]: expected 6, got $count"; fail=$((fail+1)); fi
echo "autorl full integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then exit 1; fi
