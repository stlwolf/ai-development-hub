#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2317
set -euo pipefail

# test_monitor.sh — monitor.sh のユニットテスト

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJECT_DIR

# constants.sh をロード
# shellcheck source=../lib/constants.sh
source "${PROJECT_DIR}/lib/constants.sh"

# capture.sh をロード（oe_capture_scan / oe_capture_classify）
# shellcheck source=../lib/capture.sh
source "${PROJECT_DIR}/lib/capture.sh"

# audit.sh をロード（stub）
# shellcheck source=../lib/audit.sh
source "${PROJECT_DIR}/lib/audit.sh"

# cleanup.sh をロード（stub）
# shellcheck source=../lib/cleanup.sh
source "${PROJECT_DIR}/lib/cleanup.sh"

# monitor.sh をロード
# shellcheck source=../lib/monitor.sh
source "${PROJECT_DIR}/lib/monitor.sh"

# --- モック ---

_MOCK_TMPDIR="${SCRIPT_DIR}/.tmp_test_monitor_$$"
mkdir -p "$_MOCK_TMPDIR"
trap 'rm -rf "$_MOCK_TMPDIR"' EXIT

declare -A _MOCK_SCAN_OUTPUT
_MOCK_KILL_CALLS=()

# wez モック（CB の kill 経路用。#114/#98 以降 monitor は target を pane capture せず
# log ファイルを走査するため capture 分岐は廃止）
wez() {
  if [[ "${1:-}" == "pane" && "${2:-}" == "kill" ]]; then
    _MOCK_KILL_CALLS+=("${3:-}")
    return 0
  fi
  return 1
}

# _oe_target_log_path / _oe_scan_log_file のモック（#114/#98）
#
# monitor は `_oe_scan_log_file "$(_oe_target_log_path "$session_id" "$pane_id")"` を呼ぶ。
# 本テストは monitor の **ループ制御**（完了検知 / ポーリング継続 / CB）を対象にするため、
# scan 層をモックして pane 単位の入力と呼び出し回数を制御する（log ファイル走査の実体
# = capture.sh:_oe_scan_log_file / _oe_target_log_path は test_capture.sh で実ファイルで検証）。
# _oe_target_log_path を「pane_id をそのまま返す」よう上書きし、mock の scan へ pane_id を渡す。
_oe_target_log_path() {
  printf '%s' "$2"
}

# scan モック: 渡された path(=pane_id) で呼び出し回数を記録し、_MOCK_SCAN_OUTPUT[pane] を
# 実 parse (_oe_capture_scan_parse) に流して OE_SCAN_* を本物どおり設定する（parse 忠実性を保つ）。
_oe_scan_log_file() {
  local pane_id="$1"
  local count_file="${_MOCK_TMPDIR}/scan_${pane_id}"
  local current=0
  [[ -f "$count_file" ]] && current=$(<"$count_file")
  echo $(( current + 1 )) > "$count_file"

  OE_SCAN_MARKER_TYPE=""
  OE_SCAN_VALUE=""
  OE_SCAN_BLOCKED="false"
  OE_SCAN_EXIT_CODE=""
  OE_SCAN_VERIFY_RESULT=""
  _oe_capture_scan_parse "${_MOCK_SCAN_OUTPUT[$pane_id]:-}"
}

mock_scan_count() {
  local pane_id="$1"
  local count_file="${_MOCK_TMPDIR}/scan_${pane_id}"
  if [[ -f "$count_file" ]]; then
    cat "$count_file"
  else
    echo "0"
  fi
}

# sleep モック（即座に返す）
sleep() { :; }

# audit_emit トラッカー
_MOCK_AUDIT_CALLS=()
oe_audit_emit() {
  _MOCK_AUDIT_CALLS+=("$1|$2|$3|${4:-}|${5:-}")
}

# cleanup トラッカー
_MOCK_CLEANUP_CALLED=0
oe_cleanup() {
  _MOCK_CLEANUP_CALLED=1
}

# KVS write トラッカー
_MOCK_KVS_WRITE_COUNT=0
_MOCK_KVS_LAST_ARGS=""
oe_capture_write_kvs() {
  _MOCK_KVS_LAST_ARGS="${1:-}|${2:-}|${3:-}"
  (( _MOCK_KVS_WRITE_COUNT++ )) || true
}

