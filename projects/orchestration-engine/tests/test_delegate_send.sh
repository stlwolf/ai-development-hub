#!/usr/bin/env bash
# test_delegate_send.sh — oe_send_line の単体テスト
#
# 改行拒否・pane 検証・list-panes 失敗の環境エラー区別・Enter 発火/--no-enter を
# tmux 関数モックで自動検証する（Issue #142 / Copilot 指摘）。実 tmux サーバ不要。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="${SCRIPT_DIR}/../lib/delegate-send.sh"

export OE_SEND_ENTER_DELAY=0   # テスト高速化（Enter 前の小休止を 0 に）

# --- モック tmux: list-panes は MOCK_LIVE_PANES、send-keys は MOCK_SENDKEYS_LOG に記録 ---
MOCK_LIVE_PANES="%5 %7"
MOCK_SENDKEYS_LOG=""
tmux() {
  case "${1:-} ${2:-}" in
    "list-panes -a"|"list-panes"*)
      if [[ -n "${MOCK_TMUX_FAIL:-}" ]]; then echo "no server running on socket" >&2; return 1; fi
      # shellcheck disable=SC2086
      printf '%s\n' $MOCK_LIVE_PANES ;;
    "send-keys"*) MOCK_SENDKEYS_LOG+="tmux $*"$'\n' ;;
    *) return 0 ;;
  esac
}

# shellcheck source=../lib/delegate-send.sh
source "$LIB"

pass=0; fail=0
ck() { # <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; pass=$((pass+1));
  else echo "  FAIL: $1 (want='$2' got='$3')"; fail=$((fail+1)); fi
}

echo "[1] 改行拒否 → rc 2 / send-keys 未呼び出し"
MOCK_SENDKEYS_LOG=""
rc=0; oe_send_line "%5" "$(printf 'a\nb')" >/dev/null 2>&1 || rc=$?
ck "newline reject rc=2" "2" "$rc"
ck "改行時は send-keys を呼ばない" "" "$MOCK_SENDKEYS_LOG"

echo "[2] pane 未指定 → rc 2"
rc=0; oe_send_line "" "x" >/dev/null 2>&1 || rc=$?
ck "empty pane rc=2" "2" "$rc"

echo "[3] 死ペイン（生存リストに無い）→ rc 1"
rc=0; oe_send_line "%999" "x" >/dev/null 2>&1 || rc=$?
ck "dead pane rc=1" "1" "$rc"

echo "[4] list-panes 失敗 → rc 2（環境エラー・ペイン無し rc1 と区別）"
MOCK_TMUX_FAIL=1; rc=0; oe_send_line "%5" "x" >/dev/null 2>&1 || rc=$?; unset MOCK_TMUX_FAIL
ck "list-panes fail rc=2" "2" "$rc"

echo "[5] 正常送信 + Enter 発火"
MOCK_SENDKEYS_LOG=""
rc=0; oe_send_line "%5" "hello" >/dev/null 2>&1 || rc=$?
ck "send rc=0" "0" "$rc"
ck "literal 'hello' を送信" "yes" "$(echo "$MOCK_SENDKEYS_LOG" | grep -q 'hello' && echo yes || echo no)"
ck "Enter 発火" "yes" "$(echo "$MOCK_SENDKEYS_LOG" | grep -q 'Enter' && echo yes || echo no)"

echo "[6] --no-enter（send_enter=0）→ Enter 撃たない"
MOCK_SENDKEYS_LOG=""
rc=0; oe_send_line "%5" "hello" "0" >/dev/null 2>&1 || rc=$?
ck "send rc=0" "0" "$rc"
ck "literal 'hello' を送信" "yes" "$(echo "$MOCK_SENDKEYS_LOG" | grep -q 'hello' && echo yes || echo no)"
ck "Enter を撃たない" "yes" "$(echo "$MOCK_SENDKEYS_LOG" | grep -q 'Enter' && echo no || echo yes)"

echo "=== RESULT: pass=${pass} fail=${fail} ==="
[[ "$fail" -eq 0 ]]
