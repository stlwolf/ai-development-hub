#!/usr/bin/env bash
set -euo pipefail

# test_kvs.sh — capture.sh の KVS 書き込みテスト

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJECT_DIR

_TMP_DIR="${SCRIPT_DIR}/.tmp_test_kvs_$$"
mkdir -p "$_TMP_DIR/state"
trap 'rm -rf "$_TMP_DIR"' EXIT

OE_DATA_DIR="$_TMP_DIR"
export OE_DATA_DIR

# shellcheck source=../lib/constants.sh
source "${PROJECT_DIR}/lib/constants.sh"
# shellcheck source=../lib/capture.sh
source "${PROJECT_DIR}/lib/capture.sh"

PASS=0
FAIL=0

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    (( PASS++ )) || true
  else
    echo "  FAIL: $label (expected='$expected', actual='$actual')"
    (( FAIL++ )) || true
  fi
}

echo "=== oe_capture_write_kvs ==="

session_id="S02TEST"
state_file="${OE_STATE_DIR}/${session_id}.state.json"

oe_capture_write_kvs "$session_id" 12 "blocked"

assert_eq "state file exists" "true" "$( [[ -f "$state_file" ]] && echo true || echo false )"
assert_eq "session_id" "$session_id" "$(jq -r '.session_id' "$state_file")"
assert_eq "pane_id" "12" "$(jq -r '.pane_id' "$state_file")"
assert_eq "state blocked" "blocked" "$(jq -r '.state' "$state_file")"
assert_eq "outputs empty array" "[]" "$(jq -c '.outputs' "$state_file")"
assert_eq "blockers for blocked" '["@@OE_BLOCKED"]' "$(jq -c '.blockers' "$state_file")"
assert_eq "last_updated present" "true" "$(jq -r '.last_updated | length > 0' "$state_file")"

oe_capture_write_kvs "$session_id" 12 "success"

assert_eq "state success overwrite" "success" "$(jq -r '.state' "$state_file")"
assert_eq "blockers for non-blocked" "[]" "$(jq -c '.blockers' "$state_file")"

if compgen -G "${OE_STATE_DIR}/.${session_id}.state.json.*" > /dev/null; then
  echo "  FAIL: temp file leftover"
  (( FAIL++ )) || true
else
  echo "  PASS: no temp file leftover"
  (( PASS++ )) || true
fi

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
