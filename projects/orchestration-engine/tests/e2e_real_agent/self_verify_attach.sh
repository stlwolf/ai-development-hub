#!/usr/bin/env bash
set -euo pipefail

# self_verify_attach.sh — bin/oe-capture の実 wez 自己検証（Issue #109 / Slice A）
#
# 使い捨てペインを split → 末尾に @@OE_EXIT:0 を独立行で送出 → bin/oe-capture で attach
# → state=success / KVS / audit(session_end, source=attach) を確認 → pane kill。
#
# 実 wez 必須（ローカル mac でのみ動作）。OE_DATA_DIR を temp に向けるため
# リポジトリの state/・audit/ は汚さない。
#
# 実行: bash projects/orchestration-engine/tests/e2e_real_agent/self_verify_attach.sh
# Exit: 0=PASS, 1=FAIL, 77=SKIP（wez 不在）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if ! command -v wez >/dev/null 2>&1; then
  echo "[self_verify_attach] SKIP: 'wez' not found in PATH (real-wez only)" >&2
  exit 77
fi

TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
TMP_DATA_DIR="${SCRIPT_DIR}/.tmp_self_verify_${TIMESTAMP}"
mkdir -p "${TMP_DATA_DIR}/state" "${TMP_DATA_DIR}/audit"

PANE_ID=""
# shellcheck disable=SC2317  # trap 経由で呼ばれる（shellcheck は到達不能と誤判定）
cleanup() {
  if [[ -n "$PANE_ID" ]]; then
    wez pane kill "$PANE_ID" 2>/dev/null || true
  fi
  rm -rf "$TMP_DATA_DIR"
}
trap cleanup EXIT

echo "=== self_verify_attach ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
echo "PROJECT_DIR : ${PROJECT_DIR}"
echo "TMP_DATA    : ${TMP_DATA_DIR}"
echo ""

# 1) 使い捨てペインを作成
PANE_ID="$(wez pane split --bottom --percent 25 --wait-ready --timeout 10)"
echo "pane_id     : ${PANE_ID}"

# 2) 末尾に終端マーカーを独立行で送出（spawn.sh の marker emit 注入の手動版）
wez pane send "$PANE_ID" "printf '\\n@@OE_EXIT:0\\n'"
sleep 2

# 3) bin/oe-capture で attach（OE_DATA_DIR を temp に）
echo ""
echo "--- oe-capture output ---"
set +e
OUTPUT="$(OE_DATA_DIR="$TMP_DATA_DIR" bash "${PROJECT_DIR}/bin/oe-capture" "$PANE_ID" 2>&1)"
CAPTURE_RC=$?
set -e
printf '%s\n' "$OUTPUT"
echo ""

# 4) 結果検証
FAIL=0

if [[ $CAPTURE_RC -ne 0 ]]; then
  echo "[self_verify_attach] FAIL: oe-capture exit=${CAPTURE_RC} (expected 0)"
  FAIL=1
fi

STATE_LINE="$(printf '%s\n' "$OUTPUT" | grep -oE 'state=[a-z_]+' | head -1)"
if [[ "$STATE_LINE" != "state=success" ]]; then
  echo "[self_verify_attach] FAIL: stdout state は '${STATE_LINE}' (expected state=success)"
  FAIL=1
fi

KVS_PATH="$(printf '%s\n' "$OUTPUT" | sed -nE 's/^kvs=(.*)$/\1/p' | head -1)"
AUDIT_PATH="$(printf '%s\n' "$OUTPUT" | sed -nE 's/^audit=(.*)$/\1/p' | head -1)"

if [[ -z "$KVS_PATH" || ! -f "$KVS_PATH" ]]; then
  echo "[self_verify_attach] FAIL: KVS ファイルが見つからない (kvs='${KVS_PATH}')"
  FAIL=1
else
  kvs_state="$(jq -r '.state' "$KVS_PATH")"
  [[ "$kvs_state" == "success" ]] || { echo "[self_verify_attach] FAIL: KVS .state='${kvs_state}' (expected success)"; FAIL=1; }
fi

if [[ -z "$AUDIT_PATH" || ! -f "$AUDIT_PATH" ]]; then
  echo "[self_verify_attach] FAIL: audit ファイルが見つからない (audit='${AUDIT_PATH}')"
  FAIL=1
else
  audit_event="$(jq -r '.event_type' "$AUDIT_PATH")"
  audit_source="$(jq -r '.payload.source' "$AUDIT_PATH")"
  audit_state="$(jq -r '.state' "$AUDIT_PATH")"
  [[ "$audit_event" == "session_end" ]] || { echo "[self_verify_attach] FAIL: audit .event_type='${audit_event}' (expected session_end)"; FAIL=1; }
  [[ "$audit_source" == "attach" ]] || { echo "[self_verify_attach] FAIL: audit .payload.source='${audit_source}' (expected attach)"; FAIL=1; }
  [[ "$audit_state" == "success" ]] || { echo "[self_verify_attach] FAIL: audit .state='${audit_state}' (expected success)"; FAIL=1; }
fi

echo ""
echo "=== self_verify_attach result ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "[self_verify_attach] FAIL"
  exit 1
fi
echo "[self_verify_attach] PASS: state=success / KVS / audit(session_end, source=attach) すべて確認"
exit 0
