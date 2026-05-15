#!/usr/bin/env bash
set -euo pipefail

# validate-session-state.sh — Session State KVS JSON の schema 検証（jq ベース）
#
# 使用例:
#   ./scripts/validate-session-state.sh path/to/{session_id}.state.json
#   ./scripts/validate-session-state.sh path/to/state.json --verbose
#
# Exit codes:
#   0 = valid
#   1 = invalid (検証エラー)
#   2 = file not found / jq not found
#
# Step 4-3 で追加。session-state.schema.json の主要制約（必須フィールド・型・enum・
# verification map / verification_summary の構造）を jq で検証する。
# validate-envelope.sh の構造を踏襲。

VERBOSE=0
if [[ "${2:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

log() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "[validate-state] $*" >&2
  fi
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is not installed" >&2
  exit 2
fi

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <session-state.json> [--verbose]" >&2
  exit 2
fi

if [[ ! -f "$TARGET" ]]; then
  echo "ERROR: file not found: $TARGET" >&2
  exit 2
fi

if ! jq empty "$TARGET" 2>/dev/null; then
  fail "invalid JSON: $TARGET"
fi

log "checking required top-level fields..."
REQUIRED_TOP=("session_id" "pane_id" "state" "last_updated")
for field in "${REQUIRED_TOP[@]}"; do
  if ! jq -e --arg f "$field" 'has($f)' "$TARGET" >/dev/null 2>&1; then
    fail "missing required field: $field"
  fi
done

log "checking field types..."
jq -e '.session_id | type == "string"' "$TARGET" >/dev/null 2>&1 \
  || fail "session_id must be string"
jq -e '.session_id | test("^[0-9A-HJKMNP-TV-Z]{26}$")' "$TARGET" >/dev/null 2>&1 \
  || fail "session_id must match ULID pattern"
jq -e '.pane_id | type == "number"' "$TARGET" >/dev/null 2>&1 \
  || fail "pane_id must be number"
jq -e '.state | type == "string"' "$TARGET" >/dev/null 2>&1 \
  || fail "state must be string"
jq -e '.last_updated | type == "string"' "$TARGET" >/dev/null 2>&1 \
  || fail "last_updated must be string"

log "checking state enum..."
VALID_STATES='["success","partial","retryable_failure","blocked","protocol_error","timeout"]'
jq -e --argjson valid "$VALID_STATES" \
  '.state as $s | $valid | index($s) != null' \
  "$TARGET" >/dev/null 2>&1 \
  || fail "state must be one of: success, partial, retryable_failure, blocked, protocol_error, timeout"

log "checking optional outputs / blockers arrays..."
if jq -e 'has("outputs")' "$TARGET" >/dev/null 2>&1; then
  jq -e '.outputs | type == "array"' "$TARGET" >/dev/null 2>&1 \
    || fail "outputs must be array"
fi
if jq -e 'has("blockers")' "$TARGET" >/dev/null 2>&1; then
  jq -e '.blockers | type == "array"' "$TARGET" >/dev/null 2>&1 \
    || fail "blockers must be array"
fi

log "checking optional verification map (Step 4-3)..."
if jq -e 'has("verification")' "$TARGET" >/dev/null 2>&1; then
  jq -e '.verification | type == "object"' "$TARGET" >/dev/null 2>&1 \
    || fail "verification must be object (pane-keyed map)"

  VALID_RESULTS='["pass","fail","warn"]'
  # 各 pane キーのオブジェクトを検証
  while IFS= read -r pane_key; do
    log "  checking verification.$pane_key ..."
    jq -e --arg k "$pane_key" '.verification[$k] | type == "object"' "$TARGET" >/dev/null 2>&1 \
      || fail "verification.$pane_key must be object"

    REQUIRED_V=("result" "reviewer_session_id" "reviewer_pane_id" "completed_at")
    for field in "${REQUIRED_V[@]}"; do
      if ! jq -e --arg k "$pane_key" --arg f "$field" \
        '.verification[$k] | has($f)' "$TARGET" >/dev/null 2>&1; then
        fail "missing verification.$pane_key.$field"
      fi
    done

    jq -e --arg k "$pane_key" --argjson valid "$VALID_RESULTS" \
      '.verification[$k].result as $r | $valid | index($r) != null' \
      "$TARGET" >/dev/null 2>&1 \
      || fail "verification.$pane_key.result must be pass/fail/warn"

    jq -e --arg k "$pane_key" \
      '.verification[$k].reviewer_session_id | test("^[0-9A-HJKMNP-TV-Z]{26}$")' \
      "$TARGET" >/dev/null 2>&1 \
      || fail "verification.$pane_key.reviewer_session_id must match ULID pattern"

    jq -e --arg k "$pane_key" \
      '.verification[$k].reviewer_pane_id | type == "number"' \
      "$TARGET" >/dev/null 2>&1 \
      || fail "verification.$pane_key.reviewer_pane_id must be number"

    # marker_raw は optional だが、ある場合はパターン検証
    if jq -e --arg k "$pane_key" '.verification[$k] | has("marker_raw")' \
      "$TARGET" >/dev/null 2>&1; then
      jq -e --arg k "$pane_key" \
        '.verification[$k].marker_raw | test("^@@OE_VERIFY:(pass|fail|warn)$")' \
        "$TARGET" >/dev/null 2>&1 \
        || fail "verification.$pane_key.marker_raw must match @@OE_VERIFY:(pass|fail|warn)"
    fi
  done < <(jq -r '.verification | keys[]' "$TARGET")
fi

log "checking optional verification_summary (Step 4-3)..."
if jq -e 'has("verification_summary")' "$TARGET" >/dev/null 2>&1; then
  jq -e '.verification_summary | type == "object"' "$TARGET" >/dev/null 2>&1 \
    || fail "verification_summary must be object"

  REQUIRED_VS=("total" "passed" "failed" "warned" "fail_rate")
  for field in "${REQUIRED_VS[@]}"; do
    if ! jq -e --arg f "$field" '.verification_summary | has($f)' \
      "$TARGET" >/dev/null 2>&1; then
      fail "missing verification_summary.$field"
    fi
  done

  for field in total passed failed warned; do
    jq -e --arg f "$field" \
      '.verification_summary[$f] | type == "number" and . >= 0 and (. - (. | floor) == 0)' \
      "$TARGET" >/dev/null 2>&1 \
      || fail "verification_summary.$field must be non-negative integer"
  done

  jq -e \
    '.verification_summary.fail_rate | type == "number" and . >= 0 and . <= 1' \
    "$TARGET" >/dev/null 2>&1 \
    || fail "verification_summary.fail_rate must be number in [0, 1]"
fi

echo "OK: $TARGET"
exit 0
