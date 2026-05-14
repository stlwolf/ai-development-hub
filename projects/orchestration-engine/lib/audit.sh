# shellcheck shell=bash
# audit.sh — 監査ログ JSONL 追記（source 専用）

oe_audit_emit() {
  local event_type="${1:-}"
  local session_id="${2:-}"
  local pane_id="${3:-}"
  local state="${4:-}"
  local payload_json="${5:-}"

  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")"

  local out_file="${OE_AUDIT_DIR}/${session_id}.jsonl"
  local state_json
  local payload_arg
  local oe_valid_state_re='^(success|partial|retryable_failure|blocked|protocol_error|timeout)$'

  if [[ -n "$state" ]]; then
    if [[ "$state" =~ $oe_valid_state_re ]]; then
      state_json="$(jq -cn --arg value "$state" '$value')"
    else
      echo "oe_audit_emit: invalid state '${state}', coercing to null" >&2
      state_json="null"
    fi
  else
    state_json="null"
  fi

  if [[ -n "$payload_json" ]]; then
    if ! echo "$payload_json" | jq -e 'type == "object"' >/dev/null 2>&1; then
      echo "oe_audit_emit: invalid payload (must be JSON object)" >&2
      return 1
    fi
    payload_arg="$payload_json"
  else
    payload_arg='{}'
  fi

  jq -cn \
    --arg ts "$ts" \
    --arg event_type "$event_type" \
    --arg session_id "$session_id" \
    --argjson pane_id "$pane_id" \
    --argjson state "$state_json" \
    --argjson payload "$payload_arg" \
    '{ts:$ts,event_type:$event_type,session_id:$session_id,pane_id:$pane_id,state:$state,payload:$payload}' \
    >> "$out_file"
  return 0
}
