#!/usr/bin/env bash
set -uo pipefail
# test_heartbeat_hook.sh — #562 T-9: canonical/hooks/scripts/oe-heartbeat-hook.sh（hook で書く拍動）の検査。
#   Claude の statusLine の書き手と同じ鍵の sidecar を、Codex の hook の標準入力と環境から書くこと。
#   実 tmux 不要。stdin の payload と env（TMUX_PANE / TMUX / OE_LEASE_ID / OE_GENERATION）だけで動く。
#   bash 5 と bash 3.2（/bin/bash）の両方で回す。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
HOOK="$REPO_DIR/canonical/hooks/scripts/oe-heartbeat-hook.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }
[[ -f "$HOOK" ]] || { echo "FAIL: hook not found: $HOOK"; exit 1; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
PASS=0; FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then echo "  PASS: $label"; PASS=$((PASS+1));
  else echo "  FAIL: $label (want=[$expected] got=[$actual])"; FAIL=$((FAIL+1)); fi
}
HB="$_TMP_DIR/hb"; EV="$_TMP_DIR/ev"; mkdir -p "$HB" "$EV"
LID="01KZ1VQA1979K4S2MMH5YY24ZJ"
run_hook() { # <payload-json> [env assignments...]
  printf '%s' "$1" | env -u OE_LEASE_ID -u OE_GENERATION OE_HEARTBEAT_DIR="$HB" OE_EVENT_DIR="$EV" TMUX_PANE="${HP_PANE-%7}" TMUX="${HP_TMUX-oe,999,0}" "${@:2}" "$BASH" "$HOOK" 2>"$_TMP_DIR/err.txt"
}
T="$_TMP_DIR/rollout.jsonl"
printf '%s\n' '{"type":"session_meta","payload":{"id":"sid-x"}}' \
  '{"type":"event_msg","payload":{"type":"token_count","info":{"model_context_window":400000}}}' \
  '{"type":"event_msg","payload":{"type":"token_count","info":{"model_context_window":475000}}}' > "$T"

echo "[1] PostModelRequest: token_usage と記録の model_context_window から context_pct を出し、同じ鍵の sidecar を書く"
# input_tokens は cached を含む（Codex の TokenUsage）。文脈の中の数は total_tokens = input + output = 47500。
P="$(jq -cn --arg t "$T" --arg l "$LID" '{hook_event_name:"PostModelRequest", session_id:"sid-x", model:"gpt-6.1-sol", transcript_path:$t, token_usage:{input_tokens:45000, cached_input_tokens:40000, output_tokens:2500, total_tokens:47500}}')"
out="$(run_hook "$P" OE_LEASE_ID="$LID" OE_GENERATION=2)"
ck "stdout は空" "" "$out"
ck "sidecar が session_id の名前で在る" "yes" "$([[ -f "$HB/sid-x.json" ]] && echo yes || echo no)"
ck "鍵は Claude の書き手と同じ（+ agent）" "agent context_pct generation lease_id model pane server_pid ts" "$(jq -r 'keys | join(" ")' "$HB/sid-x.json")"
ck "context_pct = 47500 / 475000（いちばん新しい token_count の窓）" "10.0" "$(jq -r '.context_pct' "$HB/sid-x.json")"
ck "pane は TMUX_PANE" "%7" "$(jq -r '.pane' "$HB/sid-x.json")"
ck "server_pid は \$TMUX の pid" "999" "$(jq -r '.server_pid' "$HB/sid-x.json")"
ck "model は object（読む側が display_name を使う）" "gpt-6.1-sol gpt-6.1-sol" "$(jq -r '"\(.model.id) \(.model.display_name)"' "$HB/sid-x.json")"
ck "lease_id と generation" "$LID 2" "$(jq -r '"\(.lease_id) \(.generation)"' "$HB/sid-x.json")"
ck "agent は codex" "codex" "$(jq -r '.agent' "$HB/sid-x.json")"
ck "ts は整数" "number" "$(jq -r '.ts | type' "$HB/sid-x.json")"

echo "[2] UserPromptSubmit: context_pct は前の sidecar の値を残す（使用量が無い）"
P2='{"hook_event_name":"UserPromptSubmit","session_id":"sid-x","model":"gpt-6.1-sol","prompt":"x","transcript_path":"/nonexistent"}'
run_hook "$P2" >/dev/null
ck "context_pct を残す" "10.0" "$(jq -r '.context_pct' "$HB/sid-x.json")"
ck "lease の環境が無ければ lease_id は無い" "null" "$(jq -r '.lease_id' "$HB/sid-x.json")"

