#!/usr/bin/env bash
# notify.sh - Notification operations for wez CLI
#
# Sourced by bin/wez. Not intended for standalone execution.
# Naming: wez_* for public, _wez_* for private.

# --- Helper functions ---

_wez_notify_resolve_pane() {
  local opt_pane_id="$1"
  local json

  if [[ -n "$opt_pane_id" ]]; then
    if ! [[ "$opt_pane_id" =~ ^[0-9]+$ ]]; then
      wez_error "notify: invalid pane-id: $opt_pane_id"
      return "${WEZ_EXIT_USAGE}"
    fi
    if ! json=$(wezterm cli list --format json 2>/dev/null); then
      wez_error "notify: failed to list panes"
      return "${WEZ_EXIT_PANE_OP_FAILED}"
    fi
    local tty_name=""
    if command -v jq >/dev/null 2>&1; then
      tty_name=$(jq -r --arg id "$opt_pane_id" \
        '.[] | select((.pane_id | tostring) == $id) | .tty_name // ""' <<< "$json" 2>/dev/null) || true
    else
      tty_name=$(grep -A 30 -E "\"pane_id\":[[:space:]]*${opt_pane_id}[^0-9]" <<< "$json" \
        | grep -oE '"tty_name":[[:space:]]*"[^"]*"' | head -1 \
        | grep -oE '/dev/[^"]+') || true
    fi
    printf '%s\t%s\n' "$opt_pane_id" "$tty_name"
    return 0
  fi

  if ! json=$(wezterm cli list --format json 2>/dev/null); then
    wez_error "notify: failed to list panes"
    return "${WEZ_EXIT_PANE_OP_FAILED}"
  fi

  local pane_id="" tty_name=""
  if command -v jq >/dev/null 2>&1; then
    pane_id=$(jq -r '.[0].pane_id // ""' <<< "$json" 2>/dev/null) || true
    tty_name=$(jq -r '.[0].tty_name // ""' <<< "$json" 2>/dev/null) || true
  else
    pane_id=$(grep -oE '"pane_id":[[:space:]]*[0-9]+' <<< "$json" | head -1 | grep -oE '[0-9]+$') || true
    tty_name=$(grep -oE '"tty_name":[[:space:]]*"[^"]*"' <<< "$json" | head -1 | grep -oE '/dev/[^"]+') || true
  fi

  if [[ -z "$pane_id" ]]; then
    wez_error "notify: no panes found"
    return "${WEZ_EXIT_PANE_NOT_FOUND}"
  fi

  printf '%s\t%s\n' "$pane_id" "$tty_name"
}

_wez_notify_encode_payload() {
  local title="$1"
  local body="$2"
  local timeout="$3"
  printf '%s|%s|%s' "$title" "$body" "$timeout" | base64 | tr -d '\n'
}

_wez_notify_send_user_var() {
  local pane_id="$1"
  local var_name="$2"
  local encoded_value="$3"
  local tty_name="$4"

  # Primary: TTY direct write (-c: character device check to avoid writing to regular files)
  if [[ -n "$tty_name" ]] && [[ -c "$tty_name" ]] && [[ -w "$tty_name" ]]; then
    if printf '\033]1337;SetUserVar=%s=%s\007' "$var_name" "$encoded_value" > "$tty_name" 2>/dev/null; then
      printf 'tty\n'
      return 0
    fi
  fi

  # Fallback: command string via send-text
  local cmd
  cmd=$(printf "printf '\\033]1337;SetUserVar=%%s=%%s\\007' '%s' '%s'" "$var_name" "$encoded_value")
  if printf '%s\n' "$cmd" | wezterm cli send-text --pane-id "$pane_id" --no-paste 2>/dev/null; then
    printf 'send-text\n'
    return 0
  fi

  if ! _wez_pane_exists "$pane_id"; then
    wez_error "notify: pane ${pane_id} not found"
    return "${WEZ_EXIT_PANE_NOT_FOUND}"
  fi
  wez_error "notify: failed to send user-var to pane ${pane_id}"
  return "${WEZ_EXIT_PANE_OP_FAILED}"
}

# --- Main command ---

_wez_notify_help() {
  cat <<'EOF'
Usage: wez notify [options] <title> [body]

Send a notification via WezTerm user-var (OSC 1337 SetUserVar).
The notification payload is sent as the 'ai_notify' user-var in the format
'title|body|timeout' (base64 encoded). A Lua event handler in .wezterm.lua
is required to display the actual toast notification (Phase 2).

Arguments:
  <title>           Notification title (required, max 500 chars)
  [body]            Notification body (optional, max 2000 chars)

Options:
  --pane-id <ID>    Target pane (default: auto-detect first pane)
  --timeout <MS>    Toast duration in milliseconds (default: 4000)
  --socket <path>   WezTerm socket path (default: auto-detect)
  --json            Output result as JSON
  -h, --help        Show this help

Constraints:
  title and body must not contain '|' (pipe) or control characters.

Exit codes:
  0    Success
  1    Socket not found
  2    Connection failed
  3    Pane not found
  5    Send operation failed
  64   Usage error (missing title, invalid options, pipe char in text)
  127  wezterm not installed
EOF
}

