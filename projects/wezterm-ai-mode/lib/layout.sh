#!/usr/bin/env bash
# layout.sh - Declarative board construction for wez CLI (PoC: parent + N children)
#
# Sourced by bin/wez. Not intended for standalone execution.
# Layout: helper functions at top, dispatcher (wez_cmd_layout) at bottom.
# Naming: wez_* for public, _wez_* for private.
#
# Thin orchestration layer over the existing pane primitives (_wez_pane_split /
# _wez_pane_kill / _wez_pane_activate). wez-only, board-construction only,
# NON-IDEMPOTENT (create-only). Reads named JSON presets from lib/layouts/.

# Directory holding layout preset JSON files (lib/layouts/<name>.json).
# Resolved relative to this script so it works regardless of the caller's cwd.
_wez_layout_presets_dir() {
  local src_dir
  src_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s\n' "${src_dir}/layouts"
}

# --- Subcommand: list ---

_wez_layout_list() {
  # list takes no positional arguments; only --help / unknown-option handling.
  if [[ $# -gt 0 ]]; then
    case "$1" in
      --help|-h)
        cat <<'EOF'
Usage: wez layout list

List the names of available layout presets (lib/layouts/*.json).
EOF
        return 0
        ;;
      *)
        wez_error "layout list: unknown option: $1"
        return "${WEZ_EXIT_USAGE}"
        ;;
    esac
  fi

  local dir
  dir="$(_wez_layout_presets_dir)"
  if [[ ! -d "$dir" ]]; then
    return 0
  fi

  local f name
  for f in "$dir"/*.json; do
    [[ -e "$f" ]] || continue
    name="$(basename "$f" .json)"
    printf '%s\n' "$name"
  done
}

# --- Subcommand: apply ---

_wez_layout_apply_help() {
  cat <<'EOF'
Usage: wez layout apply <name> [options]

Apply a declarative layout preset to build a board (parent + N children).
Splits are performed in preset order from the root (self) pane.
Requires jq.

NON-IDEMPOTENT: layout apply is create-only. Running it twice doubles the panes
(no ownership tracking / no replace). Apply once against a clean baseline.

Options:
  --focus <target>   Pane to focus when done (default: root). Either "root",
                     a step id from the preset, or a numeric pane id. An
                     invalid target is rejected (exit 64) before any split.
  --json             Output result as JSON
  -h, --help         Show this help

Exit codes:
  0    Success
  1    Preset not found
  3    Root pane (self) not found (WEZTERM_PANE unset/stale)
  5    A split failed; created panes were rolled back (killed in reverse)
  64   Usage error (bad argument, invalid preset name/schema, jq not installed)
EOF
}

_wez_layout_apply() {
  local opt_name=""
  local opt_focus=""
  local opt_json=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --focus)
        if [[ -z "${2:-}" ]]; then
          wez_error "layout apply: --focus requires a value"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_focus="$2"; shift
        ;;
      --json)  opt_json=true ;;
      --help|-h)
        _wez_layout_apply_help
        return 0
        ;;
      -*)
        wez_error "layout apply: unknown option: $1"
        return "${WEZ_EXIT_USAGE}"
        ;;
      *)
        if [[ -z "$opt_name" ]]; then
          opt_name="$1"
        else
          wez_error "layout apply: too many arguments"
          return "${WEZ_EXIT_USAGE}"
        fi
        ;;
    esac
    shift
  done

  if [[ -z "$opt_name" ]]; then
    wez_error "layout apply: preset name is required"
    return "${WEZ_EXIT_USAGE}"
  fi

  # jq is mandatory for layout (preset parsing + map output). (W6)
  if ! command -v jq >/dev/null 2>&1; then
    wez_error "layout apply: jq is required but not installed; install jq (e.g. brew install jq)"
    return "${WEZ_EXIT_USAGE}"
  fi

  # Reject preset names that could escape the layouts directory (C2). Only a
  # single path segment of [A-Za-z0-9._-] is allowed; '/', '..' and empty are
  # rejected so "${presets_dir}/${opt_name}.json" cannot read arbitrary files.
  if [[ ! "$opt_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    wez_error "layout apply: invalid preset name '${opt_name}' (allowed: letters, digits, '.', '_', '-'; no '/' or '..')"
    return "${WEZ_EXIT_USAGE}"
  fi

  # --- Load + validate preset BEFORE resolving root (W1) ---
  # Preset problems are usage errors (1/64) independent of the live pane state;
  # resolving root first would mask a missing preset as a root-not-found (3).
  local preset_file
  preset_file="$(_wez_layout_presets_dir)/${opt_name}.json"
  if [[ ! -f "$preset_file" ]]; then
    wez_error "layout apply: preset not found: ${opt_name} (${preset_file})"
    return "${WEZ_EXIT_NOT_FOUND}"
  fi

  local preset
  if ! preset=$(jq -e '.' "$preset_file" 2>/dev/null); then
    wez_error "layout apply: preset ${opt_name} is not valid JSON"
    return "${WEZ_EXIT_USAGE}"
  fi

  # --- Validate schema (PoC constraints) ---
  # version present, root == "self", steps is a non-empty array, each step has a
  # non-empty string id that is NOT all-digits (W3: a numeric id collides with
  # the numeric-pane-id meaning of --focus), from == "root", dir in
  # {bottom,right,left,top}, percent an integer 1-99 (W2).
  if ! jq -e '
    (.version != null)
    and (.root == "self")
    and ((.steps | type) == "array")
    and ((.steps | length) > 0)
    and (all(.steps[];
          ((.id | type) == "string") and ((.id | length) > 0)
          and ((.id | test("^[0-9]+$")) | not)
          and (.from == "root")
          and (.dir as $d | ["bottom","right","left","top"] | index($d) != null)
          and ((.percent | type) == "number")
          and ((.percent | floor) == .percent)
          and (.percent >= 1) and (.percent <= 99)
        ))
  ' "$preset_file" >/dev/null 2>&1; then
    wez_error "layout apply: preset ${opt_name} has an invalid schema (expected {version, root:\"self\", steps:[{id (non-empty, not all-digits), from:\"root\", dir in bottom|right|left|top, percent integer 1-99}]}); PoC supports root/from=self/root only"
    return "${WEZ_EXIT_USAGE}"
  fi

  # focus from the preset (optional). Default to root. --focus overrides.
  local preset_focus
  preset_focus="$(jq -r '.focus // "root"' <<< "$preset" 2>/dev/null)"

  # --- Resolve root (self) once (SO reconcile #5) ---
  local root
  if ! root=$(_wez_resolve_self_pane); then
    wez_error "layout apply: could not resolve root pane from WEZTERM_PANE"
    return "${WEZ_EXIT_PANE_NOT_FOUND}"
  fi
  if ! _wez_pane_exists "$root"; then
    wez_error "layout apply: root pane ${root} not found"
    return "${WEZ_EXIT_PANE_NOT_FOUND}"
  fi

  local step_count
  step_count="$(jq '.steps | length' <<< "$preset")"

  # --- Resolve effective focus spec (DJ-d): default root, --focus overrides preset focus ---
  local focus_spec="$preset_focus"
  [[ -n "$opt_focus" ]] && focus_spec="$opt_focus"

  # --- Validate the focus target BEFORE splitting (C3) ---
  # A valid focus spec is: "root", a numeric literal pane id (W3), or a step id
  # declared in the preset. An invalid spec must fail loudly (64) and split
  # NOTHING, rather than warn + silently fall back to root and exit 0.
  # Step ids are guaranteed non-numeric by the schema (W3), so a numeric spec is
  # unambiguously a literal pane id and is checked first.
  if [[ "$focus_spec" != "root" ]] && [[ ! "$focus_spec" =~ ^[0-9]+$ ]]; then
    if ! jq -e --arg f "$focus_spec" 'any(.steps[]; .id == $f)' <<< "$preset" >/dev/null 2>&1; then
      wez_error "layout apply: --focus target '${focus_spec}' is neither 'root', a numeric pane id, nor a step id in preset ${opt_name}"
      return "${WEZ_EXIT_USAGE}"
    fi
  fi

  # --- Execute steps in order: explicit --pane-id "$root" (no B3 fallback) ---
  # Collect created pane ids and their step ids/indices for the JSON map.
  local -a created=()
  local -a created_step_ids=()
  local -a created_indices=()

  local i=0
  while (( i < step_count )); do
    local dir percent
    dir="$(jq -r ".steps[$i].dir" <<< "$preset")"
    percent="$(jq -r ".steps[$i].percent" <<< "$preset")"
    local step_id
    step_id="$(jq -r ".steps[$i].id" <<< "$preset")"

    local new_pane
    if ! new_pane=$(_wez_pane_split --pane-id "$root" "--${dir}" --percent "$percent"); then
      # --- Partial failure: rollback created panes in reverse order ---
      wez_error "layout apply: split failed at step ${i} (id=${step_id}); rolling back ${#created[@]} created pane(s)"
      # Track panes whose rollback kill failed, so consumers can flag orphans (W4).
      local -a rollback_failed=()
      local j=$(( ${#created[@]} - 1 ))
      while (( j >= 0 )); do
        if ! _wez_pane_kill --pane-id "${created[$j]}" >/dev/null 2>&1; then
          wez_warn "layout apply: rollback failed to kill pane ${created[$j]}"
          rollback_failed+=("${created[$j]}")
        fi
        j=$(( j - 1 ))
      done
      if [[ "$opt_json" == true ]]; then
        # --- Inline partial-failure JSON (C1: no nameref; arrays in scope) ---
        #   {status:"partial", root_pane_id, created:[...], failed_step:K,
        #    rollback_failed:[...]}
        local created_json="[]"
        local p
        for p in ${created[@]+"${created[@]}"}; do
          created_json="$(jq --argjson v "$p" '. + [$v]' <<< "$created_json")"
        done
        local rollback_json="[]"
        for p in ${rollback_failed[@]+"${rollback_failed[@]}"}; do
          rollback_json="$(jq --argjson v "$p" '. + [$v]' <<< "$rollback_json")"
        done
        jq -n \
          --argjson root_pane_id "$root" \
          --argjson created "$created_json" \
          --argjson failed_step "$i" \
          --argjson rollback_failed "$rollback_json" \
          '{"status": "partial", "root_pane_id": $root_pane_id, "created": $created, "failed_step": $failed_step, "rollback_failed": $rollback_failed}'
      fi
      return "${WEZ_EXIT_PANE_OP_FAILED}"
    fi

    created+=("$new_pane")
    created_step_ids+=("$step_id")
    created_indices+=("$i")
    i=$(( i + 1 ))
  done

  # --- Restore / set focus: spec already validated above (C3) ---
  local focus_target="$root"
  if [[ "$focus_spec" != "root" ]]; then
    if [[ "$focus_spec" =~ ^[0-9]+$ ]]; then
      # Numeric spec is a literal pane id (W3).
      focus_target="$focus_spec"
    else
      # Non-numeric spec is a step id; resolve to its created pane id. The spec
      # was validated against the preset and all steps succeeded, so this match
      # always exists.
      local k=0
      while (( k < ${#created_step_ids[@]} )); do
        if [[ "${created_step_ids[$k]}" == "$focus_spec" ]]; then
          focus_target="${created[$k]}"
          break
        fi
        k=$(( k + 1 ))
      done
    fi
  fi

  _wez_pane_activate --pane-id "$focus_target" >/dev/null 2>&1 || \
    wez_warn "layout apply: failed to focus pane ${focus_target}"

  # --- Success output (C1: inline JSON, arrays in scope; no nameref) ---
  if [[ "$opt_json" == true ]]; then
    # {status:"ok", root_pane_id, window_id, panes:[{id, pane_id, index}]}
    # window_id is the root pane's window from `wezterm cli list`.
    local window_id
    window_id="$(_wez_layout_root_window "$root")"

    local panes_json="[]"
    local idx=0
    while (( idx < ${#created[@]} )); do
      panes_json="$(jq \
        --arg id "${created_step_ids[$idx]}" \
        --argjson pane_id "${created[$idx]}" \
        --argjson index "${created_indices[$idx]}" \
        '. + [{"id": $id, "pane_id": $pane_id, "index": $index}]' \
        <<< "$panes_json")"
      idx=$(( idx + 1 ))
    done

    local window_arg="null"
    [[ "$window_id" =~ ^[0-9]+$ ]] && window_arg="$window_id"

    jq -n \
      --argjson root_pane_id "$root" \
      --argjson window_id "$window_arg" \
      --argjson panes "$panes_json" \
      '{"status": "ok", "root_pane_id": $root_pane_id, "window_id": $window_id, "panes": $panes}'
  fi
  return "${WEZ_EXIT_SUCCESS}"
}

# JSON map emission was inlined into _wez_layout_apply (C1): the success and
# partial-failure builders needed the created/step-id/index arrays. bash 3.2 has
# no nameref (banned by ADR-005), so the JSON is built where the arrays are in
# scope instead of passing them to a helper.

# Resolve the window_id of the root pane from `wezterm cli list --format json`.
# Outputs numeric window_id on stdout, or nothing if unresolved.
_wez_layout_root_window() {
  local root="$1"
  local json
  json=$(wezterm cli list --format json 2>/dev/null) || return 0
  jq -r --arg root "$root" '
    (map(select((.pane_id | tostring) == $root)) | .[0].window_id) // empty
  ' <<< "$json" 2>/dev/null || true
}

# --- Dispatcher ---

_wez_layout_help() {
  cat <<'EOF'
Usage: wez layout [--socket <path>] <subcommand> [options]

Build declarative pane layouts (boards) from named JSON presets.
Thin orchestration over `wez pane split`. wez-only, board-construction only,
NON-IDEMPOTENT (create-only: re-running doubles panes).
A tmux delegate is out of scope. Requires jq.

Subcommands:
  apply <name>   Apply a layout preset (splits from the root/self pane)
  list           List available preset names (lib/layouts/*.json)

Options (before subcommand):
  --socket <path>  Use specific socket path (skip auto-detection)

Run 'wez layout <subcommand> --help' for more information.

Exit codes:
  0    Success
  1    Socket / preset not found
  2    Connection failed
  3    Root pane (self) not found
  5    Split failed (created panes rolled back)
  64   Usage error
  127  wezterm not installed
EOF
}

# Two-stage parsing (mirrors wez_cmd_pane):
# Stage 1: Extract --socket and subcommand (--socket must precede subcommand)
# Stage 2: Forward remaining args to the subcommand handler.
# Socket is resolved ONCE here and exported (SO reconcile #5).
wez_cmd_layout() {
  local opt_socket=""
  local subcmd=""
  local -a subcmd_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --socket)
        if [[ -z "${2:-}" ]]; then
          wez_error "layout: --socket requires a path argument"
          return "${WEZ_EXIT_USAGE}"
        fi
        opt_socket="$2"
        shift
        ;;
      --help|-h|help)
        _wez_layout_help
        return 0
        ;;
      -*)
        wez_error "layout: unknown option: $1 (options must precede subcommand)"
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
    _wez_layout_help
    return 0
  fi

  # Whitelist subcommands BEFORE socket discovery (W5): an unknown subcommand is
  # a usage error (64) regardless of socket availability, so reject it here
  # rather than letting socket discovery turn it into a socket exit code.
  case "$subcmd" in
    apply|list) ;;
    *)
      wez_error "layout: unknown subcommand: ${subcmd}"
      printf '%s\n' "Run 'wez layout --help' for usage information." >&2
      return "${WEZ_EXIT_USAGE}"
      ;;
  esac

  # 'list' does not require a live socket connection; serve it before discovery.
  if [[ "$subcmd" == "list" ]]; then
    _wez_layout_list "${subcmd_args[@]+"${subcmd_args[@]}"}"
    return $?
  fi

  # Socket discovery and export (once, mirrors wez_cmd_pane).
  local socket exit_code=0
  socket=$(wez_discover_socket "$opt_socket") || exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    case $exit_code in
      "${WEZ_EXIT_NO_WEZTERM}")
        wez_error "layout: wezterm is not installed"
        ;;
      "${WEZ_EXIT_NOT_FOUND}")
        if [[ -n "$opt_socket" ]]; then
          wez_error "layout: specified socket not found: ${opt_socket}"
        else
          wez_error "layout: no WezTerm socket found"
        fi
        ;;
      "${WEZ_EXIT_CONN_FAIL}")
        wez_error "layout: socket connection failed"
        ;;
    esac
    return "$exit_code"
  fi

  if ! wez_verify_connection "$socket" >/dev/null; then
    wez_error "layout: socket connection failed"
    return "${WEZ_EXIT_CONN_FAIL}"
  fi

  export WEZTERM_UNIX_SOCKET="$socket"

  # Only 'apply' reaches here: 'list' returns early and unknown subcommands were
  # rejected by the pre-discovery whitelist above (W5).
  _wez_layout_apply "${subcmd_args[@]+"${subcmd_args[@]}"}"
}
