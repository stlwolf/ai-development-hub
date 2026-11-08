#!/usr/bin/env bash
set -uo pipefail

# test_oe_recover.sh — bin/oe-recover（#355・統括が応答しないときの復帰）の検証
#
# plan のテスト T-1〜T-8・T-11〜T-13 を見る（T-9・T-10 は test_delegate_send.sh と test_oe_vitals.sh）。
#   T-1  落ち方 a: binding が自分なら張り替えず、2回打っても同じ結果
#   T-2  落ち方 b: 張り替え（rebinds）・board（復帰の註）・registry（自分と子）・event。子の lease は書き換えない
#   T-3  前の binding が生きている・分からないときは何も書かずに止まり、案内が3つに分かれる（H1 の3つの節）
#   T-4  張り替えのあと止まった状態から、別のプロセスで打ち直すと続きをやる
#   T-5  同じ lease の復帰が走っているときは止まる（復帰のロック）
#   T-6  復帰のあとの計画的な交代で、前の generation の binding が復帰した会話になる
#   T-7  退任した generation・workspace の不一致・--lease の owner の確かめ
#   T-8  hint は生きていない lease だけに resume のコマンドを出し、何も書かない
#   T-11 途中で binding がほかに移ると、それより後を書かずに止まる
#   T-12 tmux を起こし直した状態で、子が先・親があと・孫ありでも registry が lease と一致する
#   T-13 board が無いときは board だけ済んでいないにして、ほかは行う
#
# ps・tmux・kill・date は偽物に差し替える（OE_TPI_* と PATH の先頭）。HOME と state の置き場は一時ディレクトリ。
# 本物の ~/.claude/state/ と本物の tmux に届かないことを最後に確かめる（negative knowledge 01M5T897YCWY13GFTADD3136EC）。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERB="$PROJECT_DIR/bin/oe-recover"
VALIDATE="$PROJECT_DIR/scripts/validate-lease.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
START_MARK="$_TMP_DIR/.start-mark"; : > "$START_MARK"
REAL_HOME="${HOME:-}"
export HOME="$_TMP_DIR/home"; mkdir -p "$HOME"
unset TMUX_PANE PARENT_TMUX_PANE CLAUDE_PID CLAUDE_CODE_SESSION_ID OE_LEASE_ID OE_GENERATION OE_BOARD_FILE 2>/dev/null || true

# --- 偽の道具。足がかりの oe-tree も偽の bin に置き、~/bin を PATH から外す ---
FAKE="$_TMP_DIR/bin"; mkdir -p "$FAKE"
PS_TABLE="$_TMP_DIR/ps.table"   # pid|lstart|comm|tty|tpgid
PANES="$_TMP_DIR/panes"         # "%N /dev/ttysNNN"
CALLS="$_TMP_DIR/calls"; : > "$CALLS"
export PS_TABLE PANES CALLS
cat > "$FAKE/ps" <<'EOF'
#!/usr/bin/env bash
echo "fake-ps $*" >> "$CALLS"
[ -z "${FAKE_PS_FAIL:-}" ] || exit 2
mode=""; pid=""; tty=""
while [ $# -gt 0 ]; do
  case "$1" in -o) mode="$2"; shift 2 ;; -p) pid="$2"; shift 2 ;; -t) tty="$2"; shift 2 ;; *) shift ;; esac
done
if [ -n "$tty" ]; then awk -F '|' -v t="$tty" '$4==t {print $1" "$5}' "$PS_TABLE"; exit 0; fi
row="$(awk -F '|' -v p="$pid" '$1==p' "$PS_TABLE")"
[ -n "$row" ] || exit 1
case "$mode" in
  lstart=) printf '%s\n' "$(printf '%s' "$row" | cut -d'|' -f2)" ;;
  comm=)   printf '%s\n' "$(printf '%s' "$row" | cut -d'|' -f3)" ;;
  pid=)    printf '%s\n' "$pid" ;;
esac
EOF
cat > "$FAKE/tmux" <<'EOF'
#!/usr/bin/env bash
echo "fake-tmux $*" >> "$CALLS"
if [ "${1:-}" = "list-panes" ]; then
  # 書式に #{pid}（server の pid）があれば "%N 900" で、それ以外は "%N /dev/ttysNNN" で答える（registry の掃除と本人確認）。
  case "$*" in *'#{pid}'*) awk '{print $1" 900"}' "$PANES" ;; *) cat "$PANES" ;; esac
  exit 0
