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

# ---- Step 4-3 Phase A: validate-session-state.sh の後方互換テスト ----
# 既存の oe_capture_write_kvs 出力（verification フィールド無し）が新 validator で PASS する
# = Step 4-2 で生成された state ファイルへの破壊的変更が起きていないことを保証する

echo ""
echo "=== validate-session-state.sh 後方互換 (Step 4-3 Phase A) ==="

# ULID 形式の session_id を使った最小有効ケース（既存 capture.sh の出力相当）
ulid_session_id="01KRMYHMET73WDE32JXD1TZ0A4"
ulid_state_file="${OE_STATE_DIR}/${ulid_session_id}.state.json"

oe_capture_write_kvs "$ulid_session_id" 5 "success"

if "${PROJECT_DIR}/scripts/validate-session-state.sh" "$ulid_state_file" > /dev/null 2>&1; then
  echo "  PASS: legacy KVS (verification なし) が validator で PASS"
  (( PASS++ )) || true
else
  echo "  FAIL: legacy KVS の validator が失敗"
  "${PROJECT_DIR}/scripts/validate-session-state.sh" "$ulid_state_file" 2>&1 | sed 's/^/    /'
  (( FAIL++ )) || true
fi

# verification + verification_summary を後付けで含めた KVS も validator で PASS する
echo ""
echo "=== validate-session-state.sh 拡張フィールド (Step 4-3 Phase A) ==="

extended_state_file="${OE_STATE_DIR}/${ulid_session_id}.extended.state.json"
cat > "$extended_state_file" <<'JSON'
{
  "session_id": "01KRMYHMET73WDE32JXD1TZ0A4",
  "pane_id": 5,
  "state": "success",
  "last_updated": "2026-05-15T12:34:56Z",
  "outputs": [],
  "blockers": [],
  "verification": {
    "12": {
      "result": "pass",
      "reviewer_session_id": "01KRMYHMETZZZZZZZZZZZZZZZZ",
      "reviewer_pane_id": 99,
      "issues_count": 0,
      "marker_raw": "@@OE_VERIFY:pass",
      "completed_at": "2026-05-15T12:35:00Z"
    },
    "13": {
      "result": "fail",
      "reviewer_session_id": "01KRMYHMETZZZZZZZZZZZZZZZY",
      "reviewer_pane_id": 100,
      "issues_count": 3,
      "marker_raw": "@@OE_VERIFY:fail",
      "completed_at": "2026-05-15T12:36:00Z"
    }
  },
  "verification_summary": {
    "total": 2,
    "passed": 1,
    "failed": 1,
    "warned": 0,
    "fail_rate": 0.5
  }
}
JSON

if "${PROJECT_DIR}/scripts/validate-session-state.sh" "$extended_state_file" > /dev/null 2>&1; then
  echo "  PASS: 拡張 KVS (verification + verification_summary) が validator で PASS"
  (( PASS++ )) || true
else
  echo "  FAIL: 拡張 KVS の validator が失敗"
  "${PROJECT_DIR}/scripts/validate-session-state.sh" "$extended_state_file" 2>&1 | sed 's/^/    /'
  (( FAIL++ )) || true
fi

# 不正値で FAIL することを確認
bad_state_file="${OE_STATE_DIR}/${ulid_session_id}.bad.state.json"
cat > "$bad_state_file" <<'JSON'
{
  "session_id": "01KRMYHMET73WDE32JXD1TZ0A4",
  "pane_id": 5,
  "state": "success",
  "last_updated": "2026-05-15T12:34:56Z",
  "verification": {
    "12": {
      "result": "invalid_value",
      "reviewer_session_id": "01KRMYHMETZZZZZZZZZZZZZZZZ",
      "reviewer_pane_id": 99,
      "completed_at": "2026-05-15T12:35:00Z"
    }
  }
}
JSON

if "${PROJECT_DIR}/scripts/validate-session-state.sh" "$bad_state_file" > /dev/null 2>&1; then
  echo "  FAIL: 不正な verification.result が validator で誤って PASS"
  (( FAIL++ )) || true
else
  echo "  PASS: 不正な verification.result が validator で FAIL を返す"
  (( PASS++ )) || true
fi

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
