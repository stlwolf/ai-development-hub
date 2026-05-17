#!/usr/bin/env bash
set -euo pipefail

# probe_target.sh — Step 4-4 Phase B Step 7
#
# target agent (デフォルト: cursor-agent / composer-2) を最小プロンプトで起動し、
# CLI が起動して期待するマーカーを出力することを確認する。
#
# 環境変数 (override 可):
#   OE_TARGET_AI_CLI    (デフォルト: cursor-agent)
#   OE_TARGET_AI_MODEL  (デフォルト: composer-2)
#
# 出力: stdout に PASS/FAIL、ログを .tmp_probe_target.log に保存
# Exit: 0=PASS, 1=FAIL

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_FILE="${SCRIPT_DIR}/.tmp_probe_target.log"

ai_cli="${OE_TARGET_AI_CLI:-cursor-agent}"
ai_model="${OE_TARGET_AI_MODEL:-composer-2}"

echo "=== probe_target ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
echo "ai_cli   : $ai_cli"
echo "ai_model : $ai_model"
echo "workspace: $PROJECT_DIR"
echo ""

# 期待マーカー: probe 固有 (engine の @@OE_EXIT/@@OE_VERIFY とは別、誤検出回避)
EXPECTED_MARKER="PROBE_TARGET_OK"
PROMPT="Print exactly the marker on a new line: ${EXPECTED_MARKER}"

set +e
output=$("${ai_cli}" --print --model "${ai_model}" --workspace "${PROJECT_DIR}" --force "${PROMPT}" 2>&1)
exit_code=$?
set -e

printf '%s\n' "$output" > "$LOG_FILE"

echo "=== output (first 40 lines) ==="
printf '%s\n' "$output" | head -40

echo ""
echo "=== probe_target result ==="
if [[ $exit_code -ne 0 ]]; then
  echo "[probe_target] FAIL: ai_cli exited non-zero (exit_code=${exit_code})"
  exit 1
fi

if ! grep -qF "${EXPECTED_MARKER}" "$LOG_FILE"; then
  echo "[probe_target] FAIL: marker '${EXPECTED_MARKER}' not detected in output"
  echo "(see ${LOG_FILE} for full output)"
  exit 1
fi

echo "[probe_target] PASS: cursor-agent (composer-2) responded with expected marker"
echo "(log: ${LOG_FILE})"
exit 0
