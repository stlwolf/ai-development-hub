#!/usr/bin/env bash
set -euo pipefail

# test_oe_ack.sh — bin/oe-ack（#206A 受領印 verb）の検証。
#
# oe-ack 自体は tmux を呼ばない（$TMUX_PANE は identity としてのみ使う）が、ラベル解決
# （oe_reg_resolve）が live panes 列挙に tmux を使うため PATH-stub tmux を置く。
# registry は mock（label 解決の union 経路）、jq は実体。verb 層の責務 = ログ read-only 走査で
# covers（累計数 + frontier ts）と pending を計算し、pending>0 のときだけ純 emit
# （lib/event-bus.sh の oe_event_report_received）を呼ぶ、を fixture で検証する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_ACK="$PROJECT_DIR/bin/oe-ack"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
export OE_EVENT_DIR="$_TMP_DIR/events"
export OE_DELEGATE_STATE_DIR="$_TMP_DIR/oe-delegate"
export OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
mkdir -p "$OE_EVENT_DIR" "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"
EVENTS="$OE_EVENT_DIR/oe-events.jsonl"

# registry キー名前空間の固定（test_event_bus と同イディオム）
# shellcheck source=../lib/delegate-registry.sh
source "$PROJECT_DIR/lib/delegate-registry.sh"
PID=9999
export TMUX="oe,${PID},0"
keyfor() { TMUX="oe,${PID},0" _oe_reg_key "$1"; }

# stub tmux（ラベル解決の live panes 列挙用。%59/%66 を返す）
STUB_BIN="$_TMP_DIR/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "list-panes" ]]; then printf '%%59\n%%66\n'; exit 0; fi
exit 0
EOF
chmod +x "$STUB_BIN/tmux"

