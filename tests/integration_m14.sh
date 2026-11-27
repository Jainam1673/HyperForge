#!/usr/bin/env bash
# M14 integration checks: SciRL solver-selection with held-out conditions.
# Run with: pixi run test-scirl
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-scirl-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "run" "$BIN" scirl run 40 10
check_output "conditions:" "held-out conditions"
check_output "learned mean return:" "learned metric"
check_output "random mean:" "random baseline"
check_output "heuristic mean:" "domain heuristic"
check_output "improvement random:" "random improvement"
check_output "improvement heur:" "heuristic improvement"
ID=$(grep -o 'scirl-[0-9a-f]*' "$TMPD/stdout" | head -1)
check_status 0 "show" "$BIN" scirl show "$ID"
check_output "state:" "show state"

record_count=$(grep -c '|scirl|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$record_count" -eq 1 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 1 scirl record, got $record_count"
  fail=$((fail + 1))
fi
if grep -q 'episode,mean_training_return' "$TMPD/workspace/artifacts/$ID.returns.txt"; then
  pass=$((pass + 1))
else
  echo "FAIL [curve]: learning curve missing"
  fail=$((fail + 1))
fi
check_status 2 "bad subcommand" "$BIN" scirl nonsense

echo "scirl integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
