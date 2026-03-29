#!/usr/bin/env bash
# WezTerm AI Mode PoC-02: Pane Operations
#
# Cursor / Claude Code統合ターミナルからWezTerm上でペイン操作を行う。
# ペイン作成 → コマンド送信 → 一覧取得 → クリーンアップの一連フローを検証。
#
# Usage:
#   bash 02-pane-operations.sh
#
# 前提: 01-socket-discovery.sh が source 済み、または WEZTERM_UNIX_SOCKET が設定済み

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ensure_socket() {
  if [[ -z "${WEZTERM_UNIX_SOCKET:-}" ]]; then
    echo "[setup] WEZTERM_UNIX_SOCKET not set, running discovery..." >&2
    # shellcheck source=01-socket-discovery.sh
    source "${SCRIPT_DIR}/01-socket-discovery.sh"
    wez_ensure_socket
  fi
}

echo "=== WezTerm Pane Operations PoC ==="
echo ""

ensure_socket
echo ""

echo "--- Step 1: Split pane (right) ---"
NEW_PANE_ID=$(wezterm cli split-pane --right --percent 30)
echo "  Created pane: $NEW_PANE_ID"
echo ""

sleep 1

echo "--- Step 2: Send command to new pane ---"
printf 'echo "Hello from AI Mode! Pane ID: %s"\n' "$NEW_PANE_ID" | wezterm cli send-text --pane-id "$NEW_PANE_ID" --no-paste
echo "  Command sent to pane $NEW_PANE_ID"
echo ""

sleep 1

echo "--- Step 3: List all panes (JSON) ---"
wezterm cli list --format json | python3 -m json.tool 2>/dev/null || wezterm cli list --format json
echo ""

echo "--- Step 4: Send another command ---"
printf 'pwd && date\n' | wezterm cli send-text --pane-id "$NEW_PANE_ID" --no-paste
echo "  Second command sent"
echo ""

sleep 1

echo "--- Step 5: Capture output from new pane ---"
echo "  Output from pane $NEW_PANE_ID:"
echo "  ---"
wezterm cli get-text --pane-id "$NEW_PANE_ID" | tail -10
echo "  ---"
echo ""

echo "--- Step 6: Cleanup - kill new pane ---"
read -r -p "Kill pane $NEW_PANE_ID? (y/N) " answer
if [[ "${answer,,}" == "y" ]]; then
  wezterm cli kill-pane --pane-id "$NEW_PANE_ID"
  echo "  Pane $NEW_PANE_ID killed"
else
  echo "  Skipped (pane $NEW_PANE_ID still alive)"
fi
echo ""

echo "=== PoC-02 PASSED ==="
