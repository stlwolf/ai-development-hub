#!/usr/bin/env bash
set -euo pipefail

# commit-gate.sh — TaskCompleted フック
# タスク完了時に未コミット変更があればエージェントに通知する（advisory）。
# master/main 上では発火しない。

notify() {
  jq -n --arg msg "$1" '{"user_message":$msg}'
  exit 0
}

silent_exit() {
  exit 0
}

main() {
  local input cwd branch dirty file_count file_list msg

  input="$(cat)"
  cwd="$(jq -r '.cwd // ""' <<< "$input")"

  if [[ -z "$cwd" || "$cwd" == "null" ]]; then
    silent_exit
  fi

  # git リポジトリ外なら何もしない
  if ! git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
    silent_exit
  fi

  # ブランチ取得（detached HEAD なら空文字列）
  branch="$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || echo "")"

  # detached HEAD → 対象外
  if [[ -z "$branch" ]]; then
    silent_exit
  fi

  # master/main → 対象外
  case "$branch" in
    main|master) silent_exit ;;
  esac

  # 未コミット変更の検出
  dirty="$(git -C "$cwd" status --porcelain 2>/dev/null || echo "")"

  if [[ -z "$dirty" ]]; then
    silent_exit
  fi

  # 変更ファイル一覧（上限10件）
  file_count="$(echo "$dirty" | wc -l | tr -d ' ')"
  file_list="$(echo "$dirty" | head -10)"

  msg="[commit-gate] Task completed with uncommitted changes on branch '${branch}'.

Changed files (${file_count}):
${file_list}"

  if (( file_count > 10 )); then
    msg="${msg}
... and $((file_count - 10)) more"
  fi

  msg="${msg}

Action required: commit these changes, or record a skip reason.
Skip-Reason format: Skip-Reason: {WIP / batch with next step / investigation only}"

  notify "$msg"
}

main
