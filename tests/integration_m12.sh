#!/usr/bin/env bash
# M12 integration checks: SciML registry, inverse solve, held-out baselines.
# Run with: pixi run test-sciml
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-sciml-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "list problems" "$BIN" sciml list-problems
check_output "poisson_amplitude_1d" "registry entry"
check_output "assumptions:" "assumptions declared"
check_output "reference:" "reference declared"

check_status 0 "solve" "$BIN" sciml solve 42
check_output "estimated k:" "parameter estimate"
check_output "parameter error:" "parameter error"
check_output "parameter std:" "variability summary"
check_output "inverse exact L2:" "inverse metric"
check_output "hybrid exact L2:" "hybrid metric"
check_output "constant exact L2:" "baseline metric"
check_output "FD reference L2:" "conventional solver reference"
ID=$(grep -o 'sciml-[0-9a-f]*' "$TMPD/stdout" | head -1)

check_status 0 "show" "$BIN" sciml show "$ID"
check_output "problem:" "show problem"

record_count=$(grep -c '|sciml|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$record_count" -eq 1 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 1 sciml record, got $record_count"
  fail=$((fail + 1))
fi

check_status 2 "bad subcommand" "$BIN" sciml nonsense
echo "sciml integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
