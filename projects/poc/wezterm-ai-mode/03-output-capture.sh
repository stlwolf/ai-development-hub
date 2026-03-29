#!/usr/bin/env bash
# WezTerm AI Mode PoC-03: Output Capture
#
# ペインの出力をプログラマティックに取得する。
# 既存ペイン（tmux内）のキャプチャと、フィルタリング処理を検証。
#
# Usage:
#   bash 03-output-capture.sh [pane-id]    # 指定ペインをキャプチャ
#   bash 03-output-capture.sh              # 全ペインの概要 + pane 0 を詳細キャプチャ
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

strip_ansi() {
  sed 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b\][^\x07]*\x07//g'
}

strip_trailing_blank() {
  sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

echo "=== WezTerm Output Capture PoC ==="
echo ""

ensure_socket
echo ""

TARGET_PANE="${1:-}"

if [[ -z "$TARGET_PANE" ]]; then
  echo "--- Step 1: List panes ---"
  wezterm cli list
  echo ""

  echo "--- Step 2: Capture viewport (pane 0, visible area) ---"
  echo "  Raw output:"
  echo "  ----"
  wezterm cli get-text --pane-id 0 | tail -20
  echo "  ----"
  echo ""

  echo "--- Step 3: Capture scrollback (pane 0, last 30 lines) ---"
  echo "  Raw output:"
  echo "  ----"
  wezterm cli get-text --pane-id 0 --start-line -30 | head -30
  echo "  ----"
  echo ""

  echo "--- Step 4: Capture with ANSI strip ---"
  echo "  Filtered output (last 15 lines, ANSI stripped, blank trimmed):"
  echo "  ----"
  wezterm cli get-text --pane-id 0 --start-line -15 | strip_ansi | strip_trailing_blank
  echo "  ----"
  echo ""

  echo "--- Step 5: Capture pane 1 for comparison ---"
  echo "  Pane 1 (last 10 lines):"
  echo "  ----"
  wezterm cli get-text --pane-id 1 --start-line -10 | strip_ansi | strip_trailing_blank
  echo "  ----"
  echo ""

else
  echo "--- Capture pane $TARGET_PANE ---"
  echo ""

  echo "  Viewport:"
  echo "  ----"
  wezterm cli get-text --pane-id "$TARGET_PANE" | strip_ansi | strip_trailing_blank
  echo "  ----"
  echo ""

  echo "  Last 50 lines (scrollback):"
  echo "  ----"
  wezterm cli get-text --pane-id "$TARGET_PANE" --start-line -50 | strip_ansi | strip_trailing_blank
  echo "  ----"
fi

echo ""
echo "=== PoC-03 PASSED ==="
