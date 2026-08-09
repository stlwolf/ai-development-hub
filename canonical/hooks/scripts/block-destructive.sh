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

# --- shared begin (3本で byte 一致させる。変更は3本同時に) ---
# jq に頼らない deny の出力。trap の収束先はこれを使う。
# jq 不在こそ trap が捕まえたい死因なので、収束先が jq を要求してはならない。
# メッセージは固定リテラル + exit code（数値）だけにして JSON escape の問題を作らない。
# shellcheck disable=SC2317  # trap 経由で呼ばれるため到達不能に見える
emit_deny_literal() {
  if [[ -n "${CURSOR_PROJECT_DIR:-}" || -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    printf '{"permission":"deny","user_message":"%s"}\n' "$1"
  else
    printf '%s\n' "$1" >&2
  fi
}

# 想定外の終了（0/2 以外）を deny へ収束させる。
# PreToolUse で実際にブロックするのは exit 2 だけで、1 を含む他の非 0 は non-blocking。
# つまり内部エラーで落ちると、止めるべきコマンドが Claude Code / Codex では素通りする。
# EXIT trap は正常終了でも発火するので、0 と 2 は必ずそのまま通すこと。
# shellcheck disable=SC2317  # trap 経由で呼ばれるため到達不能に見える
on_unexpected_exit() {
  local ec=$?
  trap - EXIT                             # 再入を止める
  case "$ec" in 0|2) exit "$ec" ;; esac    # 正常な終了はそのまま通す
  set +e +u                               # ここから先は何があっても止まらない
  emit_deny_literal "hook internal error (exit ${ec}); blocked conservatively"
  exit 2
}
trap on_unexpected_exit EXIT
# --- shared end ---

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
