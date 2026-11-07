#!/usr/bin/env bash
# shellcheck disable=SC2031  # lib() が lib を読む subshell は OE_LEASE_DIR などの export 済みの値を変えない
set -euo pipefail

# test_target_resolve.sh — #577 PR-3（送る側）の検証
#
# 見るもの:
#   (A) oe-send <lease_id>: lease から宛先を引き、ペインのフォアグラウンドのプロセスが binding なら送る。
#       活動ログの to に lease を残す
#   (B) oe-send <ラベル>: lease の記録を registry より先に引く。lease で引けなければ registry に落とす（Q77）。
#       binding の無い lease・終わった lease は候補にしない。生きた候補が2つなら決めない
#   (C) 本人を確かめられないとき（フォアグラウンドのプロセスが違う・heartbeat の候補が無い）は送らずに 5。
#       閉じた lease は 1（宛先が無い）
#   (D) oe-send --to-parent: 親の lease へ送る。統括が交代して lease が進んでも、後継のペインへ届く。
#       OE_LEASE_ID が無い子・親が空の子は PARENT_TMUX_PANE に落とす
#   (E) oe-jump: lease のラベルで飛ぶ。本人を確かめられなければ飛ばない
#   (F) oe-select: 選んだペインに lease があれば、lease_id で oe-send に渡す
#   (G) 本物の ~/.claude/state/ と本物の tmux・ps・ペインに届く経路が無い
#
# ps・kill と、lib/tmux-pane-identity.sh が呼ぶ tmux は偽物（tests/fixtures/fake-proc.sh）。
# 送る側の tmux（send-keys など）も PATH の先頭の偽物で、呼ばれた引数を記録するだけである。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$PROJECT_DIR/bin"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
REAL_HOME="${HOME:-}"
export HOME="$_TMP_DIR/home"; mkdir -p "$HOME"
START_MARK="$_TMP_DIR/.start-mark"; : > "$START_MARK"
unset CLAUDE_PID CLAUDE_CODE_SESSION_ID OE_LEASE_ID OE_GENERATION PARENT_TMUX_PANE 2>/dev/null || true

export OE_LEASE_DIR="$_TMP_DIR/lease" OE_DELEGATE_STATE_DIR="$_TMP_DIR/registry" OE_HEARTBEAT_DIR="$_TMP_DIR/heartbeat"
export OE_EVENT_DIR="$_TMP_DIR/events" OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue" OE_JUMP_STATE_DIR="$_TMP_DIR/jump"
export TMUX="/tmp/fake-tmux,4242,0" TMUX_PANE="%1" OE_LEASE_LOCK_RETRY=3
export OE_SEND_FINALIZE=0 OE_SEND_ENTER_DELAY=0
mkdir -p "$OE_LEASE_DIR" "$OE_DELEGATE_STATE_DIR" "$OE_HEARTBEAT_DIR" "$OE_EVENT_DIR" "$OE_PANE_ISSUE_DIR"
EVENTS="$OE_EVENT_DIR/oe-events.jsonl"
WS="$_TMP_DIR/ws"; mkdir -p "$WS"

# shellcheck source=fixtures/fake-proc.sh
. "$SCRIPT_DIR/fixtures/fake-proc.sh"
fake_proc_setup "$_TMP_DIR/fakeproc"
S1='Sat Nov  7 09:00:00 2026'; S2='Sat Nov  7 09:10:00 2026'; S3='Sat Nov  7 09:20:00 2026'; S4='Sat Nov  7 09:30:00 2026'
reset_proc() {
  : > "$FAKE_PROC_DIR/ps.table"; : > "$FAKE_PROC_DIR/panes"
  fake_proc_add 901 "$S1" claude ttys001 901
  fake_proc_add 902 "$S2" claude ttys002 902
  fake_proc_add 903 "$S3" claude ttys003 903
  fake_proc_add 904 "$S4" claude ttys004 904
  for n in 1 2 3 4; do fake_pane_add "%$n" "/dev/ttys00$n"; done
}
reset_proc

