#!/usr/bin/env bash
set -euo pipefail

# repro_verify_protocol_error.sh — Step 4-4 Phase C 調査用 one-shot
#
# 目的:
#   smoke で発生した verification_protocol_error (exit_without_verify_marker) の原因切り分け。
#   engine / wez を経由せず、verify.sh が組み立てる reviewer envelope + verify-inputs.md を
#   そのまま再構築して claude -p で one-shot 実行し、stdout 全文を保存・検査する。
#
# 入力 (必須環境変数):
#   SMOKE_DIR    既存 smoke の OE_DATA_DIR (state/ と audit/ がある)
#   TARGET_SID   被検証 session_id (state/audit のファイル名)
#   TARGET_PID   被検証 target_pane_id (整数)
#
# 出力:
#   .tmp_repro_verify/{rsid}.envelope.json   構築した reviewer envelope
#   .tmp_repro_verify/{rsid}.inputs.md       構築した verify-inputs.md
#   .tmp_repro_verify/{rsid}.stdout.log      claude の stdout/stderr 統合ログ
#   .tmp_repro_verify/{rsid}.summary.txt     marker 検出結果 + claude exit_code

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_DIR}/../.." && pwd)"

SMOKE_DIR="${SMOKE_DIR:-${SCRIPT_DIR}/.tmp_smoke_20260517-184129}"
TARGET_SID="${TARGET_SID:-20260517184129WJFHESKWJ0AE}"
TARGET_PID="${TARGET_PID:-4}"

if [[ ! -d "$SMOKE_DIR" ]]; then
  echo "[repro] FAIL: SMOKE_DIR not found: $SMOKE_DIR" >&2
  exit 1
fi

# verify.sh / constants.sh が参照する env を smoke 同等に設定
export OE_DATA_DIR="$SMOKE_DIR"
export OE_VERIFY_AI_CLI="${OE_VERIFY_AI_CLI:-claude}"
export OE_VERIFY_AI_MODEL="${OE_VERIFY_AI_MODEL:-claude-sonnet-4-6}"

OUT_DIR="${SCRIPT_DIR}/.tmp_repro_verify"
mkdir -p "$OUT_DIR"

# fixed reviewer session id (再現性のため固定)
RSID="01REPROVERIFYPROTOCOL$(date -u +%H%M%S)"

ENVELOPE="${OUT_DIR}/${RSID}.envelope.json"
INPUTS="${OUT_DIR}/${RSID}.inputs.md"
LOG="${OUT_DIR}/${RSID}.stdout.log"
SUMMARY="${OUT_DIR}/${RSID}.summary.txt"

# Target envelope: 既存 smoke の task description (task_description_dogfood_cleanup.md) で再構築
# (engine は /tmp/oe-{sid}-envelope.json に書いていたが既に消えている)
TARGET_ENV="/tmp/oe-${TARGET_SID}-envelope.json"
TASK_DESC="$(cat "${SCRIPT_DIR}/task_description_dogfood_cleanup.md")"
jq -n \
  --arg sid "$TARGET_SID" \
  --argjson pid "$TARGET_PID" \
  --arg desc "$TASK_DESC" \
  --arg odir "$PROJECT_DIR" \
  '{
    session_id: $sid,
    pane_id: $pid,
    task: {
      description: $desc,
      output_dir: $odir,
      exit_conditions: { marker: "@@OE_EXIT", timeout_seconds: 1800 },
      read_docs: [],
      use_skills: []
    },
    context: { parent_session_id: null, related_issues: [], shared_kvs_path: null },
    constraints: { max_panes: 5, state_vocabulary: ["spawn","ready","progress","done","blocked"] }
  }' > "$TARGET_ENV"

# lib/verify.sh の oe_verify_prompt_build / oe_verify_envelope_create を直接利用
# shellcheck source=lib/constants.sh disable=SC1091
source "${PROJECT_DIR}/lib/constants.sh"
# shellcheck source=lib/verify.sh disable=SC1091
source "${PROJECT_DIR}/lib/verify.sh"

# verify-inputs.md を構築 (smoke 時と同じ)
oe_verify_prompt_build "$RSID" "$TARGET_PID" "$TARGET_SID" "$TARGET_ENV"
cp -f "$OE_VERIFY_PROMPT_PATH" "$INPUTS"

# reviewer envelope を構築 (smoke 時と同じ)
REVIEWER_PANE_ID=999
oe_verify_envelope_create "$RSID" "$REVIEWER_PANE_ID" "$TARGET_PID" "$TARGET_SID" "$TARGET_ENV" "$OE_VERIFY_PROMPT_PATH"
cp -f "$OE_VERIFY_ENVELOPE_PATH" "$ENVELOPE"

echo "=== repro_verify_protocol_error ==="
echo "reviewer_session_id : $RSID"
echo "target_session_id   : $TARGET_SID"
echo "target_pane_id      : $TARGET_PID"
echo "envelope            : $ENVELOPE"
echo "inputs              : $INPUTS"
echo "log                 : $LOG"
echo ""
echo "envelope size : $(wc -c < "$ENVELOPE") bytes"
echo "inputs size   : $(wc -c < "$INPUTS") bytes"
echo ""

# claude one-shot (smoke が pane に送ったのと同等の prompt + flags)
PROMPT="Read ${OE_VERIFY_ENVELOPE_PATH} and execute the task"
echo "=== claude one-shot (this may take ~2 min) ==="
echo "command:"
echo "  claude -p '${PROMPT}' --model ${OE_VERIFY_AI_MODEL} --add-dir ${REPO_ROOT} --add-dir /tmp --output-format text --no-session-persistence --max-budget-usd 1.0"
echo ""

set +e
claude -p "${PROMPT}" \
  --model "${OE_VERIFY_AI_MODEL}" \
  --add-dir "${REPO_ROOT}" \
  --add-dir /tmp \
  --output-format text \
  --no-session-persistence \
  --max-budget-usd 1.0 > "$LOG" 2>&1
EXIT=$?
set -e

echo "claude exit_code: $EXIT"
echo ""
echo "=== output (last 60 lines) ==="
tail -60 "$LOG"
echo ""

# Marker detection
{
  echo "TARGET_SID=${TARGET_SID}"
  echo "TARGET_PID=${TARGET_PID}"
  echo "RSID=${RSID}"
  echo "CLAUDE_EXIT=${EXIT}"
  echo "LOG=${LOG}"
  echo ""
  echo "--- marker hits (any line containing @@OE_) ---"
  grep -nE '@@OE_' "$LOG" || echo "(none)"
  echo ""
  echo "--- strict regex (^@@OE_VERIFY:(pass|fail|warn)$) ---"
  grep -nE '^@@OE_VERIFY:(pass|fail|warn)$' "$LOG" || echo "(none)"
} | tee "$SUMMARY"

echo ""
echo "summary: $SUMMARY"
