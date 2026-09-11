#!/usr/bin/env bash
# handoff-state.sh — 統括の交代で使う「機械で取れる状態」の収集（#390 PR-1）
#
# 引き継ぎ文書のうち観測できる事実の側をここが作る。人が書く側（会話にしか無かったもの）は
# 対象外で、そちらは oe-handoff が空枠として置く。
#
# 本 lib は read-only である。ファイルを1つも書き換えない（呼び出し側が文書を書く）。
#
# 提供する関数:
#   oe_hs_server_pid                  — いまの tmux server の pid（registry と同じ導出）
#   oe_hs_pane_alive <pane>           — pane が tmux に現存するか
#   oe_hs_children_of <pane>          — <pane> を親とする登記のうち、pane が現存するものを1行1件
#   oe_hs_session_for_pane <pane>     — pane から session_id を逆引き（安全側・曖昧なら unknown）
#   oe_hs_context_for_session <sid>   — session_id の拍動から context%（取れなければ unknown）
#   oe_hs_watchdogs                   — 常駐の見張りの登録状態を1行1件
#   oe_hs_repo_state <workspace>      — master HEAD / 未 push / worktree の数
#   oe_hs_open_prs                    — open PR を1行1件（gh が無ければ unknown）
#
# 置き場の env（既存の verb と同じノブを共有する）:
#   OE_DELEGATE_STATE_DIR   登記（既定 ~/.claude/state/oe-delegate）
#   OE_HEARTBEAT_DIR        拍動 sidecar（既定 ~/.claude/state/oe-heartbeat・oe-vitals と共有）
#   OE_HS_SERVER_PID        tmux server pid の上書き（主にテストの決定論化用）

# HOME を暗黙の既定パスに使ってよいか（delegate-registry.sh と byte 一致させる・#322）。
declare -F _oe_home_usable >/dev/null 2>&1 || _oe_home_usable() {
  case "${HOME:-}" in /|//) return 1;; /*) return 0;; *) return 1;; esac
}

if   [ -n "${OE_DELEGATE_STATE_DIR+x}" ]; then :
elif _oe_home_usable; then OE_DELEGATE_STATE_DIR="${HOME}/.claude/state/oe-delegate"
else                       OE_DELEGATE_STATE_DIR=""
fi
if   [ -n "${OE_HEARTBEAT_DIR+x}" ]; then :
elif _oe_home_usable; then OE_HEARTBEAT_DIR="${HOME}/.claude/state/oe-heartbeat"
else                       OE_HEARTBEAT_DIR=""
fi

# いまの tmux server の pid。$TMUX の2番目のフィールドが server pid（registry と同じ導出）。
# テストでは OE_HS_SERVER_PID で固定する。
oe_hs_server_pid() {
  if [ -n "${OE_HS_SERVER_PID:-}" ]; then printf '%s' "$OE_HS_SERVER_PID"; return 0; fi
  local s="${TMUX:-}"
  s="${s#*,}"; s="${s%%,*}"
  printf '%s' "$s"
}

# pane が tmux に現存するか。list-panes の集合所属で見る（display-message は不在でも
# rc=0 と空を返すので使わない・#291 で踏んだ罠）。
oe_hs_pane_alive() {
  local pane="${1:-}"
  [ -n "$pane" ] || return 1
  command -v tmux >/dev/null 2>&1 || return 1
  tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -qxF -- "$pane"
}

