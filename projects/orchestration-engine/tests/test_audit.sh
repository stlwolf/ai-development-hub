#!/usr/bin/env bash
set -euo pipefail

# test_audit.sh — audit.sh のユニットテスト

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJECT_DIR

_TMP_DIR="${SCRIPT_DIR}/.tmp_test_audit_$$"
mkdir -p "$_TMP_DIR/audit"
trap 'rm -rf "$_TMP_DIR"' EXIT

OE_DATA_DIR="$_TMP_DIR"
export OE_DATA_DIR

# shellcheck source=../lib/constants.sh
source "${PROJECT_DIR}/lib/constants.sh"
# shellcheck source=../lib/audit.sh
source "${PROJECT_DIR}/lib/audit.sh"

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

echo "=== oe_audit_emit ==="

session_id="S01TEST"
audit_file="${OE_AUDIT_DIR}/${session_id}.jsonl"

oe_audit_emit "state_change" "$session_id" 7 "" ""
oe_audit_emit "session_end" "$session_id" 0 "success" '{"exit_code":0,"note":"ok"}'

assert_eq "audit file exists" "true" "$( [[ -f "$audit_file" ]] && echo true || echo false )"
assert_eq "jsonl line count" "2" "$(wc -l < "$audit_file" | tr -d ' ')"

assert_eq "line1 state is null" "null" "$(jq -r 'select(.event_type=="state_change") | (.state|tostring)' "$audit_file")"
assert_eq "line1 payload default" "{}" "$(jq -c 'select(.event_type=="state_change") | .payload' "$audit_file")"
assert_eq "line2 state value" "success" "$(jq -r 'select(.event_type=="session_end") | .state' "$audit_file")"
assert_eq "line2 pane_id type number" "number" "$(jq -r 'select(.event_type=="session_end") | (.pane_id|type)' "$audit_file")"
assert_eq "line2 payload inserted" "ok" "$(jq -r 'select(.event_type=="session_end") | .payload.note' "$audit_file")"

oe_audit_emit "interrupt" "$session_id" 0 "" '{"method":"SIGINT"}'
assert_eq "jsonl line count after interrupt" "3" "$(wc -l < "$audit_file" | tr -d ' ')"
assert_eq "interrupt line state null" "null" "$(jq -r 'select(.event_type=="interrupt") | (.state|tostring)' "$audit_file")"
assert_eq "interrupt payload method" "SIGINT" "$(jq -r 'select(.event_type=="interrupt") | .payload.method' "$audit_file")"

echo ""
echo "=== invalid payload rejected ==="
if oe_audit_emit "session_end" "$session_id" 0 "success" '[]' 2>/dev/null; then
  assert_eq "invalid payload should fail" "should_fail" "passed"
else
  assert_eq "invalid payload rejected" "true" "true"
fi

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
