#!/usr/bin/env bash
# M04 integration checks: SINN problem list, solve, artifacts, honest failure.
# Run with: pixi run test-sinn
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-sinn-test.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "list problems" "$BIN" sinn list-problems
check_output "poisson_1d" "problem listed"

check_status 0 "solve" "$BIN" sinn solve poisson_1d 42 800
check_output "state:       CONVERGED" "converged state"
check_output "boundary:    0.0" "exact boundary"
check_output "exact_l2:" "held-out exact error"
check_output "fd_l2:" "finite-difference comparison"
ID=$(grep -o 'sinn-[0-9a-f]*' "$TMPD/stdout" | head -1)

check_status 0 "show" "$BIN" sinn show "$ID"
check_output "problem:     poisson_1d" "show problem"

for path in "artifacts/$ID.config.txt" "artifacts/$ID.model.txt"; do
  if [ -f "$TMPD/workspace/$path" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL [artifact]: missing $path"
    fail=$((fail + 1))
  fi
done

if grep -q '|scientific|' "$TMPD/workspace/experiments/hf-journal.hfj"; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: missing scientific record"
  fail=$((fail + 1))
fi

# Honest failure: a tiny iteration budget must not be reported as success.
set +e
(cd "$TMPD/workspace" && "$BIN" sinn solve poisson_1d 43 3) >"$TMPD/stdout" 2>"$TMPD/stderr"
got=$?
set -e
if [ "$got" -ne 1 ]; then
  echo "FAIL [short run]: expected exit 1, got $got"
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if grep -q 'did not meet the convergence gate' "$TMPD/stderr"; then
  pass=$((pass + 1))
else
  echo "FAIL [short run]: missing honest failure message"
  fail=$((fail + 1))
fi

check_status 2 "unknown problem" "$BIN" sinn solve heat_2d 42 800
check_status 2 "bad subcommand" "$BIN" sinn nonsense

# Reproducibility across workspaces with a second seed.
"$BIN" init "$TMPD/workspace_b" >/dev/null
set +e
(cd "$TMPD/workspace_b" && "$BIN" sinn solve poisson_1d 99 800) >"$TMPD/out_b" 2>"$TMPD/err_b"
status_b=$?
set -e
if [ "$status_b" -eq 0 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [second seed]: exit $status_b"
  cat "$TMPD/err_b"
  fail=$((fail + 1))
fi

echo "sinn integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
