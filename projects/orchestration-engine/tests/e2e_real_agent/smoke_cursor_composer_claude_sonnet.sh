#!/usr/bin/env bash
set -euo pipefail

# smoke_cursor_composer_claude_sonnet.sh — Step 4-4 Phase C/D/E 共通の実 agent E2E
#
# target  : cursor-agent (composer-2)
# 検証    : claude (claude-sonnet-4-6)
#
# 実行手順:
#   bash projects/orchestration-engine/tests/e2e_real_agent/smoke_cursor_composer_claude_sonnet.sh
#
# 出力:
#   .tmp_smoke_<timestamp>/                  ... OE_DATA_DIR + log
#   .tmp_smoke_<timestamp>_result.txt        ... session_id 等のメタ情報
#
# 環境変数 (override 可):
#   OE_TARGET_AI_CLI / OE_TARGET_AI_MODEL    (デフォルト: cursor-agent / composer-2)
#   OE_VERIFY_AI_CLI / OE_VERIFY_AI_MODEL    (デフォルト: claude / claude-sonnet-4-6)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
TMP_DATA_DIR="${SCRIPT_DIR}/.tmp_smoke_${TIMESTAMP}"
LOG_DIR="${TMP_DATA_DIR}/log"
mkdir -p "${TMP_DATA_DIR}/state" "${TMP_DATA_DIR}/audit" "${LOG_DIR}"

# Step 4-4 Phase A 反映: env var で target / 検証 CLI/モデルを明示
export OE_TARGET_AI_CLI="${OE_TARGET_AI_CLI:-cursor-agent}"
export OE_TARGET_AI_MODEL="${OE_TARGET_AI_MODEL:-composer-2}"
export OE_VERIFY_AI_CLI="${OE_VERIFY_AI_CLI:-claude}"
export OE_VERIFY_AI_MODEL="${OE_VERIFY_AI_MODEL:-claude-sonnet-4-6}"
export OE_DATA_DIR="${TMP_DATA_DIR}"
export OE_MOCK_LOG_DIR="${LOG_DIR}"

# F-SO 反映 (Plan iter2): wez shim の notify.log 書き込み先を保証
mkdir -p "${OE_MOCK_LOG_DIR}"

TASK_FILE="${SCRIPT_DIR}/task_description_dogfood_cleanup.md"
if [[ ! -f "$TASK_FILE" ]]; then
  echo "[smoke] FAIL: task file not found: $TASK_FILE" >&2
  exit 1
fi

echo "=== smoke (cursor-agent + claude-sonnet-4-6) ==="
echo "TIMESTAMP        : ${TIMESTAMP}"
echo "TMP_DATA         : ${TMP_DATA_DIR}"
echo "LOG_DIR          : ${LOG_DIR}"
echo "OE_TARGET_AI_CLI : ${OE_TARGET_AI_CLI}"
echo "OE_TARGET_AI_MODEL: ${OE_TARGET_AI_MODEL}"
echo "OE_VERIFY_AI_CLI : ${OE_VERIFY_AI_CLI}"
echo "OE_VERIFY_AI_MODEL: ${OE_VERIFY_AI_MODEL}"
echo "TASK_FILE        : ${TASK_FILE}"
echo ""

# Run engine; bin/oe blocks until target → verify → cleanup 完了
set +e
bash "${PROJECT_DIR}/bin/oe" --task-file "${TASK_FILE}"
ENGINE_EXIT=$?
set -e

echo ""
echo "=== engine completed (exit_code=${ENGINE_EXIT}) ==="

# Find target session_id (single one expected per smoke run)
# shellcheck disable=SC2012  # ULID alphabet only, no special chars
state_file="$(ls "${OE_DATA_DIR}/state"/*.state.json 2>/dev/null | head -1 || true)"
if [[ -z "$state_file" ]]; then
  echo "[smoke] FAIL: no state file produced under ${OE_DATA_DIR}/state/"
  exit 1
fi
SID="$(basename "$state_file" .state.json)"
TARGET_PANE_ID="$(jq -r '.pane_id' "$state_file")"

echo "session_id       : ${SID}"
echo "target_pane_id   : ${TARGET_PANE_ID}"
echo "state_file       : ${state_file}"
echo "audit_file       : ${OE_DATA_DIR}/audit/${SID}.jsonl"

# Result meta file (for downstream tooling)
RESULT_FILE="${SCRIPT_DIR}/.tmp_smoke_${TIMESTAMP}_result.txt"
{
  echo "TIMESTAMP=${TIMESTAMP}"
  echo "SID=${SID}"
  echo "TARGET_PANE_ID=${TARGET_PANE_ID}"
  echo "OE_DATA_DIR=${OE_DATA_DIR}"
  echo "OE_MOCK_LOG_DIR=${OE_MOCK_LOG_DIR}"
  echo "STATE_FILE=${state_file}"
  echo "AUDIT_FILE=${OE_DATA_DIR}/audit/${SID}.jsonl"
  echo "ENGINE_EXIT=${ENGINE_EXIT}"
} > "${RESULT_FILE}"

echo "result_file      : ${RESULT_FILE}"

if [[ "$ENGINE_EXIT" -ne 0 ]]; then
  echo ""
  echo "[smoke] WARN: engine exited non-zero (exit_code=${ENGINE_EXIT})"
  echo "  → 構造判定 (Phase C/D の check_*) で詳細を確認する"
fi

echo ""
echo "=== running check_phase_c.sh ==="
bash "${SCRIPT_DIR}/check_phase_c.sh" "${SID}" "${OE_DATA_DIR}"
PHASE_C_EXIT=$?

# (Phase D check_cycle_complete.sh は Plan Step 12 で実装、本コミット時点では不在のためスキップ)
if [[ -f "${SCRIPT_DIR}/check_cycle_complete.sh" ]]; then
  echo ""
  echo "=== running check_cycle_complete.sh ==="
  bash "${SCRIPT_DIR}/check_cycle_complete.sh" "${SID}" "${TARGET_PANE_ID}" "${OE_DATA_DIR}"
fi

echo ""
echo "=== smoke summary ==="
echo "engine_exit : ${ENGINE_EXIT}"
echo "phase_c_exit: ${PHASE_C_EXIT}"
echo ""
if [[ "$PHASE_C_EXIT" -eq 0 ]]; then
  echo "[smoke] PASS (構造判定)"
  exit 0
fi
echo "[smoke] FAIL"
exit 1
