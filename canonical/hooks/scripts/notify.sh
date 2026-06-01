#!/usr/bin/env bash
# notify.sh — エージェントの完了 / 入力待ちを通知する advisory フック
#
# 配信は WezTerm の OSC 777 通知を主とする。tmux 内では DCS passthrough で包んで
# ペイン TTY (#{pane_tty}) に直接書く（フックは controlling TTY を持たないため
# /dev/tty は使えない）。非 tmux は /dev/tty。どちらも不可なら terminal-notifier →
# osascript にフォールバック（非 WezTerm / headless 環境用）。
#
# 前提: tmux は `set -g allow-passthrough on`（3.3+）、WezTerm に macOS 通知許可。
#
# 呼ばれ方:
#   Claude Code hooks : 第1引数 = done|wait（任意 第2引数 = tool 名）、stdin に JSON（underscore キー）
#   Codex notify      : 第1引数 = JSON 文字列（hyphen キー, type=agent-turn-complete）→ tool=Codex
#
# 通知フォーマット:
#   title: "{tool} {✅|⌨️} {repo}"   body: "{branch} · win{window.pane} — {message}"
#
# advisory 契約: 非ゼロ exit を出さない / stdout 無出力 / 末尾は無条件 exit 0。
# デバッグ: NOTIFY_DEBUG=1 または ~/.notify-hook-debug で /tmp/notify-hook.log に記録。
#
# 制限: OSC 777 にはサウンド指定が無いため、完了/入力待ちで通知音は出し分けられない
# （WezTerm の通知設定に従う）。区別はタイトルの絵文字（✅ / ⌨️）で行う。

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

arg1="${1:-}"
mode="done"
cwd=""
message=""
tool="Claude"

if [[ "$arg1" == "{"* ]]; then
  # Codex notify: argv[1] が JSON（hyphen キー、完了のみ）
  tool="Codex"
  cwd="$(printf '%s' "$arg1" | jq -r '.cwd // ""' 2>/dev/null || true)"
  message="$(printf '%s' "$arg1" | jq -r '."last-assistant-message" // ""' 2>/dev/null || true)"
  mode="done"
else
  # hooks: argv[1]=mode, argv[2]=tool(任意), stdin に JSON（underscore キー）
  mode="${arg1:-done}"
  [[ -n "${2:-}" ]] && tool="$2"
  input="$(cat 2>/dev/null || true)"
  cwd="$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null || true)"
  message="$(printf '%s' "$input" | jq -r '.message // .last_assistant_message // ""' 2>/dev/null || true)"
fi

# cwd → repo / branch
repo=""
branch=""
if [[ -n "$cwd" && "$cwd" != "null" ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  repo="$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "")")"
  branch="$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || echo "")"
fi
label="${repo:-agent}"

# tmux: ペイン TTY と 居場所(window.pane) を取得
pt=""
loc=""
if [[ -n "${TMUX:-}" ]]; then
  pane="${TMUX_PANE:-}"
  if [[ -n "$pane" ]]; then
    # 発火元ペインが特定できる場合のみ TTY と loc を取る
    pt="$(tmux display-message -t "$pane" -p '#{pane_tty}' 2>/dev/null || true)"
    # 居場所: session名:window.pane（並走時の識別。番号移動は window 番号）
    loc="$(tmux display-message -t "$pane" -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)"
  else
    # $TMUX_PANE 不在: 配信はアクティブペイン TTY 経由（通知は window レベルで表示される）。
    # ただし loc はアクティブペインを指すと別ペインの通知に誤った番号が付くため省略する。
    pt="$(tmux display-message -p '#{pane_tty}' 2>/dev/null || true)"
    loc=""
  fi
fi

# title / body
case "$mode" in
  wait)
    emoji="⌨️"
    msg="$(printf '%s' "$message" | tr -d '\033\007' | tr '\n\r' '  ' | cut -c1-80)"
    ;;
  *)
    emoji="✅"
    msg=""
    ;;
esac
title="${tool} ${emoji} ${label}"
body="${branch}"
[[ -n "$loc" ]] && body="${body:+$body · }${loc}"
[[ -n "$msg" ]] && body="${body:+$body — }$msg"
[[ -z "$body" ]] && body="$mode"

# サニタイズ（OSC を壊す制御文字・改行を除去。title は区切りの ; も除去）
title="$(printf '%s' "$title" | tr -d '\033\007;' | tr '\n\r' '  ')"
body="$(printf '%s' "$body" | tr -d '\033\007' | tr '\n\r' '  ')"

if [[ -n "${NOTIFY_DEBUG:-}" || -f "$HOME/.notify-hook-debug" ]]; then
  printf '%s tool=%s mode=%s repo=%s branch=%s loc=%s tmux=%s\n' \
    "$(date '+%H:%M:%S' 2>/dev/null || echo '?')" "$tool" "$mode" "$repo" "$branch" "$loc" "${TMUX:+yes}" \
    >> /tmp/notify-hook.log 2>/dev/null || true
fi

# --- 配信 ---
delivered=0

if [[ -n "${TMUX:-}" && -n "$pt" && -w "$pt" ]]; then
  # tmux: ペイン TTY へ DCS passthrough（内側 ESC を二重化、終端は ESC + \134=backslash）
  printf '\033Ptmux;\033\033]777;notify;%s;%s\007\033\134' "$title" "$body" > "$pt" 2>/dev/null && delivered=1
elif [[ -z "${TMUX:-}" && -w /dev/tty ]]; then
  printf '\033]777;notify;%s;%s\007' "$title" "$body" > /dev/tty 2>/dev/null && delivered=1
fi

# フォールバック（非 WezTerm / 非 tmux / headless 用）
if [[ "$delivered" -eq 0 ]]; then
  if command -v terminal-notifier >/dev/null 2>&1; then
    ( terminal-notifier -title "$title" -message "${body:-notify}" >/dev/null 2>&1 ) &
  elif command -v osascript >/dev/null 2>&1; then
    ( osascript - "$title" "${body:-notify}" >/dev/null 2>&1 <<'OSA'
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
OSA
    ) &
  fi
fi

exit 0