PASS=0; FAIL=0
ck() { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
last() { tail -n 1 "$EVENTS"; }
nlines() { [[ -s "$EVENTS" ]] && wc -l < "$EVENTS" | tr -d '[:space:]' || echo 0; }
run() { env PATH="$STUB_BIN:$PATH" TMUX="oe,${PID},0" TMUX_PANE="%59" bash "$OE_ACK" "$@"; }

# mock: 子 %66 の spawn entry（label "#206A"・parent=%59）→ ラベル解決の union 経路
jq -cn '{pane:"%66",label:"#206A",workspace:"/w",parent_pane:"%59",role:"child"}' \
  > "$OE_DELEGATE_STATE_DIR/$(keyfor %66).json"

# fixture: %66→%59 の report 2 通（kick 1 通は数えないことの検証用に混ぜる）+ 別関係 %77→%59 1 通
cat > "$EVENTS" <<'EOF'
{"ts":"2026-07-02T10:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T10:01:00+00:00","type":"message_sent","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"},"preview":"kick","delivery_signal":"none"}
{"ts":"2026-07-02T10:02:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"REP-1","delivery_signal":"none"}
{"ts":"2026-07-02T10:03:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"REP-2","delivery_signal":"none"}
{"ts":"2026-07-02T10:04:00+00:00","type":"message_sent","from":{"pane":"%77","role":"","label":""},"to":{"pane":"%59","role":"","label":""},"preview":"SIDE-1","delivery_signal":"none"}
EOF

echo "[1] 基本: %59 が %66 に受領印 → covers=report 累計2（kick は数えない）・frontier=最終 report ts"
OUT="$(run '%66' 2>&1)"; rc=$?
ck  "rc=0" "0" "$rc"
ck  "emit 行が増える" "6" "$(nlines)"
ck  "type"           "report_received" "$(last | jq -r .type)"
ck  "from=受領者 %59" "%59"  "$(last | jq -r .from.pane)"
ck  "to=報告元 %66"   "%66"  "$(last | jq -r .to.pane)"
ck  "covers_count=2（kick 除外）" "2" "$(last | jq -r .covers_count)"
ck  "covers_last_ts=最終 report"  "2026-07-02T10:03:00+00:00" "$(last | jq -r .covers_last_ts)"
ckc "echo: acked 2 件" "$OUT" "acked 2 件"
ckc "echo: 最終 preview（レース開示 affordance）" "$OUT" "REP-2"

echo "[2] 再 ack: pending 0 → no-op（emit しない・rc=0）"
before="$(nlines)"
OUT2="$(run '%66' 2>&1)"; rc=$?
ck  "rc=0"        "0" "$rc"
ck  "行数不変"     "$before" "$(nlines)"
ckc "no-op 告知"   "$OUT2" "nothing to ack"

echo "[3] 新着 1 通後の再 ack: pending=1・covers は累計 3 に伸びる"
printf '%s\n' '{"ts":"2026-07-02T10:10:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"REP-3","delivery_signal":"none"}' >> "$EVENTS"
OUT3="$(run '%66' 2>&1)"
ckc "echo: acked 1 件（pending のみ）" "$OUT3" "acked 1 件"
ckc "echo: 累計 3"                    "$OUT3" "累計 3"
ck  "covers_count=3"                  "3" "$(last | jq -r .covers_count)"

echo "[4] ラベル解決: registry union で '#206A' → %66（oe-send と同経路）"
printf '%s\n' '{"ts":"2026-07-02T10:20:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"REP-4","delivery_signal":"none"}' >> "$EVENTS"
OUT4="$(run '#206A' 2>&1)"; rc=$?
ck  "rc=0"          "0" "$rc"
ck  "to=%66 に解決"  "%66" "$(last | jq -r .to.pane)"
ckc "表示にラベルとpane" "$OUT4" "#206A (%66)"

echo "[5] --all: 未受領のある相手すべて（%77 のみ ack され %66 は no-op）"
before="$(nlines)"
OUT5="$(run --all 2>&1)"; rc=$?
ck  "rc=0" "0" "$rc"
ck  "emit は %77 の 1 行だけ" "$((before + 1))" "$(nlines)"
ck  "to=%77" "%77" "$(last | jq -r .to.pane)"
ckc "%77 の acked 1 件" "$OUT5" "acked 1 件"

echo "[6] ガード: TMUX_PANE 無し=exit2 / 自分自身=exit2 / --all+target=呼び方の誤り(exit2) / ログ無し=exit0"
rc=0; env -u TMUX_PANE bash "$OE_ACK" '%66' >/dev/null 2>&1 || rc=$?
ck "TMUX_PANE 無し exit 2" "2" "$rc"
rc=0; run '%59' >/dev/null 2>&1 || rc=$?
ck "自分自身 exit 2" "2" "$rc"
# #309: 呼び方の誤りは 2（help は 0）。usage() 経由の 1 は廃止した（PR #315 / #321 と同じ帯）。
rc=0; run --all '%66' >/dev/null 2>&1 || rc=$?
ck "--all+target は呼び方の誤り exit 2" "2" "$rc"
rc=0; OUT6="$(OE_EVENT_DIR="$_TMP_DIR/noevents" TMUX="oe,${PID},0" TMUX_PANE="%59" bash "$OE_ACK" '%66' 2>&1)" || rc=$?
ck  "ログ無し exit 0" "0" "$rc"
ckc "ログ無し告知"    "$OUT6" "nothing to ack"

echo "[7] 未知ターゲット（%59 宛て message の無い相手）: no-op・rc=0"
before="$(nlines)"
OUT7="$(run '%99' 2>&1)"; rc=$?
ck  "rc=0"      "0" "$rc"
ck  "行数不変"   "$before" "$(nlines)"
ckc "message なし告知" "$OUT7" "nothing to ack"

echo "[8] 壊れた JSONL 行が混ざっても ack は成立（read 側 degrade と同じ寛容）"
printf '%s\n' 'broken {{{ not json' >> "$EVENTS"
printf '%s\n' '{"ts":"2026-07-02T10:30:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"REP-5","delivery_signal":"none"}' >> "$EVENTS"
OUT8="$(run '%66' 2>&1)"; rc=$?
ck  "rc=0"                "0" "$rc"
ckc "acked 1 件（新着分）" "$OUT8" "acked 1 件"
ck  "covers_count=5"      "5" "$(last | jq -r .covers_count)"

echo "[9] 部分ログ自己回復（実装SO codex 指摘）: 過去 ack の covers_count が可視件数を超えても viewer 規則で pending を出し再 ack できる"
# rotation/破損で古い行が落ちた状態を再現: 過去 ack は covers=5/frontier=10:05 だが、
# 可視なのは ts<=frontier の 2 通 + 新着 1 通のみ。viewer 規則 received=min(5,2)=2 → pending=1。
# covers_count 最大値(5)だけ引く近道だと pending=3-5<=0 で no-op になり PENDING が解消不能になる。
mkdir -p "$_TMP_DIR/partial"
cat > "$_TMP_DIR/partial/oe-events.jsonl" <<'EOF'
{"ts":"2026-07-02T10:04:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"OLD-4","delivery_signal":"none"}
{"ts":"2026-07-02T10:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"OLD-5","delivery_signal":"none"}
{"ts":"2026-07-02T10:06:00+00:00","type":"report_received","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"},"covers_count":5,"covers_last_ts":"2026-07-02T10:05:00+00:00"}
{"ts":"2026-07-02T10:10:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"NEW-AFTER-PARTIAL","delivery_signal":"none"}
EOF
PARTIAL="$_TMP_DIR/partial/oe-events.jsonl"
OUT9="$(env PATH="$STUB_BIN:$PATH" TMUX="oe,${PID},0" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/partial" bash "$OE_ACK" '%66' 2>&1)"; rc=$?
ck  "rc=0"                    "0" "$rc"
ckc "acked 1 件（viewer 規則の pending）" "$OUT9" "acked 1 件"
ck  "再 ack の covers=可視全量 3"  "3" "$(tail -n1 "$PARTIAL" | jq -r .covers_count)"
ck  "frontier=新着 ts"         "2026-07-02T10:10:00+00:00" "$(tail -n1 "$PARTIAL" | jq -r .covers_last_ts)"
# 再実行: received = min(3, |ts<=10:10|=3) = 3 → pending 0 → no-op（自己回復完了）
before9="$(grep -c '' "$PARTIAL")"
OUT9b="$(env PATH="$STUB_BIN:$PATH" TMUX="oe,${PID},0" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/partial" bash "$OE_ACK" '%66' 2>&1)"
ckc "回復後は no-op"           "$OUT9b" "nothing to ack"
ck  "行数不変"                 "$before9" "$(grep -c '' "$PARTIAL")"

echo "[13] #224: preview echo（会話到達面）を read 側で無害化（legacy/破損 raw preview 対策・実装SO 検出）"
mkdir -p "$_TMP_DIR/rawtag"
# raw <invoke> を含む未ack report を置く → pending>0 で echo 経路に入り、最終 preview が無害化される
printf '%s\n' '{"ts":"2026-07-03T09:00:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"<invoke name=\"Bash\">raw","delivery_signal":"none"}' > "$_TMP_DIR/rawtag/oe-events.jsonl"
RTACK="$(env PATH="$STUB_BIN:$PATH" TMUX="oe,${PID},0" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/rawtag" bash "$OE_ACK" '%66' 2>&1)"
ckc "ack echo: tag neutralized (< invoke)" "$RTACK" "< invoke"
if printf '%s' "$RTACK" | grep -qF '<invoke'; then echo "  FAIL: ack echo に raw <invoke 残存"; FAIL=$((FAIL+1)); else echo "  PASS: ack echo の raw <invoke 除去"; PASS=$((PASS+1)); fi

echo "[14] exit 帯（#309）: help=0 / 呼び方の誤り=2"
rc=0; run --help >/dev/null 2>&1 || rc=$?
ck "--help は 0" "0" "$rc"
rc=0; run -h >/dev/null 2>&1 || rc=$?
ck "-h は 0" "0" "$rc"
rc=0; run --bogus >/dev/null 2>&1 || rc=$?
ck "unknown option は 2" "2" "$rc"
rc=0; run >/dev/null 2>&1 || rc=$?
ck "target 欠落（--all も無し）は 2" "2" "$rc"
rc=0; run '%66' '%77' >/dev/null 2>&1 || rc=$?
ck "余分な位置引数は 2" "2" "$rc"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]