# --- モックリセット ---

reset_mocks() {
  _MOCK_SCAN_OUTPUT=()
  _MOCK_KILL_CALLS=()
  _MOCK_AUDIT_CALLS=()
  _MOCK_CLEANUP_CALLED=0
  _MOCK_KVS_WRITE_COUNT=0
  _MOCK_KVS_LAST_ARGS=""
  _OE_MONITOR_INTERRUPTED=0
  _OE_INTERRUPT_METHOD=""
  OE_CB_TIMEOUT=1800
  OE_CB_MAX_TURNS=10
  OE_CB_MAX_PANES=5
  OE_POLL_INTERVAL=2
  rm -f "${_MOCK_TMPDIR}"/scan_* 2>/dev/null || true
}

# --- アサーション ---

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

assert_contains() {
  local label="$1"
  local needle="$2"
  shift 2
  local haystack=("$@")
  local item
  for item in "${haystack[@]}"; do
    if [[ "$item" == "$needle" ]]; then
      echo "  PASS: $label"
      (( PASS++ )) || true
      return 0
    fi
  done
  echo "  FAIL: $label (needle='$needle' not found in [${haystack[*]}])"
  (( FAIL++ )) || true
}

# #92: session_end は end HEAD を materialize した payload ({"git_head":...}) を持つため、
# 完全一致でなく prefix でアサートする (git_head 値は実行環境の HEAD で非決定的)。
assert_contains_prefix() {
  local label="$1"
  local prefix="$2"
  shift 2
  local haystack=("$@")
  local item
  for item in "${haystack[@]}"; do
    if [[ "$item" == "$prefix"* ]]; then
      echo "  PASS: $label"
      (( PASS++ )) || true
      return 0
    fi
  done
  echo "  FAIL: $label (prefix='$prefix' not found in [${haystack[*]}])"
  (( FAIL++ )) || true
}

# --- テスト a: 単一ペイン EXIT:0 → ループ終了 ---

echo "=== Test a: 単一ペイン EXIT:0 → ループ終了 ==="
reset_mocks
_MOCK_SCAN_OUTPUT[p1]="task output
@@OE_EXIT:0
done"

oe_monitor_loop "sess-a" "p1"

assert_eq "OE_DONE_PANES count" "1" "${#OE_DONE_PANES[@]}"
assert_eq "OE_DONE_PANES[0]" "p1" "${OE_DONE_PANES[0]}"
assert_eq "OE_LAST_STATE[p1]" "success" "$(_oe_monitor_last_state_get p1 || true)"
assert_eq "scan count for p1" "1" "$(mock_scan_count p1)"
assert_eq "KVS write count" "1" "$_MOCK_KVS_WRITE_COUNT"
assert_eq "KVS args include session/pane/state" "sess-a|p1|success" "$_MOCK_KVS_LAST_ARGS"
assert_contains "state_change emitted" "state_change|sess-a|p1|success|" "${_MOCK_AUDIT_CALLS[@]}"
assert_contains_prefix "session_end emitted (#92: git_head payload)" 'session_end|sess-a|p1|success|{"git_head":' "${_MOCK_AUDIT_CALLS[@]}"
assert_eq "no kill calls" "0" "${#_MOCK_KILL_CALLS[@]}"
assert_eq "cleanup not called in monitor" "0" "$_MOCK_CLEANUP_CALLED"

# --- テスト b: CB タイムアウト発動 ---

echo ""
echo "=== Test b: CB タイムアウト発動 ==="
reset_mocks
OE_CB_TIMEOUT=0
_MOCK_SCAN_OUTPUT[p1]="no markers here"

oe_monitor_loop "sess-b" "p1" || true

assert_eq "OE_DONE_PANES count" "0" "${#OE_DONE_PANES[@]}"
assert_contains "circuit_breaker_triggered" \
  'circuit_breaker_triggered|sess-b|0||{"reason":"timeout"}' \
  "${_MOCK_AUDIT_CALLS[@]}"
assert_eq "kill called for p1" "1" "${#_MOCK_KILL_CALLS[@]}"
assert_eq "killed pane" "p1" "${_MOCK_KILL_CALLS[0]}"

