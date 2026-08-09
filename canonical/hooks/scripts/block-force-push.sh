#!/usr/bin/env bash
set -euo pipefail

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

main() {
  local input cmd

  input="$(cat)"
  cmd="$(jq -r '.tool_input.command // .command' <<< "$input")"

  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    allow
  fi

  # Match `git push` even with intervening git options like `git -C . push`
  if [[ ! "$cmd" =~ ^[[:space:]]*git([[:space:]]+[^[:space:]]+)*[[:space:]]+push([[:space:]]|$) ]]; then
    allow
  fi

  # Parse arguments to distinguish plain --force/-f from lease-style options
  local -a args
  local has_plain_force=false
  local has_lease=false

  read -r -a args <<< "$cmd"
  for arg in "${args[@]}"; do
    case "$arg" in
      --force-with-lease|--force-with-lease=*)
        has_lease=true
        ;;
      --force-if-includes)
        has_lease=true
        ;;
      --force|-f)
        has_plain_force=true
        ;;
    esac
  done

  # Plain --force present → deny regardless of lease options
  if [[ "$has_plain_force" == true ]]; then
    deny "Force push blocked: $cmd. Use --force-with-lease instead."
  fi

  # Only lease-style force → allow
  if [[ "$has_lease" == true ]]; then
    allow
  fi

  allow
}

main
