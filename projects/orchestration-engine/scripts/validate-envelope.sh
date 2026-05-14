#!/usr/bin/env bash
set -euo pipefail

# validate-envelope.sh — エンベロープ JSON の schema 検証（jq ベース）
#
# 使用例:
#   ./scripts/validate-envelope.sh path/to/envelope.json
#   ./scripts/validate-envelope.sh path/to/envelope.json --verbose
#
# Exit codes:
#   0 = valid
#   1 = invalid (検証エラー)
#   2 = file not found / jq not found
#
# 技術選定根拠:
#   architecture-sketch §2「薄いシェル: Bash + jq」制約に準拠。
#   jq での JSON Schema 完全検証は困難だが、MVP では
#   「必須フィールド存在チェック + enum 値チェック + 型チェック」で十分。
#   JSON Schema ファイル自体は draft-07 標準準拠で作成済みのため、
#   将来 ajv-cli への移行は可能。

VERBOSE=0
if [[ "${2:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

log() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "[validate] $*" >&2
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
  echo "Usage: $0 <envelope.json> [--verbose]" >&2
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
REQUIRED_TOP=("session_id" "pane_id" "task" "context" "constraints")
for field in "${REQUIRED_TOP[@]}"; do
  if ! jq -e --arg f "$field" 'has($f)' "$TARGET" >/dev/null 2>&1; then
    fail "missing required field: $field"
  fi
done

log "checking field types..."
jq -e '.session_id | type == "string"' "$TARGET" >/dev/null 2>&1 \
  || fail "session_id must be string"
jq -e '.pane_id | type == "number"' "$TARGET" >/dev/null 2>&1 \
  || fail "pane_id must be number"
jq -e '.task | type == "object"' "$TARGET" >/dev/null 2>&1 \
  || fail "task must be object"
jq -e '.context | type == "object"' "$TARGET" >/dev/null 2>&1 \
  || fail "context must be object"
jq -e '.constraints | type == "object"' "$TARGET" >/dev/null 2>&1 \
  || fail "constraints must be object"

log "checking task required fields..."
REQUIRED_TASK=("description" "output_dir" "exit_conditions")
for field in "${REQUIRED_TASK[@]}"; do
  if ! jq -e --arg f "$field" '.task | has($f)' "$TARGET" >/dev/null 2>&1; then
    fail "missing required field: task.$field"
  fi
done

log "checking exit_conditions required fields..."
REQUIRED_EXIT=("marker" "timeout_seconds")
for field in "${REQUIRED_EXIT[@]}"; do
  if ! jq -e --arg f "$field" '.task.exit_conditions | has($f)' "$TARGET" >/dev/null 2>&1; then
    fail "missing required field: task.exit_conditions.$field"
  fi
done

log "checking constraints required fields..."
jq -e '.constraints | has("max_panes")' "$TARGET" >/dev/null 2>&1 \
  || fail "missing required field: constraints.max_panes"
jq -e '.constraints | has("state_vocabulary")' "$TARGET" >/dev/null 2>&1 \
  || fail "missing required field: constraints.state_vocabulary"

log "checking state_vocabulary enum values..."
VALID_STATES='["spawn","ready","progress","done","blocked"]'
jq -e --argjson valid "$VALID_STATES" \
  '.constraints.state_vocabulary | sort == ($valid | sort)' \
  "$TARGET" >/dev/null 2>&1 \
  || fail "constraints.state_vocabulary must contain exactly: spawn, ready, progress, done, blocked"

log "checking exit_state enum (if present)..."
VALID_EXIT_STATES='["success","partial","retryable_failure","blocked","protocol_error","timeout"]'
if jq -e 'has("exit_state")' "$TARGET" >/dev/null 2>&1; then
  jq -e --argjson valid "$VALID_EXIT_STATES" \
    '.exit_state as $s | $valid | index($s) != null' \
    "$TARGET" >/dev/null 2>&1 \
    || fail "exit_state must be one of: success, partial, retryable_failure, blocked, protocol_error, timeout"
fi

echo "OK: $TARGET"
exit 0
