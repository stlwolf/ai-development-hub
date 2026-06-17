#!/usr/bin/env bash
set -euo pipefail

# hypothesis-gate.sh — PostToolUse(Write|Edit|MultiEdit) フック
# コードパス調査の仮説外部化ファイル tmp/hypothesis-*.md が閾値 N に初めて達したとき
# 1回だけ advisory 通知する（marker で一回性を担保。Edit や削除→再作成での再通知を防ぐ）。
# 外部要因（インフラ差異等）の結論へ進む前に「入力→出力のコードパスに未読区間が無いか」
# を確認するよう促す（code-path-exhaustion #78）。ブロックはしない（compliance はモデル依存）。
# N=3 は暫定値（出自 spec は「N 個」としか言っていない）。

THRESHOLD=3

notify() { jq -n --arg msg "$1" '{"user_message":$msg}'; exit 0; }
silent_exit() { exit 0; }

main() {
  local input cwd path count marker

  input="$(cat)"
  cwd="$(jq -r '.cwd // ""' <<< "$input")"
  path="$(jq -r '.tool_input.file_path // ""' <<< "$input")"

  [[ -z "$cwd" || "$cwd" == "null" ]] && silent_exit

  # 仮説ファイルへの書き込みでなければ無視
  case "$path" in
    */tmp/hypothesis-*.md | tmp/hypothesis-*.md) ;;
    *) silent_exit ;;
  esac

  # 一回性: 通知済み marker があれば沈黙（再発火 spam を防ぐ）
  marker="$cwd/tmp/.hypothesis-gate.notified"
  [[ -f "$marker" ]] && silent_exit

  # tmp/hypothesis-*.md の個数（tmp/ 不在でも 0 になるよう || true でガード）
  count="$( { find "$cwd/tmp" -maxdepth 1 -name 'hypothesis-*.md' 2>/dev/null || true; } | wc -l | tr -d ' ')"

  if (( count >= THRESHOLD )); then
    touch "$marker" 2>/dev/null || true
    notify "[hypothesis-gate] 仮説が ${THRESHOLD} 個以上たまりました（tmp/hypothesis-*.md）。

外部要因（インフラ差異等）の結論へ進む前に確認: 入力→出力のコードパスに未読区間は無いか。
未読が残るなら、code-path-exhaustion / persistent-exploration の突破口チェックリストでコード側を尽くしてから外部仮説へ。"
  fi

  silent_exit
}

main
