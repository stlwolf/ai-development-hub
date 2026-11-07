#!/usr/bin/env bash
# shellcheck disable=SC2031  # lib() が lib を読む subshell は OE_LEASE_DIR などの export 済みの値を変えない
set -euo pipefail

# test_lease_handoff.sh — #577 PR-4（統括の lease）の検証
#
# 見るもの:
#   (A) take: 前任に lease が無ければ前任のプロセスを binding にして作り（番号は board の代目に合わせる）、
#       generation を進め、自分の session_id を登録し、前任の子の lease の親が空なら埋める。2回目は飛ばす
#   (B) take: 自分のプロセスが分からない・前任のペインのプロセスが claude でない・前任が委譲の lease に
#       座っている、のどれでも lease も board も動かさない
#   (C) take: 前任に lease があれば作らずに進める。親がもう書いてある子は変えない
#   (D) M1: 統括のプロセスが終わって新しいプロセスが同じ lease に戻ったとき、書き換わるのは統括の lease の
#       記録だけで、子の lease の記録は1つも書き換わらない
#   (E) prepare: 機械の節に lease の記録の表示が出て、ペインの pid の行は出ない
#   (F) oe-register root: 統括の lease ができる前に起こした子の lease の親を埋める
#   (G) oe-vitals: 統括の lease で判定する（健全・プロセスが無い・lease が決まらないときは board で判定）
#
# ps・tmux・kill は偽物（tests/fixtures/fake-proc.sh）。state の置き場と HOME はすべて一時ディレクトリ。
# 外部の verb（oe-register・oe-selfcheck）は OE_HANDOFF_* のノブで偽物に差し替える。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$PROJECT_DIR/bin"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
REAL_HOME="${HOME:-}"
export HOME="$_TMP_DIR/home"; mkdir -p "$HOME"
START_MARK="$_TMP_DIR/.start-mark"; : > "$START_MARK"
unset CLAUDE_PID CLAUDE_CODE_SESSION_ID OE_LEASE_ID OE_GENERATION PARENT_TMUX_PANE OE_VITALS_LEASE_ID 2>/dev/null || true

export OE_LEASE_DIR="$_TMP_DIR/lease" OE_DELEGATE_STATE_DIR="$_TMP_DIR/registry" OE_HEARTBEAT_DIR="$_TMP_DIR/heartbeat"
export OE_EVENT_DIR="$_TMP_DIR/events" OE_TRANSCRIPT_DIR="$_TMP_DIR/transcripts" OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
export OE_HS_SERVER_PID=4242 TMUX="/tmp/fake-tmux,4242,0" OE_LEASE_LOCK_RETRY=3
mkdir -p "$OE_DELEGATE_STATE_DIR" "$OE_HEARTBEAT_DIR" "$OE_EVENT_DIR" "$OE_TRANSCRIPT_DIR" "$OE_PANE_ISSUE_DIR"
WS="$_TMP_DIR/ws"; mkdir -p "$WS/.oe"
git -C "$WS" init -q 2>/dev/null || true
git -C "$WS" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null || true
EVENTS="$OE_EVENT_DIR/oe-events.jsonl"

# shellcheck source=fixtures/fake-proc.sh
. "$SCRIPT_DIR/fixtures/fake-proc.sh"
fake_proc_setup "$_TMP_DIR/fakeproc"
S910='Sat Nov  7 09:00:00 2026'; S911='Sat Nov  7 10:00:00 2026'; S912='Sat Nov  7 09:30:00 2026'; S913='Sat Nov  7 11:00:00 2026'
reset_proc() {
  : > "$FAKE_PROC_DIR/ps.table"; : > "$FAKE_PROC_DIR/panes"
  fake_proc_add 910 "$S910" claude ttys010 910
  fake_proc_add 911 "$S911" claude ttys011 911
  fake_proc_add 912 "$S912" claude ttys012 912
  fake_pane_add %10 /dev/ttys010; fake_pane_add %11 /dev/ttys011; fake_pane_add %12 /dev/ttys012
}
reset_proc

