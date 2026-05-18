#!/usr/bin/env bash
set -euo pipefail

# check_cycle_complete.sh — Step 4-4 Phase D Step 12: 1 サイクル完走の構造的判定 (4 点)
#
# 引数: target_session_id target_pane_id [data_dir]
#
# 確認項目 (Plan §Phase D Step 12 + GATE):
#   (1) target の @@OE_EXIT:0 検出 (session_end.state=success を代理指標)
#   (1) reviewer の @@OE_VERIFY:{pass|fail|warn} 検出 (KVS verification[pid].marker_raw)
#   (2) KVS validation (validate-session-state.sh + state=success + verification[pid].result)
#   (3) audit event_type ホワイトリスト + 件数 (必須イベント + CB 0 件)
#   (4) wez notify 呼び出し (notify.log 存在 + 本文フォーマット、shim 経由のみ判定可)
#
# Exit: 0 = 全 PASS、1 = いずれかが FAIL

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <target_session_id> <target_pane_id> [data_dir]" >&2
  exit 2
fi

TARGET_SESSION_ID="$1"
TARGET_PANE_ID="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DATA_DIR="${3:-${OE_DATA_DIR:-${PROJECT_DIR}}}"
STATE_FILE="${DATA_DIR}/state/${TARGET_SESSION_ID}.state.json"
AUDIT_FILE="${DATA_DIR}/audit/${TARGET_SESSION_ID}.jsonl"

FAIL=0
WARN=0
VERIFY_RESULT_OBSERVED=""

fail() { echo "[check_cycle] FAIL: $*"; FAIL=$((FAIL + 1)); }
warn() { echo "[check_cycle] WARN: $*"; WARN=$((WARN + 1)); }
pass() { echo "[check_cycle] PASS: $*"; }

echo "=== check_cycle_complete ==="
echo "target_session_id : ${TARGET_SESSION_ID}"
echo "target_pane_id    : ${TARGET_PANE_ID}"
echo "data_dir          : ${DATA_DIR}"
echo "state_file        : ${STATE_FILE}"
echo "audit_file        : ${AUDIT_FILE}"
echo ""

# ---- (1a) target session_end.state ----
echo "--- (1a) target @@OE_EXIT (session_end.state 代理指標) ---"
if [[ ! -f "$AUDIT_FILE" ]]; then
  fail "audit file not found: $AUDIT_FILE"
else
  exit_ok=$(jq -s -r 'map(select(.event_type == "session_end")) | last | .state // "null"' "$AUDIT_FILE")
  if [[ "$exit_ok" == "success" ]]; then
    pass "target session_end.state == 'success' (= @@OE_EXIT:0 の代理指標)"
  else
    fail "target session_end.state = '$exit_ok' (expected 'success')"
  fi
fi

# ---- (1b) reviewer marker_raw ----
echo ""
echo "--- (1b) reviewer @@OE_VERIFY:(pass|fail|warn) 検出 (KVS verification[pid].marker_raw) ---"
if [[ ! -f "$STATE_FILE" ]]; then
  fail "state file not found: $STATE_FILE"
else
  verify_raw=$(jq -r --arg pid "$TARGET_PANE_ID" '.verification[$pid].marker_raw // "null"' "$STATE_FILE")
  if [[ "$verify_raw" =~ ^@@OE_VERIFY:(pass|fail|warn)$ ]]; then
    VERIFY_RESULT_OBSERVED="${BASH_REMATCH[1]}"
    pass "reviewer marker_raw = '${verify_raw}' (verify_result=${VERIFY_RESULT_OBSERVED})"
  else
    fail "reviewer marker_raw expected '@@OE_VERIFY:(pass|fail|warn)', got: '${verify_raw}'"
  fi
fi

# ---- (2) KVS validation ----
echo ""
echo "--- (2) KVS validation (validate-session-state.sh + state=success + verification[pid].result) ---"
if [[ ! -f "$STATE_FILE" ]]; then
  fail "state file not found (re): $STATE_FILE"
else
  if "${PROJECT_DIR}/scripts/validate-session-state.sh" "$STATE_FILE" >/dev/null 2>&1; then
    pass "validate-session-state.sh PASS"
  else
    fail "validate-session-state.sh FAIL"
    "${PROJECT_DIR}/scripts/validate-session-state.sh" "$STATE_FILE" 2>&1 | sed 's/^/  /'
  fi

  if jq -e --arg pid "$TARGET_PANE_ID" \
      '.state == "success" and (.verification[$pid].result // null) != null' \
      "$STATE_FILE" >/dev/null; then
    pass "state.state=success かつ verification[${TARGET_PANE_ID}].result 存在"
  else
    fail "state.state != success または verification[${TARGET_PANE_ID}].result 不在"
  fi
