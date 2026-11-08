#!/usr/bin/env bash
# #515: 判定の重複と、別の判定部分から理由を拾う不具合を検証する。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/so-verdict.sh
source "$SCRIPT_DIR/../lib/so-verdict.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
if [[ -n "${SO_TEST_AWK:-}" ]]; then
  [[ "$SO_TEST_AWK" == /* && -f "$SO_TEST_AWK" && -x "$SO_TEST_AWK" ]] || { echo 'FATAL: SO_TEST_AWK must be an absolute executable file'; exit 1; }
  mkdir -p "$TMP_ROOT/awk-bin"
  ln -s "$SO_TEST_AWK" "$TMP_ROOT/awk-bin/awk"
  export PATH="$TMP_ROOT/awk-bin:$PATH"
fi
FILE="$TMP_ROOT/codex-stdout.txt"
PASS=0; FAIL=0
ck() {
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1));
  else echo "FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi
}
check_reply() {
  local label="$1" body="$2" verdict="$3" reason="$4"
  printf '%s\n' "$body" > "$FILE"
  ck "$label verdict" "$verdict" "$(so_verdict_extract_verdict "$FILE")"
  ck "$label reason" "$reason" "$(so_verdict_extract_reason "$FILE")"
}
check_reply normal $'VERDICT: survived\nREASON: actual reason' survived 'actual reason'
check_reply refuted $'VERDICT: refuted\nREASON: actual defect' refuted 'actual defect'
check_reply mixed $'VERDICT: refuted\nREASON: actual defect\nIf fixed:\nVERDICT: survived' unknown ''
so_verdict_collect_lanes "$TMP_ROOT" codex
ck 'duplicate lane becomes error' error "${SO_VERDICT_LANE_VERDICTS[0]}"
ck 'duplicate lane explains ambiguity' yes "$(printf '%s' "${SO_VERDICT_LANE_NOTES[0]}" | grep -q '複数' && echo yes || echo no)"
so_verdict_aggregate refuted survived
ck 'duplicate lane cannot survive' refuted "$SO_VERDICT_VERDICT"
check_reply reversed $'VERDICT: survived\nREASON: example\nVERDICT: refuted\nREASON: actual defect' unknown ''
check_reply repeated $'VERDICT: survived\nREASON: first\nVERDICT: survived\nREASON: second' unknown ''
check_reply repeated-refuted $'VERDICT: refuted\nVERDICT: refuted' unknown ''
check_reply case-and-suffix $'  vErDiCt: Survived (not refuted)\n  rEaSoN: 日本語の理由\\path' survived '日本語の理由\path'
check_reply reason-before $'REASON: unrelated\nVERDICT: survived' survived ''
check_reply placeholder-after $'VERDICT: survived\nREASON: actual reason\nVERDICT: <refuted or survived>\nREASON: example' survived 'actual reason'
check_reply placeholder-only-reason $'VERDICT: survived\nVERDICT: <refuted or survived>\nREASON: example' survived ''
check_reply first-reason $'VERDICT: survived\nREASON: first\nREASON: unrelated' survived first
check_reply invalid-token $'VERDICT: survivedness\nREASON: invalid' unknown ''
check_reply no-verdict $'REASON: unrelated' unknown ''
check_reply placeholder-before $'VERDICT: <refuted or survived>\nREASON: example\nVERDICT: survived\nREASON: actual' survived actual
printf 'VERDICT: survived\nREASON: fine\n' > "$FILE"
printf 'tool_status=degraded\n' > "$TMP_ROOT/codex-meta.txt"
so_verdict_collect_lanes "$TMP_ROOT" codex
ck '#448 remains authoritative' error "${SO_VERDICT_LANE_VERDICTS[0]}"
ck '#448 diagnostic preserved' yes "$(printf '%s' "${SO_VERDICT_LANE_NOTES[0]}" | grep -q '道具の障害' && echo yes || echo no)"
echo "=== so_verdict: PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