echo "[3] 記録が無い・token_usage が null: 前の値が無ければ 0 で書く（欠落を飲む）。前の値があれば残す（取り消した要求で 0 に戻さない）"
P3='{"hook_event_name":"PostModelRequest","session_id":"sid-y","model":"m","token_usage":null,"transcript_path":"/nonexistent"}'
run_hook "$P3" >/dev/null
ck "sidecar は書く" "yes" "$([[ -f "$HB/sid-y.json" ]] && echo yes || echo no)"
ck "context_pct は 0" "0" "$(jq -r '.context_pct' "$HB/sid-y.json")"
P3b="$(jq -cn --arg t "$T" '{hook_event_name:"PostModelRequest", session_id:"sid-x", model:"m", status:"cancelled", token_usage:null, transcript_path:$t}')"
run_hook "$P3b" >/dev/null
ck "token_usage が null（取り消し）なら前の値（10.0）を残す" "10.0" "$(jq -r '.context_pct' "$HB/sid-x.json")"
P3v="$(jq -cn --arg t "$T" '{hook_event_name:"PostModelRequest", session_id:"sid-v", model:"m", transcript_path:$t, token_usage:{input_tokens:45000, cached_input_tokens:40000, output_tokens:2500}}')"
run_hook "$P3v" >/dev/null
ck "cached を二重に数えない（total_tokens が無ければ input + output）" "10.0" "$(jq -r '.context_pct' "$HB/sid-v.json")"
printf '%s\n' '{"type":"event_msg","payload":{"type":"token_count","info":{"model_context_window":475000}}}' > "$_TMP_DIR/broken.jsonl"
printf '%s' '{"type":"event_msg","payload":{"type":"token_count","info":{"model_context_wi' >> "$_TMP_DIR/broken.jsonl"
P3c="$(jq -cn --arg t "$_TMP_DIR/broken.jsonl" '{hook_event_name:"PostModelRequest", session_id:"sid-u", model:"m", transcript_path:$t, token_usage:{total_tokens:47500}}')"
run_hook "$P3c" >/dev/null
ck "書きかけの最終行があっても、読める行の窓を取る" "10.0" "$(jq -r '.context_pct' "$HB/sid-u.json")"

echo "[4] 記録の末尾の上限: 上限より前にしか token_count が無ければ窓を取れず 0"
: > "$_TMP_DIR/long.jsonl"
printf '%s\n' '{"type":"event_msg","payload":{"type":"token_count","info":{"model_context_window":475000}}}' >> "$_TMP_DIR/long.jsonl"
for _ in $(seq 1 300); do printf '%s\n' '{"type":"response_item","payload":{"type":"message"}}' >> "$_TMP_DIR/long.jsonl"; done
P4="$(jq -cn --arg t "$_TMP_DIR/long.jsonl" '{hook_event_name:"PostModelRequest", session_id:"sid-z", model:"m", transcript_path:$t, token_usage:{input_tokens:100, cached_input_tokens:0, output_tokens:0}}')"
run_hook "$P4" >/dev/null
ck "上限（200行）の外の窓は読まない → 0" "0" "$(jq -r '.context_pct' "$HB/sid-z.json")"
run_hook "$P4" OE_HB_TAIL_LINES=400 >/dev/null
ck "上限を広げれば読む" "0.0" "$(jq -r '.context_pct' "$HB/sid-z.json")"

echo "[5] session_id が無い・使えない文字: 書かずに診断に残す"
count_hb() { find "$HB" -maxdepth 1 -name '*.json' | wc -l | tr -d ' '; }
before="$(count_hb)"
run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"x"}' >/dev/null
ck "sidecar は増えない" "$before" "$(count_hb)"
ck "診断に残す" "1" "$(jq -rs '[ .[] | select(.reason=="session-id-missing") ] | length' "$EV/oe-heartbeat-diag.jsonl")"
run_hook '{"hook_event_name":"UserPromptSubmit","session_id":"../evil","prompt":"x"}' >/dev/null
ck "../ を含む session_id は書かない" "$before" "$(count_hb)"

echo "[6] lease の環境の形が正しくなければ項目ごと出さない"
run_hook "$P" OE_LEASE_ID=bad OE_GENERATION=x >/dev/null
ck "lease_id は無い" "null" "$(jq -r '.lease_id' "$HB/sid-x.json")"

