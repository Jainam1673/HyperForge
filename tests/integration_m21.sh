#!/usr/bin/env bash
# M27 integration checks: hardening probes, path validation, CSV ceilings.
# Run with: pixi run test-hardening
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-hardening-test.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

pass=0
fail=0

check_status() {
  local expected="$1"
  local label="$2"
  shift 2
  set +e
  "$@" >"$TMPD/stdout" 2>"$TMPD/stderr"
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

check_status 0 "doctor json" "$BIN" doctor --json
check_output "input_hardening" "hardening probe"
check_output "CSV<=16777216B/100000 rows/256 cols" "csv ceilings"
check_output '"milestone":"M27"' "milestone text"

check_status 2 "traversal init" "$BIN" init "$TMPD/../escape"
check_status 0 "valid init" "$BIN" init "$TMPD/workspace"

# 257 columns exceeds the 256-column ceiling.
awk 'BEGIN {
  printf "y";
  for (i = 0; i < 256; i++) printf ",f%d", i;
  printf "\n";
  for (r = 0; r < 10; r++) {
    printf "%d", r;
    for (i = 0; i < 256; i++) printf ",%d", i;
    printf "\n";
  }
}' > "$TMPD/oversized.csv"

check_status 1 "oversized csv" "$BIN" automl inspect "$TMPD/oversized.csv" y
if grep -qF "hardened input limits" "$TMPD/stderr"; then
  pass=$((pass + 1))
else
  echo "FAIL [oversized csv]: stderr missing hardened limit message"
  cat "$TMPD/stderr"
  fail=$((fail + 1))
fi
check_status 0 "valid csv inspect" "$BIN" automl inspect "$ROOT/examples/regression_linear.csv" y

echo "hardening integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
