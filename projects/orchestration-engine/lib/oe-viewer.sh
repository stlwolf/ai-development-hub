#!/usr/bin/env bash
# oe-viewer.sh — viewer ペイン解決ロジック（oe-view 用・source 専用）
#
# Sourced by bin/oe-view. Not intended for standalone execution.
# 責務: viewer ペイン（md を glow で描画する固定ペイン）の state file 追跡・生存確認・
#       argv-spawn の replace モデル（生存なら kill→新規 spawn / stale・無しなら spawn）。
# Naming: oe_viewer_* for public, _oe_viewer_* for private。wez（engine）ペインの操作は
#         すべて下層プリミティブ `wez pane …` 経由（ADR-001/004 の wez=下層方針を守る）。
#
# viewer 解決（DJ-4・argv-spawn replace モデル・実機検証で確定・§11）:
#   実機検証で「split したシェルへ glow をタイプ送信」する旧モデルが破綻していた
#   （新規 wez ペインのシェル rc が tmux に自動アタッチし、send したコマンドが実行されず
#    glow が描画されない）。代わりに **ペインのプログラムとして glow を直接起動**する:
#     wez pane split --right --percent <P> --cwd <dir> -- glow -p -- <path>
#   （wezterm cli split-pane [PROG]＝シェルの代わりに PROG を実行・公式仕様）。
#   シェルも tmux も経由しないため確実に描画され、path が argv 要素として渡るので
#   再トークナイズが起きず注入面が消滅する（§5・%q 不要）。
#   glow -p はページャ（シェルではない）ため send による再利用ができない。よって再利用は
#   **replace**: state（OE_VIEW_STATE_FILE）の viewer が生存なら kill → 新 glow ペインを
#   spawn → state 更新 / stale・無しなら spawn + state 更新。spawn 後に source ペイン
#   （WEZTERM_PANE）へ activate して focus 奪取を回避（#111）。

