#!/usr/bin/env bash
# pane.sh - Pane operations for wez CLI
#
# Sourced by bin/wez. Not intended for standalone execution.
# Layout: helper functions at top, dispatcher (wez_cmd_pane) at bottom.
# Naming: wez_* for public, _wez_* for private.

# --- Helper functions ---

_wez_pane_exists() {
  local pane_id="$1"
  local json
  if ! json=$(wezterm cli list --format json 2>/dev/null); then
    return 1
  fi
  if command -v jq >/dev/null 2>&1; then
    jq -e --argjson id "$pane_id" 'map(select(.pane_id == $id)) | length > 0' <<< "$json" >/dev/null 2>&1
  else
    # Boundary-aware match: pane_id must be followed by , or } (JSON delimiters)
    [[ "$json" == *"\"pane_id\":${pane_id},"* ]] \
      || [[ "$json" == *"\"pane_id\":${pane_id}}"* ]] \
      || [[ "$json" == *"\"pane_id\": ${pane_id},"* ]] \
      || [[ "$json" == *"\"pane_id\": ${pane_id}}"* ]]
  fi
}

_wez_strip_trailing_blank() {
  sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

_wez_strip_ansi() {
  # CSI sequences: ESC [ ... letter
  # OSC sequences (BEL terminated): ESC ] ... BEL
  # OSC sequences (ST terminated): ESC ] ... ESC backslash
  sed 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b\][^\x07]*\x07//g; s/\x1b\][^\x1b]*\x1b\\//g'
}

# --- Subcommand: list ---

_wez_pane_list() {
  local opt_quiet=false
  local opt_verbose=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quiet)   opt_quiet=true ;;
      --verbose) opt_verbose=true ;;
      --help|-h)
        cat <<'EOF'
Usage: wez pane list [options]

List all WezTerm panes as JSON.

Options:
  --quiet          Suppress status messages on stderr
  --verbose        Show pane count on stderr
  -h, --help       Show this help
EOF
        return 0
        ;;
      *)
        wez_error "pane list: unknown option: $1"
        return "${WEZ_EXIT_USAGE}"
        ;;
    esac
    shift
  done

  local json
  if ! json=$(wezterm cli list --format json 2>/dev/null); then
    wez_error "pane list: failed to list panes"
    return "${WEZ_EXIT_PANE_OP_FAILED}"
  fi

  if [[ "$opt_verbose" == true ]] && [[ "$opt_quiet" != true ]]; then
    local count=0
    if command -v jq >/dev/null 2>&1; then
      count=$(jq 'length' <<< "$json" 2>/dev/null) || count=0
    fi
    wez_info "pane list: ${count} panes"
  fi

  echo "$json"
}

# --- Subcommand: split ---

_wez_pane_split() {
  local opt_direction="--right"
  local opt_percent=""
  local opt_pane_id=""
  local opt_json=false
  local opt_wait_ready=false
  local opt_timeout=10
  local opt_cwd=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --right)       opt_direction="--right" ;;
      --bottom)      opt_direction="--bottom" ;;
      --left)        opt_direction="--left" ;;
      --top)         opt_direction="--top" ;;
      --percent)
        if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          wez_error "pane split: --percent requires a positive integer"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_percent="$2"; shift
        ;;
      --pane-id)
        if [[ -z "${2:-}" ]]; then
          wez_error "pane split: --pane-id requires a value"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_pane_id="$2"; shift
        ;;
      --cwd)
        if [[ -z "${2:-}" ]]; then
          wez_error "pane split: --cwd requires a path"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_cwd="$2"; shift
        ;;
      --json)        opt_json=true ;;
      --wait-ready)  opt_wait_ready=true ;;
      --timeout)
        if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          wez_error "pane split: --timeout requires a positive integer (seconds)"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_timeout="$2"; shift
        ;;
      --help|-h)
        cat <<'EOF'
Usage: wez pane split [options]

Split the current (or specified) pane and create a new one.
Default direction: --right.

Options:
  --right          Split horizontally, new pane on the right (default)
  --bottom         Split vertically, new pane on the bottom
  --left           Split horizontally, new pane on the left
  --top            Split vertically, new pane on the top
  --percent <N>    Size of the new pane as percentage (default: 50)
  --pane-id <ID>   Specify the source pane to split
  --cwd <PATH>     Set working directory for the new pane
  --json           Output result as JSON
  --wait-ready     Wait until the new pane is ready for input
  --timeout <SEC>  Timeout for --wait-ready in seconds (default: 10)
  -h, --help       Show this help
