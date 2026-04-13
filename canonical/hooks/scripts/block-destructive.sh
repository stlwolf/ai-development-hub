#!/usr/bin/env bash
set -euo pipefail

SAFE_DIRS_RE='^(node_modules|dist|\.next|build|coverage|__pycache__|\.cache|tmp|\.turbo|\.parcel-cache)$'

deny() {
  local msg="$1"
  if [[ -n "${CURSOR_PROJECT_DIR:-}" || -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    jq -n --arg msg "$msg" '{"permission":"deny","user_message":$msg}'
  else
    echo "$msg" >&2
  fi
  exit 2
}

allow() {
  if [[ -n "${CURSOR_PROJECT_DIR:-}" || -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    echo '{"permission":"allow"}'
  fi
  exit 0
}

# Sets _rm_targets[]; returns 0 if rm with both -r/-R and -f flags detected
parse_rm() {
  local c="$1"
  [[ "$c" =~ ^rm[[:space:]] ]] || return 1

  _rm_has_r=false
  _rm_has_f=false
  _rm_targets=()

  local -a args
  local saw_ddash=false
  read -ra args <<< "$c"
  for arg in "${args[@]:1}"; do
    if ! $saw_ddash; then
      case "$arg" in
        --)          saw_ddash=true; continue ;;
        --recursive) _rm_has_r=true; continue ;;
        --force)     _rm_has_f=true; continue ;;
        -*)
          [[ "$arg" =~ [rR] ]] && _rm_has_r=true
          [[ "$arg" =~ f ]]    && _rm_has_f=true
          continue
          ;;
      esac
    fi
    _rm_targets+=("$arg")
  done

  $_rm_has_r && $_rm_has_f && (( ${#_rm_targets[@]} > 0 ))
}

main() {
  local input cmd cmd_clean

  input="$(cat)"
  cmd="$(jq -r '.tool_input.command // .command' <<< "$input")"

  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    allow
  fi

  # Strip sudo and its options (handles: sudo rm, sudo -E rm, sudo -- rm)
  cmd_clean="$cmd"
  if [[ "$cmd" == sudo[[:space:]]* ]]; then
    local -a _sudo_tokens
    local _i
    read -r -a _sudo_tokens <<< "$cmd"
    _i=1
    while (( _i < ${#_sudo_tokens[@]} )); do
      case "${_sudo_tokens[_i]}" in
        --)  ((_i++)); break ;;
        -*)  ((_i++)) ;;
        *)   break ;;
      esac
    done
    if (( _i < ${#_sudo_tokens[@]} )); then
      cmd_clean="${_sudo_tokens[*]:_i}"
    fi
  fi

  # rm -rf: check ALL targets — deny if any is destructive, allow only if all are safe
  if parse_rm "$cmd_clean"; then
    local _all_safe=true _t
    for _t in "${_rm_targets[@]}"; do
      if [[ "$_t" =~ $SAFE_DIRS_RE ]]; then
        continue
      fi
      _all_safe=false
      # shellcheck disable=SC2088,SC2016  # matching literal ~ and $HOME in command strings
      case "$_t" in
        /*|.|..|'~'|'~/'*|'$HOME'|'$HOME/'*)
          deny "Destructive rm blocked: $cmd"
          ;;
      esac
    done
    if [[ "$_all_safe" == true ]]; then
      allow
    fi
  fi

  if [[ "$cmd_clean" =~ ^chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/ ]]; then
    deny "Destructive chmod blocked: $cmd"
  fi

  if [[ "$cmd_clean" =~ ^chown[[:space:]]+-R[[:space:]]+[^[:space:]]+[[:space:]]+/ ]]; then
    deny "Destructive chown blocked: $cmd"
  fi

  shopt -s nocasematch
  if [[ "$cmd_clean" =~ drop[[:space:]]+table ]] ||
     [[ "$cmd_clean" =~ drop[[:space:]]+database ]] ||
     [[ "$cmd_clean" =~ truncate[[:space:]]+table ]]; then
    shopt -u nocasematch
    deny "Destructive SQL blocked: $cmd"
  fi
  shopt -u nocasematch

  if [[ "$cmd_clean" =~ ^mkfs ]]; then
    deny "Destructive mkfs blocked: $cmd"
  fi

  if [[ "$cmd_clean" =~ ^dd[[:space:]] ]] && [[ "$cmd_clean" =~ of=/dev/ ]]; then
    deny "Destructive dd blocked: $cmd"
  fi

  if [[ "$cmd_clean" =~ ^git[[:space:]]+reset[[:space:]].*--hard ]]; then
    deny "Destructive git reset blocked: $cmd"
  fi

  if [[ "$cmd_clean" =~ ^git[[:space:]]+clean[[:space:]] ]]; then
    local clean_args="${cmd_clean#*git clean }"
    if [[ "$clean_args" == *f* ]] && [[ "$clean_args" == *d* ]] && [[ "$clean_args" == *x* ]]; then
      deny "Destructive git clean blocked: $cmd"
    fi
  fi

  allow
}

main