wez_cmd_notify() {
  local opt_socket=""
  local opt_pane_id=""
  local opt_timeout="4000"
  local opt_json=false
  local title=""
  local body=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --socket)
        if [[ -z "${2:-}" ]]; then
          wez_error "notify: --socket requires a path argument"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_socket="$2"; shift
        ;;
      --pane-id)
        if [[ -z "${2:-}" ]]; then
          wez_error "notify: --pane-id requires a value"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_pane_id="$2"; shift
        ;;
      --timeout)
        if [[ -z "${2:-}" ]]; then
          wez_error "notify: --timeout requires a value"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_timeout="$2"; shift
        ;;
      --json) opt_json=true ;;
      --help|-h)
        _wez_notify_help
        return 0
        ;;
      -*)
        wez_error "notify: unknown option: $1"
        return "${WEZ_EXIT_USAGE}"
        ;;
      *)
        if [[ -z "$title" ]]; then
          title="$1"
        elif [[ -z "$body" ]]; then
          body="$1"
        else
          wez_error "notify: too many arguments"
          return "${WEZ_EXIT_USAGE}"
        fi
        ;;
    esac
    shift
  done

  # --- Validation ---

  if [[ -z "$title" ]]; then
    wez_error "notify: title is required"
    echo "Run 'wez notify --help' for usage information." >&2
    return "${WEZ_EXIT_USAGE}"
  fi

  if [[ ${#title} -gt 500 ]]; then
    wez_error "notify: title must not exceed 500 characters"
    return "${WEZ_EXIT_USAGE}"
  fi

  if [[ -n "$body" ]] && [[ ${#body} -gt 2000 ]]; then
    wez_error "notify: body must not exceed 2000 characters"
    return "${WEZ_EXIT_USAGE}"
  fi

  if [[ "$title" == *'|'* ]]; then
    wez_error "notify: title must not contain '|' (pipe character)"
    return "${WEZ_EXIT_USAGE}"
  fi
  if [[ "$title" =~ [[:cntrl:]] ]]; then
    wez_error "notify: title must not contain control characters"
    return "${WEZ_EXIT_USAGE}"
  fi

  if [[ -n "$body" ]]; then
    if [[ "$body" == *'|'* ]]; then
      wez_error "notify: body must not contain '|' (pipe character)"
      return "${WEZ_EXIT_USAGE}"
    fi
    if [[ "$body" =~ [[:cntrl:]] ]]; then
      wez_error "notify: body must not contain control characters"
      return "${WEZ_EXIT_USAGE}"
    fi
  fi

  if ! [[ "$opt_timeout" =~ ^(0|[1-9][0-9]*)$ ]]; then
    wez_error "notify: --timeout requires a numeric value (no leading zeros)"
    return "${WEZ_EXIT_USAGE}"
  fi
  if (( 10#$opt_timeout < 100 || 10#$opt_timeout > 60000 )); then
    wez_error "notify: --timeout must be between 100 and 60000 (milliseconds)"
    return "${WEZ_EXIT_USAGE}"
  fi

  # --- Socket discovery ---

  local socket exit_code=0
  socket=$(wez_discover_socket "$opt_socket") || exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    case $exit_code in
      "${WEZ_EXIT_NO_WEZTERM}")
        wez_error "notify: wezterm is not installed" ;;
      "${WEZ_EXIT_NOT_FOUND}")
        if [[ -n "$opt_socket" ]]; then
          wez_error "notify: specified socket not found: ${opt_socket}"
        else
          wez_error "notify: no WezTerm socket found"
        fi
        ;;
      "${WEZ_EXIT_CONN_FAIL}")
        wez_error "notify: socket connection failed" ;;
    esac
    return "$exit_code"
  fi

  if ! wez_verify_connection "$socket" >/dev/null; then
    wez_error "notify: socket connection failed"
    return "${WEZ_EXIT_CONN_FAIL}"
  fi

  export WEZTERM_UNIX_SOCKET="$socket"

  # --- Resolve pane ---

  local pane_info pane_id tty_name
  pane_info=$(_wez_notify_resolve_pane "$opt_pane_id") || return $?
  pane_id=$(printf '%s' "$pane_info" | cut -f1)
  tty_name=$(printf '%s' "$pane_info" | cut -f2)

  # --- Encode and send ---

  local encoded
  encoded=$(_wez_notify_encode_payload "$title" "$body" "$opt_timeout")

  local method
  method=$(_wez_notify_send_user_var "$pane_id" "ai_notify" "$encoded" "$tty_name") || return $?

  # --- Output ---

  if [[ "$opt_json" == true ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq -n \
        --arg pane_id "$pane_id" \
        --arg status "sent" \
        --arg method "$method" \
        --arg title "$title" \
        --arg timeout "$opt_timeout" \
        '{"pane_id": ($pane_id | tonumber), "status": $status, "method": $method, "title": $title, "timeout": ($timeout | tonumber)}'
    else
      local escaped_title="${title//\\/\\\\}"
      escaped_title="${escaped_title//\"/\\\"}"
      printf '{"pane_id":%s,"status":"sent","method":"%s","title":"%s","timeout":%s}\n' \
        "$pane_id" "$method" "$escaped_title" "$opt_timeout"
    fi
  fi
}
