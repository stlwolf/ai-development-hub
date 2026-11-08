#!/usr/bin/env bash
# #448: 実際の so-compare をCLIスタブで動かす。fixtureは構成したJSONLであり実測ログではない。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SO="${SCRIPT_DIR}/../../../scripts/so-compare.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
mkdir -p "$TMP_ROOT/bin"
export CODEX_HOME="$TMP_ROOT/codex-home"
cat > "$TMP_ROOT/bin/codex" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == --version ]]; then echo 'codex-cli 0.163.0-stub'; exit 0; fi
mkdir -p "$CODEX_HOME/sessions"
rollout="$CODEX_HOME/sessions/rollout-test-00000000-0000-0000-0000-000000000001.jsonl"
rm -f "$rollout"
if [[ "${CODEX_STUB_NO_ROLLOUT:-0}" == 0 ]]; then
  printf '{"type":"session_meta","payload":{"id":"%s"}}\n' "${CODEX_STUB_SESSION_ID:-00000000-0000-0000-0000-000000000001}" > "$rollout"
  if [[ -n "${ROLLOUT_FIXTURE:-}" ]]; then cat "$ROLLOUT_FIXTURE" >> "$rollout"; fi
fi
last=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-last-message) last="$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ -n "$last" && "${CODEX_STUB_NO_ANSWER:-0}" == 0 ]]; then
  printf 'VERDICT: survived\nREASON: fixture\n' > "$last"
fi
printf '%s\n' '{"type":"thread.started","thread_id":"00000000-0000-0000-0000-000000000001"}'
cat "$CODEX_FIXTURE"
exit "${CODEX_STUB_RC:-0}"
STUB
chmod +x "$TMP_ROOT/bin/codex"
export PATH="$TMP_ROOT/bin:$PATH"
export CODEX_FIXTURE="$TMP_ROOT/events.jsonl"
PASS=0; FAIL=0
ck() {
  if [[ "$2" == "$3" ]]; then PASS=$((PASS + 1));
  else echo "FAIL: $1 (want=$2 got=$3)"; FAIL=$((FAIL + 1)); fi
}
run_case() {
  local name="$1" status="$2" want_rc="$3" rc=0
  bash "$SO" --codex-only -o "$TMP_ROOT/$name" 'fixture review' > "$TMP_ROOT/$name.log" 2>&1 || rc=$?
  ck "$name exit" "$want_rc" "$rc"
  ck "$name status" "$status" "$(sed -n 's/^tool_status=//p' "$TMP_ROOT/$name/codex-meta.txt")"
}

printf '%s\n' '{"type":"turn.completed","usage":{}}' > "$CODEX_FIXTURE"
run_case normal not_observed 0

failure='{"type":"item.completed","item":{"type":"mcp_tool_call","status":"failed","error":{"message":"tool exec error: timed out negotiating with the code-mode host"}}}'
printf '%s\n' "$failure" '{"type":"turn.completed"}' > "$CODEX_FIXTURE"
run_case failed degraded 1
ck 'process exit preserved' 0 "$(sed -n 's/^exit_code=//p' "$TMP_ROOT/failed/codex-meta.txt")"
ck 'process result preserved' success "$(sed -n 's/^timeout_status=//p' "$TMP_ROOT/failed/codex-meta.txt")"
ck 'answer preserved' 'VERDICT: survived' "$(head -1 "$TMP_ROOT/failed/codex-stdout.txt")"
ck 'raw events preserved' yes "$(grep -qF "$failure" "$TMP_ROOT/failed/codex-events.jsonl" && echo yes || echo no)"
ck 'no normal success' yes "$(grep -q '成功: 0' "$TMP_ROOT/failed.log" && echo yes || echo no)"

printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message","text":"timed out negotiating with the code-mode host"}}' '{"type":"turn.completed"}' > "$CODEX_FIXTURE"
run_case answer-quote not_observed 0
printf '%s\n' '{"type":"item.completed","item":{"type":"mcp_tool_call","status":"completed","arguments":{"text":"timed out negotiating with the code-mode host"},"result":{"content":[{"text":"timed out negotiating with the code-mode host"}]}}}' > "$CODEX_FIXTURE"
run_case tool-quote not_observed 0
printf '%s\n' '{"type":"item.completed","item":{"type":"error","message":"timed out negotiating with the code-mode host"}}' > "$CODEX_FIXTURE"
run_case warning degraded 1
printf '%s\n' '{"type":"error","message":"timed out negotiating with the code-mode host"}' > "$CODEX_FIXTURE"
run_case runtime-error degraded 1
printf '%s\n' '{"type":"turn.failed","error":{"message":"timed out negotiating with the code-mode host"}}' > "$CODEX_FIXTURE"
run_case turn-error degraded 1
printf '%s\n' "$failure" '{"type":"item.completed","item":{"type":"command_execution","status":"completed","exit_code":0}}' > "$CODEX_FIXTURE"
run_case recovered degraded 1
printf '%s\n' "$failure" '{"type":' > "$CODEX_FIXTURE"
run_case truncated-failure degraded 1
printf '%s\n' '{"type":' > "$CODEX_FIXTURE"
run_case unreadable unknown 1
printf '%s\n' '{"type":"turn.completed"}' > "$CODEX_FIXTURE"
CODEX_STUB_NO_ROLLOUT=1 run_case no-rollout unknown 1
ck 'rollout copy is private' 600 "$(stat -c %a "$TMP_ROOT/normal/codex-rollout.jsonl" 2>/dev/null || stat -f %Lp "$TMP_ROOT/normal/codex-rollout.jsonl")"
export ROLLOUT_FIXTURE="$TMP_ROOT/rollout-fixture.jsonl"
printf '%s\n' \
  '{"type":"response_item","payload":{"type":"custom_tool_call","name":"exec","call_id":"c1","input":"example"}}' \
  '{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"c1","output":"timed out negotiating with the code-mode host"}}' > "$ROLLOUT_FIXTURE"
