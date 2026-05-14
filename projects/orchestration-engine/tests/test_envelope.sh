#!/usr/bin/env bash
set -euo pipefail

# test_envelope.sh — envelope.sh のユニットテスト

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJECT_DIR

# constants.sh をロード
# shellcheck source=../lib/constants.sh
source "${PROJECT_DIR}/lib/constants.sh"

# envelope.sh をロード
# shellcheck source=../lib/envelope.sh
source "${PROJECT_DIR}/lib/envelope.sh"

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

cleanup() {
  rm -f /tmp/oe-TEST_SESSION_01-envelope.json
  rm -f /tmp/oe-TEST_SESSION_02-envelope.json
}
trap cleanup EXIT

# --- oe_envelope_create テスト ---
echo "=== oe_envelope_create ==="

echo "-- 正常な envelope 生成 + validate-envelope.sh pass --"
oe_envelope_create "TEST_SESSION_01" 42 "Test task description" "./output" 300
assert_eq "OE_ENVELOPE_PATH set" "/tmp/oe-TEST_SESSION_01-envelope.json" "$OE_ENVELOPE_PATH"
assert_eq "file exists" "true" "$( [[ -f "$OE_ENVELOPE_PATH" ]] && echo true || echo false )"

echo "-- JSON フィールド検証 --"
JSON="$OE_ENVELOPE_PATH"

assert_eq "session_id" "TEST_SESSION_01" "$(jq -r '.session_id' "$JSON")"
assert_eq "pane_id" "42" "$(jq -r '.pane_id' "$JSON")"
assert_eq "task.description" "Test task description" "$(jq -r '.task.description' "$JSON")"
assert_eq "task.output_dir" "./output" "$(jq -r '.task.output_dir' "$JSON")"
assert_eq "task.exit_conditions.marker" "@@OE_EXIT" "$(jq -r '.task.exit_conditions.marker' "$JSON")"
assert_eq "task.exit_conditions.timeout_seconds" "300" "$(jq -r '.task.exit_conditions.timeout_seconds' "$JSON")"
assert_eq "task.read_docs" "[]" "$(jq -c '.task.read_docs' "$JSON")"
assert_eq "task.use_skills" "[]" "$(jq -c '.task.use_skills' "$JSON")"
assert_eq "context.parent_session_id" "null" "$(jq -r '.context.parent_session_id' "$JSON")"
assert_eq "context.related_issues" "[]" "$(jq -c '.context.related_issues' "$JSON")"
assert_eq "context.shared_kvs_path" "null" "$(jq -r '.context.shared_kvs_path' "$JSON")"
assert_eq "constraints.max_panes" "$OE_CB_MAX_PANES" "$(jq -r '.constraints.max_panes' "$JSON")"

VOCAB="$(jq -c '.constraints.state_vocabulary | sort' "$JSON")"
assert_eq "constraints.state_vocabulary" '["blocked","done","progress","ready","spawn"]' "$VOCAB"

echo ""
echo "-- 異なるパラメータでの生成 --"
oe_envelope_create "TEST_SESSION_02" 99 "Another task" "/tmp/out" 1800
assert_eq "OE_ENVELOPE_PATH set" "/tmp/oe-TEST_SESSION_02-envelope.json" "$OE_ENVELOPE_PATH"

JSON2="$OE_ENVELOPE_PATH"
assert_eq "session_id" "TEST_SESSION_02" "$(jq -r '.session_id' "$JSON2")"
assert_eq "pane_id" "99" "$(jq -r '.pane_id' "$JSON2")"
assert_eq "timeout_seconds" "1800" "$(jq -r '.task.exit_conditions.timeout_seconds' "$JSON2")"

echo ""
echo "-- validate-envelope.sh 単体検証 --"
VALIDATE_RESULT="$("${PROJECT_DIR}/scripts/validate-envelope.sh" "$JSON2" 2>&1)" || true
assert_eq "validate passes" "OK: $JSON2" "$VALIDATE_RESULT"

# --- サマリ ---
echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
