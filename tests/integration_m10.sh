#!/usr/bin/env bash
# M10 integration checks: AutoTransformers search, measured metrics, replay.
# Run with: pixi run test-autotrans
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-autotrans-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "run" "$BIN" autotransformers run 3 42
for policy in default random adaptive; do
  check_output "$policy  " "policy $policy"
done
check_output "validation MSE only" "selection discipline"
check_output "no model assumed faster" "fairness statement"
check_output "no MAX inference or serving claim" "scope honesty"
record_count=$(grep -c '|autotrans|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$record_count" -eq 3 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 3 autotrans records, got $record_count"
  fail=$((fail + 1))
fi

check_status 0 "show" "$BIN" autotransformers show random
check_output "parameters:" "show parameter count"
check_status 0 "replay" "$BIN" autotransformers replay random
check_output "REPLAY_READY" "replay ready"

check_status 2 "bad budget" "$BIN" autotransformers run 0 42
check_status 2 "bad subcommand" "$BIN" autotransformers nonsense

echo "autotrans integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
