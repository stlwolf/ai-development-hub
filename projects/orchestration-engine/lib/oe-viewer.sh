#!/usr/bin/env bash
# oe-viewer.sh — viewer ペイン解決ロジック（oe-view 用・source 専用）
#
# Sourced by bin/oe-view. Not intended for standalone execution.
# 責務: viewer ペイン（md を glow で描画する固定ペイン）の state file 追跡・生存確認・
#       再利用 / 新規 split・注入安全な glow 送信文字列の組み立て。
# Naming: oe_viewer_* for public, _oe_viewer_* for private。wez（engine）ペインの操作は
#         すべて下層プリミティブ `wez pane …` 経由（ADR-001/004 の wez=下層方針を守る）。
#
# viewer 解決（DJ-4）:
#   state file（OE_VIEW_STATE_FILE）に pane_id を保存 → `wez pane list` で生存確認 →
#   生存なら send で再利用 / stale・無しなら split で新規作成し state 更新。
#   新規 split 時は作成後に source ペインへ activate（#111: split は新ペインへ focus を奪う）。
#   glow ページャと send の衝突回避: viewer ペインでは glow を非ページャ形（`glow <file>`＝
#   レンダして終了/プロンプト復帰）で起動する。`-p`（ページャ）は --here 限定（bin/oe-view 側）。

# viewer state（最後の viewer pane_id 1 件のみ・上書き）。テストは env で隔離する。
OE_VIEW_STATE_DIR="${OE_VIEW_STATE_DIR:-${HOME}/.claude/state/oe-view}"
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

# _oe_viewer_split — 新規 viewer ペインを split で作り、新 pane_id を stdout へ。
#   作成後に source ペイン（WEZTERM_PANE）へ activate して focus 奪取を回避（#111）。
#   rc 0=成功（pane_id 出力）/ 2=split 失敗（環境エラー）。
_oe_viewer_split() {
  local new_pane source_pane
  source_pane="${WEZTERM_PANE:-}"
  if ! new_pane="$(wez pane split "$OE_VIEW_SPLIT_DIR" --percent "$OE_VIEW_SPLIT_PERCENT" 2>/dev/null)"; then
    echo "oe-view: failed to split viewer pane (wez pane split)" >&2
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

# oe_viewer_resolve — 表示に使う viewer ペイン id を stdout へ解決する。
#   state の pane が生存 → 再利用（その id）/ stale・無し → split で新規作成し state 更新。
#   rc 0=成功（pane_id 出力）/ 2=新規作成失敗（環境エラー）。
oe_viewer_resolve() {
  local cached
  cached="$(_oe_viewer_read_state)"
  if [[ -n "$cached" ]] && _oe_viewer_pane_exists "$cached"; then
    printf '%s\n' "$cached"
    return 0
  fi
  local new_pane
  new_pane="$(_oe_viewer_split)" || return
  _oe_viewer_write_state "$new_pane" || return 1
  printf '%s\n' "$new_pane"
}

# oe_viewer_render_command <path> — viewer ペインへ送る glow コマンド文字列を組み立てて
#   stdout へ。**送信層のシェル注入対策（P0）**: パスを `printf %q` でシェルクォートして
#   受信シェルの再トークナイズ（`a$(whoami).md` の `$(whoami)` 評価等）を防ぐ。
#   非ページャ形（`glow -- <quoted>`）で、表示後プロンプトに復帰する＝次回 send と衝突しない。
oe_viewer_render_command() {
  local path="$1" quoted
  printf -v quoted '%q' "$path"
  printf 'glow -- %s\n' "$quoted"
}
