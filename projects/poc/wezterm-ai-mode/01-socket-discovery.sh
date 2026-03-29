#!/usr/bin/env bash
# WezTerm AI Mode PoC-01: Socket Auto-Discovery
#
# Cursor / Claude Code統合ターミナルから親WezTermインスタンスの
# UNIXソケットを自動検出し、wezterm cli の接続を確立する。
#
# Usage:
#   source 01-socket-discovery.sh          # 関数定義のみ
#   source 01-socket-discovery.sh --run    # 検出実行 + 検証

set -euo pipefail

WEZTERM_SOCKET_DIR="${HOME}/.local/share/wezterm"
WEZTERM_SOCKET_PATTERN="gui-sock-*"

wez_discover_socket() {
  if [[ -n "${WEZTERM_UNIX_SOCKET:-}" ]]; then
    if [[ -S "$WEZTERM_UNIX_SOCKET" ]]; then
      echo "[discover] WEZTERM_UNIX_SOCKET already set: $WEZTERM_UNIX_SOCKET" >&2
      return 0
    else
      echo "[discover] WEZTERM_UNIX_SOCKET is set but socket not found: $WEZTERM_UNIX_SOCKET" >&2
      unset WEZTERM_UNIX_SOCKET
    fi
  fi

  local sockets=()
  if [[ -d "$WEZTERM_SOCKET_DIR" ]]; then
    while IFS= read -r -d '' sock; do
      if [[ -S "$sock" ]]; then
        sockets+=("$sock")
      fi
    done < <(find "$WEZTERM_SOCKET_DIR" -name "$WEZTERM_SOCKET_PATTERN" -print0 2>/dev/null)
  fi

  if [[ ${#sockets[@]} -eq 0 ]]; then
    echo "[discover] ERROR: No WezTerm sockets found in $WEZTERM_SOCKET_DIR" >&2
    return 1
  fi

  if [[ ${#sockets[@]} -gt 1 ]]; then
    echo "[discover] WARNING: Multiple sockets found (${#sockets[@]}), using newest" >&2
    local newest=""
    local newest_time=0
    for sock in "${sockets[@]}"; do
      local mtime
      mtime=$(stat -f %m "$sock" 2>/dev/null || stat -c %Y "$sock" 2>/dev/null || echo 0)
      if [[ "$mtime" -gt "$newest_time" ]]; then
        newest_time="$mtime"
        newest="$sock"
      fi
    done
    export WEZTERM_UNIX_SOCKET="$newest"
  else
    export WEZTERM_UNIX_SOCKET="${sockets[0]}"
  fi

  echo "[discover] Socket found: $WEZTERM_UNIX_SOCKET" >&2
  return 0
}

wez_verify_connection() {
  if [[ -z "${WEZTERM_UNIX_SOCKET:-}" ]]; then
    echo "[verify] ERROR: WEZTERM_UNIX_SOCKET not set. Run wez_discover_socket first." >&2
    return 1
  fi

  local output
  if output=$(wezterm cli list --format json 2>&1); then
    local pane_count
    pane_count=$(echo "$output" | grep -c '"pane_id"' || true)
    echo "[verify] OK: Connected to WezTerm ($pane_count panes found)" >&2
    return 0
  else
    echo "[verify] ERROR: Failed to connect: $output" >&2
    return 1
  fi
}

wez_ensure_socket() {
  wez_discover_socket && wez_verify_connection
}

if [[ "${1:-}" == "--run" ]]; then
  echo "=== WezTerm Socket Auto-Discovery PoC ==="
  echo ""

  echo "--- Step 1: Discover socket ---"
  if wez_discover_socket; then
    echo "  WEZTERM_UNIX_SOCKET=$WEZTERM_UNIX_SOCKET"
  else
    echo "  FAILED"
    exit 1
  fi
  echo ""

  echo "--- Step 2: Verify connection ---"
  if wez_verify_connection; then
    echo "  Connection verified"
  else
    echo "  FAILED"
    exit 1
  fi
  echo ""

  echo "--- Step 3: List panes ---"
  wezterm cli list
  echo ""

  echo "=== PoC-01 PASSED ==="
fi