run_case model-only-error degraded 1
CODEX_STUB_SESSION_ID=wrong-session run_case wrong-session unknown 1
printf '%s\n' \
  '{"type":"response_item","payload":{"type":"function_call","name":"functions.exec","call_id":"c2","arguments":"{}"}}' \
  '{"type":"response_item","payload":{"type":"function_call_output","call_id":"c2","output":[{"type":"input_text","text":"tool exec error: timed out negotiating with the code-mode host"}]}}' > "$ROLLOUT_FIXTURE"
run_case structured-model-error degraded 1
printf '%s\n' \
  '{"type":"response_item","payload":{"type":"custom_tool_call","name":"exec","call_id":"c1","input":"example"}}' \
  '{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"c1","output":"Script completed\nProcess exited with code 0\nOutput:\ntimed out negotiating with the code-mode host"}}' > "$ROLLOUT_FIXTURE"
run_case printed-quote not_observed 0
printf '%s\n' \
  '{"type":"response_item","payload":{"type":"custom_tool_call","name":"exec","call_id":"c1","input":"example"}}' \
  '{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"c1","output":[{"type":"input_text","text":"Script completed\nProcess exited with code 0\nOutput:"},{"type":"input_text","text":"timed out negotiating with the code-mode host"}]}}' > "$ROLLOUT_FIXTURE"
run_case split-header-quote not_observed 0
printf '%s\n' \
  '{"type":"response_item","payload":{"type":"custom_tool_call","name":"exec","call_id":"c1","input":"example"}}' \
  '{"type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"other","output":"timed out negotiating with the code-mode host"}}' > "$ROLLOUT_FIXTURE"
run_case other-call unknown 1
printf '%s\n' '{"type":"response_item","payload":{"type":"function_call_output","call_id":"","output":"timed out negotiating with the code-mode host"}}' > "$ROLLOUT_FIXTURE"
run_case no-call-id unknown 1
printf '%s\n' '{"type":"response_item","payload":{"type":"function_call_output","output":"timed out negotiating with the code-mode host"}}' > "$ROLLOUT_FIXTURE"
run_case missing-call-id unknown 1
printf '%s\n' '{"type":"response_item","payload":{"type":"function_call_output","call_id":null,"output":"timed out negotiating with the code-mode host"}}' > "$ROLLOUT_FIXTURE"
run_case null-call-id unknown 1
unset ROLLOUT_FIXTURE
CODEX_STUB_RC=42 run_case process-error not_observed 1
ck 'nonzero process exit preserved' 42 "$(sed -n 's/^exit_code=//p' "$TMP_ROOT/process-error/codex-meta.txt")"
printf '%s\n' '{"type":"turn.started"}' > "$CODEX_FIXTURE"
CODEX_STUB_RC=124 CODEX_STUB_NO_ANSWER=1 run_case timeout not_observed 2
ck 'timeout retries once' 2 "$(sed -n 's/^attempt=//p' "$TMP_ROOT/timeout/codex-meta.txt")"
ck 'first events backed up' yes "$(test -f "$TMP_ROOT/timeout/codex-events.jsonl.attempt1" && echo yes || echo no)"
printf '%s\n' "$failure" > "$CODEX_FIXTURE"
CODEX_STUB_RC=124 CODEX_STUB_NO_ANSWER=1 run_case broken-timeout degraded 2
ck 'known tool failure does not retry' 1 "$(sed -n 's/^attempt=//p' "$TMP_ROOT/broken-timeout/codex-meta.txt")"
# 同じ出力先を使い直しても、前の成功回答を拾わない。
CODEX_STUB_NO_ANSWER=1 run_case normal degraded 2
ck 'old answer cleared' '' "$(cat "$TMP_ROOT/normal/codex-stdout.txt")"
printf '%s\n' '{"type":"turn.completed"}' > "$CODEX_FIXTURE"
run_case normal not_observed 0

# metaの無い旧レーンと併用しても、劣化したVERDICTを採用しない。
# shellcheck source=../lib/so-verdict.sh
source "$SCRIPT_DIR/../lib/so-verdict.sh"
printf 'VERDICT: survived\nREASON: legacy\n' > "$TMP_ROOT/failed/cursor-stdout.txt"
so_verdict_collect_lanes "$TMP_ROOT/failed" codex,cursor
ck 'degraded verdict becomes error' error "${SO_VERDICT_LANE_VERDICTS[0]}"
ck 'legacy verdict stays compatible' survived "${SO_VERDICT_LANE_VERDICTS[1]}"
so_verdict_aggregate refuted survived
ck 'mixed aggregation cannot survive' refuted "$SO_VERDICT_VERDICT"
so_verdict_collect_lanes "$TMP_ROOT/normal" codex
ck 'normal verdict survives' survived "${SO_VERDICT_LANE_VERDICTS[0]}"
so_verdict_collect_lanes "$TMP_ROOT/unreadable" codex
ck 'unknown observation cannot survive' error "${SO_VERDICT_LANE_VERDICTS[0]}"
echo "=== tool_status: PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
