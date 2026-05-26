#!/usr/bin/env bash
set -euo pipefail

# test_attach.sh — lib/attach.sh (oe_capture_attach) と bin/oe-capture (oe_capture_cli) のテスト
#
# wez は関数 mock で置換し hermetic に実行（実 wez 不要）。
# bin/oe-capture は末尾ガードにより source しても自動実行されない。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJECT_DIR

_TMP_DIR="${SCRIPT_DIR}/.tmp_test_attach_$$"
mkdir -p "$_TMP_DIR/state" "$_TMP_DIR/audit"
trap 'rm -rf "$_TMP_DIR"' EXIT

OE_DATA_DIR="$_TMP_DIR"
export OE_DATA_DIR

# wez モック（test_capture.sh と同形式）: "pane capture ..." のときだけ _MOCK_WEZ_OUTPUT を返す
wez() {
  if [[ "${1:-}" == "pane" && "${2:-}" == "capture" ]]; then
    echo "$_MOCK_WEZ_OUTPUT"
    return 0
  fi
  return 1
}
_MOCK_WEZ_OUTPUT=""

# bin/oe-capture を source（constants/session/capture/audit/attach も連鎖 source される）
# shellcheck source=../bin/oe-capture
source "${PROJECT_DIR}/bin/oe-capture"

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

# ---- Layer 1: oe_capture_attach (glue) ----
echo "=== oe_capture_attach (mock wez) ==="

echo "-- EXIT:0 → success + audit/KVS --"
_MOCK_WEZ_OUTPUT=$'task output\n@@OE_EXIT:0\ndone'
sid="S_SUCCESS_$$"
rc=0; oe_capture_attach "$sid" 42 50 || rc=$?
sf="${OE_STATE_DIR}/${sid}.state.json"
af="${OE_AUDIT_DIR}/${sid}.jsonl"
assert_eq "rc" "0" "$rc"
assert_eq "OE_ATTACH_STATE" "success" "$OE_ATTACH_STATE"
assert_eq "kvs .state" "success" "$(jq -r '.state' "$sf")"
assert_eq "kvs .pane_id" "42" "$(jq -r '.pane_id' "$sf")"
assert_eq "audit .event_type" "session_end" "$(jq -r '.event_type' "$af")"
assert_eq "audit .state" "success" "$(jq -r '.state' "$af")"
assert_eq "audit .payload.source" "attach" "$(jq -r '.payload.source' "$af")"
assert_eq "audit single line" "1" "$(wc -l < "$af" | tr -d ' ')"

echo "-- @@OE_BLOCKED + EXIT:2 → blocked --"
_MOCK_WEZ_OUTPUT=$'log\n@@OE_BLOCKED\n@@OE_EXIT:2'
sid="S_BLOCKED_$$"
rc=0; oe_capture_attach "$sid" 7 50 || rc=$?
sf="${OE_STATE_DIR}/${sid}.state.json"
assert_eq "rc" "0" "$rc"
assert_eq "OE_ATTACH_STATE" "blocked" "$OE_ATTACH_STATE"
assert_eq "kvs .state" "blocked" "$(jq -r '.state' "$sf")"
assert_eq "kvs .blockers" '["@@OE_BLOCKED"]' "$(jq -c '.blockers' "$sf")"

echo "-- マーカー無し → rc 1 / KVS 未生成 --"
_MOCK_WEZ_OUTPUT="just logs, no marker here"
sid="S_NOMARK_$$"
rc=0; oe_capture_attach "$sid" 1 50 || rc=$?
assert_eq "rc" "1" "$rc"
assert_eq "OE_ATTACH_STATE empty" "" "$OE_ATTACH_STATE"
assert_eq "kvs not created" "false" "$( [[ -f "${OE_STATE_DIR}/${sid}.state.json" ]] && echo true || echo false )"

echo "-- @@OE_VERIFY:pass 単独 (EXIT 無し) → rc 1 (未完了) --"
_MOCK_WEZ_OUTPUT=$'review output\n@@OE_VERIFY:pass'
sid="S_VERIFYONLY_$$"
rc=0; oe_capture_attach "$sid" 2 50 || rc=$?
assert_eq "rc" "1" "$rc"
assert_eq "kvs not created" "false" "$( [[ -f "${OE_STATE_DIR}/${sid}.state.json" ]] && echo true || echo false )"

# ---- Layer 2: oe_capture_cli (entry validation) ----
echo ""
echo "=== oe_capture_cli (入口バリデーション) ==="

echo "-- pane_id 先頭ゼロ '07' → exit 2 --"
rc=0; oe_capture_cli 07 >/dev/null 2>&1 || rc=$?
assert_eq "rc" "2" "$rc"

echo "-- pane_id 非整数 'abc' → exit 2 --"
rc=0; oe_capture_cli abc >/dev/null 2>&1 || rc=$?
assert_eq "rc" "2" "$rc"

echo "-- pane_id 未指定 → exit 2 --"
rc=0; oe_capture_cli >/dev/null 2>&1 || rc=$?
assert_eq "rc" "2" "$rc"

echo "-- --lines 非正整数 '0' → exit 2 --"
rc=0; oe_capture_cli 42 --lines 0 >/dev/null 2>&1 || rc=$?
assert_eq "rc" "2" "$rc"

echo "-- --session-id 非 ULID → exit 2 --"
rc=0; oe_capture_cli 42 --session-id not-a-ulid >/dev/null 2>&1 || rc=$?
assert_eq "rc" "2" "$rc"

echo "-- 未知オプション → exit 2 --"
rc=0; oe_capture_cli 42 --bogus >/dev/null 2>&1 || rc=$?
assert_eq "rc" "2" "$rc"

echo "-- 正常系 (自動生成 session_id, EXIT:0) → exit 0 + state=success 出力 --"
_MOCK_WEZ_OUTPUT=$'@@OE_EXIT:0'
rc=0; out="$(oe_capture_cli 99 2>/dev/null)" || rc=$?
assert_eq "rc" "0" "$rc"
assert_eq "stdout に state=success" "1" "$(printf '%s\n' "$out" | grep -c 'state=success')"

echo "-- 正常系 (--session-id 指定 ULID, fresh) → exit 0 + KVS --"
freshid="00000000000000000000000001"
_MOCK_WEZ_OUTPUT=$'@@OE_EXIT:0'
rc=0; oe_capture_cli 99 --session-id "$freshid" >/dev/null 2>&1 || rc=$?
assert_eq "rc" "0" "$rc"
assert_eq "kvs .state" "success" "$(jq -r '.state' "${OE_STATE_DIR}/${freshid}.state.json")"

echo "-- --session-id 衝突 (既存 state) → exit 2 で拒否 --"
collisionid="00000000000000000000000002"
printf '{"session_id":"%s","verification":{"x":1}}\n' "$collisionid" > "${OE_STATE_DIR}/${collisionid}.state.json"
rc=0; oe_capture_cli 99 --session-id "$collisionid" >/dev/null 2>&1 || rc=$?
assert_eq "rc" "2" "$rc"
# 既存ファイルが破壊されていない（verification 保持）
assert_eq "既存 state 非破壊" "1" "$(jq -r '.verification.x' "${OE_STATE_DIR}/${collisionid}.state.json")"

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
