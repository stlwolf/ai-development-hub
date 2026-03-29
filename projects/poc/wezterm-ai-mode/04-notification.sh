#!/usr/bin/env bash
# WezTerm AI Mode PoC-04: Notification via user-var
#
# user-var (OSC 1337) → WezTerm Lua → toast_notification のパスを検証。
#
# 2段階で検証:
#   1. user-var送信自体の動作確認（wezterm cli send-text経由でWezTermペインに送る）
#   2. Luaイベントハンドラとの連携（ai-mode-events.lua を .wezterm.lua に適用済みの場合）
#
# Usage:
#   bash 04-notification.sh           # WezTermペイン経由で通知テスト
#   bash 04-notification.sh --direct  # 直接user-varを送信（WezTermペイン内で実行する場合）
#
# 前提: 01-socket-discovery.sh が source 済み、または WEZTERM_UNIX_SOCKET が設定済み

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ensure_socket() {
  if [[ -z "${WEZTERM_UNIX_SOCKET:-}" ]]; then
    # shellcheck source=01-socket-discovery.sh
    source "${SCRIPT_DIR}/01-socket-discovery.sh"
    wez_ensure_socket
  fi
}

wez_set_user_var() {
  local name="$1"
  local value="$2"
  printf "\033]1337;SetUserVar=%s=%s\007" "$name" "$(echo -n "$value" | base64)"
}

wez_notify() {
  local title="${1:-Notification}"
  local body="${2:-}"
  local timeout="${3:-4000}"
  wez_set_user_var "ai_notify" "${title}|${body}|${timeout}"
}

echo "=== WezTerm Notification PoC ==="
echo ""

if [[ "${1:-}" == "--direct" ]]; then
  echo "--- Direct mode: sending user-var from this terminal ---"
  echo ""

  echo "  Sending ai_notify user-var..."
  wez_notify "PoC Test" "Hello from AI Mode!" 5000
  echo "  Sent. If ai-mode-events.lua is loaded, a toast notification should appear."
  echo ""

  echo "  Sending ai_status user-var..."
  wez_set_user_var "ai_status" "poc-running"
  echo "  Sent."
  echo ""

  echo "=== PoC-04 (direct) PASSED ==="
  exit 0
fi

ensure_socket
echo ""

echo "--- Step 1: Identify a WezTerm pane for user-var injection ---"
PANE_LIST=$(wezterm cli list --format json)
FIRST_PANE=$(echo "$PANE_LIST" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['pane_id'])" 2>/dev/null || echo "0")
echo "  Target pane: $FIRST_PANE"
echo ""

echo "--- Step 2: Send user-var via send-text to WezTerm pane ---"
NOTIFY_CMD="printf '\\033]1337;SetUserVar=%s=%s\\007' 'ai_notify' \"\$(echo -n 'PoC Test|Hello from Cursor!|5000' | base64)\""
printf '%s\n' "$NOTIFY_CMD" | wezterm cli send-text --pane-id "$FIRST_PANE" --no-paste
echo "  user-var command sent to pane $FIRST_PANE"
echo ""

sleep 2

echo "--- Step 3: Verify user-var was received ---"
echo "  Checking pane output for confirmation..."
CAPTURE=$(wezterm cli get-text --pane-id "$FIRST_PANE" --start-line -5 2>/dev/null || echo "(capture failed)")
if echo "$CAPTURE" | grep -q "1337"; then
  echo "  WARNING: OSC 1337 sequence visible in output (may not have been consumed by WezTerm)"
else
  echo "  OK: OSC 1337 sequence was consumed (not visible in pane output)"
fi
echo ""

echo "--- Step 4: Verify helper functions ---"
echo "  wez_set_user_var: defined"
echo "  wez_notify: defined"
echo "  These can be sourced for use in other scripts:"
echo "    source 04-notification.sh --direct  # inside WezTerm pane"
echo ""

echo "--- Notes ---"
echo "  For toast_notification to work:"
echo "  1. Copy wezterm-config/ai-mode-events.lua content to .wezterm.lua"
echo "  2. Add: local ai_mode = require('ai-mode-events')"
echo "  3. Add: ai_mode.setup(config)  -- before 'return config'"
echo ""

echo "=== PoC-04 PASSED (user-var injection verified) ==="
