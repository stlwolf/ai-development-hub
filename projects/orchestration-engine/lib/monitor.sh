# shellcheck shell=bash
# shellcheck disable=SC2034
# monitor.sh — ポーリングループ + サーキットブレーカー（source 専用）

# 管理ペイン追跡（spawn 済みペイン ID）
OE_MANAGED_PANES=()

# 完了済みペイン（マーカー検出済み、監視対象から除外）
OE_DONE_PANES=()

# 前回 state 保持（Bash 4+ 必須: declare -A）
declare -A OE_LAST_STATE

# シグナル受信フラグ（trap ハンドラ用グローバル）
_OE_MONITOR_INTERRUPTED=0

# oe_monitor_loop — メインポーリングループ
#
# 引数: session_id pane_id1 [pane_id2 ...]
# 終了条件: 全ペイン完了 / CB 発動 / SIGINT・SIGTERM 受信
oe_monitor_loop() {
  local session_id="$1"
  shift

  local monitor_rc=0

  OE_MANAGED_PANES=("$@")
  OE_DONE_PANES=()
  OE_LAST_STATE=()
  _OE_MONITOR_INTERRUPTED=0

  local cb_payload

  # CB: ペイン数チェック（初回のみ）
  if [[ ${#OE_MANAGED_PANES[@]} -gt $OE_CB_MAX_PANES ]]; then
    cb_payload='{"reason":"max_panes"}'
    oe_audit_emit "circuit_breaker_triggered" "$session_id" 0 "" "$cb_payload"
    _oe_monitor_kill_all_panes
    return 1
  fi

  trap '_OE_MONITOR_INTERRUPTED=1' INT TERM

  local turn=0
  SECONDS=0

  while true; do
    if [[ $_OE_MONITOR_INTERRUPTED -ne 0 ]]; then
      monitor_rc=130
      break
    fi

    # 未完了ペインリスト取得
    local pending=()
    local pane_id
    for pane_id in "${OE_MANAGED_PANES[@]}"; do
      if ! _oe_monitor_is_done "$pane_id"; then
        pending+=("$pane_id")
      fi
    done

    if [[ ${#pending[@]} -eq 0 ]]; then
      break
    fi

    # 各ペインスキャン + マーカー処理
    for pane_id in "${pending[@]}"; do
      oe_capture_scan "$pane_id"

      case "$OE_SCAN_MARKER_TYPE" in
        EXIT)
          oe_capture_classify "$OE_SCAN_VALUE" "$OE_SCAN_BLOCKED"

          # 状態変化時に state_change → session_end の順で emit
          if [[ "${OE_LAST_STATE[$pane_id]:-}" != "$OE_CLASSIFY_STATE" ]]; then
            OE_LAST_STATE[$pane_id]="$OE_CLASSIFY_STATE"
            oe_audit_emit "state_change" "$session_id" "$pane_id" "$OE_CLASSIFY_STATE"
          fi

          oe_audit_emit "session_end" "$session_id" "$pane_id" "$OE_CLASSIFY_STATE"
          oe_capture_write_kvs "$session_id" "$pane_id" "$OE_CLASSIFY_STATE"
          OE_DONE_PANES+=("$pane_id")
          ;;
        # 将来: STATUS / READY / OUTPUT / BLOCKED を追加
        *)
          ;;
      esac
    done

    # CB: 経過時間
    if [[ $SECONDS -ge $OE_CB_TIMEOUT ]]; then
      cb_payload='{"reason":"timeout"}'
      oe_audit_emit "circuit_breaker_triggered" "$session_id" 0 "" "$cb_payload"
      _oe_monitor_kill_all_panes
      monitor_rc=1
      break
    fi

    # CB: ターン数
    (( turn++ )) || true
    if [[ $turn -ge $OE_CB_MAX_TURNS ]]; then
      cb_payload='{"reason":"max_turns"}'
      oe_audit_emit "circuit_breaker_triggered" "$session_id" 0 "" "$cb_payload"
      _oe_monitor_kill_all_panes
      monitor_rc=1
      break
    fi

    sleep "$OE_POLL_INTERVAL"
  done

  trap - INT TERM
  return "$monitor_rc"
}

# _oe_monitor_is_done — ペインが OE_DONE_PANES に含まれるか判定
_oe_monitor_is_done() {
  local target="$1"
  [[ ${#OE_DONE_PANES[@]} -eq 0 ]] && return 1
  local done_id
  for done_id in "${OE_DONE_PANES[@]}"; do
    if [[ "$done_id" == "$target" ]]; then
      return 0
    fi
  done
  return 1
}

# _oe_monitor_kill_all_panes — 全管理ペインを wez pane kill で終了
_oe_monitor_kill_all_panes() {
  local pane_id
  for pane_id in "${OE_MANAGED_PANES[@]}"; do
    wez pane kill "$pane_id" 2>/dev/null || true
  done
}
