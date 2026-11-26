#!/usr/bin/env bash
# M02 CLI integration checks: build, help/version, doctor, init, exit codes.
# Run with: pixi run test-cli
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-cli-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_stderr() {
  local pattern="$1"
  local label="$2"
  if grep -qF "$pattern" "$TMPD/stderr"; then
    pass=$((pass + 1))
  else
    echo "FAIL [$label]: stderr missing '$pattern'"
    fail=$((fail + 1))
  fi
}

echo "Building hyperforge..."
mojo build -I "$ROOT/src" "$ROOT/src/main.mojo" -o "$BIN"

check_status 0 "help" "$BIN" --help
check_output "IMPLEMENTED COMMANDS" "help section"

check_status 0 "version" "$BIN" --version
check_output "hyperforge 0.1.0 (M02)" "version text"

check_status 0 "doctor" "$BIN" doctor
check_output "hyperforge doctor (M02)" "doctor header"
check_output "toolchain_pin" "doctor probe"

check_status 0 "doctor json" "$BIN" doctor --json
check_output '"schema":"hyperforge-doctor-v1"' "doctor json schema"

check_status 0 "init" "$BIN" init "$TMPD/workspace"
check_status 2 "init no target" "$BIN" init
check_stderr "init requires a target directory" "init error hint"
check_status 2 "unknown command" "$BIN" nonsense
check_stderr "unknown command: nonsense" "unknown command error"
check_status 2 "unknown option" "$BIN" --bogus
check_stderr "unknown option: --bogus" "unknown option error"
check_status 2 "path traversal" "$BIN" init ../escape
check_stderr "not allowed" "traversal rejection"
check_status 2 "re-init" "$BIN" init "$TMPD/workspace"
check_stderr "already initialized" "re-init rejection"

for path in hyperforge.toml experiments artifacts logs; do
  if [ -e "$TMPD/workspace/$path" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL [init layout]: missing $path"
    fail=$((fail + 1))
  fi
done

echo "integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
