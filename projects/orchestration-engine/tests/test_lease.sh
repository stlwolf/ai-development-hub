#!/usr/bin/env bash
set -euo pipefail

# test_lease.sh — lib/tmux-pane-identity.sh・lib/heartbeat-resolve.sh・lib/lease.sh・bin/oe-lease・
#                 scripts/validate-lease.sh の検証（#577 PR-1）
#
# 見るもの:
#   (1) プロセスの生死を、ある・無い・分からないの3つで返す（ps の失敗を「無い」に畳まない・DJ-9）
#   (2) ペインのフォアグラウンドのプロセスの発見と、binding との照合を分けて返す（DJ-19）
#   (3) heartbeat の候補の選び方（server の一致・鮮度の窓・lease と generation か session_id・同率は分かれた）
#   (4) binding の張り替えの決まり（前が無い・本人・前が死んでいるときだけ。生きている・分からないは断る・epoch）
#   (5) session_id の登録は本人だけで、開いた lease のあいだで重ならない（DJ-18・DJ-5）
#   (6) generation を進める（planned・recover）・親の書き換えで epoch が増える・閉じる
#   (7) whoami（環境変数・session_id・退任）と resolve（送る前の確かめ）
#   (8) gc は閉じた古い lease と古い sidecar だけを消し、.hb.* と参照されている sidecar を残す
#   (9) 検査のスクリプトが正しい記録を通し、壊れた記録を落とす
#   (10) 本物の ~/.claude/state/ と本物の tmux・ps に届く経路が無い
#
# ps と tmux は偽物に差し替える（OE_TPI_PS・OE_TPI_TMUX と PATH の先頭の両方）。HOME も一時ディレクトリにする。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_LEASE_BIN="$PROJECT_DIR/bin/oe-lease"
VALIDATE="$PROJECT_DIR/scripts/validate-lease.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

REAL_HOME="${HOME:-}"
export HOME="$_TMP_DIR/home"; mkdir -p "$HOME"
unset TMUX TMUX_PANE PARENT_TMUX_PANE CLAUDE_PID CLAUDE_CODE_SESSION_ID OE_LEASE_ID OE_GENERATION 2>/dev/null || true

# --- 偽の ps と tmux（呼ばれたら自分のパスを記録する） ---
FAKE="$_TMP_DIR/bin"; mkdir -p "$FAKE"
PS_TABLE="$_TMP_DIR/ps.table"   # pid|lstart|comm|tty|tpgid
PANES="$_TMP_DIR/panes"         # "%N /dev/ttysNNN"
CALLS="$_TMP_DIR/calls"; : > "$CALLS"
export PS_TABLE PANES CALLS
cat > "$FAKE/ps" <<'EOF'
#!/usr/bin/env bash
echo "fake-ps $*" >> "$CALLS"
[ -z "${FAKE_PS_FAIL:-}" ] || exit 2
if [ -n "${FAKE_PS_RC1:-}" ]; then echo "ps: cannot allocate memory" >&2; exit 1; fi
mode=""; pid=""; tty=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) mode="$2"; shift 2 ;;
    -p) pid="$2"; shift 2 ;;
    -t) tty="$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [ -n "$tty" ]; then
  awk -F '|' -v t="$tty" '$4==t {print $1" "$5}' "$PS_TABLE"; exit 0
fi
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
[ -z "${FAKE_TMUX_FAIL:-}" ] || exit 1
if [ "${1:-}" = "list-panes" ]; then cat "$PANES"; exit 0; fi
exit 0
EOF
cat > "$FAKE/kill" <<'EOF'
#!/usr/bin/env bash
# 偽の kill -0: ps の表に pid があれば生きている。FAKE_KILL_EXISTS=1 なら表に無くても生きている（ps だけが失敗した場面）。
echo "fake-kill $*" >> "$CALLS"
pid="${2:-}"
if [ -n "${FAKE_KILL_EXISTS:-}" ] || awk -F '|' -v p="$pid" '$1==p {f=1} END {exit f?0:1}' "$PS_TABLE"; then exit 0; fi
echo "kill: ($pid) - No such process" >&2; exit 1
EOF
chmod +x "$FAKE/ps" "$FAKE/tmux" "$FAKE/kill"
export PATH="$FAKE:$PATH"
export OE_TPI_PS="$FAKE/ps" OE_TPI_TMUX="$FAKE/tmux" OE_TPI_KILL="$FAKE/kill"