# viewer state（最後の viewer pane_id 1 件のみ・上書き）。テストは env で隔離する。
# HOME を暗黙の既定パスに使ってよいかを決める（#322・全箇所で byte 一致させる）。
# 非空だけでは足りない: HOME=/ は //.claude/... ＝ root 直下を掴み、相対 HOME は cwd 配下へ
# state を散らす。先例（canonical/hooks/scripts/cc-lint.sh:39-41）が -n で済むのは、あちらが
# tally を 1 バイト追記するだけの best-effort だからで、state を作る engine には足りない。
declare -F _oe_home_usable >/dev/null 2>&1 || _oe_home_usable() { case "${HOME:-}" in /) return 1;; /*) return 0;; *) return 1;; esac; }

if   [ -n "${OE_VIEW_STATE_DIR+x}" ]; then :
elif _oe_home_usable; then OE_VIEW_STATE_DIR="${HOME}/.claude/state/oe-view"
else                       OE_VIEW_STATE_DIR=""
fi
OE_VIEW_STATE_FILE="${OE_VIEW_STATE_DIR}/viewer-pane-id"

# 新規 viewer split のジオメトリ（既定: 右 40%）。
OE_VIEW_SPLIT_DIR="${OE_VIEW_SPLIT_DIR:---right}"
OE_VIEW_SPLIT_PERCENT="${OE_VIEW_SPLIT_PERCENT:-40}"

# _oe_viewer_read_state — state file から viewer pane_id を stdout へ（無ければ空・常に rc 0）。
_oe_viewer_read_state() {
  [[ -r "$OE_VIEW_STATE_FILE" ]] || return 0
  head -n 1 "$OE_VIEW_STATE_FILE" 2>/dev/null || true
}

# _oe_viewer_write_state <pane_id> — viewer pane_id を state file へ atomic 記録（oe-jump 同型）。
_oe_viewer_write_state() {
  local pane_id="$1"
  mkdir -p "$OE_VIEW_STATE_DIR" 2>/dev/null || {
    echo "oe-view: cannot create state dir ${OE_VIEW_STATE_DIR}" >&2; return 1; }
  local tmp="${OE_VIEW_STATE_FILE}.tmp.$$"
  if printf '%s\n' "$pane_id" >"$tmp" 2>/dev/null && mv -f "$tmp" "$OE_VIEW_STATE_FILE" 2>/dev/null; then
    return 0
  fi
  rm -f "$tmp" 2>/dev/null
  echo "oe-view: failed to record viewer pane id to ${OE_VIEW_STATE_FILE}" >&2
  return 1
}

# _oe_viewer_pane_exists <pane_id> — pane が生存しているか（`wez pane list` JSON を引く・
#   pane.sh:_wez_pane_exists 相当）。rc 0=生存 / 1=不在・非数値・list 失敗。
_oe_viewer_pane_exists() {
  local pane_id="$1"
  [[ "$pane_id" =~ ^[0-9]+$ ]] || return 1
  local json
  json="$(wez pane list 2>/dev/null)" || return 1
  if command -v jq >/dev/null 2>&1; then
    jq -e --arg id "$pane_id" 'map(select((.pane_id | tostring) == $id)) | length > 0' \
      <<< "$json" >/dev/null 2>&1
  else
    [[ "$json" == *"\"pane_id\":${pane_id},"* ]] \
      || [[ "$json" == *"\"pane_id\":${pane_id}}"* ]] \
      || [[ "$json" == *"\"pane_id\": ${pane_id},"* ]] \
      || [[ "$json" == *"\"pane_id\": ${pane_id}}"* ]]
  fi
}

# _oe_viewer_spawn <path> — viewer ペインを argv-spawn で新規作成し、新 pane_id を stdout へ。
#   ペインのプログラムとして glow を直接起動する（DJ-4・shell/tmux 非経由）:
#     wez pane split --right --percent <P> --cwd <dir> -- glow -p -- <path>
#   --cwd は path の dirname（glow の相対参照・cwd 表示の整合用）。path は argv 要素で渡す
#   （`-- glow -p -- <path>`）ため再トークナイズが起きず %q 不要・注入面が消滅（§5）。
#   作成後に source ペイン（WEZTERM_PANE）へ activate して focus 奪取を回避（#111）。
#   rc 0=成功（pane_id 出力）/ 2=spawn 失敗（環境エラー）。
_oe_viewer_spawn() {
  local path="$1" new_pane source_pane dir
  source_pane="${WEZTERM_PANE:-}"
  dir="$(dirname -- "$path")"
  if ! new_pane="$(wez pane split "$OE_VIEW_SPLIT_DIR" --percent "$OE_VIEW_SPLIT_PERCENT" --cwd "$dir" -- glow -p -- "$path" 2>/dev/null)"; then
    echo "oe-view: failed to spawn viewer pane (wez pane split -- glow)" >&2
    return 2
  fi
  if ! [[ "$new_pane" =~ ^[0-9]+$ ]]; then
    echo "oe-view: unexpected pane id from wez pane split: ${new_pane}" >&2
    return 2
  fi
  # #111: split は新ペインへ focus を奪うため、作業ペインへ focus を戻す（best-effort）。
  if [[ -n "$source_pane" && "$source_pane" =~ ^[0-9]+$ ]]; then
    wez pane activate "$source_pane" 2>/dev/null || true
  fi
  printf '%s\n' "$new_pane"
}

# oe_viewer_resolve <path> — viewer ペインに <path> を glow で表示し、使った viewer
#   pane id を stdout へ出す（argv-spawn replace モデル）。
#   state の viewer が生存 → kill → 新 glow ペインを spawn → state 更新 /
#   stale・無し → spawn + state 更新。
#   glow -p はページャ（シェルではない）ため send による再利用はできず、毎回 replace する。
#   rc 0=成功（pane_id 出力）/ 2=spawn 失敗（環境エラー）。
oe_viewer_resolve() {
  local path="$1" cached
  # state の置き場が決まらないなら、旧 pane の kill も新 pane の spawn もしない（#322）。
  # 書き込みの直前だけで失敗させると、spawn 済みの glow ペインが未追跡のまま残る。
  if [[ -z "$OE_VIEW_STATE_DIR" ]]; then
    echo "oe-view: viewer state の置き場が決まりません（HOME 未設定・OE_VIEW_STATE_DIR も未指定）" >&2
    return 1
  fi
  cached="$(_oe_viewer_read_state)"
  # 生存している旧 viewer は kill（replace モデル: 新 glow ペインで置き換える）。
  # best-effort: kill 失敗（既に消えた等）は新規 spawn を妨げない。
  if [[ -n "$cached" ]] && _oe_viewer_pane_exists "$cached"; then
    wez pane kill "$cached" 2>/dev/null || true
  fi
  local new_pane
  new_pane="$(_oe_viewer_spawn "$path")" || return
  _oe_viewer_write_state "$new_pane" || return 1
  printf '%s\n' "$new_pane"
}
