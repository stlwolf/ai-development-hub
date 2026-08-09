#!/usr/bin/env bash
set -euo pipefail

CC_TYPES="feat|fix|ui|refactor|style|test|docs|revert|ci|infra|chore|local|wip"

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

# grep の「非マッチ」は正常なデータ不在であって失敗ではない。実行できない（環境エラー）
# とは扱いを分ける。`|| true` で握り潰すと、この2つが同じ空出力に化けて区別できなくなる。
#
# パイプラインをやめた理由は2つある。(1) pipefail 下では grep の非マッチ 1 が
# パイプライン全体の非 0 になり、inherit_errexit が有効だと script ごと落ちる（#310）。
# (2) head の早期終了は SIGPIPE 由来の非 0 も生むので、非マッチと環境エラーの区別を壊す。
# head -1 と sed の役割は bash のパラメータ展開へ置き換えた（外部プロセスも2つ減る）。
#
# 正規表現そのものは据え置く。マッチ意味論を変えると非回帰を証明できなくなるため。
extract_commit_segment() {
  local cmd="$1"
  if [[ "$cmd" == *"&&"* ]]; then
    local matches rc=0
    matches="$(grep -oE '(^|&&)[[:space:]]*git[[:space:]]+commit[^&]*' <<< "$cmd")" || rc=$?
    case "$rc" in
      0) ;;                 # マッチした
      1) matches="" ;;      # マッチ無し = 正常なデータ不在
      *) return "$rc" ;;    # 環境エラー。呼び出し側が deny に倒す
    esac
    if [[ -n "$matches" ]]; then
      local segment="${matches%%$'\n'*}"                    # head -1 相当
      local trimmed="${segment#"${segment%%[![:space:]]*}"}"
      if [[ "$trimmed" == "&&"* ]]; then                    # sed の条件付き除去に対応
        trimmed="${trimmed#&&}"
        segment="${trimmed#"${trimmed%%[![:space:]]*}"}"
      fi
      if [[ -n "$segment" ]]; then
        printf '%s\n' "$segment"
        return 0
      fi
    fi
  fi
  printf '%s\n' "$cmd"
}

extract_message() {
  local cmd="$1"
  if [[ "$cmd" =~ \$\( ]] || [[ "$cmd" =~ \` ]]; then
    return 1
  fi

  local msg=""
  local -a tokens
  local in_m=false

  read -ra tokens <<< "$cmd"
  for token in "${tokens[@]}"; do
    if $in_m; then
      if [[ -z "$msg" ]]; then
        msg="$token"
      else
        msg="$msg $token"
      fi
      if [[ "$msg" == \"*\" ]] || [[ "$msg" == \'*\' ]]; then
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
      fi
      if [[ "$msg" != \"* ]] && [[ "$msg" != \'* ]]; then
        echo "$msg"
        return 0
      fi
      if [[ "$msg" == *\" ]] || [[ "$msg" == *\' ]]; then
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
      fi
      continue
    fi
    case "$token" in
      -m|--message)
        in_m=true
        ;;
      -m=*)
        msg="${token#-m=}"
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
        ;;
      --message=*)
        msg="${token#--message=}"
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
        ;;
      -[a-zA-Z]*m)
        in_m=true
        ;;
    esac
  done

  if $in_m && [[ -n "$msg" ]]; then
    msg="${msg#[\"\']}"
    msg="${msg%[\"\']}"
    echo "$msg"
    return 0
  fi

  return 1
}

main() {
  local input cmd

  input="$(cat)"
  cmd="$(jq -r '.tool_input.command // .command' <<< "$input")"

  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    allow
  fi

  # 環境エラー（grep が実行できない等）は deny に倒す。握り潰すと、強制が静かに消える。
  # deny は extract_commit_segment の中では呼べない — あの関数はコマンド置換の中で走るので、
  # そこで出した制御 JSON は本物の stdout に届かず置換の戻り値に化ける。
  local commit_segment ecs_rc=0
  commit_segment="$(extract_commit_segment "$cmd")" || ecs_rc=$?
  if (( ecs_rc >= 2 )); then
    deny "cc-lint: could not parse the command (grep failed with ${ecs_rc}). Blocked conservatively."
  fi

  if [[ ! "$commit_segment" =~ ^[[:space:]]*git[[:space:]]+(.*[[:space:]]+)?commit([[:space:]]|$) ]]; then
    allow
  fi

  if [[ "$commit_segment" =~ --fixup[=[:space:]] ]] || [[ "$commit_segment" =~ --squash[=[:space:]] ]]; then
    allow
  fi

  if [[ ! "$commit_segment" =~ [[:space:]]-[a-zA-Z]*m ]] && [[ ! "$commit_segment" =~ --message ]]; then
    allow
  fi

  local message
  if ! message="$(extract_message "$commit_segment")"; then
    allow
  fi

  if [[ -z "$message" ]]; then
    allow
  fi

  local cc_pattern="^(${CC_TYPES})(\(.+\))?: .+"
  if [[ "$message" =~ $cc_pattern ]]; then
    allow
  fi

  deny "Commit message does not follow Conventional Commits format.
Expected: <type>(<optional scope>): <description>
Types: feat, fix, ui, refactor, style, test, docs, revert, ci, infra, chore, local, wip
Example: feat(hooks): add cc-lint pre-command hook
Got: $message"
}

main
