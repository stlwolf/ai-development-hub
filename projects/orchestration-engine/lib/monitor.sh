# shellcheck shell=bash
# shellcheck disable=SC2034
# monitor.sh — ポーリングループ + サーキットブレーカー（source 専用）

# 管理ペイン追跡（spawn 済みペイン ID）
OE_MANAGED_PANES=()

# 完了済みペイン（マーカー検出済み、監視対象から除外）
OE_DONE_PANES=()

# 前回 state 保持（Bash 3.2 互換: ペイン ID と state を平行配列で保持）
_OE_LAST_STATE_PANES=()
_OE_LAST_STATE_VALS=()

# シグナル受信フラグ（trap ハンドラ用グローバル）
_OE_MONITOR_INTERRUPTED=0

# SIGINT / SIGTERM 区別（trap から設定、interrupt 監査の payload.method に使用）
_OE_INTERRUPT_METHOD=""

_oe_monitor_last_state_clear() {
  _OE_LAST_STATE_PANES=()
  _OE_LAST_STATE_VALS=()
}

# 戻り値: 0 で stdout に state（改行なし）、未登録は 1
_oe_monitor_last_state_get() {
  local pane_id="$1"
  local i
  for (( i = 0; i < ${#_OE_LAST_STATE_PANES[@]}; i++ )); do
    if [[ "${_OE_LAST_STATE_PANES[i]}" == "$pane_id" ]]; then
      printf '%s' "${_OE_LAST_STATE_VALS[i]}"
      return 0
    fi
  done
  return 1
}

_oe_monitor_last_state_set() {
  local pane_id="$1"
  local state="$2"
  local i
  for (( i = 0; i < ${#_OE_LAST_STATE_PANES[@]}; i++ )); do
    if [[ "${_OE_LAST_STATE_PANES[i]}" == "$pane_id" ]]; then
      _OE_LAST_STATE_VALS[i]="$state"
      return 0
    fi
  done
  _OE_LAST_STATE_PANES+=("$pane_id")
  _OE_LAST_STATE_VALS+=("$state")
}

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
  _oe_monitor_last_state_clear
  _OE_MONITOR_INTERRUPTED=0
  _OE_INTERRUPT_METHOD=""

  local cb_payload

  # CB: ペイン数チェック（初回のみ）
  if [[ ${#OE_MANAGED_PANES[@]} -gt $OE_CB_MAX_PANES ]]; then
    cb_payload='{"reason":"max_panes"}'
    oe_audit_emit "circuit_breaker_triggered" "$session_id" 0 "" "$cb_payload"
    _oe_monitor_kill_all_panes
    return 1
  fi

  trap '_OE_MONITOR_INTERRUPTED=1; _OE_INTERRUPT_METHOD=SIGINT' INT
  trap '_OE_MONITOR_INTERRUPTED=1; _OE_INTERRUPT_METHOD=SIGTERM' TERM

  local turn=0
  local start_seconds=$SECONDS

  while true; do
    if [[ $_OE_MONITOR_INTERRUPTED -ne 0 ]]; then
      local intr_payload
      intr_payload="$(jq -cn --arg m "${_OE_INTERRUPT_METHOD:-SIGINT}" '{method:$m}')"
      oe_audit_emit "interrupt" "$session_id" 0 "" "$intr_payload" || true
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
    #
    # #114/#98: pane scrape (oe_capture_scan = wez pane capture, viewport-only/2D グリッド) でなく
    #   target が tee した per-session ログファイルを走査する (spawn.sh:oe_spawn_send が同じ
    #   _oe_target_log_path で tee 先を組む = パス書式の単一情報源)。OE_SCAN_MARKER_TYPE=EXIT の
    #   消費部 (下記 case) は不変で、marker の source が pane→file に変わるだけ。
    for pane_id in "${pending[@]}"; do
      _oe_scan_log_file "$(_oe_target_log_path "$session_id" "$pane_id")"

      case "$OE_SCAN_MARKER_TYPE" in
        EXIT)
          oe_capture_classify "$OE_SCAN_VALUE" "$OE_SCAN_BLOCKED"

          # 状態変化時に state_change → session_end の順で emit
          local _prev_ls
          _prev_ls="$(_oe_monitor_last_state_get "$pane_id" 2>/dev/null || true)"
          if [[ "$_prev_ls" != "$OE_CLASSIFY_STATE" ]]; then
            _oe_monitor_last_state_set "$pane_id" "$OE_CLASSIFY_STATE"
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

    # CB: 経過時間（呼び出し元の SECONDS を壊さないようローカル起点との差分で判定）
    if [[ $((SECONDS - start_seconds)) -ge $OE_CB_TIMEOUT ]]; then
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
