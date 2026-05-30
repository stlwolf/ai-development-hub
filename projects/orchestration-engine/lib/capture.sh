# shellcheck shell=bash
# shellcheck disable=SC2034
# capture.sh — 成果物キャプチャ・分類・KVS 書き込み（source 専用）

# グローバル変数: oe_capture_scan() の戻り値
OE_SCAN_MARKER_TYPE=""
OE_SCAN_VALUE=""
OE_SCAN_BLOCKED="false"

# Step 4-3 F3: 二値保持 — @@OE_EXIT: と @@OE_VERIFY: の同時検出に対応
# (検証 agent の出力では shell が @@OE_EXIT:{code} を後置するため両方が並ぶ)
OE_SCAN_EXIT_CODE=""
OE_SCAN_VERIFY_RESULT=""

# グローバル変数: oe_capture_classify() の戻り値
OE_CLASSIFY_STATE=""

# _oe_normalize_capture_output — marker 走査前に capture/log 出力を正規化する共通ヘルパー
#
# CR 除去・ANSI エスケープ除去に加え、全角空白(U+3000)/NBSP(U+00A0) を ASCII 空白へ畳む。
# `[[:space:]]` のマルチバイト空白判定はロケール依存（ja_JP.UTF-8 では U+3000 が真、
# LC_ALL=C では偽）で marker 検知が割れるため、parse 前にここで環境差を消す。
# capture 経路 (oe_capture_scan) と verify 経路 (verify.sh:_oe_verify_scan_log_file) の
# 両方から呼ぶ。正規化を1箇所に集約し、経路間の差異（=ロケール依存の取り残し）を防ぐ。
#
# 引数: 生の capture 文字列
# 出力: 正規化済み文字列を stdout へ
_oe_normalize_capture_output() {
  printf '%s' "$1" | sed -E $'s/\r//g; s/\x1B\\[[0-9;?]*[ -/]*[@-~]//g; s/\xE3\x80\x80/ /g; s/\xC2\xA0/ /g'
}

# oe_capture_scan — pane 出力からマーカーをスキャンし種別と値を返す
#
# 引数: pane_id（WezTerm ペイン ID）
# 戻り値: OE_SCAN_MARKER_TYPE / OE_SCAN_VALUE に設定
#   マーカー未検出時は両方空文字
oe_capture_scan() {
  local pane_id="$1"
  local lines="${2:-50}"  # F-SO-4: 検証ペインなど verbose 出力を扱うケースでは呼び出し側が 200 を渡す

  OE_SCAN_MARKER_TYPE=""
  OE_SCAN_VALUE=""
  OE_SCAN_BLOCKED="false"
  OE_SCAN_EXIT_CODE=""
  OE_SCAN_VERIFY_RESULT=""

  local captured
  captured="$(wez pane capture "$pane_id" --lines "$lines" 2>/dev/null)" || return 0

  local normalized
  normalized="$(_oe_normalize_capture_output "$captured")"

  _oe_capture_scan_parse "$normalized"
}

# _oe_capture_scan_parse — capture 出力文字列をパースする内部関数
# テスト容易性のために wez 呼び出しと分離
#
# Step 4-3 F3: 二値保持
#   OE_SCAN_EXIT_CODE         @@OE_EXIT:{1-3 桁} 検出時の値
#   OE_SCAN_VERIFY_RESULT     @@OE_VERIFY:(pass|fail|warn) 検出時の値
#   OE_SCAN_MARKER_TYPE/VALUE 後方互換のため残す:
#     - EXIT 検出時 → MARKER_TYPE=EXIT, VALUE=exit_code (従来通り)
#     - VERIFY のみ検出時 → MARKER_TYPE=VERIFY, VALUE=verify_result
#     - 両方検出時 → MARKER_TYPE=EXIT (既存 monitor.sh への影響最小化、verify.sh は新変数を直接参照)
_oe_capture_scan_parse() {
  local input="$1"

  OE_SCAN_MARKER_TYPE=""
  OE_SCAN_VALUE=""
  OE_SCAN_BLOCKED="false"
  OE_SCAN_EXIT_CODE=""
  OE_SCAN_VERIFY_RESULT=""

  local line
  while IFS= read -r line; do
    # #112: TUI 字下げ対応で先頭空白を許容。
    # 理由なし `@@OE_BLOCKED` は末尾空白のみ許容し EXIT/VERIFY と対称。
    # 理由付き `@@OE_BLOCKED:reason` は後置自由（行末アンカーなし）＝エコー保護がない点に注意。
    # ただし blocked は exit_code==2 のときのみ昇格する fail-safe 設計（oe_capture_classify 参照）。
    if [[ "$line" =~ ^[[:space:]]*@@OE_BLOCKED([[:space:]]*$|:.*$) ]]; then
      OE_SCAN_BLOCKED="true"
    fi

    if [[ "$line" =~ $OE_EXIT_MARKER_RE ]]; then
      OE_SCAN_EXIT_CODE="${BASH_REMATCH[1]}"
    fi

    if [[ "$line" =~ $OE_VERIFY_MARKER_RE ]]; then
      OE_SCAN_VERIFY_RESULT="${BASH_REMATCH[1]}"
    fi
  done <<< "$input"

  # 後方互換: MARKER_TYPE / VALUE を設定
  #
  # 重要 (F-SO-5): MARKER_TYPE="VERIFY" は **検証専用ループ (oe_verify_run_phase) からのみ参照される
  # 後方互換の内部値**。monitor.sh の case "$OE_SCAN_MARKER_TYPE" に "VERIFY)" 分岐を**追加してはならない**。
  # 通常 agent ペインで偶発的に @@OE_VERIFY: が出現した場合、誤動作の原因になる。
  # 検証側は OE_SCAN_VERIFY_RESULT を直接参照する設計 (lib/verify.sh:oe_verify_run_phase)。
  if [[ -n "$OE_SCAN_EXIT_CODE" ]]; then
    OE_SCAN_MARKER_TYPE="EXIT"
    OE_SCAN_VALUE="$OE_SCAN_EXIT_CODE"
  elif [[ -n "$OE_SCAN_VERIFY_RESULT" ]]; then
    OE_SCAN_MARKER_TYPE="VERIFY"
    OE_SCAN_VALUE="$OE_SCAN_VERIFY_RESULT"
  fi
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
