#!/usr/bin/env bash
# M05 integration checks: SciTransformers train/show/predict and reproducibility.
# Run with: pixi run test-scit
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-scit-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "train" "$BIN" sci-transformers train 42 10
check_output "state:            CONVERGED" "converged state"
check_output "model_mse:" "model metric"
check_output "persistence_mse:" "persistence baseline"
check_output "mean_mse:" "mean baseline"
check_output "linear_mse:" "linear baseline"
check_output "rollout_drift:" "rollout metric"
ID=$(grep -o 'scit-[0-9a-f]*' "$TMPD/stdout" | head -1)
cp "$TMPD/stdout" "$TMPD/train_out"

check_status 0 "show" "$BIN" sci-transformers show "$ID"
check_output "task:            decaying_mode_1d" "show task"
check_status 0 "predict" "$BIN" sci-transformers predict "$ID" 0
check_output "prediction:" "predict output"
check_output "actual:" "actual output"

for path in "artifacts/$ID.config.txt" "artifacts/$ID.model.txt"; do
  if [ -f "$TMPD/workspace/$path" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL [artifact]: missing $path"
    fail=$((fail + 1))
  fi
done

check_status 2 "bad epochs" "$BIN" sci-transformers train 42 0
check_status 2 "bad subcommand" "$BIN" sci-transformers nonsense

# Determinism across workspaces.
"$BIN" init "$TMPD/workspace_b" >/dev/null
set +e
(cd "$TMPD/workspace_b" && "$BIN" sci-transformers train 42 10) >"$TMPD/out_b" 2>"$TMPD/err_b"
status_b=$?
set -e
if [ "$status_b" -eq 0 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [second workspace]: exit $status_b"
  cat "$TMPD/err_b"
  fail=$((fail + 1))
fi
for pattern in "model_mse:" "persistence_mse:" "rollout_drift:"; do
  a=$(grep "$pattern" "$TMPD/train_out" | head -1)
  b=$(grep "$pattern" "$TMPD/out_b" | head -1)
  if [ "$a" = "$b" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL [determinism]: $pattern differs: '$a' vs '$b'"
    fail=$((fail + 1))
  fi
done

echo "scit integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
