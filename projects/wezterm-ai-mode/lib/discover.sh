#!/usr/bin/env bash
# discover.sh - Socket auto-discovery for wez CLI
#
# Sourced by bin/wez. Library functions are silent by default (DJ-3):
# no stderr output. CLI handler (wez_cmd_discover) controls stderr via flags.

readonly _WEZ_SOCKET_DIR="${HOME}/.local/share/wezterm"
readonly _WEZ_SOCKET_PATTERN="gui-sock-*"

# Discover the best WezTerm socket.
# Override priority (DJ-2): --socket > WEZTERM_UNIX_SOCKET > auto-detect
#
# Args:
#   $1 - explicit socket path (optional, from --socket flag)
# Outputs:
#   stdout: socket path on success
# Returns:
#   WEZ_EXIT_SUCCESS / WEZ_EXIT_NOT_FOUND / WEZ_EXIT_CONN_FAIL / WEZ_EXIT_NO_WEZTERM
wez_discover_socket() {
  local explicit_socket="${1:-}"

  if ! command -v wezterm >/dev/null 2>&1; then
    return "${WEZ_EXIT_NO_WEZTERM}"
  fi

  # Priority 1: explicit --socket argument
  if [[ -n "$explicit_socket" ]]; then
    if [[ -S "$explicit_socket" ]]; then
      echo "$explicit_socket"
      return "${WEZ_EXIT_SUCCESS}"
    fi
    return "${WEZ_EXIT_NOT_FOUND}"
  fi

  # Priority 2: WEZTERM_UNIX_SOCKET environment variable
  if [[ -n "${WEZTERM_UNIX_SOCKET:-}" ]]; then
    if [[ -S "$WEZTERM_UNIX_SOCKET" ]]; then
      echo "$WEZTERM_UNIX_SOCKET"
      return "${WEZ_EXIT_SUCCESS}"
    fi
    return "${WEZ_EXIT_NOT_FOUND}"
  fi

  # Priority 3: auto-detect from socket directory
  _wez_auto_detect_socket
}