EOF
        return 0
        ;;
      *)
        wez_error "pane split: unknown option: $1"
        return "${WEZ_EXIT_USAGE}"
        ;;
    esac
    shift
  done

  local -a split_args=("$opt_direction")
  [[ -n "$opt_percent" ]] && split_args+=(--percent "$opt_percent")
  [[ -n "$opt_pane_id" ]] && split_args+=(--pane-id "$opt_pane_id")
  [[ -n "$opt_cwd" ]] && split_args+=(--cwd "$opt_cwd")

  local new_pane_id
  if ! new_pane_id=$(wezterm cli split-pane "${split_args[@]}" 2>/dev/null); then
    wez_error "pane split: failed to split pane"
    return "${WEZ_EXIT_PANE_OP_FAILED}"
  fi

  if [[ "$opt_wait_ready" == true ]]; then
    if ! _wez_wait_pane_ready "$new_pane_id" "$opt_timeout"; then
      wez_warn "pane split: timed out waiting for pane ${new_pane_id} to become ready"
      if [[ "$opt_json" == true ]]; then
        _wez_pane_split_json "$new_pane_id" "timeout"
      else
        echo "$new_pane_id"
      fi
      return "${WEZ_EXIT_TIMEOUT}"
    fi
  fi

  if [[ "$opt_json" == true ]]; then
    _wez_pane_split_json "$new_pane_id" "ok"
  else
    echo "$new_pane_id"
  fi
}

_wez_pane_split_json() {
  local pane_id="$1"
  local status="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -n --argjson pane_id "$pane_id" --arg status "$status" \
      '{"pane_id": $pane_id, "status": $status}'
  else
    printf '{"pane_id":%s,"status":"%s"}\n' "$pane_id" "$status"
  fi
}

# Polling: wait until pane output is non-empty and stable.
# Non-empty: [[ "$curr" == *[!$' \t\n']* ]]
# Stable: last 5 lines unchanged across 2 consecutive checks.
# Interval: 0.5s. Timeout: configurable (default 10s).
# Uses integer milliseconds to avoid bc dependency.
_wez_wait_pane_ready() {
  local pane_id="$1"
  local timeout="${2:-10}"
  local interval_ms=500
  local timeout_ms=$((timeout * 1000))
  local elapsed_ms=0
  local prev_tail=""

  while (( elapsed_ms < timeout_ms )); do
    local curr
    curr=$(wezterm cli get-text --pane-id "$pane_id" 2>/dev/null) || true

    if [[ "$curr" == *[!$' \t\n']* ]]; then
      local curr_tail
      curr_tail=$(tail -n 5 <<< "$curr")
      if [[ -n "$prev_tail" ]] && [[ "$curr_tail" == "$prev_tail" ]]; then
        return 0
      fi
      prev_tail="$curr_tail"
    fi

    sleep 0.5
    elapsed_ms=$((elapsed_ms + interval_ms))
  done

  return 1
}

# --- Subcommand: send ---

_wez_pane_send() {
  local opt_pane_id=""
  local opt_json=false
  local text=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pane-id)
        if [[ -z "${2:-}" ]]; then
          wez_error "pane send: --pane-id requires a value"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_pane_id="$2"; shift
        ;;
      --json)  opt_json=true ;;
      --help|-h)
        cat <<'EOF'
Usage: wez pane send <pane-id> <text>

Send text to a pane as if typed. Uses --no-paste mode.
Newlines and carriage returns in text are rejected.

Options:
  --pane-id <ID>   Target pane (alternative to positional argument)
  --json           Output result as JSON
  -h, --help       Show this help
