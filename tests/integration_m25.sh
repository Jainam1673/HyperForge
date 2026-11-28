#!/usr/bin/env bash
# M26 integration: full AutoDL HPO/NAS breadth.
# Run with: pixi run test-autodl-full
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/hyperforge"
TMPD="$(mktemp -d /tmp/opencode/hf-autodl-full.XXXXXX 2>/dev/null || mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
pass=0; fail=0

check_status() {
  local expected="$1"; local label="$2"; shift 2
  set +e
  (cd "$TMPD/workspace" && "$@") >"$TMPD/stdout" 2>"$TMPD/stderr"
  local got=$?; set -e
  if [ "$got" -ne "$expected" ]; then
    echo "FAIL [$label]: expected $expected, got $got"; cat "$TMPD/stdout" "$TMPD/stderr"; fail=$((fail+1))
  else pass=$((pass+1)); fi
}
check_output() {
  local pattern="$1"; local label="$2"
  if grep -qF "$pattern" "$TMPD/stdout"; then pass=$((pass+1)); else
    echo "FAIL [$label]: missing '$pattern'"; fail=$((fail+1)); fi
}
bash "$ROOT/scripts/mojo.sh" build -I "$ROOT/src" "$ROOT/src/main.mojo" -o "$BIN"
"$BIN" init "$TMPD/workspace" >/dev/null
for policy in grid random adaptive multifidelity; do
  check_status 0 "$policy" "$BIN" autodl full "$policy" 4 42 2
  check_output "policy:              $policy" "policy $policy"
done
check_output "policies:            grid, random, adaptive, multifidelity" "policy list"
check_output "architecture:        depth=" "structural NAS"
check_output "distinct_architectures:" "architecture diversity"
check_output "seeds:               2" "repeated seeds"
check_output "NAS varies structure; HPO varies validated parameters" "NAS/HPO distinction"
check_status 0 "version" "$BIN" --version
check_output "hyperforge 0.1.0 (M26)" "version text"
check_status 1 "bad policy" "$BIN" autodl full nonsense 4 42 2
count=$(grep -c '|autodl_full|' "$TMPD/workspace/experiments/hf-journal.hfj" || true)
if [ "$count" -eq 4 ]; then pass=$((pass+1)); else echo "FAIL [journal]: expected 4, got $count"; fail=$((fail+1)); fi
echo "autodl full integration: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then exit 1; fi