fi
if [ "${1:-}" = "display-message" ]; then echo 900; exit 0; fi
exit 0
EOF
cat > "$FAKE/kill" <<'EOF'
#!/usr/bin/env bash
echo "fake-kill $*" >> "$CALLS"
pid="${2:-}"
if awk -F '|' -v p="$pid" '$1==p {f=1} END {exit f?0:1}' "$PS_TABLE"; then exit 0; fi
echo "kill: ($pid) - No such process" >&2; exit 1
EOF
# 偽の date。FAKE_DATE_HOOK があれば、board の日付（+%Y-%m-%d）を作る呼び出しで1回だけ実行する
# （T-11: board を書いたあと、registry を書く前に binding をほかへ移す）。
cat > "$FAKE/date" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "+%Y-%m-%d" ] && [ -n "${FAKE_DATE_HOOK:-}" ] && [ ! -e "${FAKE_DATE_HOOK}.done" ]; then : > "${FAKE_DATE_HOOK}.done"; bash "$FAKE_DATE_HOOK"; fi
exec /bin/date "$@"
EOF
ln -s "$PROJECT_DIR/bin/oe-tree" "$FAKE/oe-tree"
chmod +x "$FAKE/ps" "$FAKE/tmux" "$FAKE/kill" "$FAKE/date"
PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v "^${REAL_HOME}/bin\$" | paste -sd: -)"
export PATH="$FAKE:$PATH"
export OE_TPI_PS="$FAKE/ps" OE_TPI_TMUX="$FAKE/tmux" OE_TPI_KILL="$FAKE/kill"
export OE_RECOVER_TREE="$PROJECT_DIR/bin/oe-tree"

PASS=0; FAIL=0
ck()  { if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { case "$2" in *"$3"*) echo "  PASS: $1"; PASS=$((PASS+1)) ;; *) echo "  FAIL: $1 (missing=[$3])"; FAIL=$((FAIL+1)) ;; esac; }
nck() { case "$2" in *"$3"*) echo "  FAIL: $1 (unexpected=[$3])"; FAIL=$((FAIL+1)) ;; *) echo "  PASS: $1"; PASS=$((PASS+1)) ;; esac; }

S1='Sun Nov  8 09:00:00 2026'; S2='Sun Nov  8 12:00:00 2026'; S3='Sun Nov  8 09:30:00 2026'; S4='Sun Nov  8 08:00:00 2026'
S5='Sun Nov  8 09:40:00 2026'; S6='Sun Nov  8 13:00:00 2026'
NOW="$(/bin/date +%s)"
export OE_HB_NOW_EPOCH="$NOW"

