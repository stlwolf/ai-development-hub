# shellcheck shell=bash
# cleanup.sh — trap ハンドラ: ペイン削除 + /tmp 削除（source 専用）

oe_cleanup() {
  [[ -n "${OE_CLEANUP_DONE:-}" ]] && return 0
  OE_CLEANUP_DONE=1

  trap - EXIT INT TERM

  local killed_json='[]'
  if [[ ${#OE_MANAGED_PANES[@]} -gt 0 ]]; then
    local pane_id
    local ids_lines=""
    for pane_id in "${OE_MANAGED_PANES[@]}"; do
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
    oe_audit_emit "cleanup" "$session_id" 0 "" "$payload_json" || true
  fi

  return 0
}
