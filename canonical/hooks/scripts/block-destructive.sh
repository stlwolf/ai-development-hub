#!/usr/bin/env bash
set -euo pipefail

SAFE_DIRS_RE='^(node_modules|dist|\.next|build|coverage|__pycache__|\.cache|tmp|\.turbo|\.parcel-cache)$'

deny() {
  jq -n --arg msg "$1" '{"permission":"deny","user_message":$msg}'
  exit 2
}

allow() {
  echo '{"permission":"allow"}'
  exit 0
}

# Sets _rm_target; returns 0 if rm with both -r/-R and -f flags detected
parse_rm() {
  local c="$1"
  [[ "$c" =~ ^rm[[:space:]] ]] || return 1

  _rm_has_r=false
  _rm_has_f=false
  _rm_target=""

  local -a args
  read -ra args <<< "$c"
  for arg in "${args[@]:1}"; do
    if [[ "$arg" =~ ^-[^-] ]]; then
      [[ "$arg" =~ [rR] ]] && _rm_has_r=true
      [[ "$arg" =~ f ]] && _rm_has_f=true
    elif [[ ! "$arg" =~ ^- ]]; then
      _rm_target="$arg"
      break
    fi
  done

  $_rm_has_r && $_rm_has_f && [[ -n "$_rm_target" ]]
}

main() {
  local input cmd cmd_clean

  input="$(cat)"
  cmd="$(jq -r '.tool_input.command // .command' <<< "$input")"

  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    allow
  fi

  if [[ "$cmd" =~ ^sudo[[:space:]]+(.*) ]]; then
    cmd_clean="${BASH_REMATCH[1]}"
  else
    cmd_clean="$cmd"
  fi

  # rm -rf: safe exceptions → early allow, then destructive targets → deny
  if parse_rm "$cmd_clean"; then
    if [[ "$_rm_target" =~ $SAFE_DIRS_RE ]]; then
      allow
    fi
    # shellcheck disable=SC2088,SC2016  # matching literal ~ and $HOME in command strings
    case "$_rm_target" in
      /*|.|..|'~'|'~/'*|'$HOME'|'$HOME/'*)
        deny "Destructive rm blocked: $cmd"
        ;;
    esac
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