# Auto-detect socket using hybrid selection (DJ-2: mtime sort + connection verify).
# Outputs:
#   stdout: socket path on success
# Returns:
#   WEZ_EXIT_SUCCESS / WEZ_EXIT_NOT_FOUND
_wez_auto_detect_socket() {
  local sockets=()
  if [[ -d "$_WEZ_SOCKET_DIR" ]]; then
    while IFS= read -r -d '' sock; do
      if [[ -S "$sock" ]]; then
        sockets+=("$sock")
      fi
    done < <(find "$_WEZ_SOCKET_DIR" -name "$_WEZ_SOCKET_PATTERN" -print0 2>/dev/null)
  fi

  if [[ ${#sockets[@]} -eq 0 ]]; then
    return "${WEZ_EXIT_NOT_FOUND}"
  fi

  if [[ ${#sockets[@]} -eq 1 ]]; then
    echo "${sockets[0]}"
    return "${WEZ_EXIT_SUCCESS}"
  fi

  # Multiple sockets: sort by mtime descending, pick first that verifies
  _wez_sort_by_mtime "${sockets[@]}"

  local sock
  for sock in "${_WEZ_SORTED_SOCKETS[@]}"; do
    if _wez_try_connect "$sock" >/dev/null 2>&1; then
      echo "$sock"
      return "${WEZ_EXIT_SUCCESS}"
    fi
  done

  # Sockets found but none passed connection verify
  return "${WEZ_EXIT_CONN_FAIL}"
}

# Sort socket paths by mtime descending (newest first).
# Uses stat -f %m (macOS) with stat -c %Y (Linux) fallback.
# Result is stored in _WEZ_SORTED_SOCKETS (avoids bash 3.2 incompatible local -n).
# Args:
#   $@  - socket paths
_WEZ_SORTED_SOCKETS=()
_wez_sort_by_mtime() {
  local -a pairs=()
  local sock mtime
  for sock in "$@"; do
    mtime=$(stat -f %m "$sock" 2>/dev/null || stat -c %Y "$sock" 2>/dev/null || echo 0)
    pairs+=("${mtime} ${sock}")
  done

  _WEZ_SORTED_SOCKETS=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && _WEZ_SORTED_SOCKETS+=("${line#* }")
  done < <(printf '%s\n' "${pairs[@]}" | sort -k1 -rn)
}

# Try connecting to a socket via wezterm cli list.
# Args:
#   $1 - socket path
# Outputs:
#   stdout: pane count on success
# Returns:
#   0 on success, non-zero on failure
_wez_try_connect() {
  local sock="$1"
  local output
  if output=$(WEZTERM_UNIX_SOCKET="$sock" wezterm cli list --format json 2>/dev/null); then
    local pane_count
    if command -v jq >/dev/null 2>&1; then
      pane_count=$(echo "$output" | jq 'length' 2>/dev/null) || pane_count=0
    else
      pane_count=$(echo "$output" | grep -c '"pane_id"' 2>/dev/null) || pane_count=0
    fi
    [[ "$pane_count" =~ ^[0-9]+$ ]] || pane_count=0
    echo "$pane_count"
    return 0
  fi
  return 1
}

# Verify connection to a specific socket.
# Args:
#   $1 - socket path
# Outputs:
#   stdout: pane count
# Returns:
#   WEZ_EXIT_SUCCESS / WEZ_EXIT_CONN_FAIL
wez_verify_connection() {
  local sock="$1"
  local pane_count
  if pane_count=$(_wez_try_connect "$sock"); then
    echo "$pane_count"
    return "${WEZ_EXIT_SUCCESS}"
  fi
  return "${WEZ_EXIT_CONN_FAIL}"
}

# CLI handler for 'wez discover' subcommand.
# Parses options and delegates to library functions.
# Output control (DJ-3): default stderr status + stdout socket path.
# --json: stdout JSON only, stderr silent.
# --quiet: suppress stderr even in default mode.
# --verbose: enable stderr even with --json.
wez_cmd_discover() {
  local opt_json=false
  local opt_quiet=false
  local opt_verbose=false
  local opt_socket=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)    opt_json=true ;;
      --quiet)   opt_quiet=true ;;
      --verbose) opt_verbose=true ;;
      --socket)
        if [[ -z "${2:-}" ]]; then
          wez_error "--socket requires a path argument"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_socket="$2"
        shift
        ;;
      --help|-h)
        _wez_discover_help
        return 0
        ;;
      *)
        wez_error "Unknown option: $1"
        return "${WEZ_EXIT_USAGE}"
        ;;
    esac
    shift
  done

  # Determine stderr behavior:
  # --json implies quiet stderr; --verbose re-enables it; --quiet always silences
  local stderr_enabled=true
  if [[ "$opt_json" == true ]]; then
    stderr_enabled=false
    [[ "$opt_verbose" == true ]] && stderr_enabled=true
  fi
  [[ "$opt_quiet" == true ]] && stderr_enabled=false

  # Check wezterm installation
  if ! command -v wezterm >/dev/null 2>&1; then
    [[ "$stderr_enabled" == true ]] && wez_error "wezterm is not installed"
    return "${WEZ_EXIT_NO_WEZTERM}"
  fi

  # Discover socket
  [[ "$stderr_enabled" == true ]] && wez_info "Searching for WezTerm socket..."

  local socket exit_code=0
  socket=$(wez_discover_socket "$opt_socket") || exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    if [[ "$stderr_enabled" == true ]]; then
      if [[ -n "$opt_socket" ]]; then
        wez_error "Specified socket not found: ${opt_socket}"
      elif [[ -n "${WEZTERM_UNIX_SOCKET:-}" ]]; then
        wez_error "WEZTERM_UNIX_SOCKET socket not found: ${WEZTERM_UNIX_SOCKET}"
      elif [[ $exit_code -eq "${WEZ_EXIT_CONN_FAIL}" ]]; then
        wez_error "Sockets found but all failed connection verification"
      else
        wez_error "No WezTerm sockets found in ${_WEZ_SOCKET_DIR}"
      fi
    fi
    return "$exit_code"
  fi

  [[ "$stderr_enabled" == true ]] && wez_info "Socket found: ${socket}"

  # Verify connection
  [[ "$stderr_enabled" == true ]] && wez_info "Verifying connection..."

  local pane_count
  if ! pane_count=$(wez_verify_connection "$socket"); then
    [[ "$stderr_enabled" == true ]] && wez_error "Failed to connect to socket: ${socket}"
    return "${WEZ_EXIT_CONN_FAIL}"
  fi

  [[ "$stderr_enabled" == true ]] && wez_info "Connected (${pane_count} panes)"

  # Output result
  if [[ "$opt_json" == true ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg socket "$socket" --argjson pane_count "$pane_count" \
        '{"socket": $socket, "pane_count": $pane_count}'
    else
      printf '{"socket":"%s","pane_count":%s}\n' "$socket" "$pane_count"
    fi
  else
    echo "$socket"
  fi

  return "${WEZ_EXIT_SUCCESS}"
}

_wez_discover_help() {
  cat <<'EOF'
Usage: wez discover [options]

Auto-detect WezTerm socket and verify connection.

Options:
  --json           Output as JSON (suppresses stderr by default)
  --quiet          Suppress status messages on stderr
  --verbose        Show status messages even with --json
  --socket <path>  Use specific socket path (skip auto-detection)
  -h, --help       Show this help

Override priority: --socket > WEZTERM_UNIX_SOCKET env var > auto-detect

Exit codes:
  0    Success
  1    Socket not found
  2    Connection failed
  64   Usage error (invalid option or missing argument)
  127  wezterm not installed
EOF
}