export OE_LEASE_DIR="$_TMP_DIR/lease"
export OE_HEARTBEAT_DIR="$_TMP_DIR/heartbeat"; mkdir -p "$OE_HEARTBEAT_DIR"
export OE_LEASE_LOCK_RETRY=3
NOW="$(date +%s)"
export OE_HB_NOW_EPOCH="$NOW" OE_LEASE_NOW_EPOCH="$NOW"

# 開始時刻は実物の ps と同じく、日付の1桁の前に空白が2つ入る形にする（詰めて比べることを確かめる）。
S1='Fri Nov  6 02:44:37 2026'; S2='Fri Nov  6 03:00:00 2026'; S3='Fri Nov  6 04:00:00 2026'
printf '%s\n' "101|$S1|claude|ttys001|101" "102|$S1|node|ttys001|101" "201|$S2|claude|ttys002|201" \
  "301|$S3|-bash|ttys003|302" "302|$S3|claude|ttys003|302" "401|$S3|bash|ttys004|401" > "$PS_TABLE"
printf '%s\n' "%1 /dev/ttys001" "%2 /dev/ttys002" "%3 /dev/ttys003" "%4 /dev/ttys004" > "$PANES"

# shellcheck source=../lib/lease.sh
. "$PROJECT_DIR/lib/lease.sh"