# 場面を作る。統括（前は pid 101 がペイン %1・いまは pid 201 がペイン %2 で resume した）・lease を持つ子（pid 301・%3）・
# 孫（pid 351・%5）・lease を持たない古い子（pid 401・%4・registry の親は %1）。tmux server の pid は 900。
setup() {
  local d="$_TMP_DIR/case-$1"
  rm -rf "$d"; mkdir -p "$d/ws/.oe" "$d/cws" "$d/gws"
  export OE_LEASE_DIR="$d/lease" OE_HEARTBEAT_DIR="$d/hb" OE_DELEGATE_STATE_DIR="$d/reg" OE_EVENT_DIR="$d/ev"
  mkdir -p "$OE_HEARTBEAT_DIR" "$OE_DELEGATE_STATE_DIR" "$OE_EVENT_DIR"
  WS="$d/ws"; BOARD="$WS/.oe/START-HERE.md"
  printf '%s\n' "# board" "- 現統括: \`%1\`（統括23代目・鮮度: 2026-11-07）" "本文" > "$BOARD"
  printf '%s\n' "101|$S1|claude|ttys001|101" "201|$S2|claude|ttys002|201" "301|$S3|claude|ttys003|301" \
    "351|$S5|claude|ttys005|351" "401|$S4|claude|ttys004|401" > "$PS_TABLE"
  printf '%s\n' "%1 /dev/ttys001" "%2 /dev/ttys002" "%3 /dev/ttys003" "%4 /dev/ttys004" "%5 /dev/ttys005" > "$PANES"
  (
    # shellcheck source=../lib/lease.sh
    . "$PROJECT_DIR/lib/lease.sh"
    export OE_LEASE_NOW_ISO="2026-11-08T00:00:00Z"
    SUP="$(oe_lease_create supervisor cockpit "$WS" "")"
    oe_lease_claim "$SUP" 0 101 "$S1" claude sid-sup
    CH="$(oe_lease_create delegation '#9 child' "$d/cws" "$SUP")"
    oe_lease_claim "$CH" 0 301 "$S3" claude sid-child
    GC="$(oe_lease_create delegation '#10 grand' "$d/gws" "$CH")"
    oe_lease_claim "$GC" 0 351 "$S5" claude sid-grand
    printf '%s %s %s\n' "$SUP" "$CH" "$GC" > "$d/ids"
  )
  read -r SUP CH GC < "$d/ids"
  mk_beat sid-sup %2 5 "$SUP" 1; mk_beat sid-child %3 5 "$CH" 1; mk_beat sid-grand %5 5 "$GC" 1
  # registry: 前の server（800）の行と、いまの server の古い子
  jq -cn '{pane:"%1", label:"cockpit", workspace:"/x", parent_pane:"", role:"child"}' > "$OE_DELEGATE_STATE_DIR/800__1.json"
  jq -cn '{pane:"%4", label:"#7 old", workspace:"/x", parent_pane:"%1", role:"child"}' > "$OE_DELEGATE_STATE_DIR/900__4.json"
  # 落ちていたあいだに子が送れなかった送信が2回（同じ brief）と、報告のファイル
  for t in 01 02; do
    jq -cn --arg ts "2026-11-08T10:${t}:00+00:00" --arg c "$CH" --arg s "$SUP" \
      '{ts:$ts, type:"delivery_held", from:{pane:"%3", role:"", label:"#9 child", lease_id:$c, generation:1},
        to:{pane:"", role:"", label:"", lease_id:$s, generation:1}, held_reason:"not_self", brief:"/ws/.oe/report-9.md", preview:"x"}' \
      >> "$OE_EVENT_DIR/oe-events.jsonl"
  done
  : > "$WS/.oe/report-9.md"
}
mk_beat() { # <sid> <pane> <age> <lease_id> <generation>
  jq -cn --argjson ts "$((NOW - $3))" --arg p "$2" --arg l "$4" --argjson g "$5" \
    '{ts:$ts, context_pct:10, pane:$p, server_pid:"900", lease_id:$l, generation:$g}' > "$OE_HEARTBEAT_DIR/$1.json"
}
kill_pid() { sed -i.bak "/^$1|/d" "$PS_TABLE"; rm -f "$PS_TABLE.bak"; }
as_sup() { env TMUX="/tmp/fake-sock,900,0" TMUX_PANE=%2 CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-sup "$@"; }
run() { OUT="$("$@" 2>&1)"; RC=$?; }
lease_pid() { jq -r '.current_generation as $g | .generations[] | select(.generation==$g) | .binding.pid' "$OE_LEASE_DIR/$1.json"; }
reg_parent() { jq -r '.parent_pane' "$OE_DELEGATE_STATE_DIR/900__${1#%}.json" 2>/dev/null || echo none; }
three_sections() { ckc "$1: いまの状況の節" "$OUT" "--- いまの状況 ---"; ckc "$1: 書いたもの・書かなかったものの節" "$OUT" "--- 書いたもの・書かなかったもの ---"; ckc "$1: 次にやることの節" "$OUT" "--- 次にやること ---"; }