EOF
        return 0
        ;;
      -*)
        wez_error "pane send: unknown option: $1"
        return "${WEZ_EXIT_USAGE}"
        ;;
      *)
        if [[ -z "$opt_pane_id" ]]; then
          opt_pane_id="$1"
        elif [[ -z "$text" ]]; then
          text="$1"
        else
          wez_error "pane send: too many arguments"
          return "${WEZ_EXIT_USAGE}"
        fi
        ;;
    esac
    shift
  done

  if [[ -z "$opt_pane_id" ]]; then
    wez_error "pane send: pane-id is required"
    return "${WEZ_EXIT_USAGE}"
  fi
  if [[ -z "$text" ]]; then
    wez_error "pane send: text is required"
    return "${WEZ_EXIT_USAGE}"
  fi

  # Reject newlines and carriage returns
  if [[ "$text" == *$'\n'* ]] || [[ "$text" == *$'\r'* ]]; then
    wez_error "pane send: text must not contain newlines or carriage returns"
    return "${WEZ_EXIT_USAGE}"
  fi

  if ! _wez_pane_exists "$opt_pane_id"; then
    wez_error "pane send: pane ${opt_pane_id} not found"
    return "${WEZ_EXIT_PANE_NOT_FOUND}"
  fi

  if ! printf '%s\n' "$text" | wezterm cli send-text --pane-id "$opt_pane_id" --no-paste 2>/dev/null; then
    if ! _wez_pane_exists "$opt_pane_id"; then
      wez_error "pane send: pane ${opt_pane_id} no longer exists"
      return "${WEZ_EXIT_PANE_NOT_FOUND}"
    fi
    wez_error "pane send: failed to send text to pane ${opt_pane_id}"
    return "${WEZ_EXIT_PANE_OP_FAILED}"
  fi

  if [[ "$opt_json" == true ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq -n --argjson pane_id "$opt_pane_id" '{"pane_id": $pane_id, "status": "sent"}'
    else
      printf '{"pane_id":%s,"status":"sent"}\n' "$opt_pane_id"
    fi
  fi
}

# --- Subcommand: capture ---

_wez_pane_capture() {
  local opt_pane_id=""
  local opt_lines=""
  local opt_raw=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pane-id)
        if [[ -z "${2:-}" ]]; then
          wez_error "pane capture: --pane-id requires a value"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_pane_id="$2"; shift
        ;;
      --lines)
        if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          wez_error "pane capture: --lines requires a positive integer"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_lines="$2"; shift
        ;;
      --raw) opt_raw=true ;;
      --help|-h)
        cat <<'EOF'
Usage: wez pane capture <pane-id> [options]

Capture text output from a pane.
Default: returns unattributed text with trailing blank lines stripped.

Options:
  --pane-id <ID>   Target pane (alternative to positional argument)
  --lines <N>      Capture only the last N lines
  --raw            Include ANSI escape sequences (uses get-text --escapes)
  -h, --help       Show this help
EOF
        return 0
        ;;
      -*)
        wez_error "pane capture: unknown option: $1"
        return "${WEZ_EXIT_USAGE}"
        ;;
      *)
        if [[ -z "$opt_pane_id" ]]; then
          opt_pane_id="$1"
        else
          wez_error "pane capture: too many arguments"
          return "${WEZ_EXIT_USAGE}"
        fi
        ;;
    esac
    shift
  done

  if [[ -z "$opt_pane_id" ]]; then
    wez_error "pane capture: pane-id is required"
    return "${WEZ_EXIT_USAGE}"
  fi

  if ! _wez_pane_exists "$opt_pane_id"; then
    wez_error "pane capture: pane ${opt_pane_id} not found"
    return "${WEZ_EXIT_PANE_NOT_FOUND}"
  fi

  local -a get_args=(--pane-id "$opt_pane_id")
  [[ -n "$opt_lines" ]] && get_args+=(--start-line "-${opt_lines}")
  [[ "$opt_raw" == true ]] && get_args+=(--escapes)

  local output
  if ! output=$(wezterm cli get-text "${get_args[@]}" 2>/dev/null); then
    if ! _wez_pane_exists "$opt_pane_id"; then
      wez_error "pane capture: pane ${opt_pane_id} no longer exists"
      return "${WEZ_EXIT_PANE_NOT_FOUND}"
    fi
    wez_error "pane capture: failed to capture from pane ${opt_pane_id}"
    return "${WEZ_EXIT_PANE_OP_FAILED}"
  fi

  if [[ "$opt_raw" == true ]]; then
    echo "$output"
  else
    echo "$output" | _wez_strip_trailing_blank
  fi
}

# --- Subcommand: kill ---

_wez_pane_kill() {
  local opt_pane_id=""
  local opt_json=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pane-id)
        if [[ -z "${2:-}" ]]; then
          wez_error "pane kill: --pane-id requires a value"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_pane_id="$2"; shift
        ;;
      --json)  opt_json=true ;;
      --help|-h)
        cat <<'EOF'
Usage: wez pane kill <pane-id> [options]

Kill (close) a pane. No confirmation prompt.

Options:
  --pane-id <ID>   Target pane (alternative to positional argument)
  --json           Output result as JSON
  -h, --help       Show this help
