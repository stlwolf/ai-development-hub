#!/usr/bin/env bash
# shellcheck disable=SC2016  # 一重引用符の中は jq の式で、$c などは jq の変数である
set -euo pipefail

# validate-lease.sh — lease の記録（schemas/oe-lease.schema.json）の検証（jq ベース・#577 PR-1）
#
# 使用例:
#   ./scripts/validate-lease.sh ~/.claude/state/oe-lease/<lease_id>.json
#   ./scripts/validate-lease.sh path/to/lease.json --verbose
#
# Exit codes:
#   0 = valid
#   1 = invalid (検証エラー)
#   2 = file not found / jq not found / usage
#
# validate-session-state.sh の構造を踏襲する。schema の主な制約（必須の項目・型・enum・generations の
# 並びと current_generation の対応・active の generation が1つだけ）を jq で見る。

VERBOSE=0
if [[ "${2:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

log() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "[validate-lease] $*" >&2
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
  echo "Usage: $0 <lease.json> [--verbose]" >&2
  exit 2
fi

if [[ ! -f "$TARGET" ]]; then
  echo "ERROR: file not found: $TARGET" >&2
  exit 2
fi

if ! jq empty "$TARGET" 2>/dev/null; then
  fail "invalid JSON: $TARGET"
fi

check() { # check <jq の真偽式> <失敗の理由>
  jq -e "$1" "$TARGET" >/dev/null 2>&1 || fail "$2"
}

log "checking top-level fields..."
check 'type == "object"' "top level must be an object"
for field in format lease_id kind label workspace parent_lease_id state created_at closed_at epoch current_generation generations; do
  jq -e --arg f "$field" 'has($f)' "$TARGET" >/dev/null 2>&1 || fail "missing required field: $field"
done
check '(keys - ["format","lease_id","kind","label","workspace","parent_lease_id","state","created_at","closed_at","epoch","current_generation","generations"]) | length == 0' "unknown top-level field"
check '.format == 1' "format must be 1"
check '.lease_id | type == "string" and test("^[0-9A-HJKMNP-TV-Z]{26}$")' "lease_id must match ULID pattern"
check '.kind | IN("supervisor","delegation")' "kind must be supervisor|delegation"
check '.label | type == "string"' "label must be string"
check '.workspace | type == "string"' "workspace must be string"
check '.parent_lease_id | type == "string" and test("^([0-9A-HJKMNP-TV-Z]{26})?$")' "parent_lease_id must be empty or ULID"
check '.parent_lease_id != .lease_id' "parent_lease_id must not be itself"
check '.state | IN("open","closed")' "state must be open|closed"
check '.created_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "created_at must be UTC ISO 8601 (Z)"
check '.closed_at | type == "string" and test("^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$")' "closed_at must be empty or UTC ISO 8601 (Z)"
check '(.state == "closed") == (.closed_at != "")' "closed_at must be set exactly when state is closed"
check '.epoch | type == "number" and . >= 0 and (. == floor)' "epoch must be a non-negative integer"
check '.current_generation | type == "number" and . >= 1 and (. == floor)' "current_generation must be a positive integer"

log "checking generations..."
check '.generations | type == "array" and length >= 1' "generations must be a non-empty array"
check 'all(.generations[]; type == "object"
        and ((keys - ["generation","state","started_at","retired_at","successor","session_ids","binding"]) | length == 0)
        and has("generation") and has("state") and has("started_at") and has("retired_at")
        and has("successor") and has("session_ids") and has("binding"))' "generation entries must have exactly the known fields"
check 'all(.generations[]; (.generation | type == "number" and . >= 1 and (. == floor)))' "generation must be a positive integer"
check '[.generations[].generation] | (. == (unique)) ' "generation numbers must be unique and ascending"
check '.current_generation as $c | any(.generations[]; .generation == $c)' "current_generation must exist in generations"
check 'all(.generations[]; .state | IN("active","retired"))' "generation state must be active|retired"
check '.current_generation as $c | [.generations[] | select(.state == "active") | .generation] | (. == [$c])' "exactly the current generation must be active"
check 'all(.generations[]; (.state == "retired") == (.retired_at != ""))' "retired_at must be set exactly when retired"
check 'all(.generations[]; .successor == null or (.successor | type == "number"))' "successor must be null or integer"
check 'all(.generations[]; .session_ids | type == "array" and all(.[]; type == "string" and test("^[A-Za-z0-9._-]+$")) and (length == (unique | length)))' "session_ids must be unique strings"
check '[.generations[].session_ids[]] | length == (unique | length)' "a session_id must not appear in two generations"
check 'all(.generations[]; .binding == null or (.binding | type == "object"
        and ((keys - ["pid","started","comm","bound_at"]) | length == 0)
        and (.pid | type == "number" and . >= 1 and (. == floor))
        and (.started | type == "string" and length > 0)
        and (.comm | type == "string" and test("claude"))
        and (.bound_at | type == "string")))' "binding must be null or {pid, started, comm(claude), bound_at}"

log "valid"
echo "OK: $TARGET"
