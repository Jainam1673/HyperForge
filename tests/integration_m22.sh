#!/usr/bin/env bash
# M22 integration checks: complete AutoML algorithm suite with k-fold CV.
# Run with: pixi run test-automl-full
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-automl-full.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "regression full run" "$BIN" automl full "$ROOT/examples/regression_linear.csv" y 12 42 3
check_output "task:            regression" "regression task detection"
check_output "candidates:      12" "full budget"
check_output "cv_folds:        3" "k-fold reporting"
check_output "test_rmse:" "regression metrics"
check_output "selection used validation + k-fold; test evaluated once" "leakage honesty"

check_status 0 "classification full run" "$BIN" automl full "$ROOT/examples/classification_binary.csv" y 12 42 3
check_output "task:            classification" "classification task detection"
check_output "test_accuracy:" "classification accuracy"
check_output "test_f1:" "classification f1"
check_output "test_auc:" "classification auc"
check_output "test_log_loss:" "classification log loss"

check_status 0 "grid run" "$BIN" automl full "$ROOT/examples/classification_binary.csv" y 6 42 2 grid
check_output "candidates:" "grid candidate count"

full_trials=$(grep -c '|full_trial|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
summaries=$(grep -c '|full_summary|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$full_trials" -eq 60 ] && [ "$summaries" -eq 3 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 60 trials and 3 summaries, got $full_trials/$summaries"
  fail=$((fail + 1))
fi

check_status 2 "invalid folds" "$BIN" automl full "$ROOT/examples/regression_linear.csv" y 4 42 1
check_status 2 "bad subcommand" "$BIN" automl nonsense

echo "automl full integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