# <pane> を親とする登記のうち、pane が現存するものを1行1件（"<pane> <label>"）。
#
# 錨は「自ペイン」ではなく引数の pane である。oe_reg_list は parent_pane == 自ペイン で
# 数えるので、後継のセッションから前任の子を数える用途には使えない（使うと常に0件になり、
# 「子が居ないから閉じてよい」へ倒れる）。
oe_hs_children_of() {
  local parent="${1:-}"
  [ -n "$parent" ] || return 2
  [ -n "$OE_DELEGATE_STATE_DIR" ] || return 2
  command -v jq >/dev/null 2>&1 || return 2
  [ -d "$OE_DELEGATE_STATE_DIR" ] || return 0
  local f pane label
  for f in "$OE_DELEGATE_STATE_DIR"/*.json; do
    [ -f "$f" ] || continue
    pane="$(jq -r --arg p "$parent" 'select(.parent_pane == $p) | .pane // empty' "$f" 2>/dev/null)" || continue
    [ -n "$pane" ] || continue
    oe_hs_pane_alive "$pane" || continue
    label="$(jq -r '.label // ""' "$f" 2>/dev/null)" || label=""
    printf '%s %s\n' "$pane" "$label"
  done
}

# pane から session_id を逆引きする。**曖昧なら unknown を返す。**
#
# sidecar は掃除されないので、同じ pane 番号の別世代が貯まる（実測で pane を持つ sidecar
# 198 件に対し異なる番号は 171 個）。pane だけで引くと古い世代を掴む。だから
#   (1) いまの tmux server の pid が一致するものだけに絞り
#   (2) 絞った結果がちょうど1件のときだけ値を返す
# とする。0 件でも複数でも unknown で、**誤った session_id を書くくらいなら書かない**。
oe_hs_session_for_pane() {
  local pane="${1:-}" spid hit count=0 sid=""
  [ -n "$pane" ] || { printf 'unknown'; return 0; }
  [ -n "$OE_HEARTBEAT_DIR" ] || { printf 'unknown'; return 0; }
  [ -d "$OE_HEARTBEAT_DIR" ] || { printf 'unknown'; return 0; }
  command -v jq >/dev/null 2>&1 || { printf 'unknown'; return 0; }
  spid="$(oe_hs_server_pid)"
  [ -n "$spid" ] || { printf 'unknown'; return 0; }
  local f
  for f in "$OE_HEARTBEAT_DIR"/*.json; do
    [ -f "$f" ] || continue
    hit="$(jq -r --arg p "$pane" --arg s "$spid" \
      'select((.pane // "") == $p and ((.server_pid // "") | tostring) == $s) | "hit"' "$f" 2>/dev/null)" || continue
    [ "$hit" = "hit" ] || continue
    count=$((count + 1))
    sid="$(basename "$f" .json)"
  done
  if [ "$count" -eq 1 ]; then printf '%s' "$sid"; else printf 'unknown'; fi
}

# session_id の拍動から context%。取れなければ unknown。
oe_hs_context_for_session() {
  local sid="${1:-}" v
  if [ -z "$sid" ] || [ "$sid" = "unknown" ]; then printf 'unknown'; return 0; fi
  [ -n "$OE_HEARTBEAT_DIR" ] || { printf 'unknown'; return 0; }
  command -v jq >/dev/null 2>&1 || { printf 'unknown'; return 0; }
  local f="${OE_HEARTBEAT_DIR}/${sid}.json"
  [ -f "$f" ] || { printf 'unknown'; return 0; }
  v="$(jq -r '.context_pct // empty' "$f" 2>/dev/null)" || v=""
  if [ -n "$v" ]; then printf '%s' "$v"; else printf 'unknown'; fi
}

# 常駐の見張りの登録状態。launchd が無い環境では unknown を1行返す（不在を「見張り0本」に
# 化かさない）。
oe_hs_watchdogs() {
  if ! command -v launchctl >/dev/null 2>&1; then
    printf 'unknown launchctl-not-found\n'
    return 0
  fi
  local out
  out="$(launchctl list 2>/dev/null | awk '$3 ~ /oe-/ {print $3" "$2}')" || out=""
  if [ -z "$out" ]; then
    printf 'none registered\n'
  else
    printf '%s\n' "$out"
  fi
}

# master HEAD / 未 push の数 / worktree の数。workspace は git 作業ディレクトリ。
oe_hs_repo_state() {
  local ws="${1:-.}" head_sha unpushed wt
  command -v git >/dev/null 2>&1 || { printf 'head=unknown unpushed=unknown worktrees=unknown\n'; return 0; }
  head_sha="$(git -C "$ws" rev-parse --short HEAD 2>/dev/null)" || head_sha="unknown"
  unpushed="$(git -C "$ws" log --oneline '@{upstream}..HEAD' 2>/dev/null | wc -l | tr -d ' ')" || unpushed="unknown"
  [ -n "$unpushed" ] || unpushed="unknown"
  wt="$(git -C "$ws" worktree list 2>/dev/null | wc -l | tr -d ' ')" || wt="unknown"
  printf 'head=%s unpushed=%s worktrees=%s\n' "$head_sha" "$unpushed" "$wt"
}

# open PR を1行1件（"<番号> draft=<true|false> <タイトル>"）。gh が無ければ unknown。
oe_hs_open_prs() {
  command -v gh >/dev/null 2>&1 || { printf 'unknown gh-not-found\n'; return 0; }
  local out
  out="$(gh pr list --state open --json number,title,isDraft \
        -q '.[] | "\(.number) draft=\(.isDraft) \(.title)"' 2>/dev/null)" || {
    printf 'unknown gh-call-failed\n'; return 0; }
  if [ -z "$out" ]; then printf 'none\n'; else printf '%s\n' "$out"; fi
}
