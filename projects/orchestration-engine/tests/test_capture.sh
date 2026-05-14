#!/usr/bin/env bash
set -euo pipefail

# test_capture.sh — capture.sh のユニットテスト

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJECT_DIR

# constants.sh をロード
# shellcheck source=../lib/constants.sh
source "${PROJECT_DIR}/lib/constants.sh"

# capture.sh をロード
# shellcheck source=../lib/capture.sh
source "${PROJECT_DIR}/lib/capture.sh"

# wez コマンドのモック
wez() {
  # "pane capture <pane_id>" の場合にモック出力を返す
  if [[ "${1:-}" == "pane" && "${2:-}" == "capture" ]]; then
    echo "$_MOCK_WEZ_OUTPUT"
    return 0
  fi
  return 1
}

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

# --- _oe_capture_scan_parse テスト ---
echo "=== _oe_capture_scan_parse ==="

echo "-- EXIT マーカーあり (exit code 0) --"
_oe_capture_scan_parse "some output
@@OE_EXIT:0
trailing line"
assert_eq "marker_type" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "0" "$OE_SCAN_VALUE"
assert_eq "blocked_flag" "false" "$OE_SCAN_BLOCKED"

echo "-- EXIT マーカーあり (exit code 1) --"
_oe_capture_scan_parse "@@OE_EXIT:1"
assert_eq "marker_type" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "1" "$OE_SCAN_VALUE"

echo "-- EXIT マーカーあり (exit code 124) --"
_oe_capture_scan_parse "line1
line2
@@OE_EXIT:124"
assert_eq "marker_type" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "124" "$OE_SCAN_VALUE"

echo "-- EXIT マーカーあり (3 桁 exit code 255) --"
_oe_capture_scan_parse "@@OE_EXIT:255"
assert_eq "marker_type" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "255" "$OE_SCAN_VALUE"

echo "-- 複数マーカー → 最後の 1 つを採用 --"
_oe_capture_scan_parse "@@OE_EXIT:1
some middle output
@@OE_EXIT:0"
assert_eq "marker_type" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "0" "$OE_SCAN_VALUE"

echo "-- マーカーなし --"
_oe_capture_scan_parse "no markers here
just normal output"
assert_eq "marker_type" "" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "" "$OE_SCAN_VALUE"
assert_eq "blocked_flag" "false" "$OE_SCAN_BLOCKED"

echo "-- 空文字列 --"
_oe_capture_scan_parse ""
assert_eq "marker_type" "" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "" "$OE_SCAN_VALUE"

echo "-- 行途中のマーカーは無視（行頭アンカー） --"
_oe_capture_scan_parse "prefix @@OE_EXIT:0 suffix"
assert_eq "marker_type" "" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "" "$OE_SCAN_VALUE"

echo "-- 4 桁 exit code は無視（1-3 桁のみ） --"
_oe_capture_scan_parse "@@OE_EXIT:1234"
assert_eq "marker_type" "" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "" "$OE_SCAN_VALUE"

echo "-- 値なし @@OE_EXIT: は不一致 --"
_oe_capture_scan_parse "@@OE_EXIT:"
assert_eq "marker_type" "" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "" "$OE_SCAN_VALUE"

echo "-- @@OE_BLOCKED 検出 --"
_oe_capture_scan_parse "log line
@@OE_BLOCKED
@@OE_EXIT:2"
assert_eq "marker_type" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "2" "$OE_SCAN_VALUE"
assert_eq "blocked_flag" "true" "$OE_SCAN_BLOCKED"

# --- oe_capture_scan テスト（wez モック経由） ---
echo ""
echo "=== oe_capture_scan (wez mock) ==="

echo "-- wez モック出力から EXIT マーカー検出 --"
_MOCK_WEZ_OUTPUT="task output
@@OE_EXIT:2
done"
oe_capture_scan "42"
assert_eq "marker_type" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "2" "$OE_SCAN_VALUE"
assert_eq "blocked_flag" "false" "$OE_SCAN_BLOCKED"

echo "-- wez モック出力にマーカーなし --"
_MOCK_WEZ_OUTPUT="just normal output"
oe_capture_scan "42"
assert_eq "marker_type" "" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "" "$OE_SCAN_VALUE"
assert_eq "blocked_flag" "false" "$OE_SCAN_BLOCKED"

echo "-- CR 付きマーカーを正規化して検出 --"
_MOCK_WEZ_OUTPUT=$'line\r\n@@OE_EXIT:0\r\n'
oe_capture_scan "42"
assert_eq "marker_type" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "0" "$OE_SCAN_VALUE"

echo "-- ANSI 付きマーカーを正規化して検出 --"
_MOCK_WEZ_OUTPUT=$'\033[32m@@OE_EXIT:1\033[0m'
oe_capture_scan "42"
assert_eq "marker_type" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "1" "$OE_SCAN_VALUE"

# --- oe_capture_classify テスト ---
echo ""
echo "=== oe_capture_classify ==="

echo "-- exit_code=0 → success --"
oe_capture_classify 0
assert_eq "state" "success" "$OE_CLASSIFY_STATE"

echo "-- exit_code=1 → partial --"
oe_capture_classify 1
assert_eq "state" "partial" "$OE_CLASSIFY_STATE"

echo "-- exit_code=2 → retryable_failure --"
oe_capture_classify 2
assert_eq "state" "retryable_failure" "$OE_CLASSIFY_STATE"

echo "-- exit_code=2 + blocked_flag=true → blocked --"
oe_capture_classify 2 "true"
assert_eq "state" "blocked" "$OE_CLASSIFY_STATE"

echo "-- scan blocked_flag と classify の連携 --"
_oe_capture_scan_parse "@@OE_BLOCKED:needs-human
@@OE_EXIT:2"
oe_capture_classify "$OE_SCAN_VALUE" "$OE_SCAN_BLOCKED"
assert_eq "state" "blocked" "$OE_CLASSIFY_STATE"

echo "-- exit_code=2 + blocked_flag=false → retryable_failure --"
oe_capture_classify 2 "false"
assert_eq "state" "retryable_failure" "$OE_CLASSIFY_STATE"

echo "-- exit_code=124 → timeout --"
oe_capture_classify 124
assert_eq "state" "timeout" "$OE_CLASSIFY_STATE"

echo "-- exit_code=3 → protocol_error --"
oe_capture_classify 3
assert_eq "state" "protocol_error" "$OE_CLASSIFY_STATE"

echo "-- exit_code=255 → protocol_error --"
oe_capture_classify 255
assert_eq "state" "protocol_error" "$OE_CLASSIFY_STATE"

echo "-- exit_code=42 → protocol_error --"
oe_capture_classify 42
assert_eq "state" "protocol_error" "$OE_CLASSIFY_STATE"

# --- サマリ ---
echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
