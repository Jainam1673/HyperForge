#!/usr/bin/env bash
# M24 integration checks: full AutoLLM PreTrain/MidTrain/PostTrain/Infer.
# Run with: pixi run test-autollm-lifecycle
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-autollm-lifecycle.XXXXXX 2>/dev/null || mktemp -d)"
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

check_status 0 "initial status" "$BIN" autollm status
check_output "lifecycle_stage: none" "initial stage"
check_output "model_scope:     tiny byte-level max-entropy context model; not a frontier LLM" "model scope honesty"
check_output "max_inference:   BLOCKED_BY_MAX_INTERFACE (separate boundary)" "max boundary separation"

check_status 1 "invalid transition" "$BIN" autollm midtrain "$ROOT/examples/autollm/corpus_mid.txt" 2

check_status 0 "pretrain" "$BIN" autollm pretrain "$ROOT/examples/autollm/corpus_pre.txt" 4
check_output "stage:           pretrain" "pretrain stage"
check_output "final_loss:" "real training loss"
check_output "checksum:" "checkpoint checksum"
check_output "tiny first-party byte model with real gradients" "boundary note"

check_status 0 "midtrain" "$BIN" autollm midtrain "$ROOT/examples/autollm/corpus_mid.txt" 4
check_output "previous_stage:  pretrain" "midtrain lineage parent"
check_output "stage:           midtrain" "midtrain stage"

check_status 0 "posttrain" "$BIN" autollm posttrain "$ROOT/examples/autollm/pairs.tsv" 4
check_output "previous_stage:  midtrain" "posttrain lineage parent"
check_output "stage:           posttrain" "posttrain stage"

$BIN init "$TMPD/other" >/dev/null
set +e
(cd "$TMPD/other" && "$BIN" autollm infer "the " 4 1.0) >"$TMPD/stdout" 2>"$TMPD/stderr"
got=$?
set -e
if [ "$got" -eq 1 ] && grep -qF "invalid lifecycle transition" "$TMPD/stderr"; then
  pass=$((pass + 1))
else
  echo "FAIL [invalid infer]: expected transition rejection, got $got"
  cat "$TMPD/stdout" "$TMPD/stderr"
  fail=$((fail + 1))
fi

check_status 0 "infer" "$BIN" autollm infer "the " 6 1.0
check_output "stage:           infer" "infer stage"
check_output "response:" "decoded response"
check_output "model_checksum:" "lineage model checksum"
check_output "lineage:         " "lineage chain present"

check_status 0 "final status" "$BIN" autollm status
check_output "lifecycle_stage: posttrain" "final stage"
check_output "checkpoint_chain: " "checkpoint chain"
check_output "next_action:     hyperforge autollm infer <prompt>" "next action"

stage_count=$(grep -c '|autollm_stage|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
response_count=$(grep -c '|autollm_response|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$stage_count" -eq 3 ] && [ "$response_count" -eq 1 ]; then
  pass=$((pass + 1))
else
  echo "FAIL [journal]: expected 3 stages and 1 response, got $stage_count/$response_count"
  fail=$((fail + 1))
fi

check_status 0 "version" "$BIN" --version
check_output "hyperforge 0.1.0 (M24)" "version text"
check_status 2 "bad subcommand" "$BIN" autollm nonsense

echo "autollm lifecycle integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