echo "[7] 100% を超えない・agent は上書きできる"
P7="$(jq -cn --arg t "$T" '{hook_event_name:"PostModelRequest", session_id:"sid-w", model:"m", transcript_path:$t, token_usage:{input_tokens:900000, cached_input_tokens:0, output_tokens:0}}')"
run_hook "$P7" OE_HB_AGENT=other >/dev/null
ck "100 で頭打ち" "100.0" "$(jq -r '.context_pct' "$HB/sid-w.json")"
ck "agent の上書き" "other" "$(jq -r '.agent' "$HB/sid-w.json")"

echo "[9] #562 マージ後: ペインの主の会話だけを書く（サブエージェント・記録の無い内部の会話・codex exec は書かない）"
printf '%s\n' '{"type":"session_meta","payload":{"id":"m-cli","source":"cli"}}' > "$_TMP_DIR/cli.jsonl"
printf '%s\n' '{"type":"session_meta","payload":{"id":"m-exec","source":"exec"}}' > "$_TMP_DIR/exec.jsonl"
printf '%s\n' '{"type":"session_meta","payload":{"id":"m-sub","source":{"subagent":"memory_consolidation"}}}' > "$_TMP_DIR/sub.jsonl"
mk() { jq -cn --arg sid "$1" --arg t "$2" '{hook_event_name:"UserPromptSubmit", session_id:$sid, model:"gpt-6.1-sol", prompt:"x"} + (if $t != "" then {transcript_path:$t} else {} end)'; }
run_hook "$(mk m-cli "$_TMP_DIR/cli.jsonl")" >/dev/null
ck "source が cli の会話は書く" "yes" "$([[ -f "$HB/m-cli.json" ]] && echo yes || echo no)"
run_hook "$(mk m-exec "$_TMP_DIR/exec.jsonl")" >/dev/null
ck "source が exec の会話（ペインから打った codex exec）は書かない" "no" "$([[ -f "$HB/m-exec.json" ]] && echo yes || echo no)"
run_hook "$(mk m-sub "$_TMP_DIR/sub.jsonl")" >/dev/null
ck "source がサブエージェントの会話は書かない" "no" "$([[ -f "$HB/m-sub.json" ]] && echo yes || echo no)"
run_hook "$(mk m-none "")" >/dev/null
ck "transcript_path が無い内部の会話（記憶の整理など）は書かない" "no" "$([[ -f "$HB/m-none.json" ]] && echo yes || echo no)"
run_hook "$(jq -cn --arg t "$_TMP_DIR/cli.jsonl" '{hook_event_name:"PostModelRequest", session_id:"m-agent", model:"m", agent_id:"01a1dafa-0000-0000-0000-000000000000", agent_type:"default", transcript_path:$t, token_usage:{total_tokens:10}}')" >/dev/null
ck "agent_id がある会話（サブエージェント）は書かない" "no" "$([[ -f "$HB/m-agent.json" ]] && echo yes || echo no)"
run_hook "$(mk m-unread "/nonexistent/rollout.jsonl")" >/dev/null
ck "記録の先頭が読めないときは書く（主の会話を落とさない）" "yes" "$([[ -f "$HB/m-unread.json" ]] && echo yes || echo no)"
d0="$(cat "$EV/oe-heartbeat-diag.jsonl" 2>/dev/null | wc -l | tr -d ' ')"
run_hook "$(mk m-exec2 "$_TMP_DIR/exec.jsonl")" >/dev/null
run_hook "$(mk m-none2 "")" >/dev/null
ck "書かない会話は診断も残さない（ふつうのこと・診断の行数が増えない）" "$d0" "$(cat "$EV/oe-heartbeat-diag.jsonl" 2>/dev/null | wc -l | tr -d ' ')"
printf '%s\n' '{"type":"session_meta","payload":{"id":"m-vs","source":"vscode"}}' > "$_TMP_DIR/vscode.jsonl"
run_hook "$(mk m-vs "$_TMP_DIR/vscode.jsonl")" >/dev/null
ck "source が vscode の対話の会話は書く（cli 以外の対話を落とさない）" "yes" "$([[ -f "$HB/m-vs.json" ]] && echo yes || echo no)"
: > "$_TMP_DIR/empty.jsonl"
run_hook "$(mk m-empty "$_TMP_DIR/empty.jsonl")" >/dev/null
ck "記録が空（まだ書かれていない）なら書く" "yes" "$([[ -f "$HB/m-empty.json" ]] && echo yes || echo no)"

echo "[8] 一時ファイルを残さない"
ck ".hb.* が残らない" "0" "$(find "$HB" -name '.hb.*' | wc -l | tr -d ' ')"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
