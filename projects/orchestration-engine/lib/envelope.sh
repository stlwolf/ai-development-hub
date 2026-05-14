# shellcheck shell=bash
# shellcheck disable=SC2034
# envelope.sh — エンベロープ生成（source 専用）

# グローバル変数: oe_envelope_create() の戻り値
OE_ENVELOPE_PATH=""

# oe_envelope_create — エンベロープ JSON を生成し validate-envelope.sh で検証
#
# 引数: session_id, pane_id, task_description, output_dir, timeout_seconds
# 戻り値: OE_ENVELOPE_PATH に生成ファイルパスを設定
# 検証失敗時は exit 1（set -e による自動終了）
oe_envelope_create() {
  local session_id="$1"
  local pane_id="$2"
  local task_description="$3"
  local output_dir="$4"
  local timeout_seconds="$5"

  OE_ENVELOPE_PATH=""

  local envelope_path="/tmp/oe-${session_id}-envelope.json"

  jq -n \
    --arg sid "$session_id" \
    --argjson pid "$pane_id" \
    --arg desc "$task_description" \
    --arg odir "$output_dir" \
    --argjson timeout "$timeout_seconds" \
    --argjson max_panes "$OE_CB_MAX_PANES" \
    '{
      session_id: $sid,
      pane_id: $pid,
      task: {
        description: $desc,
        output_dir: $odir,
        exit_conditions: {
          marker: "@@OE_EXIT",
          timeout_seconds: $timeout
        },
        read_docs: [],
        use_skills: []
      },
      context: {
        parent_session_id: null,
        related_issues: [],
        shared_kvs_path: null
      },
      constraints: {
        max_panes: $max_panes,
        state_vocabulary: ["spawn","ready","progress","done","blocked"]
      }
    }' > "$envelope_path"

  "${PROJECT_DIR}/scripts/validate-envelope.sh" "$envelope_path"

  OE_ENVELOPE_PATH="$envelope_path"
}
