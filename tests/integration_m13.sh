#!/usr/bin/env bash
# M13 integration checks: SciDL supervised field benchmark and baselines.
# Run with: pixi run test-scidl
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-scidl-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "run" "$BIN" scidl run 42
check_output "held-out k range:" "held-out parameter range"
check_output "learned RMSE:" "learned metric"
check_output "linear baseline:" "data baseline"
check_output "FD reference:" "numerical baseline"
ID=$(grep -o 'scidl-[0-9a-f]*' "$TMPD/stdout" | head -1)
check_status 0 "show" "$BIN" scidl show "$ID"
check_output "state:" "show state"

record_count=$(grep -c '|scidl|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$record_count" -eq 1 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 1 scidl record, got $record_count"
  fail=$((fail + 1))
fi
check_status 2 "bad subcommand" "$BIN" scidl nonsense

echo "scidl integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
