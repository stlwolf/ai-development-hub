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

# --- #112: TUI 字下げ marker 対応（先頭/末尾空白許容、行末アンカー維持） ---
echo ""
echo "=== _oe_capture_scan_parse — #112 TUI 字下げ対応 ==="

echo "-- 字下げ EXIT marker（空白2: Claude Code TUI 実測ケース） --"
_oe_capture_scan_parse "pong
  @@OE_EXIT:0"
assert_eq "marker_type (字下げ)" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (字下げ)" "0" "$OE_SCAN_VALUE"

echo "-- タブ字下げ EXIT marker --"
_oe_capture_scan_parse $'\t@@OE_EXIT:1'
assert_eq "marker_type (タブ)" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (タブ)" "1" "$OE_SCAN_VALUE"

echo "-- 末尾空白付き EXIT marker --"
_oe_capture_scan_parse "@@OE_EXIT:124   "
assert_eq "marker_type (末尾空白)" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (末尾空白)" "124" "$OE_SCAN_VALUE"

echo "-- 字下げ + 後置テキスト（プロンプトエコー）は無視（行末アンカー維持） --"
_oe_capture_scan_parse "  正確に @@OE_EXIT:0 とだけ出力してください"
assert_eq "marker_type (字下げエコー)" "" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (字下げエコー)" "" "$OE_SCAN_VALUE"

echo "-- 字下げ marker の直後に非空白が続く行は無視 --"
_oe_capture_scan_parse "  @@OE_EXIT:0 done"
assert_eq "marker_type (marker後テキスト)" "" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (marker後テキスト)" "" "$OE_SCAN_VALUE"

echo "-- 字下げ @@OE_BLOCKED 検出 --"
_oe_capture_scan_parse "  @@OE_BLOCKED
  @@OE_EXIT:2"
assert_eq "blocked_flag (字下げ)" "true" "$OE_SCAN_BLOCKED"
assert_eq "value (字下げ BLOCKED+EXIT)" "2" "$OE_SCAN_VALUE"

echo "-- 末尾空白のみ @@OE_BLOCKED 検出（EXIT/VERIFY と対称化, SO 指摘） --"
_oe_capture_scan_parse "@@OE_BLOCKED   "
assert_eq "blocked_flag (末尾空白)" "true" "$OE_SCAN_BLOCKED"

echo "-- 字下げ + 末尾空白 @@OE_BLOCKED 検出 --"
_oe_capture_scan_parse "  @@OE_BLOCKED   "
assert_eq "blocked_flag (字下げ+末尾空白)" "true" "$OE_SCAN_BLOCKED"

echo "-- 字下げ + 理由 + 末尾空白 @@OE_BLOCKED 検出 --"
_oe_capture_scan_parse "  @@OE_BLOCKED:needs-human   "
assert_eq "blocked_flag (字下げ+理由+末尾空白)" "true" "$OE_SCAN_BLOCKED"

echo "-- @@OE_BLOCKED に英字が続く行は無視（誤検知回避） --"
_oe_capture_scan_parse "@@OE_BLOCKEDX"
assert_eq "blocked_flag (後続英字)" "false" "$OE_SCAN_BLOCKED"

echo "-- 字下げ @@OE_VERIFY 検出 --"
_oe_capture_scan_parse "  @@OE_VERIFY:pass"
assert_eq "verify_result (字下げ)" "pass" "$OE_SCAN_VERIFY_RESULT"

echo "-- ボックス装飾は非マッチ（scrape 本質限界の境界、#114 領域） --"
_oe_capture_scan_parse "│ @@OE_EXIT:0 │"
assert_eq "marker_type (ボックス装飾)" "" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (ボックス装飾)" "" "$OE_SCAN_VALUE"

echo "-- 引用/リスト glyph プレフィックスは非マッチ（#114 領域） --"
_oe_capture_scan_parse "> @@OE_EXIT:0"
assert_eq "marker_type (引用glyph)" "" "$OE_SCAN_MARKER_TYPE"
_oe_capture_scan_parse "- @@OE_EXIT:0"
assert_eq "marker_type (リストglyph)" "" "$OE_SCAN_MARKER_TYPE"

echo "-- コロン直後スペースは非マッチ（内部空白は救わない境界） --"
_oe_capture_scan_parse "@@OE_EXIT: 0"
assert_eq "marker_type (コロン直後スペース)" "" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (コロン直後スペース)" "" "$OE_SCAN_VALUE"

echo "-- 字下げ + 後置テキスト VERIFY はエコーとして非マッチ（EXIT と同じ行末アンカー） --"
_oe_capture_scan_parse "  @@OE_VERIFY:pass など出力してください"
assert_eq "verify_result (VERIFYエコー)" "" "$OE_SCAN_VERIFY_RESULT"

