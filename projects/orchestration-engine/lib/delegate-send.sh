# shellcheck shell=bash
# delegate-send.sh — 親子委譲の 1 行安全送信プリミティブ（source 専用）
#
# tmux send-keys -l は改行をそのまま端末へ流すため、複数行を送ると Claude Code
# プロンプトが途中で送信される。本 lib は「1 行であること」を保証する単一の送信口。
#
# 既存 lib/spawn.sh の oe_spawn_send（wez・claude -p・非対話・envelope 経由）とは
# 別系統。こちらは対話セッションへ tmux send-keys で注入する transport。
# bin/oe-send / bin/oe-delegate が使う。将来 bin/oe-report も無改修で乗れるよう独立。

# oe_send_line <pane_id> <text> [send_enter]
#   <text> に改行（LF / CR）が含まれていれば送信せず非 0 で失敗する（途中送信の根本封じ）。
#   対象ペインが存在しなければ非 0 で失敗する（死んだペインへの無言送信を防ぐ）。
#   send_enter（既定 "1"）が "0" のときは Enter を発火せずテキスト投入のみ（ステージ）。
#   成功時は tmux send-keys -l でリテラル注入し、既定では続けて Enter を発火する。
oe_send_line() {
  local pane="${1:-}"
  local text="${2:-}"
  local send_enter="${3:-1}"

  if [[ -z "$pane" ]]; then
    echo "oe_send_line: pane_id is required" >&2
    return 2
  fi
  # 改行（LF / CR）を含む payload は送信前に拒否する。今回の再設計の根本原因なので
  # 除去ではなく fail-fast にして、呼び出し側に 1 行化を強制する。
  if [[ "$text" == *$'\n'* || "$text" == *$'\r'* ]]; then
    echo "oe_send_line: refusing to send multi-line text (contains newline) to ${pane}" >&2
    return 2
  fi
  # tmux 不在は環境エラー（exit 2）として「ペイン無し (exit 1)」と区別する。
  # これが無いと list-panes の失敗が握りつぶされ「target pane not found」と誤表示する。
  if ! command -v tmux >/dev/null 2>&1; then
    echo "oe_send_line: tmux not found in PATH (required to send to a pane)" >&2
    return 2
  fi
  # 対象ペインの生存確認。
  if ! tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -qxF "$pane"; then
    echo "oe_send_line: target pane not found: ${pane}" >&2
    return 1
  fi
  # -- で text のオプション誤解釈を防ぐ。-l はリテラル送信。Enter は別途発火（任意）。
  tmux send-keys -l -t "$pane" -- "$text"
  if [[ "$send_enter" != "0" ]]; then
    tmux send-keys -t "$pane" Enter
  fi
}