STUB="$_TMP_DIR/stub"; mkdir -p "$STUB"
SENT="$_TMP_DIR/sent.log"; : > "$SENT"
cat > "$STUB/tmux" <<EOF
#!/usr/bin/env bash
case "\${1:-}" in
  list-panes)
    if [[ "\$*" == *'#{pid}'* ]]; then printf '%%1 4242\n%%2 4242\n%%3 4242\n%%4 4242\n'
    else printf '%%1\n%%2\n%%3\n%%4\n'; fi; exit 0 ;;
  send-keys) printf '%s\n' "\$*" >> "$SENT"; exit 0 ;;
  display-message)
    if [[ "\$*" == *'#{session_id}'* ]]; then printf '\$0 @0\n'; else printf '0\n'; fi; exit 0 ;;
  select-pane|select-window|switch-client) printf 'focus %s\n' "\$*" >> "$SENT"; exit 0 ;;
esac
exit 0
EOF
chmod +x "$STUB/tmux"
export PATH="$STUB:$PATH"

PASS=0; FAIL=0
ck()  { if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }

lib() { ( set +e
  # shellcheck source=../lib/lease.sh
  . "$PROJECT_DIR/lib/lease.sh"; "$@" ); }
NOW="$(date +%s)"
beat() { jq -cn --arg p "$2" --argjson t "$NOW" '{ts:$t, context_pct:10, pane:$p, server_pid:"4242"}' > "$OE_HEARTBEAT_DIR/$1.json"; }
# mk_lease <kind> <label> <pid> <started> <session_id> [parent] — binding と session_id を持つ lease を作る
mk_lease() {
  local id; id="$(lib oe_lease_create "$1" "$2" "$WS" "${6:-}" 1)"
  lib oe_lease_claim "$id" 0 "$3" "$4" claude "$5"; printf '%s' "$id"; }
sent_to() { awk '{for (i=1;i<=NF;i++) if ($i=="-t") {print $(i+1); exit}}' <(grep -- '-l' "$SENT" | tail -1); }
# 送る側は統括（自分の lease は SUP）。ラベルは自分の lease を親に持つ子だけから引く。
send() { : > "$SENT"; set +e; OUT="$(OE_LEASE_ID="$SUP" bash "$BIN/oe-send" "$@" 2>&1)"; RC=$?; set -e; }

SUP="$(mk_lease supervisor cockpit 901 "$S1" sid-sup)"; beat sid-sup %1
C2="$(mk_lease delegation '#900' 902 "$S2" sid-c2 "$SUP")"; beat sid-c2 %2

echo "=== (A) lease_id で送る ==="
send "$C2" "hello"
ck  "0 で終わる" "0" "$RC"
ck  "lease のペインへ送る" "%2" "$(sent_to)"
ckc "lease を名乗る" "$OUT" "lease ${C2} generation 1"
ck  "活動ログの to に lease を残す" "${C2}:1" "$(jq -r 'select(.type=="message_sent") | "\(.to.lease_id):\(.to.generation)"' "$EVENTS" | tail -1)"

echo "=== (B) ラベルで送る ==="
# registry と pane-issue は古いペイン（%3）を指しているが、lease の記録が先に効く
printf '{"name":"#900"}\n' > "$OE_PANE_ISSUE_DIR/4242__3"
send '#900' "hi"
ck  "(1) lease のペインへ送る" "%2" "$(sent_to)"
rm -f "$OE_PANE_ISSUE_DIR/4242__3"
printf '{"name":"#701"}\n' > "$OE_PANE_ISSUE_DIR/4242__3"
send '#701' "hi"
ck  "(2) lease で引けなければ古い引き方で送る" "%3" "$(sent_to)"
U="$(lib oe_lease_create delegation '#702' "$WS" "$SUP" 1)"
printf '{"name":"#702"}\n' > "$OE_PANE_ISSUE_DIR/4242__3"
send '#702' "hi"
ck  "(3) binding の無い lease しか無ければ古い引き方で送る" "%3" "$(sent_to)"
ckc "(3) そう言う" "$OUT" "binding が無い（${U}"
D="$(mk_lease delegation '#703' 904 "$S4" sid-d "$SUP")"; beat sid-d %4
fake_proc_del 904
L3="$(mk_lease delegation '#703' 903 "$S3" sid-l3 "$SUP")"; beat sid-l3 %3
send '#703' "hi"
ck  "(4) 終わった lease は候補にせず、生きている方へ送る" "%3" "$(sent_to)"
ckc "(4) 生きている方の lease を名乗る" "$OUT" "lease ${L3}"
reset_proc
send '#703' "hi"
ck  "(5) 生きた候補が2つなら決めない（1）" "1" "$RC"
ckc "(5) そう言う" "$OUT" "1つに決まりません"
ck  "(5) 送らない" "0" "$(grep -c -- '-l' "$SENT" || true)"
lib oe_lease_close "$D" "$(lib oe_lease_epoch "$D")" >/dev/null || true
OTHER="$(mk_lease supervisor other 904 "$S4" sid-other)"
O6="$(mk_lease delegation '#706' 903 "$S3" sid-o6 "$OTHER")"; beat sid-o6 %3
send '#706' "hi"
ck  "(6) 別の統括の子のラベルは lease から引かない（registry にも無いので 1）" "1" "$RC"
ck  "(6) 別の統括の子へ送らない" "0" "$(grep -c -- '-l' "$SENT" || true)"
: > "$SENT"; set +e; OUT="$(OE_LEASE_ID="$OTHER" bash "$BIN/oe-send" '#706' "hi" 2>&1)"; RC=$?; set -e
ck  "(6) その統括からは引ける" "%3" "$(sent_to)"
lib oe_lease_close "$O6" "$(lib oe_lease_epoch "$O6")" >/dev/null || true
lib oe_lease_close "$OTHER" "$(lib oe_lease_epoch "$OTHER")" >/dev/null || true

