#!/usr/bin/env bash
# test_oe_status.sh — oe-status の audit-terminal reducer / timeline / 区画 degrade の単体テスト
#
# engine 側（state/audit ファイル）は OE_DATA_DIR を mktemp で隔離して検証するため tmux 不要。
# delegate 側の degrade は tmux 不在の PATH stub で検証する（test_oe_select 流）。
# 設計の正本: docs/discussions/2026-06-19-discussion-cockpit-observation-ui.md §8
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OE_STATUS="${SCRIPT_DIR}/../bin/oe-status"

# --- 隔離した data dir（engine fixtures） ---
FX="$(mktemp -d)"
mkdir -p "${FX}/audit" "${FX}/state"
trap 'rm -rf "$FX" "${PATHBIN:-/nonexistent-xyz}"' EXIT
export OE_DATA_DIR="$FX"

# --- 有効な Crockford ULID（14 桁日付 + 12 文字・I/L/O/U 除外） ---
OK=202606200100000000000000AA   # success
BLK=202606200200000000000000BB  # blocked
TMO=202606200300000000000000TT  # timeout（CB audit-only・session_end/KVS 無し）
RUN=202606200400000000000000RR  # running?（session_start のみ）
INT=202606200500000000000000NT  # interrupted（session_end 無し）
MUL=202606200600000000000000MP  # multi-pane: p1 blocked → p2 success（severity-max=blocked）
VTO=202606200700000000000000VT  # verification_timeout（target success のまま・注記のみ）
MTR=202606200800000000000000MT  # max_turns（limit_type フォールバック → blocked）
KVO=202606200900000000000000KV  # KVS only（audit 不在）

j() { printf '%s\n' "$@"; }

j '{"ts":"2026-06-20T01:00:00+00:00","event_type":"session_start","session_id":"'"$OK"'","pane_id":3,"state":null,"payload":{}}' \
  '{"ts":"2026-06-20T01:01:00+00:00","event_type":"session_end","session_id":"'"$OK"'","pane_id":3,"state":"success","payload":{}}' \
  '{"ts":"2026-06-20T01:01:01+00:00","event_type":"cleanup","session_id":"'"$OK"'","pane_id":0,"state":null,"payload":{"killed_pane_ids":[3]}}' > "${FX}/audit/${OK}.jsonl"
printf '{"session_id":"%s","pane_id":3,"state":"success","last_updated":"2026-06-20T01:01:00+00:00","outputs":["a.md","b.md"],"blockers":[]}\n' "$OK" > "${FX}/state/${OK}.state.json"

j '{"ts":"2026-06-20T02:00:00+00:00","event_type":"session_start","session_id":"'"$BLK"'","pane_id":4,"state":null,"payload":{}}' \
  '{"ts":"2026-06-20T02:01:00+00:00","event_type":"session_end","session_id":"'"$BLK"'","pane_id":4,"state":"blocked","payload":{}}' > "${FX}/audit/${BLK}.jsonl"

j '{"ts":"2026-06-20T03:00:00+00:00","event_type":"session_start","session_id":"'"$TMO"'","pane_id":5,"state":null,"payload":{}}' \
  '{"ts":"2026-06-20T03:30:00+00:00","event_type":"circuit_breaker_triggered","session_id":"'"$TMO"'","pane_id":0,"state":null,"payload":{"reason":"timeout"}}' \
  '{"ts":"2026-06-20T03:30:01+00:00","event_type":"cleanup","session_id":"'"$TMO"'","pane_id":0,"state":null,"payload":{}}' > "${FX}/audit/${TMO}.jsonl"

j '{"ts":"2026-06-20T04:00:00+00:00","event_type":"session_start","session_id":"'"$RUN"'","pane_id":6,"state":null,"payload":{}}' > "${FX}/audit/${RUN}.jsonl"

j '{"ts":"2026-06-20T05:00:00+00:00","event_type":"session_start","session_id":"'"$INT"'","pane_id":7,"state":null,"payload":{}}' \
  '{"ts":"2026-06-20T05:01:00+00:00","event_type":"interrupt","session_id":"'"$INT"'","pane_id":0,"state":null,"payload":{"method":"SIGINT"}}' > "${FX}/audit/${INT}.jsonl"