echo "=== T-2 落ち方 b（ペインが変わる・前のプロセスは死んでいる）==="
setup b
kill_pid 101; sed -i.bak '/^%1 /d' "$PANES"; rm -f "$PANES.bak"
CH_BEFORE="$(cat "$OE_LEASE_DIR/$CH.json")"; GC_BEFORE="$(cat "$OE_LEASE_DIR/$GC.json")"
run as_sup "$VERB" -w "$WS" --board "$BOARD"
[ -z "${OE_TEST_DUMP:-}" ] || printf '%s\n' "$OUT"
ck "終了コードは 0" "0" "$RC"
three_sections "T-2"
ck "binding は自分（201）" "201" "$(lease_pid "$SUP")"
ck "前の binding を rebinds に残した" "1:101" "$(jq -r '.generations[0].rebinds | "\(length):\(.[0].pid)"' "$OE_LEASE_DIR/$SUP.json")"
ck "generation は進まない" "1:1" "$(jq -r '"\(.current_generation):\(.generations|length)"' "$OE_LEASE_DIR/$SUP.json")"
ck "lease の記録は検査を通る" "0" "$("$VALIDATE" "$OE_LEASE_DIR/$SUP.json" >/dev/null 2>&1; echo $?)"
ck "board は自分を指す" "%2" "$(bash -c ". '$PROJECT_DIR/lib/seat.sh'; oe_seat_resolve '$BOARD'")"
ckc "board に復帰の註" "$(cat "$BOARD")" "前のペイン \`%1\` は応答なし・復帰で張り替え"
ck "registry: 自分は root" "" "$(reg_parent %2)"
ck "registry: 子の親は自分" "%2" "$(reg_parent %3)"
ck "子の lease の記録は書き換わらない" "$CH_BEFORE" "$(cat "$OE_LEASE_DIR/$CH.json")"
ck "孫の lease の記録も書き換わらない" "$GC_BEFORE" "$(cat "$OE_LEASE_DIR/$GC.json")"
ckc "古い子の一覧" "$OUT" "古い子 #7 old（%4）"
ckc "古い子へ送るコマンド" "$OUT" "oe-send %4"
ckc "送れなかった送信を畳んで出す" "$OUT" "#9 child（lease ${CH}）: 2 回"
ckc "要照合と名乗る" "$OUT" "要照合"
ckc "時刻で絞った報告のファイル" "$OUT" "report-9.md"
ckc "検算: oe-tree の行が alive" "$OUT" "oe-tree --lease の自分の行は alive"
ev="$(grep '"supervisor_recovery"' "$OE_EVENT_DIR/oe-events.jsonl" | tail -1)"
ck "event: complete と前の binding" "true:101:supervisor" "$(printf '%s' "$ev" | jq -r '"\(.complete):\(.prev_binding.pid):\(.kind)"')"
ck "event: role は空・lease を持つ" ":${SUP}" "$(printf '%s' "$ev" | jq -r '"\(.from.role):\(.from.lease_id)"')"
ck "event: lease_bound の rebind も書く" "1" "$(grep -c '"bind_reason":"rebind"' "$OE_EVENT_DIR/oe-events.jsonl")"

echo "=== T-1 打ち直し（binding はもう自分）==="
BOARD_AFTER="$(cat "$BOARD")"
run as_sup "$VERB" -w "$WS" --board "$BOARD"
ck "終了コードは 0" "0" "$RC"
ckc "張り替えは要らないと言う" "$OUT" "いまの binding はもう自分です"
ck "rebinds は増えない" "1" "$(jq -r '.generations[0].rebinds | length' "$OE_LEASE_DIR/$SUP.json")"
ck "board は変わらない" "$BOARD_AFTER" "$(cat "$BOARD")"

echo "=== T-6 復帰のあとの計画的な交代 ==="
(
  . "$PROJECT_DIR/lib/lease.sh"
  printf '%s\n' "601|$S6|claude|ttys006|601" >> "$PS_TABLE"
  oe_lease_advance "$SUP" "$(oe_lease_epoch "$SUP")" planned 601 "$S6" claude >/dev/null
)
ck "前の generation の binding は復帰した会話（201）" "201:retired" "$(jq -r '.generations[0] | "\(.binding.pid):\(.state)"' "$OE_LEASE_DIR/$SUP.json")"

echo "=== T-3 前の binding が生きている ==="
setup alive
run as_sup "$VERB" -w "$WS" --board "$BOARD"
[ -z "${OE_TEST_DUMP:-}" ] || printf '%s\n' "$OUT"
ck "終了コードは 1" "1" "$RC"
three_sections "T-3 生きていてペインが分かる"
ckc "ペインを確かめて閉じるコマンドを出す" "$OUT" "tmux kill-pane -t %1"
ck "binding は変えない" "101" "$(lease_pid "$SUP")"
ck "board は変えない" "%1" "$(bash -c ". '$PROJECT_DIR/lib/seat.sh'; oe_seat_resolve '$BOARD'")"
sed -i.bak '/^%1 /d' "$PANES"; rm -f "$PANES.bak"
run as_sup "$VERB" -w "$WS" --board "$BOARD"
ck "ペインが無いとき: 終了コードは 1" "1" "$RC"
nck "ペインの番号を出さない" "$OUT" "kill-pane"
ckc "pid で確かめる手順を出す" "$OUT" "ps -p 101 -o pid,lstart,command"
run env FAKE_PS_FAIL=1 TMUX="/tmp/fake-sock,900,0" TMUX_PANE=%2 CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-sup "$VERB" -w "$WS" --board "$BOARD"
ck "ps が失敗したとき: 何も書かず止まる" "1:101" "$RC:$(lease_pid "$SUP")"
nck "閉じるコマンドを出さない" "$OUT" "kill-pane"
nck "kill のコマンドも出さない" "$OUT" "が kill 101"