fi

# ---- (3) audit event_type ホワイトリスト + 件数 ----
echo ""
echo "--- (3) audit event_type ホワイトリスト + 件数 ---"
if [[ ! -f "$AUDIT_FILE" ]]; then
  fail "audit file not found (re): $AUDIT_FILE"
else
  required_events=(session_start state_change session_end verification_started verification_completed cleanup)
  for ev in "${required_events[@]}"; do
    count=$(jq -s --arg ev "$ev" 'map(select(.event_type == $ev)) | length' "$AUDIT_FILE")
    if [[ "$count" -ge 1 ]]; then
      pass "audit event '${ev}' = ${count} 件"
    else
      fail "audit event '${ev}' 不在 (0 件)"
    fi
  done

  cb_count=$(jq -s 'map(select(.event_type == "circuit_breaker_triggered")) | length' "$AUDIT_FILE")
  if [[ "$cb_count" -eq 0 ]]; then
    pass "circuit_breaker_triggered = 0 件 (完走判定)"
  else
    fail "circuit_breaker_triggered emitted (${cb_count} 件) — 本サイクルは完走失敗"
  fi

  pe_count=$(jq -s 'map(select(.event_type == "verification_protocol_error")) | length' "$AUDIT_FILE")
  if [[ "$pe_count" -eq 0 ]]; then
    pass "verification_protocol_error = 0 件"
  else
    fail "verification_protocol_error emitted (${pe_count} 件) — Phase C.5 修正後の期待値は 0、so-compare iter2 反映で WARN→FAIL に厳密化"
  fi
fi

# ---- (3.5) verification_summary.protocol_errors / timeouts == 0 (so-compare iter2 反映) ----
echo ""
echo "--- (3.5) verification_summary の protocol_errors / timeouts == 0 直接検証 ---"
if [[ ! -f "$STATE_FILE" ]]; then
  fail "state file not found (re): $STATE_FILE"
else
  summary_pe=$(jq -r '.verification_summary.protocol_errors // "missing"' "$STATE_FILE")
  summary_to=$(jq -r '.verification_summary.timeouts // "missing"' "$STATE_FILE")
  if [[ "$summary_pe" == "0" ]]; then
    pass "verification_summary.protocol_errors == 0"
  else
    fail "verification_summary.protocol_errors = '${summary_pe}' (expected '0')"
  fi
  if [[ "$summary_to" == "0" ]]; then
    pass "verification_summary.timeouts == 0"
  else
    fail "verification_summary.timeouts = '${summary_to}' (expected '0')"
  fi
fi

# ---- (4) wez notify 呼び出し (shim 経由のみ判定可、shim 不在時は WARN) ----
echo ""
echo "--- (4) wez notify 呼び出し (shim 経由) ---"
NOTIFY_LOG="${OE_MOCK_LOG_DIR:-}/notify.log"
if [[ -z "${OE_MOCK_LOG_DIR:-}" ]]; then
  warn "OE_MOCK_LOG_DIR が未設定 — notify shim 経由判定をスキップ (Plan F-10 / Phase E Step 13 で shim 配置)"
elif [[ ! -f "$NOTIFY_LOG" ]]; then
  warn "notify.log 不在 (${NOTIFY_LOG}) — shim が PATH 先頭にないか、wez notify が呼ばれていない"
else
  if grep -qE 'pass=[0-9]+, fail=[0-9]+, warn=[0-9]+, fail_rate=[0-9.]+, protocol_errors=[0-9]+, timeouts=[0-9]+' "$NOTIFY_LOG"; then
    pass "wez notify 本文フォーマット一致 (${NOTIFY_LOG})"
  else
    fail "wez notify 本文フォーマット不一致 — 内容: $(cat "$NOTIFY_LOG")"
  fi
fi

# ---- Summary ----
echo ""
echo "=== check_cycle_complete summary ==="
echo "verify_result : ${VERIFY_RESULT_OBSERVED:-<unknown>} (Episode 記録用、assertion 対象外)"
echo "FAIL=${FAIL} WARN=${WARN}"
if [[ "$FAIL" -gt 0 ]]; then
  echo "[check_cycle] OVERALL FAIL"
  exit 1
fi
echo "[check_cycle] OVERALL PASS (verify_result=${VERIFY_RESULT_OBSERVED:-<unknown>}, WARN=${WARN})"
exit 0
