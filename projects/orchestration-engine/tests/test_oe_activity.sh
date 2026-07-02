#!/usr/bin/env bash
set -euo pipefail

# test_oe_activity.sh — bin/oe-activity（#206 増分1 read-only 投影ビュー）の検証。
#
# liveness は PATH-stub tmux で固定（%59/%66 を alive・%77 は出さない＝gone）。jq は実体。
# fixture の oe-events.jsonl を直に置いて投影（往復カウント / liveness / report/kick 向き /
# inbox フィルタ / timeline(turn 連番・全体時系列・kick 可視) / degrade / 空）を検証する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_ACTIVITY="$PROJECT_DIR/bin/oe-activity"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
export OE_EVENT_DIR="$_TMP_DIR/events"; mkdir -p "$OE_EVENT_DIR"
EVENTS="$OE_EVENT_DIR/oe-events.jsonl"

# --- stub tmux: list-panes は %59 %66 を返す（%77 は不在＝gone）---
STUB_BIN="$_TMP_DIR/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "list-panes" ]]; then printf '%%59\n%%66\n'; exit 0; fi
exit 0
EOF
chmod +x "$STUB_BIN/tmux"

# fixture: %66 = 生存子（kick + report の 2 往復）、%77 = departed 子（report 1・suspected_miss）
cat > "$EVENTS" <<'EOF'
{"ts":"2026-06-22T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"#206 inbox"},"to":{"pane":"%66","role":"child","label":"#206 impl"}}
{"ts":"2026-06-22T12:01:00+00:00","type":"message_sent","from":{"pane":"%59","role":"parent","label":"#206 inbox"},"to":{"pane":"%66","role":"child","label":"#206 impl"},"preview":"increment1 を進めて","delivery_signal":"none"}
{"ts":"2026-06-22T12:02:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206 impl"},"to":{"pane":"%59","role":"parent","label":"#206 inbox"},"preview":"DONE-IMPL-REPORT","delivery_signal":"none"}
{"ts":"2026-06-22T12:03:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"#206 inbox"},"to":{"pane":"%77","role":"child","label":"#199 old"}}
{"ts":"2026-06-22T12:04:00+00:00","type":"message_sent","from":{"pane":"%77","role":"child","label":"#199 old"},"to":{"pane":"%59","role":"parent","label":"#206 inbox"},"preview":"PARTIAL-OLD-REPORT","delivery_signal":"suspected_miss"}
EOF

PASS=0; FAIL=0
ck() { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { # contains: <desc> <haystack> <needle>
  if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
run() { env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" bash "$OE_ACTIVITY" "$@"; }
# %66 row / %77 row を取り出す（preview マーカで一意特定）
row_of() { printf '%s\n' "$1" | grep -F "$2"; }

echo "[1] overview: 2 関係・新しい順（%77 の最終 12:04 が先頭）"
OUT="$(run)"
ckc "has %66 child label" "$OUT" "#206 impl"
ckc "has %77 child label" "$OUT" "#199 old"
first_data="$(printf '%s\n' "$OUT" | sed -n '3p')"   # 1=title 2=header 3=first row
ckc "newest first = %77 row" "$first_data" "#199 old"

echo "[2] liveness: 生存子=alive / departed 子=gone"
ckc "%66 alive" "$(row_of "$OUT" "DONE-IMPL-REPORT")" "alive"
ckc "%77 gone"  "$(row_of "$OUT" "PARTIAL-OLD-REPORT")" "gone"

echo "[3] 往復回数: %66=2（kick+report）/ %77=1"
r66="$(row_of "$OUT" "DONE-IMPL-REPORT")"; r77="$(row_of "$OUT" "PARTIAL-OLD-REPORT")"
ck "%66 trips=2" "2" "$(printf '%s' "$r66" | awk '{print $2}')"
ck "%77 trips=1" "1" "$(printf '%s' "$r77" | awk '{print $2}')"

echo "[4] delivery: %77 は suspected_miss（miss 表示）/ %66 は none"
ckc "%77 suspected_miss" "$r77" "suspected_miss"
ckc "%66 none"           "$r66" "none"

echo "[5] preview: 直近 message が出る"
ckc "%66 latest preview" "$r66" "DONE-IMPL-REPORT"

echo "[6] inbox: 自分(%59)宛の報告を送信元ごとに（kick は出ない）"
IN="$(run --inbox)"
ckc "inbox header" "$IN" "report inbox (to %59"
ckc "inbox has %66 report" "$IN" "DONE-IMPL-REPORT"
ckc "inbox has %77 report" "$IN" "PARTIAL-OLD-REPORT"
in66="$(row_of "$IN" "DONE-IMPL-REPORT")"
ck "inbox %66 trips=1 (report のみ)" "1" "$(printf '%s' "$in66" | awk '{print $2}')"
ckc "inbox %66 alive" "$in66" "alive"

echo "[7] liveness ?: tmux 失敗時は ? に degrade"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$STUB_BIN/tmux"
OUT2="$(run)"
ckc "live=? on tmux fail" "$(row_of "$OUT2" "DONE-IMPL-REPORT")" "?"
# stub 復元
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "list-panes" ]]; then printf '%%59\n%%66\n'; exit 0; fi
exit 0
EOF
chmod +x "$STUB_BIN/tmux"

echo "[8] 空ログ: メッセージ + exit 0"
rc=0; OUT3="$(OE_EVENT_DIR="$_TMP_DIR/empty" bash "$OE_ACTIVITY" 2>&1)" || rc=$?
ck "empty exit 0" "0" "$rc"
ckc "empty message" "$OUT3" "no activity recorded yet"

echo "[9] jq 不在: degrade（件数のみ・exit 0）"
NOJQ="$_TMP_DIR/nojq"; mkdir -p "$NOJQ"
# 「jq だけ不在」の PATH を作る: 現 PATH の全実行可能ファイルを jq 以外 symlink する
# （bash や profile 依存も残るので startup を壊さない）。
IFS=':' read -ra _pdirs <<< "$PATH"
for d in "${_pdirs[@]}"; do
  [[ -d "$d" ]] || continue
  for f in "$d"/*; do
    [[ -x "$f" && ! -d "$f" ]] || continue
    b="$(basename "$f")"
    [[ "$b" == "jq" ]] && continue
    [[ -e "$NOJQ/$b" ]] || ln -s "$f" "$NOJQ/$b" 2>/dev/null || true
  done
done
rc=0; OUT4="$(PATH="$NOJQ" TMUX_PANE="%59" bash "$OE_ACTIVITY" 2>&1)" || rc=$?
ck "nojq exit 0" "0" "$rc"
ckc "nojq notice" "$OUT4" "jq not found"
ckc "nojq count" "$OUT4" "events: 5"

echo "[10] 不正オプション → usage・exit 2"
rc=0; env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" bash "$OE_ACTIVITY" --bogus >/dev/null 2>&1 || rc=$?
ck "bad opt exit 2" "2" "$rc"

echo "[11] 壊れた JSONL 行は read 時にスキップ（degrade・exit 0・実装SO cursor 指摘）"
mkdir -p "$_TMP_DIR/corrupt"
{
  printf '%s\n' 'this is not json {{{'
  printf '%s\n' '{"ts":"2026-06-22T13:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"#206 inbox"},"to":{"pane":"%66","role":"child","label":"#206 impl"}}'
  printf '%s\n' '{"ts":"2026-06-22T13:01:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206 impl"},"to":{"pane":"%59","role":"parent","label":"#206 inbox"},"preview":"VALID-AFTER-CORRUPT","delivery_signal":"none"}'
} > "$_TMP_DIR/corrupt/oe-events.jsonl"
rc=0; OUT5="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/corrupt" bash "$OE_ACTIVITY" 2>&1)" || rc=$?
ck "corrupt exit 0" "0" "$rc"
ckc "valid row survives corrupt line" "$OUT5" "VALID-AFTER-CORRUPT"

echo "[12] timeline: 1 送信 1 行・関係内 turn 連番・全体時系列（古→新）・kick も出る"
TL="$(run --timeline)"
ckc "timeline header" "$TL" "activity timeline"
ckc "timeline shows kick (inbox では出ない送信)" "$TL" "increment1"
ckc "timeline has %66 report" "$TL" "DONE-IMPL-REPORT"
ckc "timeline has %77 report" "$TL" "PARTIAL-OLD-REPORT"
# 行抽出（preview マーカで一意）。列: TURN TS DIR DELIVERY RELATION... PREVIEW → $1=turn
tl_kick="$(row_of "$TL" "increment1")"
tl_rep66="$(row_of "$TL" "DONE-IMPL-REPORT")"
tl_rep77="$(row_of "$TL" "PARTIAL-OLD-REPORT")"
ck "%66 kick turn=1"   "1" "$(printf '%s' "$tl_kick"  | awk '{print $1}')"
ck "%66 report turn=2" "2" "$(printf '%s' "$tl_rep66" | awk '{print $1}')"
ck "%77 report turn=1" "1" "$(printf '%s' "$tl_rep77" | awk '{print $1}')"
ckc "%66 kick dir=kick"     "$tl_kick"  "kick"
ckc "%66 report dir=report" "$tl_rep66" "report"
ckc "%77 report suspected_miss" "$tl_rep77" "suspected_miss"
# 全体は時系列（古→新）: 先頭データ行（title+header の次）= 最古 12:01 の kick
tl_first="$(printf '%s\n' "$TL" | sed -n '3p')"
ckc "timeline oldest-first (先頭=12:01 kick)" "$tl_first" "increment1"

echo "[13] timeline: message_sent 無し（spawn のみ）→ (no messages) + exit 0"
mkdir -p "$_TMP_DIR/spawnonly"
printf '%s\n' '{"ts":"2026-06-22T14:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"p"},"to":{"pane":"%66","role":"child","label":"c"}}' > "$_TMP_DIR/spawnonly/oe-events.jsonl"
rc=0; TL2="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/spawnonly" bash "$OE_ACTIVITY" --timeline 2>&1)" || rc=$?
ck "timeline spawn-only exit 0" "0" "$rc"
ckc "timeline spawn-only no-messages msg" "$TL2" "no messages"

echo "[14] timeline: 壊れた JSONL 行は read 時にスキップ（exit 0・有効行は残る）"
rc=0; TL3="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/corrupt" bash "$OE_ACTIVITY" --timeline 2>&1)" || rc=$?
ck "timeline corrupt exit 0" "0" "$rc"
ckc "timeline valid row survives corrupt" "$TL3" "VALID-AFTER-CORRUPT"

echo "[15] 空 label でも列ズレしない（US 区切り・実装SO cursor 指摘・overview + timeline）"
mkdir -p "$_TMP_DIR/emptylabel"
{
  printf '%s\n' '{"ts":"2026-06-22T15:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":""},"to":{"pane":"%66","role":"child","label":""}}'
  printf '%s\n' '{"ts":"2026-06-22T15:01:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":""},"to":{"pane":"%59","role":"parent","label":""},"preview":"EMPTYLABEL-PREVIEW","delivery_signal":"none"}'
} > "$_TMP_DIR/emptylabel/oe-events.jsonl"
EL_OV="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/emptylabel" bash "$OE_ACTIVITY")"
ckc "overview 空label: preview が正しく出る" "$EL_OV" "EMPTYLABEL-PREVIEW"
ckc "overview 空label: RELATION=%59 → %66" "$(row_of "$EL_OV" "EMPTYLABEL-PREVIEW")" "%59 → %66"
EL_TL="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/emptylabel" bash "$OE_ACTIVITY" --timeline)"
ckc "timeline 空label: preview が正しく出る" "$EL_TL" "EMPTYLABEL-PREVIEW"
el_tl="$(row_of "$EL_TL" "EMPTYLABEL-PREVIEW")"
ckc "timeline 空label: RELATION=%59 → %66" "$el_tl" "%59 → %66"
ck "timeline 空label: turn=1" "1" "$(printf '%s' "$el_tl" | awk '{print $1}')"

echo "[16] preview の制御文字（ESC 等）は空白へ畳む（端末注入防止・実装SO codex 指摘）"
mkdir -p "$_TMP_DIR/ctrl"
{
  printf '%s\n' '{"ts":"2026-06-22T16:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"p"},"to":{"pane":"%66","role":"child","label":"c"}}'
  printf '%s\n' '{"ts":"2026-06-22T16:01:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"c"},"to":{"pane":"%59","role":"parent","label":"p"},"preview":"CTRL\u001b[31mINJECT","delivery_signal":"none"}'
} > "$_TMP_DIR/ctrl/oe-events.jsonl"
CT="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/ctrl" bash "$OE_ACTIVITY" --timeline)"
ESC="$(printf '\033')"
if printf '%s' "$CT" | LC_ALL=C grep -q "$ESC"; then echo "  FAIL: ESC 未畳み込み"; FAIL=$((FAIL+1)); else echo "  PASS: ESC folded to space"; PASS=$((PASS+1)); fi
ckc "ctrl: 周辺テキスト CTRL 残存" "$CT" "CTRL"
ckc "ctrl: 周辺テキスト INJECT 残存" "$CT" "INJECT"

echo "[17] 同一秒の複数送信でも turn は append 順で決定的（実装SO codex 指摘・idx tiebreak）"
mkdir -p "$_TMP_DIR/samesec"
{
  printf '%s\n' '{"ts":"2026-06-22T17:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"p"},"to":{"pane":"%66","role":"child","label":"c"}}'
  printf '%s\n' '{"ts":"2026-06-22T17:01:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"c"},"to":{"pane":"%59","role":"parent","label":"p"},"preview":"SS-FIRST","delivery_signal":"none"}'
  printf '%s\n' '{"ts":"2026-06-22T17:01:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"c"},"to":{"pane":"%59","role":"parent","label":"p"},"preview":"SS-SECOND","delivery_signal":"none"}'
  printf '%s\n' '{"ts":"2026-06-22T17:01:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"c"},"to":{"pane":"%59","role":"parent","label":"p"},"preview":"SS-THIRD","delivery_signal":"none"}'
} > "$_TMP_DIR/samesec/oe-events.jsonl"
SS="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/samesec" bash "$OE_ACTIVITY" --timeline)"
ck "same-sec FIRST turn=1"  "1" "$(printf '%s' "$(row_of "$SS" "SS-FIRST")"  | awk '{print $1}')"
ck "same-sec SECOND turn=2" "2" "$(printf '%s' "$(row_of "$SS" "SS-SECOND")" | awk '{print $1}')"
ck "same-sec THIRD turn=3"  "3" "$(printf '%s' "$(row_of "$SS" "SS-THIRD")"  | awk '{print $1}')"

echo "[18] inbox PENDING（#206A）: 未ack / 部分ack（count cap で同秒割込み除外）/ 全ack"
mkdir -p "$_TMP_DIR/acked"
{
  printf '%s\n' '{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}'
  printf '%s\n' '{"ts":"2026-07-02T12:01:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"ACK-R1","delivery_signal":"none"}'
  printf '%s\n' '{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"ACK-R2","delivery_signal":"none"}'
  # ack（covers=2・frontier=12:05）emit 後、同秒 12:05 に 3 通目が割り込んだ状況を再現
  printf '%s\n' '{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"ACK-R3-SAMESEC","delivery_signal":"none"}'
  printf '%s\n' '{"ts":"2026-07-02T12:05:01+00:00","type":"report_received","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"},"covers_count":2,"covers_last_ts":"2026-07-02T12:05:00+00:00"}'
  # 未ack の別関係（%77）
  printf '%s\n' '{"ts":"2026-07-02T12:10:00+00:00","type":"message_sent","from":{"pane":"%77","role":"","label":""},"to":{"pane":"%59","role":"","label":""},"preview":"NOACK-X1","delivery_signal":"none"}'
} > "$_TMP_DIR/acked/oe-events.jsonl"
AIN="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/acked" bash "$OE_ACTIVITY" --inbox)"
ckc "inbox PENDING header" "$AIN" "PENDING"
a66="$(row_of "$AIN" "ACK-R3-SAMESEC")"; a77="$(row_of "$AIN" "NOACK-X1")"
# 列: LIVE TRIPS PENDING ... → $3=PENDING。count cap: K=min(2, |ts<=12:05|=3)=2 → pending=3-2=1
ck "%66 部分ack pending=1（同秒割込みは cap で未受領のまま）" "1" "$(printf '%s' "$a66" | awk '{print $3}')"
ck "%77 未ack pending=1" "1" "$(printf '%s' "$a77" | awk '{print $3}')"
# 全 ack: covers=3・frontier=12:05 を追記 → pending=0
printf '%s\n' '{"ts":"2026-07-02T12:11:00+00:00","type":"report_received","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"},"covers_count":3,"covers_last_ts":"2026-07-02T12:05:00+00:00"}' >> "$_TMP_DIR/acked/oe-events.jsonl"
AIN2="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/acked" bash "$OE_ACTIVITY" --inbox)"
ck "%66 全ack pending=0" "0" "$(printf '%s' "$(row_of "$AIN2" "ACK-R3-SAMESEC")" | awk '{print $3}')"

echo "[19] PENDING 続き: 複数 ack は max（巻き戻りなし）/ ack 後の新着 / kick は数えない"
# 古い ack（covers=1）を後から追記しても received は max のまま → pending=0 を維持
printf '%s\n' '{"ts":"2026-07-02T12:12:00+00:00","type":"report_received","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"},"covers_count":1,"covers_last_ts":"2026-07-02T12:01:00+00:00"}' >> "$_TMP_DIR/acked/oe-events.jsonl"
AIN3="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/acked" bash "$OE_ACTIVITY" --inbox)"
ck "古い ack 追記でも pending=0（max・巻き戻りなし）" "0" "$(printf '%s' "$(row_of "$AIN3" "ACK-R3-SAMESEC")" | awk '{print $3}')"
# ack 後の新着 → pending=1 に戻る。kick（%59→%66）は自分宛てでないので inbox/pending に影響しない
printf '%s\n' '{"ts":"2026-07-02T12:20:00+00:00","type":"message_sent","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"},"preview":"ACK-KICK","delivery_signal":"none"}' >> "$_TMP_DIR/acked/oe-events.jsonl"
printf '%s\n' '{"ts":"2026-07-02T12:21:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"ACK-R4-NEW","delivery_signal":"none"}' >> "$_TMP_DIR/acked/oe-events.jsonl"
AIN4="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/acked" bash "$OE_ACTIVITY" --inbox)"
a66n="$(row_of "$AIN4" "ACK-R4-NEW")"
ck "新着後 pending=1（kick は数えない）" "1" "$(printf '%s' "$a66n" | awk '{print $3}')"
ck "trips=4（report のみ・kick 除外）"   "4" "$(printf '%s' "$a66n" | awk '{print $2}')"

echo "[20] timeline: 受領印(ack)行が interleave（turn=- / dir=ack / covers 表示）"
ATL="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/acked" bash "$OE_ACTIVITY" --timeline)"
ack_row="$(row_of "$ATL" "covers=2")"
ck  "ack 行 turn=-"   "-"   "$(printf '%s' "$ack_row" | awk '{print $1}')"
ck  "ack 行 dir=ack"  "ack" "$(printf '%s' "$ack_row" | awk '{print $3}')"
ckc "ack 行 frontier 表示" "$ack_row" "2026-07-02T12:05:00+00:00"
ckc "ack 行 受領印 preview" "$ack_row" "受領印"
# message 行の turn 連番は ack 行に影響されない
ck "R1 turn=1" "1" "$(printf '%s' "$(row_of "$ATL" "ACK-R1")" | awk '{print $1}')"
ck "R4 turn=5" "5" "$(printf '%s' "$(row_of "$ATL" "ACK-R4-NEW")" | awk '{print $1}')"

echo "[21] 回帰: report_received が混在しても overview の列構成・既存投影は不変"
AOV="$(env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" OE_EVENT_DIR="$_TMP_DIR/acked" bash "$OE_ACTIVITY")"
ov66="$(row_of "$AOV" "ACK-R4-NEW")"
ck "overview に PENDING ヘッダは無い" "0" "$(printf '%s\n' "$AOV" | sed -n '2p' | grep -cF PENDING || true)"
ck  "overview trips は kick 込み 5"    "5" "$(printf '%s' "$ov66" | awk '{print $2}')"
ckc "overview 最新 preview"            "$ov66" "ACK-R4-NEW"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