j '{"ts":"2026-06-20T06:00:00+00:00","event_type":"session_start","session_id":"'"$MUL"'","pane_id":8,"state":null,"payload":{}}' \
  '{"ts":"2026-06-20T06:01:00+00:00","event_type":"session_end","session_id":"'"$MUL"'","pane_id":8,"state":"blocked","payload":{}}' \
  '{"ts":"2026-06-20T06:02:00+00:00","event_type":"session_end","session_id":"'"$MUL"'","pane_id":9,"state":"success","payload":{}}' > "${FX}/audit/${MUL}.jsonl"

j '{"ts":"2026-06-20T07:00:00+00:00","event_type":"session_start","session_id":"'"$VTO"'","pane_id":10,"state":null,"payload":{}}' \
  '{"ts":"2026-06-20T07:01:00+00:00","event_type":"session_end","session_id":"'"$VTO"'","pane_id":10,"state":"success","payload":{}}' \
  '{"ts":"2026-06-20T07:02:00+00:00","event_type":"circuit_breaker_triggered","session_id":"'"$VTO"'","pane_id":10,"state":null,"payload":{"reason":"verification_timeout"}}' > "${FX}/audit/${VTO}.jsonl"

j '{"ts":"2026-06-20T08:00:00+00:00","event_type":"session_start","session_id":"'"$MTR"'","pane_id":11,"state":null,"payload":{}}' \
  '{"ts":"2026-06-20T08:01:00+00:00","event_type":"circuit_breaker_triggered","session_id":"'"$MTR"'","pane_id":0,"state":null,"payload":{"limit_type":"max_turns"}}' > "${FX}/audit/${MTR}.jsonl"

# KVS-only（audit 不在）
printf '{"session_id":"%s","pane_id":12,"state":"partial","last_updated":"2026-06-20T09:01:00+00:00","outputs":[],"blockers":["x"]}\n' "$KVO" > "${FX}/state/${KVO}.state.json"

# DJ-4: 別スキーマの SO ログは session 行に混ぜない（ULID 不一致で除外されること）
printf '{"ts":"2026-06-20T10:00:00+00:00","event_type":"oe_refute","audit_id":"x","verdict":"refuted"}\n' > "${FX}/audit/oe-refute.jsonl"

# --- assert ヘルパ ---
pass=0; fail=0
ck() { # <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; pass=$((pass+1));
  else echo "  FAIL: $1 (want='$2' got='$3')"; fail=$((fail+1)); fi
}
# overview の ENGINE 行から特定 session の STATE 列（2 列目）を取る
state_of() { "$OE_STATUS" 2>/dev/null | awk -v s="$1" '$1==s {print $2; exit}'; }

echo "[1] audit-terminal reducer: STATE 導出（severity-max・末尾行でない・caveat1）"
ck "success（cleanup 末尾でも success）" "success"     "$(state_of "$OK")"
ck "blocked（session_end）"              "blocked"      "$(state_of "$BLK")"
ck "timeout（CB audit-only・KVS 無し）"  "timeout"      "$(state_of "$TMO")"
ck "running?（session_start のみ）"      "running?"     "$(state_of "$RUN")"
ck "interrupted（session_end 無し）"     "interrupted"  "$(state_of "$INT")"
ck "multi-pane: blocked が success に隠れない" "blocked"  "$(state_of "$MUL")"
ck "verification_timeout は success のまま"     "success"  "$(state_of "$VTO")"
ck "max_turns（limit_type フォールバック）→ blocked" "blocked" "$(state_of "$MTR")"

echo "[2] 注記 / multi-pane / KVS 補足"
ck "verify-timeout 注記" "yes" "$("$OE_STATUS" 2>/dev/null | grep -E "^$VTO " | grep -q "verify-timeout" && echo yes || echo no)"
ck "multi-pane PANES=2"  "2"   "$("$OE_STATUS" 2>/dev/null | awk -v s="$MUL" '$1==s {print $3; exit}')"
ck "success に outputs=2 補足" "yes" "$("$OE_STATUS" 2>/dev/null | grep -E "^$OK " | grep -q "outputs=2" && echo yes || echo no)"
KVO_ROW="$("$OE_STATUS" 2>/dev/null | grep -E "^$KVO " || true)"
ck "KVS-only 行に partial" "yes" "$(printf '%s' "$KVO_ROW" | grep -q "partial" && echo yes || echo no)"
ck "KVS-only 行に kvs-only 注記" "yes" "$(printf '%s' "$KVO_ROW" | grep -q "kvs-only" && echo yes || echo no)"

