# shellcheck shell=bash
# shellcheck disable=SC2034
# spawn.sh — ペイン生成 + セッション開始（source 専用）

# グローバル変数: oe_spawn() の戻り値
OE_SPAWN_PANE_ID=""

# oe_spawn_prepare_pane — 新ペインを作成し OE_SPAWN_PANE_ID に保存
oe_spawn_prepare_pane() {
  OE_SPAWN_PANE_ID=""
  OE_SPAWN_PANE_ID="$(wez pane split --bottom --percent 30)"
}

# oe_spawn_send — 既存ペインに AI CLI コマンド + マーカー emit を送信
#
# 引数: session_id, pane_id, envelope_path, [ai_cli]（デフォルト: "cursor"）
oe_spawn_send() {
  local session_id="$1"
  local pane_id="$2"
  local envelope_path="$3"
  local ai_cli="${4:-cursor}"

  local cli_command
  cli_command="${ai_cli} --prompt 'Read ${envelope_path} and execute the task' ; printf '\\n@@OE_EXIT:%d\\n' \$?"

  wez pane send "$pane_id" "$cli_command"

  # session_start の state は audit schema（failure-taxonomy）と整合するため null
  oe_audit_emit "session_start" "$session_id" "$pane_id" "" "{}"
}

# oe_spawn — 後方互換ラッパー（prepare → send）
#
# 引数: session_id, envelope_path, [ai_cli]（デフォルト: "cursor"）
# 戻り値: OE_SPAWN_PANE_ID にペイン ID を設定
oe_spawn() {
  local session_id="$1"
  local envelope_path="$2"
  local ai_cli="${3:-cursor}"

  oe_spawn_prepare_pane
  oe_spawn_send "$session_id" "$OE_SPAWN_PANE_ID" "$envelope_path" "$ai_cli"
}