echo "=== T-4 張り替えたあと止まった状態から、別のプロセスで打ち直す ==="
setup restart
kill_pid 101
( . "$PROJECT_DIR/lib/lease.sh"; oe_lease_claim "$SUP" "$(oe_lease_epoch "$SUP")" 201 "$S2" claude sid-sup )   # 前の復帰は張り替えただけで止まった
kill_pid 201
printf '%s\n' "701|$S6|claude|ttys002|701" >> "$PS_TABLE"
run env TMUX="/tmp/fake-sock,900,0" TMUX_PANE=%2 CLAUDE_PID=701 CLAUDE_CODE_SESSION_ID=sid-sup "$VERB" -w "$WS" --board "$BOARD"
ck "終了コードは 0" "0" "$RC"
ck "binding は 701" "701" "$(lease_pid "$SUP")"
ck "rebinds に 101 と 201" "101,201" "$(jq -r '[.generations[0].rebinds[].pid] | map(tostring) | join(",")' "$OE_LEASE_DIR/$SUP.json")"
ck "board は %2" "%2" "$(bash -c ". '$PROJECT_DIR/lib/seat.sh'; oe_seat_resolve '$BOARD'")"

echo "=== T-5 復帰のロック ==="
setup lock
kill_pid 101
mkdir "$OE_LEASE_DIR/$SUP.json.recover.lock"; printf '%s' "$$" > "$OE_LEASE_DIR/$SUP.json.recover.lock/pid"
run as_sup "$VERB" -w "$WS" --board "$BOARD"
ck "走っているときは止まる" "1:101" "$RC:$(lease_pid "$SUP")"
ckc "ほかで走っていると言う" "$OUT" "ほかで走っています"
printf '%s' "999999" > "$OE_LEASE_DIR/$SUP.json.recover.lock/pid"
run as_sup "$VERB" -w "$WS" --board "$BOARD"
ck "持ち主が死んだロックは引き取る" "0:201" "$RC:$(lease_pid "$SUP")"
ck "終わったらロックを外す" "0" "$([ -d "$OE_LEASE_DIR/$SUP.json.recover.lock" ] && echo 1 || echo 0)"

echo "=== T-7 退任・workspace・--lease ==="
setup retired
kill_pid 101
( . "$PROJECT_DIR/lib/lease.sh"; printf '%s\n' "601|$S6|claude|ttys006|601" >> "$PS_TABLE"
  oe_lease_advance "$SUP" "$(oe_lease_epoch "$SUP")" recover 601 "$S6" claude >/dev/null )
run as_sup "$VERB" -w "$WS" --board "$BOARD"
ck "退任した generation の会話は止まる" "1" "$RC"
ckc "退任と言う" "$OUT" "退任しています"
run env TMUX="/tmp/fake-sock,900,0" TMUX_PANE=%2 CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-sup OE_GENERATION=2 "$VERB" -w "$WS" --board "$BOARD"
ck "OE_GENERATION を変えても session_id の generation で止まる" "1" "$RC"
setup lease-arg
kill_pid 101
run env TMUX="/tmp/fake-sock,900,0" TMUX_PANE=%2 CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-new "$VERB" -w "$WS" --board "$BOARD"
ck "lease が決まらなければ止まる" "1" "$RC"
ckc "hint を案内する" "$OUT" "oe-recover hint"
run env TMUX="/tmp/fake-sock,900,0" TMUX_PANE=%2 CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-new "$VERB" -w "$WS" --board "$BOARD" --lease "$SUP"
ck "--lease で統括なら owner の確かめを求める" "1:101" "$RC:$(lease_pid "$SUP")"
ckc "--owner-confirmed を案内する" "$OUT" "--owner-confirmed"
run env TMUX="/tmp/fake-sock,900,0" TMUX_PANE=%2 CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-new "$VERB" -w "$_TMP_DIR" --board "$BOARD" --lease "$SUP" --owner-confirmed
ck "workspace が違えば止まる" "1:101" "$RC:$(lease_pid "$SUP")"
run env TMUX="/tmp/fake-sock,900,0" TMUX_PANE=%2 CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-new "$VERB" -w "$WS" --board "$BOARD" --lease "$SUP" --owner-confirmed
ck "owner が確かめれば張り替える" "201" "$(lease_pid "$SUP")"