# oe-handoff take の外部の verb と、PATH の tmux（oe-vitals の liveness と oe-register の生存確かめ）
STUB="$_TMP_DIR/stub"; mkdir -p "$STUB"
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/register"
printf '#!/usr/bin/env bash\nprintf %s\\\\n %s\nexit 1\n' "'%s'" "'[{\"check\":\"watchdog-freshness\",\"verdict\":\"ok\",\"detail\":\"x\"}]'" > "$STUB/selfcheck"
cat > "$STUB/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  list-panes)
    if [[ "$*" == *'#{pane_tty}'* ]]; then printf '%%10 /dev/ttys010\n%%11 /dev/ttys011\n%%12 /dev/ttys012\n'
    elif [[ "$*" == *'#{pid}'* ]]; then printf '%%10 4242\n%%11 4242\n%%12 4242\n'
    else printf '%%10\n%%11\n%%12\n'; fi
    exit 0 ;;
  display-message) printf '4242\n'; exit 0 ;;
esac
exit 0
EOF
chmod +x "$STUB/register" "$STUB/selfcheck" "$STUB/tmux"
export PATH="$STUB:$PATH" OE_HANDOFF_REGISTER="$STUB/register" OE_HANDOFF_SELFCHECK="$STUB/selfcheck" OE_HANDOFF_TMUX="$STUB/tmux"

