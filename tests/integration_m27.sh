#!/usr/bin/env bash
# M27 integration: full SciAI breadth.
# Run with: pixi run test-sciai-full
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-sciai-full.XXXXXX 2>/dev/null || mktemp -d)"
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
check_status 0 "sciai full" "$BIN" sciai full 42
for p in poisson_amplitude heat_decay linear_wave; do
  check_output "problem:         $p" "problem $p"
done
check_output "ci95:" "bootstrap uncertainty"
check_output "field_rmse:" "SciDL field metric"
check_output "linear_rmse:" "linear baseline"
check_output "bandit_return:" "SciRL selection"
check_output "jet_grad_err:" "differentiable simulation"
check_output "operator_err:" "neural operator spike"
check_output "SciML + UQ, SciDL baselines, SciRL selection, differentiable simulation, neural operator" "family list"
check_output "UQ intervals are bootstrap ensembles with stated noise assumptions" "UQ assumptions"
check_output "affine parameter-to-solution spike, not a DeepONet/FNO" "operator honesty"
check_status 0 "version" "$BIN" --version
check_output "hyperforge 0.1.0 (M27)" "version text"
check_status 2 "bad subcommand" "$BIN" sciai nonsense
count=$(grep -c '|sciai_outcome|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$count" -eq 3 ]; then pass=$((pass+1)); else echo "FAIL [journal]: expected 3, got $count"; fail=$((fail+1)); fi
echo "sciai full integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then exit 1; fi