# --- テスト c: 複数ペイン — 1 つ完了 + 残り未完了 ---

echo ""
echo "=== Test c: 複数ペイン — 1 完了 + 1 未完了 ==="
reset_mocks
OE_CB_MAX_TURNS=3
_MOCK_SCAN_OUTPUT[p1]="@@OE_EXIT:0"
_MOCK_SCAN_OUTPUT[p2]="still running"

oe_monitor_loop "sess-c" "p1" "p2" || true

assert_eq "OE_DONE_PANES count" "1" "${#OE_DONE_PANES[@]}"
assert_eq "OE_DONE_PANES[0]" "p1" "${OE_DONE_PANES[0]}"
assert_eq "p1 scan count" "1" "$(mock_scan_count p1)"
assert_eq "p2 scan count" "3" "$(mock_scan_count p2)"
assert_contains "state_change for p1" "state_change|sess-c|p1|success|" "${_MOCK_AUDIT_CALLS[@]}"
assert_contains_prefix "session_end for p1 (#92: git_head payload)" 'session_end|sess-c|p1|success|{"git_head":' "${_MOCK_AUDIT_CALLS[@]}"
assert_contains "CB max_turns" \
  'circuit_breaker_triggered|sess-c|0||{"reason":"max_turns"}' \
  "${_MOCK_AUDIT_CALLS[@]}"
assert_eq "kill count" "2" "${#_MOCK_KILL_CALLS[@]}"

# --- テスト d: マーカーなし → ループ継続（max_turns で終了） ---

echo ""
echo "=== Test d: マーカーなし → ループ継続 ==="
reset_mocks
OE_CB_MAX_TURNS=3
_MOCK_SCAN_OUTPUT[p1]="just normal output"

oe_monitor_loop "sess-d" "p1" || true

assert_eq "OE_DONE_PANES count" "0" "${#OE_DONE_PANES[@]}"
assert_eq "p1 scan count" "3" "$(mock_scan_count p1)"
assert_contains "CB max_turns" \
  'circuit_breaker_triggered|sess-d|0||{"reason":"max_turns"}' \
  "${_MOCK_AUDIT_CALLS[@]}"

# --- テスト e: CB ペイン数超過 ---

echo ""
echo "=== Test e: CB ペイン数超過 ==="
reset_mocks
OE_CB_MAX_PANES=2

oe_monitor_loop "sess-e" "p1" "p2" "p3" || true

assert_contains "CB pane_count_exceeded" \
  'circuit_breaker_triggered|sess-e|0||{"reason":"max_panes"}' \
  "${_MOCK_AUDIT_CALLS[@]}"
assert_eq "kill count" "3" "${#_MOCK_KILL_CALLS[@]}"

# --- テスト g: interrupt（SIGINT 経路）---
echo ""
echo "=== Test g: interrupt (SIGINT) ==="
reset_mocks
_MOCK_SCAN_OUTPUT[p1]="running without marker"
OE_CB_MAX_TURNS=100
_OE_MONITOR_SLEEP_INT_PHASE=0
sleep() {
  if [[ $_OE_MONITOR_SLEEP_INT_PHASE -eq 0 ]]; then
    _OE_MONITOR_SLEEP_INT_PHASE=1
    return 0
  fi
  _OE_MONITOR_INTERRUPTED=1
  _OE_INTERRUPT_METHOD=SIGINT
  return 0
}

int_rc=0
oe_monitor_loop "sess-int" "p1" || int_rc=$?

assert_eq "interrupt exit code 130" "130" "$int_rc"
assert_contains "interrupt audit emitted" \
  'interrupt|sess-int|0||{"method":"SIGINT"}' \
  "${_MOCK_AUDIT_CALLS[@]}"

sleep() { :; }

# --- テスト f: trap 復元 ---
echo ""
echo "=== Test f: trap 復元 ==="
reset_mocks
_MOCK_SCAN_OUTPUT[p1]="@@OE_EXIT:0"

oe_monitor_loop "sess-f" "p1"

assert_eq "INT trap cleared" "" "$(trap -p INT)"
assert_eq "TERM trap cleared" "" "$(trap -p TERM)"

# --- サマリ ---
echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
