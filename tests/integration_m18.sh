#!/usr/bin/env bash
# M18 integration checks: meta economy comparison and causal edge ledger.
# Run with: pixi run test-meta
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-meta-test.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
# shellcheck source=/dev/null
source "$ROOT/scripts/gpu-env.sh"

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

check_status 0 "meta run" "$BIN" meta run 4 42
for policy in fixed random adaptive ai_only; do
  check_output "$policy  gain=" "policy $policy"
done
check_output "matched_budget:" "matched budget"
check_output "no causal claim from a single correlated change" "causal honesty"
check_status 0 "graph" "$BIN" meta graph
check_output "hypothesized" "hypothesis label"
check_output "experimentally_supported" "supported label"
check_output "hypothesized edges are not causal claims" "coupling honesty"

economy_count=$(grep -c '|meta_economy|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
edge_count=$(grep -c '|causal_edge|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$economy_count" -eq 4 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 4 economy records, got $economy_count"
  fail=$((fail + 1))
fi
if [ "$edge_count" -eq 20 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 20 causal edges, got $edge_count"
  fail=$((fail + 1))
fi
check_status 2 "bad subcommand" "$BIN" meta nonsense

echo "meta integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
