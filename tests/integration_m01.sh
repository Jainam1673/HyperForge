#!/usr/bin/env bash
# M01 integration checks: experiment create/list/show/replay and journal recovery.
# Run with: pixi run test-experiment
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-exp-test.XXXXXX 2>/dev/null || mktemp -d)"
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

bash "$ROOT/scripts/mojo.sh" build -I "$ROOT/src" "$ROOT/src/main.mojo" -o "$BIN"
"$BIN" init "$TMPD/workspace" >/dev/null

ID=$("$BIN" init "$TMPD/workspace" >/dev/null 2>&1 || true; cd "$TMPD/workspace" && "$BIN" experiment create integration 42)
if [[ "$ID" == exp-* ]]; then
  pass=$((pass + 1))
else
  echo "FAIL [create]: unexpected id '$ID'"
  fail=$((fail + 1))
fi

check_status 0 "list" "$BIN" experiment list
check_output "$ID" "list contains id"
check_status 0 "list json" "$BIN" experiment list --json
check_output '"schema":"hyperforge-experiment-list-v1"' "list json schema"
check_status 0 "show" "$BIN" experiment show "$ID"
check_output "trial_seeds:" "show fields"
check_status 0 "replay" "$BIN" experiment replay "$ID"
check_output "REPLAY_READY" "replay ready"
check_status 1 "replay missing" "$BIN" experiment replay exp-does-not-exist
check_stderr "experiment not found" "unknown id"

# Replay must refuse when the config artifact is missing.
mv "$TMPD/workspace/artifacts/$ID.config.txt" "$TMPD/workspace/artifacts/$ID.config.saved"
check_status 3 "replay missing artifact" "$BIN" experiment replay "$ID"
check_stderr "config artifact missing" "replay refusal"
mv "$TMPD/workspace/artifacts/$ID.config.saved" "$TMPD/workspace/artifacts/$ID.config.txt"

# Corrupt the last record; recovery must keep the good prefix and report it.
printf 'HFJ1|3|event|deadbeef|exp_id=x|kind=Y|detail=z|state=DRAFT\n' >> "$TMPD/workspace/experiments/hf-journal.hfj"
check_status 0 "recover tail" "$BIN" experiment list
check_stderr "recovered journal tail" "recovery notice"

# Unknown version in a non-last record is a hard error and leaves the file alone.
J="$TMPD/workspace/experiments/hf-journal.hfj"
sed -i '1s/HFJ1/HFJ9/' "$J"
check_status 1 "middle corruption" "$BIN" experiment list
check_stderr "journal error" "hard error"

echo "experiment integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
