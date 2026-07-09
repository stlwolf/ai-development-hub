#!/usr/bin/env bash
# statusline-oe-heartbeat.sh — #239 段階1 PR-A: statusLine 拍動 producer（sidecar write）
#
# Claude Code の statusLine コマンドとして invocation 毎（event 駆動 + refreshInterval の idle timer）に
# 走り、session の「拍動（heartbeat）」を sidecar ファイルへ best-effort で書く producer。
# out-of-session の consumer（#239 PR-B）が拍動鮮度と context% 閾値を read して owner に ping する。
#
# 契約（PR-A が正本として定義・PR-B が read する前提）:
#   - sidecar パス : ${OE_HEARTBEAT_DIR:-${HOME}/.claude/state/oe-heartbeat}/<session_id>.json
#                    <session_id> は stdin JSON の .session_id（ULID・session 安定）。
#   - sidecar 内容 : {"ts":<epoch秒>, "context_pct":<0-100>, "pane":"<tmux pane|空>"}
#       ts          = date +%s（BSD/GNU 両可搬・bin/oe-undelivered:100 と同型）
#       context_pct = stdin .context_window.used_percentage（null/早期は // 0 fallback）
#       pane        = ${TMUX_PANE:-}（statusLine 実行 env に伝播すれば載る。stdin には tmux pane 情報が
#                     無いため env から取得する。伝播しない環境では空になり、consumer は session_id
#                     主キー + board 突合で pane を解決する＝空でも契約は保たれる）
#   - write は atomic（同一 dir 内 temp + rename）。毎秒級 write × 別プロセス read の競合で
#     consumer が半端な JSON を読まないようにする。
#
# 非破壊（status bar を壊さない）:
#   - sidecar write は side-effect。write が失敗してもスクリプトは通常どおり statusLine 文字列を出力し、
#     exit 0 で終える（best-effort。だから set -e は使わない）。
#   - 既存 statusLine があれば wrap（call-through）して表示を保つ: 環境変数 OE_HEARTBEAT_WRAP_CMD に
#     元コマンドが入っていれば、stdin をそれへ渡してその出力を表示する（sync 側が非破壊 merge で設定）。
#     無ければ beat producer が最小 statusLine（model + context%）を担う。
#
# 既定パスは verb/lib 内でインライン宣言し env で上書き可（lib/event-bus.sh:44-46 idiom）。
# lib/constants.sh には足さない（あそこは engine/project-relative 専用）。テストは OE_HEARTBEAT_DIR で隔離。

set -u

# stdin（statusLine session JSON）を1度だけ読む。
input="$(cat 2>/dev/null || true)"

# 既定 sidecar dir（env で上書き可・テスト隔離）。
# HOME 未設定でも set -u で abort しないよう ${HOME:-} で守る（非破壊契約: 表示を出して exit 0）。
# HOME 空なら既定 dir は /.claude/... となり write は best-effort で失敗し、表示だけ出る。
OE_HEARTBEAT_DIR="${OE_HEARTBEAT_DIR:-${HOME:-}/.claude/state/oe-heartbeat}"

# --- 拍動 write（best-effort side-effect・全失敗を飲み込み status bar を壊さない）---
_oe_heartbeat_write() {
  command -v jq >/dev/null 2>&1 || return 0

  local sid ts pane dir tmp
  sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)" || return 0
  [[ -n "$sid" ]] || return 0
  # session_id をファイル名として安全な文字集合に限定（区切り混入 / path traversal 防止）。
  [[ "$sid" =~ ^[A-Za-z0-9._-]+$ ]] || return 0

  ts="$(date +%s 2>/dev/null)" || return 0
  [[ "$ts" =~ ^[0-9]+$ ]] || return 0
  pane="${TMUX_PANE:-}"
  dir="$OE_HEARTBEAT_DIR"

  mkdir -p "$dir" 2>/dev/null || return 0
  tmp="$(mktemp "${dir}/.hb.XXXXXX" 2>/dev/null)" || return 0
  # 本体は input を主入力に取り、ts/pane を注入。context_pct は null/欠落を // 0 で吸収。
  if printf '%s' "$input" \
    | jq -c --argjson ts "$ts" --arg pane "$pane" \
        '{ts:$ts, context_pct:((.context_window.used_percentage // 0) | tonumber? // 0), pane:$pane}' \
        > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "${dir}/${sid}.json" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  else
    rm -f "$tmp" 2>/dev/null
  fi
  return 0
}
_oe_heartbeat_write || true

# --- 表示（非破壊）---
# 既存 statusLine を wrap: 元コマンドへ stdin を渡し、その出力をそのまま表示（best-effort）。
# eval は set +u の subshell で走らせ、元コマンドが未設定変数を参照しても（通常 shell 同様に
# 空へ）動くようにする（本 producer 自身の set -u で元 statusLine の意味を変えない）。~/ や $VAR
# の展開は %q（sync 側の退避）→ outer shell の語 parse → eval の再 parse を経て保たれる。
if [[ -n "${OE_HEARTBEAT_WRAP_CMD:-}" ]]; then
  if wrapped_out="$(printf '%s' "$input" | ( set +u; eval "${OE_HEARTBEAT_WRAP_CMD}" ) 2>/dev/null)"; then
    printf '%s\n' "$wrapped_out"
    exit 0
  fi
  # wrap 失敗時は最小行へフォールバック（表示を空にしない）。
fi

# 最小 statusLine（model + context%）。
if command -v jq >/dev/null 2>&1; then
  line="$(printf '%s' "$input" \
    | jq -r '"[\(.model.display_name // "?")] \(.context_window.used_percentage // 0)% ctx"' 2>/dev/null)" || line=""
  if [[ -n "$line" ]]; then
    printf '%s\n' "$line"
  else
    printf '%s\n' "oe-heartbeat"
  fi
else
  printf '%s\n' "oe-heartbeat"
fi

exit 0
