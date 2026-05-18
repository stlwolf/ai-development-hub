#!/usr/bin/env bash
set -euo pipefail

# check_phase_c.sh — Step 4-4 Phase C 完了判定
#
# 引数: target_session_id [data_dir]
#   target_session_id  bin/oe が生成した session ID (ULID)
#   data_dir          OE_DATA_DIR のパス (デフォルト: projects/orchestration-engine)
#
# 確認項目 (Phase C 完了条件):
#   (a) state/{sid}.state.json に state == "success" + session_id 整合
#   (b) audit/{sid}.jsonl に state_change (state=success) と session_end が記録
#   (c) target stdout (.tmp_target_stdout_{sid}.log) があれば shellcheck/PASS evidence を grep
#       (Plan F-H: capture 経路は cleanup 競合のため MVP では best-effort 扱い)
#
# Exit: 0 = (a) + (b) PASS、(c) は warning レベル / 1 = 構造的 FAIL

if [[ "${1:-}" == "" ]]; then
  echo "Usage: $0 <session_id> [data_dir]" >&2
  exit 2
fi

SID="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DATA_DIR="${2:-${OE_DATA_DIR:-${PROJECT_DIR}}}"
STATE_FILE="${DATA_DIR}/state/${SID}.state.json"
AUDIT_FILE="${DATA_DIR}/audit/${SID}.jsonl"

FAIL=0
WARN=0
fail() { echo "[check_phase_c] FAIL: $*"; FAIL=$((FAIL + 1)); }
warn() { echo "[check_phase_c] WARN: $*"; WARN=$((WARN + 1)); }
pass() { echo "[check_phase_c] PASS: $*"; }

echo "=== check_phase_c ==="
echo "session_id : ${SID}"
echo "data_dir   : ${DATA_DIR}"
echo "state_file : ${STATE_FILE}"
echo "audit_file : ${AUDIT_FILE}"
echo ""

# ---- (a) KVS state ----
if [[ ! -f "$STATE_FILE" ]]; then
  fail "state file not found: $STATE_FILE"
else
  state=$(jq -r '.state' "$STATE_FILE")
  if [[ "$state" == "success" ]]; then
    pass "state.state == 'success'"
  else
    fail "state.state = '$state' (expected 'success')"
  fi

  recorded_sid=$(jq -r '.session_id' "$STATE_FILE")
  if [[ "$recorded_sid" == "$SID" ]]; then
    pass "state.session_id matches"
  else
    fail "state.session_id = '$recorded_sid' (expected '$SID')"
  fi
fi

# ---- (b) Audit events ----
if [[ ! -f "$AUDIT_FILE" ]]; then
  fail "audit file not found: $AUDIT_FILE"
else
  sc_count=$(jq -s 'map(select(.event_type == "state_change" and .state == "success")) | length' "$AUDIT_FILE")
  if [[ "$sc_count" -ge 1 ]]; then
    pass "audit: state_change (state=success) emitted (${sc_count} time(s))"
  else
    fail "audit: state_change (state=success) not emitted"
  fi

  se_count=$(jq -s 'map(select(.event_type == "session_end")) | length' "$AUDIT_FILE")
  if [[ "$se_count" -ge 1 ]]; then
    pass "audit: session_end emitted (${se_count} time(s))"
  else
    fail "audit: session_end not emitted"
  fi
fi

# ---- (c) Optional: target stdout grep (F-H best-effort) ----
STDOUT_FILE="${SCRIPT_DIR}/.tmp_target_stdout_${SID}.log"
if [[ -f "$STDOUT_FILE" ]]; then
  if grep -qiE 'shellcheck|PASS=' "$STDOUT_FILE"; then
    pass "target stdout: shellcheck / mock test PASS evidence found"
  else
    warn "target stdout file exists but no shellcheck / 'PASS=' evidence found (review ${STDOUT_FILE})"
  fi
else
  warn "target stdout file not captured (${STDOUT_FILE}) — Plan F-H best-effort deferred for MVP"
  warn "  → 構造的判定 (a)(b) のみで Phase C 完了判定。shellcheck/mock test の検証は人間が git diff + 手動実行で確認"
fi

echo ""
if [[ "$FAIL" -gt 0 ]]; then
  echo "[check_phase_c] OVERALL FAIL (FAIL=${FAIL}, WARN=${WARN})"
  exit 1
fi
echo "[check_phase_c] OVERALL PASS (WARN=${WARN}, 構造的判定のみ)"
exit 0
