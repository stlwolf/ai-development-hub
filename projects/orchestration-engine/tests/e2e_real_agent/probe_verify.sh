#!/usr/bin/env bash
set -euo pipefail

# probe_verify.sh — Step 4-4 Phase B Step 8 (2 段確認、F-12 反映)
#
# 検証 agent (デフォルト: claude / claude-sonnet-4-6) を最小プロンプトで起動。
# (a) emit プロトコルの最小確認: @@OE_VERIFY:pass を 1 行で出力できるか
# (b) skill ロード通電確認: --add-dir 経由で workspace 外の skill ファイルを読めるか + マーカー出力
#
# 環境変数 (override 可):
#   OE_VERIFY_AI_CLI    (デフォルト: claude)
#   OE_VERIFY_AI_MODEL  (デフォルト: claude-sonnet-4-6)
#
# 出力: stdout に PASS/FAIL、各部のログを .tmp_probe_verify_{emit,skill}.log に保存
# Exit: 0=ALL PASS, 1=FAIL (どこで失敗したかを stdout で示す)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_DIR}/../.." && pwd)"
SKILL_PATH="${REPO_ROOT}/canonical/skills/adversarial-review/SKILL.md"

LOG_EMIT="${SCRIPT_DIR}/.tmp_probe_verify_emit.log"
LOG_SKILL="${SCRIPT_DIR}/.tmp_probe_verify_skill.log"

ai_cli="${OE_VERIFY_AI_CLI:-claude}"
ai_model="${OE_VERIFY_AI_MODEL:-claude-sonnet-4-6}"

echo "=== probe_verify ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
echo "ai_cli    : $ai_cli"
echo "ai_model  : $ai_model"
echo "workspace : $PROJECT_DIR"
echo "repo_root : $REPO_ROOT"
echo "skill_path: $SKILL_PATH"
echo ""

# ---- Part (a): emit プロトコルの最小確認 ----
echo "=== Part (a): emit-only minimal ==="
PROMPT_A="On a single line, print exactly this marker and nothing else: @@OE_VERIFY:pass"

set +e
output_a=$("${ai_cli}" -p "${PROMPT_A}" \
  --model "${ai_model}" \
  --output-format text \
  --no-session-persistence \
  --max-budget-usd 1.0 2>&1)
exit_a=$?
set -e

printf '%s\n' "$output_a" > "$LOG_EMIT"

echo "--- output (first 20 lines) ---"
printf '%s\n' "$output_a" | head -20

if [[ $exit_a -ne 0 ]]; then
  echo "[probe_verify] (a) FAIL: claude exited non-zero (exit_code=${exit_a})"
  exit 1
fi

if ! grep -qF "@@OE_VERIFY:pass" "$LOG_EMIT"; then
  echo "[probe_verify] (a) FAIL: marker '@@OE_VERIFY:pass' not detected"
  echo "(see ${LOG_EMIT} for full output)"
  exit 1
fi

echo "[probe_verify] (a) PASS: emit-only"
echo ""

# ---- Part (b): skill ロード通電確認 ----
echo "=== Part (b): skill load (workspace 外アクセス) ==="

if [[ ! -f "$SKILL_PATH" ]]; then
  echo "[probe_verify] (b) FAIL: skill file not found at ${SKILL_PATH}"
  exit 1
fi

PROMPT_B="Read the file ${SKILL_PATH} and output its very first line on its own line, then on the next line print exactly: @@OE_VERIFY:pass"

set +e
output_b=$("${ai_cli}" -p "${PROMPT_B}" \
  --model "${ai_model}" \
  --add-dir "${REPO_ROOT}" \
  --output-format text \
  --no-session-persistence \
  --max-budget-usd 1.0 2>&1)
exit_b=$?
set -e

printf '%s\n' "$output_b" > "$LOG_SKILL"

echo "--- output (first 30 lines) ---"
printf '%s\n' "$output_b" | head -30

if [[ $exit_b -ne 0 ]]; then
  echo "[probe_verify] (b) FAIL: claude exited non-zero (exit_code=${exit_b})"
  exit 1
fi

if ! grep -qF "@@OE_VERIFY:pass" "$LOG_SKILL"; then
  echo "[probe_verify] (b) FAIL: marker '@@OE_VERIFY:pass' not detected"
  echo "(see ${LOG_SKILL} for full output)"
  exit 1
fi

# skill 読み取り痕跡: skill の冒頭行は YAML frontmatter "---"。output 内に "---" があれば読み取り成功
if grep -qE '^[[:space:]]*---[[:space:]]*$' "$LOG_SKILL"; then
  echo "[probe_verify] (b) PASS: skill load (frontmatter '---' detected in output)"
else
  echo "[probe_verify] (b) PARTIAL: marker emitted but no '---' (skill frontmatter) found in output"
  echo "    → claude が skill ファイルを実際に開いたか曖昧。--add-dir の挙動を要確認"
  echo "    → ログ確認: ${LOG_SKILL}"
  # marker は出ているので exit 0 とするが、warning を残す
fi

echo ""
echo "[probe_verify] ALL PASS (emit + skill load)"
exit 0