PASS=0; FAIL=0
ck()  { if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
nck() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

BOARD="$WS/.oe/START-HERE-board.md"; HANDOFF="$WS/.oe/handoff.md"
mk_board() {
  # shellcheck disable=SC2016  # backtick は board の Markdown 記法
  printf '# START HERE\n\n鮮度: 2026-11-01 / 現統括: pane `%%10`（統括**14代目**・2026-11-01 着任）/ succession: **完了**\n' > "$BOARD"
}
mk_handoff() { printf '%s\n' '<!-- oe-handoff:machine:begin -->' '## 観測できる状態' '<!-- oe-handoff:machine:end -->' '人の節' > "$HANDOFF"; }
reg_child() { # <pane> <parent_pane>
  local key; key="$(printf '%s' "4242_$1" | tr -c 'A-Za-z0-9' '_')"
  jq -cn --arg p "$1" --arg par "$2" --arg ws "$WS" '{pane:$p, label:"#900", workspace:$ws, parent_pane:$par, role:"child"}' > "$OE_DELEGATE_STATE_DIR/${key}.json"
}
lib() { ( set +e
  # shellcheck source=../lib/lease.sh
  . "$PROJECT_DIR/lib/lease.sh"; "$@" ); }
child_lease() { # 子（%12・pid 912）の委譲の lease を親なしで作る
  local id; id="$(lib oe_lease_create delegation "#900" "$WS" "" 1)"; lib oe_lease_bind "$id" 0 912 "$S912" claude; printf '%s' "$id"; }
take() { CLAUDE_PID="${1:-911}" CLAUDE_CODE_SESSION_ID=sid-succ TMUX_PANE=%11 bash "$BIN/oe-handoff" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1; }
n_leases() { find "$OE_LEASE_DIR" -name '*.json' 2>/dev/null | grep -c . || true; }
sup_of() { for f in "$OE_LEASE_DIR"/*.json; do jq -r 'select(.kind=="supervisor") | .lease_id' "$f"; done | head -1; }

echo "=== (A) take: 前任に lease が無ければ作って進める ==="
mk_board; mk_handoff; reg_child %12 %10
CHILD="$(child_lease)"
out="$(take)"; rc=$?
ck  "0 で終わる" "0" "$rc"
SUP="$(sup_of)"
ck  "統括の lease ができた" "26" "${#SUP}"
ckc "作ったと言う" "$out" "前任の lease が無かったので、前任のプロセス（pid 910）を binding にして作った"
ck  "番号は board の代目に合わせる（前任 14・後継 15）" "15" "$(jq -r '.current_generation' "$OE_LEASE_DIR/$SUP.json")"
ck  "前の generation は退任" "retired" "$(jq -r '.generations[] | select(.generation==14) | .state' "$OE_LEASE_DIR/$SUP.json")"
ck  "前の generation の binding は前任" "910" "$(jq -r '.generations[] | select(.generation==14) | .binding.pid' "$OE_LEASE_DIR/$SUP.json")"
ck  "いまの generation の binding は自分" "911" "$(jq -r '.generations[] | select(.generation==15) | .binding.pid' "$OE_LEASE_DIR/$SUP.json")"
ck  "自分の session_id を登録した" "sid-succ" "$(jq -r '.generations[] | select(.generation==15) | .session_ids[0]' "$OE_LEASE_DIR/$SUP.json")"
ck  "子の lease の親を埋めた" "$SUP" "$(jq -r '.parent_lease_id' "$OE_LEASE_DIR/$CHILD.json")"
ckc "埋めたと言う" "$out" "子 %12 ${CHILD} の lease の親を ${SUP} にした"
ckc "lease の書き込みが board より先" "$(printf '%s' "$out" | grep -nE 'generation を 15 に進めた|board の宣言を自分' | head -1)" "generation を 15 に進めた"
# shellcheck disable=SC2016  # backtick は board の Markdown 記法
ck  "board も張り替わった" "1" "$(grep -c '現統括: pane `%11`' "$BOARD")"
ck  "lease_bound（adopt）が残る" "adopt" "$(jq -r --arg l "$SUP" 'select(.type=="lease_bound" and .lease_id==$l) | .bind_reason' "$EVENTS" | tail -1)"
n1="$(n_leases)"; e1="$(jq -r '.epoch' "$OE_LEASE_DIR/$SUP.json")"
# lease を進めたあと board を書く前に止まった形（board はまだ前任）。もう一度走らせると lease は飛ばして board を直す。
mk_board
out2="$(take)"
ckc "2回目は lease を飛ばす" "$out2" "のいまの generation は既に自分である（進めていない）"
# shellcheck disable=SC2016  # backtick は board の Markdown 記法
ck  "2回目で board を直す" "1" "$(grep -c '現統括: pane `%11`' "$BOARD")"
ck  "2回目で lease は増えない" "$n1" "$(n_leases)"
ck  "2回目で epoch は動かない" "$e1" "$(jq -r '.epoch' "$OE_LEASE_DIR/$SUP.json")"
for f in "$OE_LEASE_DIR"/*.json; do ck "記録が検査を通る（$(basename "$f" .json | cut -c1-8)）" "0" "$(bash "$PROJECT_DIR/scripts/validate-lease.sh" "$f" >/dev/null 2>&1; echo $?)"; done

echo "=== (B) take: 前提を満たさないときは lease も board も動かさない ==="
rm -rf "$OE_LEASE_DIR"; mkdir -p "$OE_LEASE_DIR"; mk_board; before="$(cat "$BOARD")"
set +e; out="$(CLAUDE_CODE_SESSION_ID=sid-succ TMUX_PANE=%11 bash "$BIN/oe-handoff" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1)"; rc=$?; set -e
ck  "(1) CLAUDE_PID が無ければ 1" "1" "$rc"
ckc "(1) 理由を言う" "$out" "CLAUDE_PID がありません"
ck  "(1) lease を作らない" "0" "$(n_leases)"
ck  "(1) board を変えない" "$before" "$(cat "$BOARD")"
fake_proc_del 910; fake_proc_add 910 "$S910" -bash ttys010 910
set +e; out="$(take)"; rc=$?; set -e
ck  "(2) 前任のペインのプロセスが claude でなければ 1" "1" "$rc"
ckc "(2) 理由を言う" "$out" "フォアグラウンドのプロセスが claude ではありません（-bash）"
ck  "(2) lease を作らない" "0" "$(n_leases)"
ck  "(2) board を変えない" "$before" "$(cat "$BOARD")"
reset_proc
D="$(lib oe_lease_create delegation "#5" "$WS" "" 1)"; lib oe_lease_bind "$D" 0 910 "$S910" claude
set +e; out="$(take)"; rc=$?; set -e
ck  "(3) 前任が委譲の lease に座っていれば 1" "1" "$rc"
ckc "(3) 理由を言う" "$out" "統括でなく delegation の lease"
ck  "(3) 委譲の lease を進めない" "1" "$(jq -r '.current_generation' "$OE_LEASE_DIR/$D.json")"
ck  "(3) board を変えない" "$before" "$(cat "$BOARD")"

echo "=== (C) take: 前任に lease があれば作らずに進める・親がある子は変えない ==="
rm -rf "$OE_LEASE_DIR"; mkdir -p "$OE_LEASE_DIR"; mk_board
P="$(lib oe_lease_create supervisor cockpit "$WS" "" 1)"; lib oe_lease_bind "$P" 0 910 "$S910" claude
OTHER="$(lib oe_lease_create supervisor other "$WS" "" 1)"
CHILD="$(child_lease)"; lib oe_lease_set_parent "$CHILD" "$(lib oe_lease_epoch "$CHILD")" "$OTHER"
out="$(take)"
ck  "lease を作らない" "3" "$(n_leases)"
ck  "前任の lease を進めた" "2" "$(jq -r '.current_generation' "$OE_LEASE_DIR/$P.json")"
ck  "親がある子は変えない" "$OTHER" "$(jq -r '.parent_lease_id' "$OE_LEASE_DIR/$CHILD.json")"
nck "作ったとは言わない" "$out" "前任の lease が無かったので"

echo "=== (D) M1: 統括のプロセスが新しいプロセスで戻っても、子の lease の記録は書き換わらない ==="
# 統括の lease に記録に無い session_id で戻るのは owner の確かめが要る（--owner-confirmed・PR-1 の決まり）。
rm -rf "$OE_LEASE_DIR"; mkdir -p "$OE_LEASE_DIR"
SUP="$(lib oe_lease_create supervisor cockpit "$WS" "" 1)"; lib oe_lease_bind "$SUP" 0 911 "$S911" claude
C1="$(lib oe_lease_create delegation "#1" "$WS" "$SUP" 1)"; lib oe_lease_bind "$C1" 0 912 "$S912" claude
C2="$(lib oe_lease_create delegation "#2" "$WS" "$SUP" 1)"
snap() { for f in "$OE_LEASE_DIR"/*.json; do printf '%s %s\n' "$(basename "$f")" "$(shasum "$f" | cut -d' ' -f1)"; done; }
before="$(snap)"
fake_proc_del 911; fake_proc_add 913 "$S913" claude ttys011 913
out="$(CLAUDE_PID=913 CLAUDE_CODE_SESSION_ID=sid-resumed TMUX_PANE=%11 bash "$BIN/oe-lease" bind "$SUP" -w "$WS" --owner-confirmed 2>&1)" || true
after="$(snap)"
changed="$( (diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") || true) | { grep '^>' || true; } | cut -d' ' -f2 | sed 's/\.json$//' | tr '\n' ' ')"
ck  "書き換わったのは統括の lease だけ" "$SUP " "$changed"
ck  "binding は新しいプロセス" "913" "$(jq -r '.generations[0].binding.pid' "$OE_LEASE_DIR/$SUP.json")"
ck  "generation は進まない（resume は交代ではない）" "1" "$(jq -r '.current_generation' "$OE_LEASE_DIR/$SUP.json")"
ck  "子の親はそのまま" "$SUP" "$(jq -r '.parent_lease_id' "$OE_LEASE_DIR/$C1.json")"
ck  "binding の無い子もそのまま" "$SUP" "$(jq -r '.parent_lease_id' "$OE_LEASE_DIR/$C2.json")"
reset_proc

echo "=== (E) prepare: 機械の節に lease の記録の表示が出る ==="
rm -rf "$OE_LEASE_DIR"; mkdir -p "$OE_LEASE_DIR"
P="$(lib oe_lease_create supervisor cockpit "$WS" "" 7)"; lib oe_lease_bind "$P" 0 910 "$S910" claude
rm -f "$HANDOFF"
TMUX_PANE=%10 bash "$BIN/oe-handoff" prepare -w "$WS" --out "$HANDOFF" >/dev/null 2>&1 || true
m="$(sed -n '/oe-handoff:machine:begin/,/oe-handoff:machine:end/p' "$HANDOFF")"
ckc "lease_id と generation を出す" "$m" "- 前任の lease: \`${P}\`（generation \`7\`）"
ckc "binding を出す" "$m" "- 前任の binding: pid \`910\`"
ckc "表示だと書く" "$m" "この節は表示である"
nck "ペインの pid の行は出さない" "$m" "前任のペインの pid"
fake_proc_del 910
rm -f "$HANDOFF"
TMUX_PANE=%10 bash "$BIN/oe-handoff" prepare -w "$WS" --out "$HANDOFF" >/dev/null 2>&1 || true
ckc "プロセスを確かめられなければそう書く" "$(cat "$HANDOFF")" "- 前任の lease: ペインのフォアグラウンドのプロセスを確かめられなかった"
reset_proc

echo "=== (F) oe-register root: 統括の lease ができる前に起こした子の lease の親を埋める ==="
rm -rf "$OE_LEASE_DIR"; mkdir -p "$OE_LEASE_DIR"; rm -f "$OE_DELEGATE_STATE_DIR"/*.json
reg_child %12 %11
CHILD="$(child_lease)"
out="$(CLAUDE_PID=911 CLAUDE_CODE_SESSION_ID=sid-root TMUX_PANE=%11 bash "$BIN/oe-register" root --label cockpit -w "$WS" 2>&1)" || true
SUP="$(sup_of)"
ck  "統括の lease を作った" "26" "${#SUP}"
ck  "子の lease の親を埋めた" "$SUP" "$(jq -r '.parent_lease_id' "$OE_LEASE_DIR/$CHILD.json")"
ckc "埋めたと言う" "$out" "の lease の親を ${SUP} にしました"
out="$(CLAUDE_PID=911 CLAUDE_CODE_SESSION_ID=sid-root TMUX_PANE=%11 bash "$BIN/oe-register" root --label cockpit -w "$WS" 2>&1)" || true
ck  "もう一度打っても lease は増えない" "2" "$(n_leases)"

echo "=== (G) oe-vitals: 統括の lease で判定する ==="
NOW=2000000000
beat() { jq -cn --arg p "$2" --argjson t "$3" --argjson c "$4" '{ts:$t, context_pct:$c, pane:$p, server_pid:"4242"}' > "$OE_HEARTBEAT_DIR/$1.json"; }
rm -rf "$OE_LEASE_DIR" "$OE_HEARTBEAT_DIR"; mkdir -p "$OE_LEASE_DIR" "$OE_HEARTBEAT_DIR"
SUP="$(lib oe_lease_create supervisor cockpit "$WS" "" 1)"; lib oe_lease_claim "$SUP" 0 911 "$S911" claude sid-v
beat sid-v %11 $((NOW - 60)) 40
beat sid-old %10 $((NOW - 30)) 99
mk_board   # board はまだ前任（%10）を指している。lease が正本なので、こちらは見ない
vit() { OE_BOARD_FILE="$BOARD" OE_VITALS_NOW_EPOCH="$NOW" bash "$BIN/oe-vitals" 2>&1; }
out="$(vit)"
ckc "健全と判定する" "$out" "現統括 %11は健全"
ckc "lease の拍動を使う（ctx 40）" "$out" "ctx=40%"
nck "board のペインの拍動は使わない" "$out" "ctx=99%"
beat sid-v %11 $((NOW - 60)) 95
ckc "context の閾値を超えれば出す" "$(vit)" "context 肥大接近"
fake_proc_del 911
out="$(vit)"
ckc "binding のプロセスが無ければ death" "$out" "binding のプロセスが無い"
ckc "lease を名指す" "$out" "lease ${SUP} generation 1"
rm -f "$OE_HEARTBEAT_DIR/sid-v.json"
ckc "拍動が無くてもプロセスが無ければ death" "$(vit)" "death"
reset_proc; beat sid-v %11 $((NOW - 60)) 40
S2="$(lib oe_lease_create supervisor cockpit2 "$WS" "" 1)"; lib oe_lease_bind "$S2" 0 912 "$S912" claude
out="$(vit)"
ckc "lease が2つでも、生きているのが2つなら決めずに board で判定する" "$out" "1つに決まらない"
ckc "board のペイン（%10）の拍動で判定する" "$out" "sid-old"
out="$(OE_VITALS_LEASE_ID="$SUP" vit)"
ckc "OE_VITALS_LEASE_ID で指せる" "$out" "現統括 %11は健全"

echo "=== 本物に届く経路が無い ==="
if [ -n "$REAL_HOME" ]; then
  ck "本物の lease の置き場は、このテストで書き換わっていない" "0" "$(find "$REAL_HOME/.claude/state/oe-lease" -newer "$START_MARK" 2>/dev/null | grep -c . || true)"
fi

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