PASS=0; FAIL=0
ck()  { if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
rc_of() { local r=0; "$@" >/dev/null 2>&1 || r=$?; printf '%s' "$r"; }
TAB="$(printf '\t')"

echo "=== (1) プロセスの生死は3つの値 ==="
ck "生きている" "alive" "$(oe_tpi_proc_state 101 "$S1")"
ck "空白の数が違っても同じ開始時刻なら生きている" "alive" "$(oe_tpi_proc_state 101 'Fri Nov 6 02:44:37 2026')"
ck "pid が無ければ死んでいる" "dead" "$(oe_tpi_proc_state 999 "$S1")"
ck "同じ pid で開始時刻が違えば別のプロセス（死んでいる）" "dead" "$(oe_tpi_proc_state 101 "$S2")"
ck "ps が失敗したら分からない" "unknown" "$(FAKE_PS_FAIL=1 oe_tpi_proc_state 101 "$S1")"
ck "ps が rc 1 とエラーを返しても、プロセスがあれば分からない（無いに畳まない）" "unknown" "$(FAKE_PS_RC1=1 FAKE_KILL_EXISTS=1 oe_tpi_proc_state 999 "$S1")"
ck "ps が rc 1 で kill -0 も No such process なら死んでいる" "dead" "$(FAKE_PS_RC1=1 oe_tpi_proc_state 999 "$S1")"
ck "開始時刻が無ければ分からない" "unknown" "$(oe_tpi_proc_state 101 "")"
ck "コマンド名" "claude" "$(oe_tpi_proc_comm 101)"

echo "=== (2) ペインの発見と照合 ==="
ck "フォアグラウンドのプロセス（claude の子が同じ tpgid でも、pid と tpgid が一致する行）" "101${TAB}Fri Nov 6 02:44:37 2026" "$(oe_tpi_pane_foreground %1)"
ck "シェルで始まるペインでもフォアグラウンドは claude" "302" "$(oe_tpi_pane_foreground %3 | cut -f1)"
ck "無いペインは rc 1" "1" "$(rc_of oe_tpi_pane_foreground %9)"
ck "tmux が失敗したら rc 2" "2" "$(FAKE_TMUX_FAIL=1 rc_of oe_tpi_pane_foreground %1)"
ck "ペインの形でなければ rc 2" "2" "$(rc_of oe_tpi_pane_foreground 1)"
ck "照合: 一致" "0" "$(rc_of oe_tpi_verify_pane %1 101 "$S1")"
ck "照合: 別の pid" "1" "$(rc_of oe_tpi_verify_pane %1 201 "$S2")"
ck "照合: 同じ pid で開始時刻が違う" "1" "$(rc_of oe_tpi_verify_pane %1 101 "$S2")"
ck "照合: ps が失敗したら rc 2" "2" "$(FAKE_PS_FAIL=1 rc_of oe_tpi_verify_pane %1 101 "$S1")"

echo "=== (3) heartbeat の候補 ==="
mk_beat() { # mk_beat <sid> <pane> <server_pid> <age> [lease_id] [generation]
  jq -cn --argjson ts "$((NOW - $4))" --arg p "$2" --arg s "$3" --arg l "${5:-}" --arg g "${6:-}" \
    '{ts:$ts, context_pct:10, pane:$p, server_pid:$s} + (if $l != "" then {lease_id:$l, generation:($g|tonumber)} else {} end)' \
    > "$OE_HEARTBEAT_DIR/$1.json"
}
L0="AAAAAAAAAAAAAAAAAAAAAAAAAA"
mk_beat sid-a %1 900 10
mk_beat sid-b %2 900 5 "$L0" 1
mk_beat sid-c %3 800 1
mk_beat sid-d %4 900 99999
ck "session_id で選ぶ" "%1${TAB}sid-a" "$(oe_hb_pane_for 900 3600 "" "" sid-a)"
ck "lease と generation で選ぶ（lease_id が無い sidecar と混ざっても列がずれない）" "%2${TAB}sid-b" "$(oe_hb_pane_for 900 3600 "$L0" 1)"
ck "より新しいほうを選ぶ" "%2${TAB}sid-b" "$(oe_hb_pane_for 900 3600 "$L0" 1 sid-a)"
ck "server が違えば外す" "1" "$(rc_of oe_hb_pane_for 900 3600 "" "" sid-c)"
ck "鮮度の窓の外は外す" "1" "$(rc_of oe_hb_pane_for 900 3600 "" "" sid-d)"
ck "generation が違えば外す" "1" "$(rc_of oe_hb_pane_for 900 3600 "$L0" 2)"
mk_beat sid-e %4 900 5
ck "同じ時刻で別のペインに分かれたら rc 3" "3" "$(rc_of oe_hb_pane_for 900 3600 "$L0" 1 sid-e)"
ck "ペインから session_id" "sid-a" "$(oe_hb_session_for_pane 900 3600 %1)"
rm -f "$OE_HEARTBEAT_DIR"/*.json

echo "=== (4) binding の張り替え ==="
L1="$(oe_lease_create delegation '#577' /ws "")"
ck "作った記録が検査を通る" "0" "$(rc_of "$VALIDATE" "$OE_LEASE_DIR/$L1.json")"
ck "作った直後の epoch は 0" "0" "$(oe_lease_epoch "$L1")"
ck "claude でなければ断る" "6" "$(rc_of oe_lease_bind "$L1" 0 401 "$S3" bash)"
ck "前が無ければ書ける" "0" "$(rc_of oe_lease_bind "$L1" 0 101 "$S1" claude)"
ck "書くと epoch が増える" "1" "$(oe_lease_epoch "$L1")"
ck "本人がもう一度書いても何も変えない" "0" "$(rc_of oe_lease_bind "$L1" 1 101 'Fri Nov 6 02:44:37 2026' claude)"
ck "本人のときは epoch を増やさない" "1" "$(oe_lease_epoch "$L1")"
ck "epoch が合わなければ rc 3" "3" "$(rc_of oe_lease_bind "$L1" 0 201 "$S2" claude)"
ck "前が生きていれば断る" "5" "$(rc_of oe_lease_bind "$L1" 1 201 "$S2" claude)"
ck "前が生きているか分からなければ断る" "5" "$(FAKE_PS_FAIL=1 rc_of oe_lease_bind "$L1" 1 201 "$S2" claude)"
sed -i.bak "s/^101|/111|/" "$PS_TABLE"
ck "前が死んでいれば張り替えられる" "0" "$(rc_of oe_lease_bind "$L1" 1 201 "$S2" claude)"
ck "張り替えた binding" "201" "$(oe_lease_get "$L1" | jq -r '.generations[0].binding.pid')"
mv "$PS_TABLE.bak" "$PS_TABLE"
ck "張り替えたあとも検査を通る" "0" "$(rc_of "$VALIDATE" "$OE_LEASE_DIR/$L1.json")"

echo "=== (5) session_id の登録 ==="
ck "binding と一致しなければ登録しない" "5" "$(rc_of oe_lease_register_session "$L1" sid-1 101 "$S1")"
ck "本人なら登録できる" "0" "$(rc_of oe_lease_register_session "$L1" sid-1 201 "$S2")"
ck "同じものをもう一度は何もしない" "0" "$(rc_of oe_lease_register_session "$L1" sid-1 201 "$S2")"
ck "重ねて入らない" "1" "$(oe_lease_get "$L1" | jq '.generations[0].session_ids | length')"
ck "登録で epoch は増えない" "2" "$(oe_lease_epoch "$L1")"
L2="$(oe_lease_create delegation '#578' /ws "")"
oe_lease_bind "$L2" 0 302 "$S3" claude
ck "ほかの開いた lease にある session_id は入れない" "8" "$(rc_of oe_lease_register_session "$L2" sid-1 302 "$S3")"
ck "/clear のあとの session_id も本人なら足せる" "0" "$(rc_of oe_lease_register_session "$L1" sid-2 201 "$S2")"
L6="$(oe_lease_create delegation '#580' /ws "")"
ck "claim: ほかの lease にある session_id なら 8" "8" "$(rc_of oe_lease_claim "$L6" 0 201 "$S2" claude sid-1)"
ck "claim: 8 で止まったときは binding も epoch も変えない" "null:0" "$(oe_lease_get "$L6" | jq -r '"\(.generations[0].binding):\(.epoch)"')"
ck "claim: binding と session_id を一緒に書く" "0" "$(rc_of oe_lease_claim "$L6" 0 302 "$S3" claude sid-6)"
ck "claim のあと" "302:sid-6:1" "$(oe_lease_get "$L6" | jq -r '"\(.generations[0].binding.pid):\(.generations[0].session_ids[0]):\(.epoch)"')"
oe_lease_close "$L6"
ck "session_id で探す" "${L1}${TAB}1" "$(oe_lease_find_by_session sid-2)"

echo "=== (6) generation を進める・親・閉じる ==="
ck "planned で進める" "2" "$(oe_lease_advance "$L1" 2 planned 302 "$S3" claude)"
ck "前の generation は退任" "retired" "$(oe_lease_get "$L1" | jq -r '.generations[0].state')"
ck "前の generation の後任" "2" "$(oe_lease_get "$L1" | jq -r '.generations[0].successor')"
ck "いまの generation" "2" "$(oe_lease_get "$L1" | jq -r '.current_generation')"
ck "進めたあとも検査を通る" "0" "$(rc_of "$VALIDATE" "$OE_LEASE_DIR/$L1.json")"
ck "同じ lease の退任した generation の session_id は、いまの generation に登録しない" "8" "$(rc_of oe_lease_register_session "$L1" sid-1 302 "$S3")"
ck "recover は前の binding が生きていれば断る" "5" "$(rc_of oe_lease_advance "$L1" 3 recover 201 "$S2" claude)"
sed -i.bak "s/^302|/312|/" "$PS_TABLE"
ck "recover は前の binding が死んでいれば進める" "3" "$(oe_lease_advance "$L1" 3 recover 201 "$S2" claude)"
mv "$PS_TABLE.bak" "$PS_TABLE"
E1="$(oe_lease_epoch "$L1")"
ck "親を書き換えると epoch が増える" "0" "$(rc_of oe_lease_set_parent "$L1" "$E1" "$L2")"
ck "親" "$L2" "$(oe_lease_get "$L1" | jq -r '.parent_lease_id')"
ck "epoch が1つ増えた" "$((E1 + 1))" "$(oe_lease_epoch "$L1")"
ck "古い epoch で親を書き換えようとすると rc 3" "3" "$(rc_of oe_lease_set_parent "$L1" "$E1" "")"
ck "自分を親にできない" "2" "$(rc_of oe_lease_set_parent "$L1" "$((E1 + 1))" "$L1")"
ck "閉じる" "0" "$(rc_of oe_lease_close "$L2")"
ck "閉じたものは書けない" "7" "$(rc_of oe_lease_bind "$L2" 1 302 "$S3" claude)"
ck "閉じたあとも検査を通る" "0" "$(rc_of "$VALIDATE" "$OE_LEASE_DIR/$L2.json")"
ck "label で探すと開いたものだけ" "$L1" "$(oe_lease_find_by_label '#577')"
ck "閉じた lease の label は見つからない" "1" "$(rc_of oe_lease_find_by_label '#578')"

echo "=== (7) whoami と resolve ==="
ck "環境変数で名乗る" "3" "$(OE_LEASE_ID="$L1" OE_GENERATION=3 oe_lease_whoami | jq -r '.generation')"
ck "session_id で名乗る（方法2）" "${L1}:session" "$(CLAUDE_CODE_SESSION_ID=sid-2 oe_lease_whoami | jq -r '"\(.lease_id):\(.source)"')"
ck "退任した generation で名乗ると retired" "retired" "$(CLAUDE_CODE_SESSION_ID=sid-1 oe_lease_whoami | jq -r '.state')"
ck "どちらも無ければ rc 1" "1" "$(rc_of oe_lease_whoami)"
mk_beat sid-x %2 900 3 "$L1" 3
ck "resolve: binding と一致するペイン" "%2" "$(OE_LEASE_SERVER_PID=900 oe_lease_resolve_pane "$L1")"
mk_beat sid-x %1 900 3 "$L1" 3
ck "resolve: 候補のペインにいるのが binding でなければ rc 5（送らない）" "5" "$(OE_LEASE_SERVER_PID=900 rc_of oe_lease_resolve_pane "$L1")"
ck "resolve: ps が失敗したら rc 6" "6" "$(FAKE_PS_FAIL=1 OE_LEASE_SERVER_PID=900 rc_of oe_lease_resolve_pane "$L1")"
ck "resolve: server の pid が分からなければ rc 6" "6" "$(rc_of oe_lease_resolve_pane "$L1")"
ck "resolve: 閉じた lease は rc 7" "7" "$(OE_LEASE_SERVER_PID=900 rc_of oe_lease_resolve_pane "$L2")"
L3="$(oe_lease_create delegation '#579' /ws "")"
ck "resolve: binding が無ければ rc 9" "9" "$(OE_LEASE_SERVER_PID=900 rc_of oe_lease_resolve_pane "$L3")"
rm -f "$OE_HEARTBEAT_DIR"/*.json

echo "=== verb: oe-lease ==="
mkdir -p "$_TMP_DIR/wsx"
out="$(CLAUDE_PID=302 CLAUDE_CODE_SESSION_ID=sid-root "$OE_LEASE_BIN" create --root --label cockpit -w "$_TMP_DIR/wsx" --generation 22)"
ck "create --root は lease_id を出す" "26" "${#out}"
ck "create --root は自分を binding に書く" "302" "$(oe_lease_get "$out" | jq -r '.generations[0].binding.pid')"
ck "create --root は自分の session_id を登録する" "sid-root" "$(oe_lease_get "$out" | jq -r '.generations[0].session_ids[0]')"
ck "create --root は generation を渡した番号から始める" "22" "$(oe_lease_get "$out" | jq -r '.current_generation')"
ck "create --root は CLAUDE_PID が無ければ止まる" "2" "$(rc_of "$OE_LEASE_BIN" create --root --label cockpit2)"
ck "whoami（session_id）" "$out" "$(CLAUDE_CODE_SESSION_ID=sid-root "$OE_LEASE_BIN" whoami | jq -r '.lease_id')"
ck "whoami: 退任した generation は exit 7" "7" "$(CLAUDE_CODE_SESSION_ID=sid-1 rc_of "$OE_LEASE_BIN" whoami)"
ck "bind: 前が生きていれば exit 5" "5" "$(CLAUDE_PID=101 CLAUDE_CODE_SESSION_ID=sid-new rc_of "$OE_LEASE_BIN" bind "$out" -w "$_TMP_DIR/wsx" --owner-confirmed)"
sed -i.bak "s/^302|/322|/" "$PS_TABLE"
ck "bind: 前が死んでいれば張り替えて session_id を登録する" "0" "$(CLAUDE_PID=101 CLAUDE_CODE_SESSION_ID=sid-new rc_of "$OE_LEASE_BIN" bind "$out" -w "$_TMP_DIR/wsx" --owner-confirmed)"
ck "bind（方法2）: もう記録にある session_id なら確かめを求めない" "0" "$(CLAUDE_PID=101 CLAUDE_CODE_SESSION_ID=sid-new rc_of "$OE_LEASE_BIN" bind "$out" -w /nonexistent)"
ck "bind のあとの session_id" "sid-root,sid-new" "$(oe_lease_get "$out" | jq -r '.generations[0].session_ids | join(",")')"
mv "$PS_TABLE.bak" "$PS_TABLE"
RL="$(oe_lease_find_by_session sid-root | cut -f1)"
ck "bind（方法3）: workspace が違えば exit 10" "10" "$(CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-m3 rc_of "$OE_LEASE_BIN" bind "$RL" -w "$_TMP_DIR")"
ck "bind（方法3）: workspace のディレクトリが無いときに一致と読まない" "10" "$(CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-m3 rc_of "$OE_LEASE_BIN" bind "$RL" -w /nonexistent-a)"
ck "bind（方法3）: 統括の lease は --owner-confirmed が無ければ exit 10" "10" "$(CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-m3 rc_of "$OE_LEASE_BIN" bind "$RL" -w "$_TMP_DIR/wsx")"
ck "bind（方法3）: 確かめを付けても、前の binding が生きていれば exit 5" "5" "$(CLAUDE_PID=201 CLAUDE_CODE_SESSION_ID=sid-m3 rc_of "$OE_LEASE_BIN" bind "$RL" -w "$_TMP_DIR/wsx" --owner-confirmed)"
ck "create --root: もう開いた lease にある session_id なら exit 8" "8" "$(CLAUDE_PID=302 CLAUDE_CODE_SESSION_ID=sid-root rc_of "$OE_LEASE_BIN" create --root --label cockpit3)"
ck "resolve: label が無ければ exit 1" "1" "$(rc_of "$OE_LEASE_BIN" resolve '#nothing')"
ck "show" "cockpit" "$("$OE_LEASE_BIN" show "$out" | jq -r '.label')"
ck "unknown subcommand は exit 2" "2" "$(rc_of "$OE_LEASE_BIN" frobnicate)"

echo "=== (8) gc ==="
OLD=$((NOW - 40 * 86400))
OLDISO="$(jq -rn --argjson t "$OLD" '$t | todate')"
L4="$(oe_lease_create delegation '#old' /ws "")"
jq --arg c "$OLDISO" '.state="closed" | .closed_at=$c' "$OE_LEASE_DIR/$L4.json" > "$_TMP_DIR/x" && mv "$_TMP_DIR/x" "$OE_LEASE_DIR/$L4.json"
L5="$(oe_lease_create delegation '#recent' /ws "")"; oe_lease_close "$L5"
mk_beat sid-old 0 900 $((40 * 86400))
mk_beat sid-new %1 900 $((40 * 86400))   # 古いが、開いた lease のいまの generation が参照している
printf 'x' > "$OE_HEARTBEAT_DIR/.hb.ABCDEF"
touch -t 202601010000 "$OE_HEARTBEAT_DIR/.hb.ABCDEF"
dry="$(oe_lease_gc 30 dry-run)"
ck "dry-run は消すはずのものを出す（閉じた古い lease と、参照されない古い sidecar）" "2" "$(printf '%s\n' "$dry" | grep -c .)"
ck "dry-run は消さない" "1" "$([ -f "$OE_LEASE_DIR/$L4.json" ] && echo 1 || echo 0)"
oe_lease_gc 30 >/dev/null
ck "閉じた古い lease を消す" "0" "$([ -f "$OE_LEASE_DIR/$L4.json" ] && echo 1 || echo 0)"
ck "閉じたばかりの lease は残す" "1" "$([ -f "$OE_LEASE_DIR/$L5.json" ] && echo 1 || echo 0)"
ck "参照されない古い sidecar を消す" "0" "$([ -f "$OE_HEARTBEAT_DIR/sid-old.json" ] && echo 1 || echo 0)"
ck "参照されている sidecar は古くても残す" "1" "$([ -f "$OE_HEARTBEAT_DIR/sid-new.json" ] && echo 1 || echo 0)"
ck ".hb.* は触らない（別 issue）" "1" "$([ -f "$OE_HEARTBEAT_DIR/.hb.ABCDEF" ] && echo 1 || echo 0)"
ck "gc: 日数が数でなければ rc 2" "2" "$(rc_of oe_lease_gc abc)"

echo "=== (9) 検査のスクリプトが壊れた記録を落とす ==="
G="$OE_LEASE_DIR/$L1.json"
bad() { jq "$1" "$G" > "$_TMP_DIR/bad.json"; rc_of "$VALIDATE" "$_TMP_DIR/bad.json"; }
ck "知らない項目" "1" "$(bad '.extra=1')"
ck "kind の値" "1" "$(bad '.kind="x"')"
ck "current_generation が並びに無い" "1" "$(bad '.current_generation=99')"
ck "active が2つ" "1" "$(bad '.generations |= map(.state="active" | .retired_at="")')"
ck "binding のコマンドが claude でない" "1" "$(bad '.generations[-1].binding.comm="bash"')"
ck "session_id が2つの generation に重なる" "1" "$(bad '.generations[1].session_ids = .generations[0].session_ids')"
ck "閉じていないのに closed_at がある" "1" "$(bad '.closed_at="2026-11-06T00:00:00Z"')"
ck "started_at が文字列でない" "1" "$(bad '.generations[0].started_at=123')"
ck "successor が整数でない" "1" "$(bad '.generations[0].successor=1.5')"
ck "ファイルが無ければ exit 2" "2" "$(rc_of "$VALIDATE" "$_TMP_DIR/none.json")"

echo "=== (10) 本物に届く経路が無い ==="
ck "ps と tmux は偽物だけが呼ばれた（記録がある）" "1" "$([ -s "$CALLS" ] && echo 1 || echo 0)"
in_tmp=0; [ "${OE_LEASE_DIR#"$_TMP_DIR"/}" != "$OE_LEASE_DIR" ] && in_tmp=1
ck "置き場は一時ディレクトリ" "1" "$in_tmp"
if [ -n "$REAL_HOME" ]; then
  ck "本物の置き場は作っていない（このテストの前から無ければ無いまま）" "ok" "$(find "$REAL_HOME/.claude/state/oe-lease" -newer "$CALLS" 2>/dev/null | grep -c . | sed 's/^0$/ok/')"
fi

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