EOF
        return 0
        ;;
      -*)
        wez_error "pane kill: unknown option: $1"
        return "${WEZ_EXIT_USAGE}"
        ;;
      *)
        if [[ -z "$opt_pane_id" ]]; then
          opt_pane_id="$1"
        else
          wez_error "pane kill: too many arguments"
          return "${WEZ_EXIT_USAGE}"
        fi
        ;;
    esac
    shift
  done

  if [[ -z "$opt_pane_id" ]]; then
    wez_error "pane kill: pane-id is required"
    return "${WEZ_EXIT_USAGE}"
  fi

  if ! _wez_pane_exists "$opt_pane_id"; then
    wez_error "pane kill: pane ${opt_pane_id} not found"
    return "${WEZ_EXIT_PANE_NOT_FOUND}"
  fi

  if ! wezterm cli kill-pane --pane-id "$opt_pane_id" 2>/dev/null; then
    if ! _wez_pane_exists "$opt_pane_id"; then
      wez_error "pane kill: pane ${opt_pane_id} already gone"
      return "${WEZ_EXIT_PANE_NOT_FOUND}"
    fi
    wez_error "pane kill: failed to kill pane ${opt_pane_id}"
    return "${WEZ_EXIT_PANE_OP_FAILED}"
  fi

  if [[ "$opt_json" == true ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq -n --argjson pane_id "$opt_pane_id" '{"pane_id": $pane_id, "status": "killed"}'
    else
      printf '{"pane_id":%s,"status":"killed"}\n' "$opt_pane_id"
    fi
  fi
}

# --- Dispatcher ---

_wez_pane_help() {
  cat <<'EOF'
Usage: wez pane [--socket <path>] <subcommand> [options]

Manage WezTerm panes.

Subcommands:
  list      List all panes as JSON
  split     Split a pane to create a new one
  send      Send text to a pane
  capture   Capture text output from a pane
  kill      Kill (close) a pane

Options (before subcommand):
  --socket <path>  Use specific socket path (skip auto-detection)

Run 'wez pane <subcommand> --help' for more information.

Exit codes:
  0    Success
  1    Socket not found
  2    Connection failed
  3    Pane not found
  4    Timeout (--wait-ready)
  5    Pane operation failed
  64   Usage error
  127  wezterm not installed
EOF
}

# Two-stage parsing:
# Stage 1: Extract --socket and subcommand (--socket must precede subcommand)
# Stage 2: Forward remaining args to subcommand handler
wez_cmd_pane() {
  local opt_socket=""
  local subcmd=""
  local -a subcmd_args=()

  # Stage 1: parse --socket and extract subcommand
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --socket)
        if [[ -z "${2:-}" ]]; then
          wez_error "pane: --socket requires a path argument"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_socket="$2"
        shift
        ;;
      --help|-h|help)
        _wez_pane_help
        return 0
        ;;
      -*)
        wez_error "pane: unknown option: $1 (options must precede subcommand)"
        return "${WEZ_EXIT_USAGE}"
        ;;
      *)
        subcmd="$1"
        shift
        if [[ $# -gt 0 ]]; then
          subcmd_args=("$@")
        fi
        break
        ;;
    esac
    shift
  done

  if [[ -z "$subcmd" ]]; then
    _wez_pane_help
    return 0
  fi

  # Socket discovery and export
  local socket exit_code=0
  socket=$(wez_discover_socket "$opt_socket") || exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    case $exit_code in
      "${WEZ_EXIT_NO_WEZTERM}")
        wez_error "pane: wezterm is not installed"
        ;;
      "${WEZ_EXIT_NOT_FOUND}")
        if [[ -n "$opt_socket" ]]; then
          wez_error "pane: specified socket not found: ${opt_socket}"
        else
          wez_error "pane: no WezTerm socket found"
        fi
        ;;
      "${WEZ_EXIT_CONN_FAIL}")
        wez_error "pane: socket connection failed"
        ;;
    esac
    return "$exit_code"
  fi

  export WEZTERM_UNIX_SOCKET="$socket"

  # Stage 2: dispatch to subcommand
  case "$subcmd" in
    list)    _wez_pane_list ${subcmd_args[@]+"${subcmd_args[@]}"} ;;
    split)   _wez_pane_split ${subcmd_args[@]+"${subcmd_args[@]}"} ;;
    send)    _wez_pane_send ${subcmd_args[@]+"${subcmd_args[@]}"} ;;
    capture) _wez_pane_capture ${subcmd_args[@]+"${subcmd_args[@]}"} ;;
    kill)    _wez_pane_kill ${subcmd_args[@]+"${subcmd_args[@]}"} ;;
    *)
      wez_error "pane: unknown subcommand: ${subcmd}"
      echo "Run 'wez pane --help' for usage information." >&2
      return "${WEZ_EXIT_USAGE}"
      ;;
  esac
}