echo "[3] DJ-4: oe-refute.jsonl（別スキーマ）は ENGINE 区画に出ない"
# DELEGATE 区画は実 tmux 由来のラベルに 'refute' を含みうるため ENGINE 区画に限定して確認する
ENGINE_SECTION="$("$OE_STATUS" 2>/dev/null | sed -n '/=== ENGINE/,/=== DELEGATE/p')"
ck "ENGINE 区画に refute 行が無い" "" "$(printf '%s\n' "$ENGINE_SECTION" | grep -iE 'refute' || true)"

echo "[4] timeline（受入2: start→end が追える）"
TL="$("$OE_STATUS" "$OK" 2>/dev/null)"
ck "derived state 行" "yes" "$(printf '%s\n' "$TL" | grep -q "derived state: success" && echo yes || echo no)"
ck "session_start 行" "yes" "$(printf '%s\n' "$TL" | grep -q "session_start" && echo yes || echo no)"
ck "session_end[success] 行" "yes" "$(printf '%s\n' "$TL" | grep -q "session_end  \[success\]" && echo yes || echo no)"
ck "timeout timeline に CB reason" "yes" "$("$OE_STATUS" "$TMO" 2>/dev/null | grep -q '"reason":"timeout"' && echo yes || echo no)"

echo "[5] 引数ハンドリング"
"$OE_STATUS" --help >/dev/null 2>&1; ck "--help rc0" "0" "$?"
rc=0; "$OE_STATUS" --bogus >/dev/null 2>&1 || rc=$?; ck "未知オプション rc2" "2" "$rc"
rc=0; "$OE_STATUS" not-a-ulid >/dev/null 2>&1 || rc=$?; ck "非 ULID 引数 rc2" "2" "$rc"
rc=0; "$OE_STATUS" "$RUN" extra >/dev/null 2>&1 || rc=$?; ck "余分な引数 rc2" "2" "$rc"
rc=0; "$OE_STATUS" 202606209999999999999999ZZ >/dev/null 2>&1 || rc=$?; ck "存在しない session rc1" "1" "$rc"

echo "[6] delegate degrade: tmux 不在でも ENGINE は出て exit 0"
# stub のみの PATH（tmux を含めない）を作り、oe-status が必要とするツールだけ symlink する。
# Copilot #3446407858 反映: PATH に /usr/bin:/bin を残すと、その環境（Linux/CI 等）に
# /usr/bin/tmux があると degrade せずテストが不安定になる。stub のみにして tmux を確実に隠す
# （shebang の /usr/bin/env は絶対パスなので PATH の影響を受けない）。
PATHBIN="$(mktemp -d)"
for tool in jq awk sed sort basename dirname cat printf env bash grep; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  if [[ -n "$p" ]]; then ln -sf "$p" "${PATHBIN}/${tool}" 2>/dev/null || true; fi
done
degrade_out="$(PATH="${PATHBIN}" "$OE_STATUS" 2>/dev/null)"; drc=$?
ck "tmux 不在で exit 0" "0" "$drc"
ck "ENGINE 区画は出る" "yes" "$(printf '%s\n' "$degrade_out" | grep -q "=== ENGINE" && echo yes || echo no)"
ck "ENGINE 行（timeout）は出る" "yes" "$(printf '%s\n' "$degrade_out" | grep -E "^$TMO " | grep -q "timeout" && echo yes || echo no)"
ck "DELEGATE は degrade 注記" "yes" "$(printf '%s\n' "$degrade_out" | grep -q "tmux unavailable" && echo yes || echo no)"

echo ""
echo "=== RESULT: pass=${pass} fail=${fail} ==="
[[ "$fail" -eq 0 ]]
