# shellcheck shell=bash
# shellcheck disable=SC2034
# attach.sh — 既存（対話中）ペインに attach して capture→classify→audit/KVS（source 専用）
#
# 前提: constants.sh / capture.sh / audit.sh が source 済み（呼び出し側 entry が保証）。
# bin/oe の spawn フローとは独立した最小経路（Issue #109 / Slice A）。
# 「対話セッションの末尾に終端マーカーを出す → engine が読む」を成立させる
# （spawn.sh が自動注入する marker emit の手動版）。

# グローバル: oe_capture_attach() の結果（分類後 state）
OE_ATTACH_STATE=""

# oe_capture_attach — pane を1回 scan し、EXIT マーカー検出時に classify→audit→KVS
#
# 引数: session_id pane_id [lines=50]
# 戻り値:
#   0 = EXIT マーカー検出。OE_ATTACH_STATE に分類結果を設定し audit/KVS 書き込み済み
#   1 = EXIT マーカー未検出（まだ完了していない）。KVS/audit は書かない
#
# viewport-only 制約: oe_capture_scan は `wez pane capture --lines N`（viewport の tail）を
# 使うため、マーカーは末尾近傍の単独行である必要がある。スクロールアウトしたマーカーは
# lines を増やしても回収できない（Plan の「viewport スコープ契約」を参照）。
oe_capture_attach() {
  local session_id="$1"
  local pane_id="$2"
  local lines="${3:-50}"

  OE_ATTACH_STATE=""

  oe_capture_scan "$pane_id" "$lines"

  # EXIT マーカー未検出（VERIFY 単独 / マーカー無し含む）は未完了扱い。
  # monitor.sh が EXIT 以外を「未完了（ポーリング継続）」とする設計と整合。
  if [[ "$OE_SCAN_MARKER_TYPE" != "EXIT" ]]; then
    return 1
  fi

  oe_capture_classify "$OE_SCAN_VALUE" "$OE_SCAN_BLOCKED"
  OE_ATTACH_STATE="$OE_CLASSIFY_STATE"

  # spawn 無しのため session_start は出さず session_end のみ。
  # payload.source="attach" で monitor 由来の session_end と区別できるようにする。
  local payload
  payload="$(jq -cn '{source:"attach"}')"
  oe_audit_emit "session_end" "$session_id" "$pane_id" "$OE_CLASSIFY_STATE" "$payload"
  oe_capture_write_kvs "$session_id" "$pane_id" "$OE_CLASSIFY_STATE"
  return 0
}
