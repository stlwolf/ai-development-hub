#!/usr/bin/env bash
# notify.sh — エージェントの完了 / 入力待ちを macOS 通知する advisory フック
#
# Claude Code / Codex の hooks から呼ばれる共有ハンドラ。
#   完了    : Claude `Stop` / Codex `Stop`            → 第1引数 done（無音 + group 集約）
#   入力待ち: Claude `Notification` / Codex `PermissionRequest` → 第1引数 wait（音あり）
#
# 意図(done/wait)は hook 設定側の引数で明示渡しする（stdin からのイベント推論より堅い）。
# stdin の JSON からは cwd / message / session_id のみ読む。
#
# advisory 契約: エージェントを絶対に止めない。
#   - `set -e` は使わない（非ゼロ exit を出さない）
#   - 非 macOS / jq 不在は no-op
#   - 外部呼び出しは全て `|| true`、発火は background、末尾は無条件 exit 0
#   - stdout には何も出さない（Codex Stop で制御 JSON を返すと副作用）
#
# デバッグ: NOTIFY_DEBUG=1 または ~/.notify-hook-debug があれば /tmp/notify-hook.log に記録。

set -uo pipefail

# 非 macOS / jq 不在は no-op
[[ "$(uname 2>/dev/null || echo)" == "Darwin" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

mode="${1:-done}"

input="$(cat 2>/dev/null || true)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null || true)"
message="$(printf '%s' "$input" | jq -r '.message // ""' 2>/dev/null || true)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null || true)"
event="$(printf '%s' "$input" | jq -r '.hook_event_name // ""' 2>/dev/null || true)"

# cwd → repo / branch（並走時の識別用）
repo=""
branch=""
if [[ -n "$cwd" && "$cwd" != "null" ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  repo="$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "")")"
  branch="$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || echo "")"
fi
label="${repo:-agent}"

# デバッグログ
if [[ -n "${NOTIFY_DEBUG:-}" || -f "$HOME/.notify-hook-debug" ]]; then
  printf '%s mode=%s event=%s repo=%s branch=%s msg=%.40s\n' \
    "$(date '+%H:%M:%S' 2>/dev/null || echo '?')" "$mode" "$event" "$repo" "$branch" "$message" \
    >> /tmp/notify-hook.log 2>/dev/null || true
fi

# モード → 表示内容
case "$mode" in
  wait)
    title="⌨️ ${label} 入力待ち"
    msg_clean="$(printf '%s' "$message" | tr '\n' ' ' | cut -c1-80)"
    body="${branch}"
    [[ -n "$msg_clean" ]] && body="${body:+${body} — }${msg_clean}"
    [[ -z "$body" ]] && body="入力を待っています"
    sound="Glass"
    ;;
  done|*)
    # 完了: 機微情報を載せない（repo/branch のみ）。無音 + group 集約でノイズ抑制
    title="✅ ${label} 完了"
    body="${branch:-${label}}"
    sound=""
    ;;
esac

# terminal-notifier の -message が "-" 始まりだとフラグ誤認するため回避
[[ "$body" == -* ]] && body="• ${body#-}"

dispatch() {
  if command -v terminal-notifier >/dev/null 2>&1; then
    local args=(-title "$title" -message "$body")
    [[ -n "$session_id" ]] && args+=(-group "$session_id")
    if [[ -n "$sound" ]]; then
      args+=(-sound "$sound")
    else
      args+=(-sound none)
    fi
    terminal-notifier "${args[@]}" >/dev/null 2>&1 || true
  elif [[ -n "$sound" ]]; then
    osascript - "$title" "$body" "$sound" >/dev/null 2>&1 <<'OSA' || true
on run argv
  display notification (item 2 of argv) with title (item 1 of argv) sound name (item 3 of argv)
end run
OSA
  else
    osascript - "$title" "$body" >/dev/null 2>&1 <<'OSA' || true
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
OSA
  fi
}

# 承認パスを遅延させないため background で発火し、即 return
( dispatch ) >/dev/null 2>&1 &

exit 0
