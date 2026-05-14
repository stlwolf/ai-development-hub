# shellcheck shell=bash
# shellcheck disable=SC2034
# capture.sh — 成果物キャプチャ・分類・KVS 書き込み（source 専用）

# グローバル変数: oe_capture_scan() の戻り値
OE_SCAN_MARKER_TYPE=""
OE_SCAN_VALUE=""
OE_SCAN_BLOCKED="false"

# グローバル変数: oe_capture_classify() の戻り値
OE_CLASSIFY_STATE=""

# oe_capture_scan — pane 出力からマーカーをスキャンし種別と値を返す
#
# 引数: pane_id（WezTerm ペイン ID）
# 戻り値: OE_SCAN_MARKER_TYPE / OE_SCAN_VALUE に設定
#   マーカー未検出時は両方空文字
oe_capture_scan() {
  local pane_id="$1"

  OE_SCAN_MARKER_TYPE=""
  OE_SCAN_VALUE=""
  OE_SCAN_BLOCKED="false"

  local captured
  captured="$(wez pane capture "$pane_id" --lines 50 2>/dev/null)" || return 0

  local normalized
  normalized="$(printf '%s' "$captured" | sed -E $'s/\r//g; s/\x1B\\[[0-9;?]*[ -/]*[@-~]//g')"

  _oe_capture_scan_parse "$normalized"
}

# _oe_capture_scan_parse — capture 出力文字列をパースする内部関数
# テスト容易性のために wez 呼び出しと分離
_oe_capture_scan_parse() {
  local input="$1"

  OE_SCAN_MARKER_TYPE=""
  OE_SCAN_VALUE=""
  OE_SCAN_BLOCKED="false"

  local line
  while IFS= read -r line; do
    if [[ "$line" =~ ^@@OE_BLOCKED($|:.*$) ]]; then
      OE_SCAN_BLOCKED="true"
    fi

    if [[ "$line" =~ $OE_EXIT_MARKER_RE ]]; then
      OE_SCAN_MARKER_TYPE="EXIT"
      OE_SCAN_VALUE="${BASH_REMATCH[1]}"
    fi
  done <<< "$input"
}

# oe_capture_classify — exit code を failure-taxonomy 6 値に分類
#
# 引数: exit_code（整数）, [blocked_flag]（"true" の場合 blocked 上書き）
# 戻り値: OE_CLASSIFY_STATE に 6 値文字列を設定
oe_capture_classify() {
  local exit_code="$1"
  local blocked_flag="${2:-}"

  OE_CLASSIFY_STATE=""

  case "$exit_code" in
    0)   OE_CLASSIFY_STATE="success" ;;
    1)   OE_CLASSIFY_STATE="partial" ;;
    2)
      if [[ "$blocked_flag" == "true" ]]; then
        OE_CLASSIFY_STATE="blocked"
      else
        OE_CLASSIFY_STATE="retryable_failure"
      fi
      ;;
    124) OE_CLASSIFY_STATE="timeout" ;;
    *)   OE_CLASSIFY_STATE="protocol_error" ;;
  esac
}

oe_capture_write_kvs() {
  local session_id="${1:-}"
  local pane_id="${2:-}"
  local state="${3:-}"
  : "$session_id" "$pane_id" "$state"

  local last_updated
  last_updated="$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")"

  local blockers='[]'
  if [[ "$state" == "blocked" ]]; then
    blockers='["@@OE_BLOCKED"]'
  fi

  local state_file="${OE_STATE_DIR}/${session_id}.state.json"
  local tmp_file="${OE_STATE_DIR}/.${session_id}.state.json.$$"

  jq -n \
    --arg session_id "$session_id" \
    --argjson pane_id "$pane_id" \
    --arg state "$state" \
    --arg last_updated "$last_updated" \
    --argjson blockers "$blockers" \
    '{session_id:$session_id,pane_id:$pane_id,state:$state,last_updated:$last_updated,outputs:[],blockers:$blockers}' \
    > "$tmp_file"

  mv -f "$tmp_file" "$state_file"
  return 0
}