echo "=== T-8 hint ==="
setup hint
kill_pid 101
SNAP="$(find "$_TMP_DIR/case-hint" -type f -exec shasum {} + | sort)"
run "$VERB" hint -w "$WS"
ck "終了コードは 0" "0" "$RC"
ckc "resume のコマンドを出す" "$OUT" "OE_LEASE_ID=${SUP} OE_GENERATION=1 claude --resume sid-sup"
nck "--all が無ければ子を出さない" "$OUT" "#9 child"
run "$VERB" hint -w "$WS" --all
ckc "--all で子を出す" "$OUT" "#9 child"
ckc "--all で孫を出す" "$OUT" "#10 grand"
ckc "生きている子には復帰は要らないと言う" "$OUT" "復帰は要りません"
ck "何も書いていない" "$SNAP" "$(find "$_TMP_DIR/case-hint" -type f -exec shasum {} + | sort)"

echo "=== T-11 途中で binding がほかに移る ==="
setup lost
kill_pid 101
HOOK="$_TMP_DIR/hook.sh"
cat > "$HOOK" <<EOF
f="$OE_LEASE_DIR/$SUP.json"
jq '.generations[0].binding.pid = 888 | .epoch += 1' "\$f" > "\$f.t" && mv "\$f.t" "\$f"
EOF
run env FAKE_DATE_HOOK="$HOOK" TMUX="/tmp/fake-sock,900,0" TMUX_PANE=%2 CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-sup "$VERB" -w "$WS" --board "$BOARD"
ck "終了コードは 1" "1" "$RC"
ckc "binding が自分でなくなったと言う" "$OUT" "binding が自分でなくなりました"
ck "registry の自分の行は書かない" "none" "$(reg_parent %2)"
ck "event は complete=false" "false" "$(grep '"supervisor_recovery"' "$OE_EVENT_DIR/oe-events.jsonl" | tail -1 | jq -r '.complete')"

echo "=== T-12 tmux を起こし直した（子が先・親があと・孫あり）==="
setup restart-all
kill_pid 101
# 子が先に打つ。親（統括）はまだ復帰していないので、自分の行は書けない。
run env TMUX="/tmp/fake-sock,900,0" TMUX_PANE=%3 CLAUDE_PID=301 CLAUDE_CODE_SESSION_ID=sid-child "$VERB" -w "$_TMP_DIR/case-restart-all/cws"
ck "子が先: 終了コードは 1" "1" "$RC"
ckc "親を待つと言う" "$OUT" "親（統括）が復帰したあと"
ck "子が先: 孫の行は書く（親は子）" "%3" "$(reg_parent %5)"
run as_sup "$VERB" -w "$WS" --board "$BOARD"
ck "親があと: 終了コードは 0" "0" "$RC"
ck "親があと: 子の行の親は統括" "%2" "$(reg_parent %3)"
ck "前の server の行は消えている" "0" "$([ -f "$OE_DELEGATE_STATE_DIR/800__1.json" ] && echo 1 || echo 0)"
run env TMUX="/tmp/fake-sock,900,0" TMUX_PANE=%3 CLAUDE_PID=301 CLAUDE_CODE_SESSION_ID=sid-child "$VERB" -w "$_TMP_DIR/case-restart-all/cws"
ck "子がもう一度: 終了コードは 0" "0" "$RC"
ck "registry の親子が lease と一致（子→統括・孫→子）" "%2,%3" "$(reg_parent %3),$(reg_parent %5)"

echo "=== T-13 board が無い ==="
setup noboard
kill_pid 101
run as_sup "$VERB" -w "$WS"
ck "終了コードは 1" "1" "$RC"
ckc "board の場所を案内する" "$OUT" "oe-recover --board"
ck "張り替えはした" "201" "$(lease_pid "$SUP")"
ck "registry は書いた" "%2" "$(reg_parent %3)"
ck "event の undone に board" "board" "$(grep '"supervisor_recovery"' "$OE_EVENT_DIR/oe-events.jsonl" | tail -1 | jq -r '.undone | join(",")')"

echo "=== 本物に届く経路が無い ==="
ck "偽の ps と tmux が呼ばれた" "1" "$([ -s "$CALLS" ] && echo 1 || echo 0)"
if [ -n "$REAL_HOME" ]; then
  ck "本物の置き場は書いていない" "ok" "$(find "$REAL_HOME/.claude/state/oe-lease" "$REAL_HOME/.claude/state/oe-delegate" "$REAL_HOME/.claude/state/oe-events.jsonl" -newer "$START_MARK" 2>/dev/null | grep -c . | sed 's/^0$/ok/')"
fi

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
