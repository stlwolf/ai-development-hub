#!/usr/bin/env bash
# shellcheck disable=SC2034
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

declare -A _MOCK_CAPTURE_OUTPUT
_MOCK_KILL_CALLS=()

# wez モック（capture count はサブシェル対応のためファイルベース）
wez() {
  if [[ "${1:-}" == "pane" && "${2:-}" == "capture" ]]; then
    local pane_id="${3:-}"
    local count_file="${_MOCK_TMPDIR}/capture_${pane_id}"
    local current=0
    [[ -f "$count_file" ]] && current=$(<"$count_file")
    echo $(( current + 1 )) > "$count_file"
    echo "${_MOCK_CAPTURE_OUTPUT[$pane_id]:-}"
    return 0
  fi
  if [[ "${1:-}" == "pane" && "${2:-}" == "kill" ]]; then
    _MOCK_KILL_CALLS+=("${3:-}")
    return 0
  fi
  return 1
}

mock_capture_count() {
  local pane_id="$1"
  local count_file="${_MOCK_TMPDIR}/capture_${pane_id}"
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
  _MOCK_CAPTURE_OUTPUT=()
  _MOCK_KILL_CALLS=()
  _MOCK_AUDIT_CALLS=()
  _MOCK_CLEANUP_CALLED=0
  _MOCK_KVS_WRITE_COUNT=0
  _MOCK_KVS_LAST_ARGS=""
  _OE_MONITOR_INTERRUPTED=0
  OE_CB_TIMEOUT=1800
  OE_CB_MAX_TURNS=10
  OE_CB_MAX_PANES=5
  OE_POLL_INTERVAL=2
  rm -f "${_MOCK_TMPDIR}"/capture_* 2>/dev/null || true
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

# --- テスト a: 単一ペイン EXIT:0 → ループ終了 ---

echo "=== Test a: 単一ペイン EXIT:0 → ループ終了 ==="
reset_mocks
_MOCK_CAPTURE_OUTPUT[p1]="task output
@@OE_EXIT:0
done"

oe_monitor_loop "sess-a" "p1"

assert_eq "OE_DONE_PANES count" "1" "${#OE_DONE_PANES[@]}"
assert_eq "OE_DONE_PANES[0]" "p1" "${OE_DONE_PANES[0]}"
assert_eq "OE_LAST_STATE[p1]" "success" "${OE_LAST_STATE[p1]}"
assert_eq "capture count for p1" "1" "$(mock_capture_count p1)"
assert_eq "KVS write count" "1" "$_MOCK_KVS_WRITE_COUNT"
assert_eq "KVS args include session/pane/state" "sess-a|p1|success" "$_MOCK_KVS_LAST_ARGS"
assert_contains "state_change emitted" "state_change|sess-a|p1|success|" "${_MOCK_AUDIT_CALLS[@]}"
assert_contains "session_end emitted" "session_end|sess-a|p1|success|" "${_MOCK_AUDIT_CALLS[@]}"
assert_eq "no kill calls" "0" "${#_MOCK_KILL_CALLS[@]}"
assert_eq "cleanup not called in monitor" "0" "$_MOCK_CLEANUP_CALLED"

# --- テスト b: CB タイムアウト発動 ---

echo ""
echo "=== Test b: CB タイムアウト発動 ==="
reset_mocks
OE_CB_TIMEOUT=0
_MOCK_CAPTURE_OUTPUT[p1]="no markers here"

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
_MOCK_CAPTURE_OUTPUT[p1]="@@OE_EXIT:0"
_MOCK_CAPTURE_OUTPUT[p2]="still running"

oe_monitor_loop "sess-c" "p1" "p2" || true

assert_eq "OE_DONE_PANES count" "1" "${#OE_DONE_PANES[@]}"
assert_eq "OE_DONE_PANES[0]" "p1" "${OE_DONE_PANES[0]}"
assert_eq "p1 capture count" "1" "$(mock_capture_count p1)"
assert_eq "p2 capture count" "3" "$(mock_capture_count p2)"
assert_contains "state_change for p1" "state_change|sess-c|p1|success|" "${_MOCK_AUDIT_CALLS[@]}"
assert_contains "session_end for p1" "session_end|sess-c|p1|success|" "${_MOCK_AUDIT_CALLS[@]}"
assert_contains "CB max_turns" \
  'circuit_breaker_triggered|sess-c|0||{"reason":"max_turns"}' \
  "${_MOCK_AUDIT_CALLS[@]}"
assert_eq "kill count" "2" "${#_MOCK_KILL_CALLS[@]}"

# --- テスト d: マーカーなし → ループ継続（max_turns で終了） ---

echo ""
echo "=== Test d: マーカーなし → ループ継続 ==="
reset_mocks
OE_CB_MAX_TURNS=3
_MOCK_CAPTURE_OUTPUT[p1]="just normal output"

oe_monitor_loop "sess-d" "p1" || true

assert_eq "OE_DONE_PANES count" "0" "${#OE_DONE_PANES[@]}"
assert_eq "p1 capture count" "3" "$(mock_capture_count p1)"
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

# --- テスト f: trap 復元 ---
echo ""
echo "=== Test f: trap 復元 ==="
reset_mocks
_MOCK_CAPTURE_OUTPUT[p1]="@@OE_EXIT:0"

oe_monitor_loop "sess-f" "p1"

assert_eq "INT trap cleared" "" "$(trap -p INT)"
assert_eq "TERM trap cleared" "" "$(trap -p TERM)"

# --- サマリ ---
echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