BS="$(mk_lease delegation 'a\b' 903 "$S3" sid-bs "$SUP")"; beat sid-bs %3
send 'a\b' "hi"
ck  "(7) バックスラッシュを含むラベルも lease から引く（Copilot の指摘）" "%3" "$(sent_to)"
ckc "(7) lease を名乗る" "$OUT" "lease ${BS}"
lib oe_lease_close "$BS" "$(lib oe_lease_epoch "$BS")" >/dev/null || true

echo "=== (C) 本人を確かめられなければ送らない ==="
fake_proc_del 902; fake_proc_add 950 'Sat Nov  7 12:00:00 2026' claude ttys002 950
send "$C2" "hi"
ck  "(1) フォアグラウンドのプロセスが違えば 5" "5" "$RC"
ckc "(1) 理由を言う" "$OUT" "binding（pid と開始時刻）と一致しません"
ckc "(1) 逃げ道を言う" "$OUT" "oe-send %N"
ck  "(1) 送らない" "0" "$(grep -c -- '-l' "$SENT" || true)"
reset_proc
mv "$OE_HEARTBEAT_DIR/sid-c2.json" "$_TMP_DIR/away.json"
send "$C2" "hi"
ck  "(2) heartbeat の候補が無ければ 5" "5" "$RC"
mv "$_TMP_DIR/away.json" "$OE_HEARTBEAT_DIR/sid-c2.json"
X="$(mk_lease delegation '#704' 903 "$S3" sid-x)"; lib oe_lease_close "$X" "$(lib oe_lease_epoch "$X")" >/dev/null || true
send "$X" "hi"
ck  "(3) 閉じた lease は 1" "1" "$RC"

echo "=== (D) --to-parent ==="
send --to-parent "report"
ck  "(0) 親が分からなければ 1" "1" "$RC"
: > "$SENT"; set +e; OUT="$(OE_LEASE_ID="$C2" OE_GENERATION=1 TMUX_PANE=%2 bash "$BIN/oe-send" --to-parent "report" 2>&1)"; RC=$?; set -e
ck  "(1) 親の lease のペインへ送る" "%1" "$(sent_to)"
ck  "(1) 活動ログの from と to に lease を残す" "${C2}:1>${SUP}:1" "$(jq -r 'select(.type=="message_sent") | "\(.from.lease_id):\(.from.generation)>\(.to.lease_id):\(.to.generation)"' "$EVENTS" | tail -1)"
# 統括が交代した: lease を進め、後継（pid 903・%3）が持ち主になる
lib oe_lease_advance "$SUP" "$(lib oe_lease_epoch "$SUP")" planned 903 "$S3" claude >/dev/null
lib oe_lease_register_session "$SUP" sid-sup2 903 "$S3"; beat sid-sup2 %3
: > "$SENT"; set +e; OUT="$(OE_LEASE_ID="$C2" OE_GENERATION=1 TMUX_PANE=%2 bash "$BIN/oe-send" --to-parent "report" 2>&1)"; RC=$?; set -e
ck  "(2) 交代のあとは後継のペインへ送る" "%3" "$(sent_to)"
ckc "(2) 進んだ generation を名乗る" "$OUT" "generation 2"
: > "$SENT"; set +e; OUT="$(PARENT_TMUX_PANE=%4 TMUX_PANE=%2 bash "$BIN/oe-send" --to-parent "report" 2>&1)"; RC=$?; set -e
ck  "(3) OE_LEASE_ID が無い子は PARENT_TMUX_PANE へ送る" "%4" "$(sent_to)"
ckc "(3) そう言う" "$OUT" "OE_LEASE_ID が無い子なので PARENT_TMUX_PANE"
NP="$(mk_lease delegation '#705' 904 "$S4" sid-np)"
: > "$SENT"; set +e; OUT="$(OE_LEASE_ID="$NP" OE_GENERATION=1 PARENT_TMUX_PANE=%1 TMUX_PANE=%4 bash "$BIN/oe-send" --to-parent "report" 2>&1)"; RC=$?; set -e
ck  "(4) 自分の lease に親が無ければ PARENT_TMUX_PANE へ送る" "%1" "$(sent_to)"
ckc "(4) そう言う" "$OUT" "親の lease が書かれていない"
set +e; OUT="$(bash "$BIN/oe-send" --to-parent 2>&1)"; RC=$?; set -e
ck  "(5) 送る文が無ければ 2（呼び方の誤り）" "2" "$RC"
: > "$SENT"; set +e; OUT="$(OE_LEASE_ID=00000000000000000000000000 PARENT_TMUX_PANE=%1 TMUX_PANE=%2 bash "$BIN/oe-send" --to-parent "report" 2>&1)"; RC=$?; set -e
ck  "(6) 自分の lease の記録を読めなければ PARENT_TMUX_PANE に落とさず 2（Copilot の指摘）" "2" "$RC"
ck  "(6) 送らない" "0" "$(grep -c -- '-l' "$SENT" || true)"
ckc "(6) そう言う" "$OUT" "記録を読めないので、送りません"

