#!/usr/bin/env bash
# M11 integration checks: AutoLLM discovery, offline evaluation, honest status.
# Run with: pixi run test-autollm
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-autollm-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "status" "$BIN" autollm status
check_output "status:         UNAVAILABLE" "honest unavailable"
check_output "offline_core:" "offline core available"

check_status 0 "evaluate" "$BIN" autollm evaluate "$ROOT/examples/autollm/prompts.txt" "$ROOT/examples/autollm/responses.txt"
check_output "cases:          3" "case count"
check_output "matched:        2" "matched count"
check_output "missing:        1" "missing counted"
check_output "no model was invoked" "no fake inference"

mkdir -p "$TMPD/fake_models"
printf 'synthetic fixture\n' > "$TMPD/fake_models/tiny.model.json"
printf 'Synthetic license\n' > "$TMPD/fake_models/LICENSE.txt"
check_status 0 "discover artifact" "$BIN" autollm discover "$TMPD/fake_models"
check_output "artifact_count: 1" "artifact discovered"
check_output "license=DECLARED" "license declared"
check_output "backend_status: BLOCKED_BY_MAX_INTERFACE" "honest blocked"
check_status 0 "status after" "$BIN" autollm status
check_output "BLOCKED_BY_MAX_INTERFACE" "persisted blocked status"

check_status 1 "bad evaluate" "$BIN" autollm evaluate /tmp/nope.txt /tmp/nope2.txt
check_status 2 "bad subcommand" "$BIN" autollm nonsense

echo "autollm integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