echo "-- 単独行エコーは本物の marker と区別不能（scrape 本質限界、#114 領域）--"
# プロンプトが `@@OE_EXIT:0` 単独行を復唱すると本物と同形になりマッチする。
# regex では救えないトレードオフを負例ではなく「既知の限界」として固定する。
_oe_capture_scan_parse "@@OE_EXIT:0"
assert_eq "marker_type (単独行エコー=本物と同形)" "EXIT" "$OE_SCAN_MARKER_TYPE"

# --- Step 4-3 F3: @@OE_VERIFY: 検出と二値保持 ---
echo ""
echo "=== _oe_capture_scan_parse — @@OE_VERIFY: (Step 4-3 F3) ==="

echo "-- VERIFY のみ (pass) --"
_oe_capture_scan_parse "review output
@@OE_VERIFY:pass"
assert_eq "verify_result" "pass" "$OE_SCAN_VERIFY_RESULT"
assert_eq "exit_code (空)" "" "$OE_SCAN_EXIT_CODE"
assert_eq "marker_type (VERIFY 単独 → VERIFY)" "VERIFY" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (VERIFY 単独 → pass)" "pass" "$OE_SCAN_VALUE"

echo "-- VERIFY のみ (fail) --"
_oe_capture_scan_parse "@@OE_VERIFY:fail"
assert_eq "verify_result" "fail" "$OE_SCAN_VERIFY_RESULT"
assert_eq "marker_type" "VERIFY" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "fail" "$OE_SCAN_VALUE"

echo "-- VERIFY のみ (warn) --"
_oe_capture_scan_parse "@@OE_VERIFY:warn"
assert_eq "verify_result" "warn" "$OE_SCAN_VERIFY_RESULT"

echo "-- VERIFY 不正値 → 無視 --"
_oe_capture_scan_parse "@@OE_VERIFY:invalid"
assert_eq "verify_result (不正値)" "" "$OE_SCAN_VERIFY_RESULT"
assert_eq "exit_code (不正値)" "" "$OE_SCAN_EXIT_CODE"
assert_eq "marker_type (不正値)" "" "$OE_SCAN_MARKER_TYPE"

echo "-- VERIFY 値なし @@OE_VERIFY: は無視 --"
_oe_capture_scan_parse "@@OE_VERIFY:"
assert_eq "verify_result (値なし)" "" "$OE_SCAN_VERIFY_RESULT"

echo "-- 行途中の VERIFY マーカーは無視 (行頭アンカー) --"
_oe_capture_scan_parse "prefix @@OE_VERIFY:pass suffix"
assert_eq "verify_result (行途中)" "" "$OE_SCAN_VERIFY_RESULT"

echo "-- VERIFY + EXIT 両方検出 (二値保持) --"
_oe_capture_scan_parse "task output
@@OE_VERIFY:pass
@@OE_EXIT:0"
assert_eq "verify_result (両方検出)" "pass" "$OE_SCAN_VERIFY_RESULT"
assert_eq "exit_code (両方検出)" "0" "$OE_SCAN_EXIT_CODE"
assert_eq "marker_type (両方 → EXIT 優先で後方互換)" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (両方 → exit_code)" "0" "$OE_SCAN_VALUE"

echo "-- VERIFY + EXIT 両方検出 (fail + 0) --"
_oe_capture_scan_parse "@@OE_VERIFY:fail
@@OE_EXIT:0"
assert_eq "verify_result (fail)" "fail" "$OE_SCAN_VERIFY_RESULT"
assert_eq "exit_code (0)" "0" "$OE_SCAN_EXIT_CODE"
assert_eq "marker_type" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value" "0" "$OE_SCAN_VALUE"

echo "-- 複数 VERIFY → 最後の 1 つを採用 --"
_oe_capture_scan_parse "@@OE_VERIFY:pass
middle output
@@OE_VERIFY:fail"
assert_eq "verify_result (最後)" "fail" "$OE_SCAN_VERIFY_RESULT"

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

echo "-- #112: CR + 字下げ併用をフルパイプ（oe_capture_scan 経由）で検出 --"
_MOCK_WEZ_OUTPUT=$'pong\r\n  @@OE_EXIT:0\r\n'
oe_capture_scan "42"
assert_eq "marker_type (CR+字下げ)" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (CR+字下げ)" "0" "$OE_SCAN_VALUE"

echo "-- #112: 全角空白(U+3000)字下げを正規化して検出（ロケール非依存）--"
_MOCK_WEZ_OUTPUT=$'\xE3\x80\x80@@OE_EXIT:0'
oe_capture_scan "42"
assert_eq "marker_type (U+3000字下げ)" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (U+3000字下げ)" "0" "$OE_SCAN_VALUE"

echo "-- #112: NBSP(U+00A0)字下げを正規化して検出 --"
_MOCK_WEZ_OUTPUT=$'\xC2\xA0@@OE_EXIT:1'
oe_capture_scan "42"
assert_eq "marker_type (NBSP字下げ)" "EXIT" "$OE_SCAN_MARKER_TYPE"
assert_eq "value (NBSP字下げ)" "1" "$OE_SCAN_VALUE"

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