echo "=== (E) oe-jump ==="
: > "$SENT"; set +e; OUT="$(OE_LEASE_ID="$SUP" bash "$BIN/oe-jump" '#900' 2>&1)"; RC=$?; set -e
ck  "(1) lease のペインへ飛ぶ" "0" "$RC"
ckc "(1) select-pane は lease のペイン" "$(cat "$SENT")" "select-pane -t %2"
fake_proc_del 902; fake_proc_add 950 'Sat Nov  7 12:00:00 2026' claude ttys002 950
# lease_id で指すと、プロセスが替わったペインには飛ばない（ラベルで指すと、プロセスが終わった lease は
# 候補にならず、古い引き方に落ちる・(B)(4)）。
: > "$SENT"; set +e; OUT="$(bash "$BIN/oe-jump" "$C2" 2>&1)"; RC=$?; set -e
ck  "(2) 本人を確かめられなければ 5" "5" "$RC"
ck  "(2) 飛ばない" "0" "$(grep -c 'select-pane' "$SENT" || true)"
reset_proc

echo "=== (F) oe-select ==="
SB="$_TMP_DIR/selbin"; mkdir -p "$SB"
cp "$BIN/oe-select" "$SB/oe-select"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" > "%s"\n' "$_TMP_DIR/select-args" > "$SB/oe-send"
chmod +x "$SB/oe-select" "$SB/oe-send"
ln -s "$PROJECT_DIR/lib" "$_TMP_DIR/lib"
printf '#!/usr/bin/env bash\ngrep -m1 -- "^%%2 "\n' > "$STUB/fzf"; chmod +x "$STUB/fzf"
bash "$SB/oe-select" "msg" >/dev/null 2>&1 || true
ck  "選んだペインに lease があれば lease_id で送る" "-- ${C2} msg" "$(cat "$_TMP_DIR/select-args" 2>/dev/null)"
printf '#!/usr/bin/env bash\ngrep -m1 -- "^%%4 "\n' > "$STUB/fzf"
fake_proc_del 904
bash "$SB/oe-select" "msg" >/dev/null 2>&1 || true
ck  "lease が無いペインはペイン番号で送る" "-- %4 msg" "$(cat "$_TMP_DIR/select-args" 2>/dev/null)"
reset_proc

echo "=== (G) 本物に届く経路が無い ==="
if [ -n "$REAL_HOME" ]; then
  ck "本物の lease の置き場は、このテストで書き換わっていない" "0" "$(find "$REAL_HOME/.claude/state/oe-lease" -newer "$START_MARK" 2>/dev/null | grep -c . || true)"
fi
ck "送った文は偽の tmux にだけ届いた（記録がある）" "1" "$([ -s "$SENT" ] || [ -s "$_TMP_DIR/select-args" ] && echo 1 || echo 0)"

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
