# shellcheck shell=bash
# cleanup.sh — trap ハンドラ: ペイン削除 + /tmp 削除 + wez notify（source 専用）

oe_cleanup() {
  [[ -n "${OE_CLEANUP_DONE:-}" ]] && return 0
  OE_CLEANUP_DONE=1

  trap - EXIT INT TERM

  # 防御的初期化: 未宣言でも安全に動作するよう (test_cleanup.sh のように
  # constants.sh を source せず cleanup.sh 単独で source されるケースに備える)
  declare -p OE_MANAGED_PANES >/dev/null 2>&1 || OE_MANAGED_PANES=()
  declare -p OE_VERIFY_MANAGED_PANES >/dev/null 2>&1 || OE_VERIFY_MANAGED_PANES=()

  # 通常ペイン + 検証ペイン (OE_VERIFY_MANAGED_PANES) の両方を kill 対象に
  local all_panes=()
  if [[ ${#OE_MANAGED_PANES[@]} -gt 0 ]]; then
    all_panes+=("${OE_MANAGED_PANES[@]}")
  fi
  if [[ ${#OE_VERIFY_MANAGED_PANES[@]} -gt 0 ]]; then
    all_panes+=("${OE_VERIFY_MANAGED_PANES[@]}")
  fi

  local killed_json='[]'
  if [[ ${#all_panes[@]} -gt 0 ]]; then
    local pane_id
    local ids_lines=""
    for pane_id in "${all_panes[@]}"; do
      [[ -n "$pane_id" ]] || continue
      ids_lines+="${pane_id}"$'\n'
      wez pane kill "$pane_id" 2>/dev/null || true
    done
    killed_json="$(printf '%s' "$ids_lines" | jq -R -s 'split("\n") | map(select(length>0) | tonumber)')"
  fi

  local payload_json
  payload_json="$(jq -cn --argjson ids "$killed_json" '{killed_pane_ids:$ids}')"

  local session_id="${OE_CURRENT_SESSION_ID:-}"
  if [[ -n "$session_id" ]]; then
    local tmp_path
    for tmp_path in /tmp/oe-"$session_id"-*; do
      [[ -e "$tmp_path" ]] || continue
      rm -f "$tmp_path" 2>/dev/null || true
    done

    # 検証 agent の一時ファイル (reviewer_session_id 起点) も削除
    local reviewer_pane
    for reviewer_pane in "${OE_VERIFY_MANAGED_PANES[@]}"; do
      # reviewer ファイルは reviewer_session_id ベース。pane_id では特定できないため
      # /tmp/oe-*-verify-{envelope.json,inputs.md} を一括掃除する想定だが、
      # 他セッションの一時ファイルに影響を出さないよう、ここではセッション内で
      # 生成された reviewer envelope/inputs は OS の /tmp 自動掃除に任せる。
      : "$reviewer_pane"
    done

    oe_audit_emit "cleanup" "$session_id" 0 "" "$payload_json" || true

    # Step 4-4 Phase C: reviewer 一時ファイル削除 (派生 #93 前半)
    # OE_VERIFY_REVIEWER_SESSION_IDS の各 ID について /tmp/oe-{rsid}-verify-* と
    # /tmp/oe-{rsid}-reviewer.log (Phase C.5 file-redirect 経路) を削除
    declare -p OE_VERIFY_REVIEWER_SESSION_IDS >/dev/null 2>&1 || OE_VERIFY_REVIEWER_SESSION_IDS=()
    local rsid
    for rsid in "${OE_VERIFY_REVIEWER_SESSION_IDS[@]}"; do
      [[ -n "$rsid" ]] || continue
      rm -f "/tmp/oe-${rsid}-verify-envelope.json" 2>/dev/null || true
      rm -f "/tmp/oe-${rsid}-verify-inputs.md" 2>/dev/null || true
      rm -f "/tmp/oe-${rsid}-reviewer.log" 2>/dev/null || true
    done

    # DI-6: 検証フェーズが走った場合は wez notify で完了通知
    # (monitor の CB / interrupt で検証フェーズに到達しなかった場合は OE_VERIFY_PHASE_COMPLETED=0 のままスキップ)
    #
    # Copilot #2 反映: OE_VERIFY_PHASE_COMPLETED=1 は「検証フェーズが走った」事実を示す。
    #                   timeouts / protocol_errors は notify 本文で別途明示する。
    # Copilot #8 反映: protocol_errors + timeouts を notify 本文に含めることで誤った成功通知を防ぐ。
    if [[ "${OE_VERIFY_PHASE_COMPLETED:-0}" -eq 1 ]]; then
      local state_file="${OE_STATE_DIR}/${session_id}.state.json"
      local notify_body
      if [[ -f "$state_file" ]] && jq -e '.verification_summary' "$state_file" >/dev/null 2>&1; then
        local s_pass s_fail s_warn s_rate s_protocol s_timeouts
        s_pass="$(jq -r '.verification_summary.passed' "$state_file")"
        s_fail="$(jq -r '.verification_summary.failed' "$state_file")"
        s_warn="$(jq -r '.verification_summary.warned' "$state_file")"
        s_rate="$(jq -r '.verification_summary.fail_rate' "$state_file")"
        s_protocol="$(jq -r '.verification_summary.protocol_errors // 0' "$state_file")"
        s_timeouts="$(jq -r '.verification_summary.timeouts // 0' "$state_file")"
        notify_body="session_id=${session_id}, verification: pass=${s_pass}, fail=${s_fail}, warn=${s_warn}, fail_rate=${s_rate}, protocol_errors=${s_protocol}, timeouts=${s_timeouts}"
      else
        notify_body="session_id=${session_id} (no verification_summary)"
      fi
      # best-effort: notify 失敗は engine 終了に影響させない
      wez notify "orchestration-engine session complete" "$notify_body" 2>/dev/null || true
    fi
  fi

  return 0
}
