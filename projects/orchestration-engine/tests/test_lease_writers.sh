#!/usr/bin/env bash
set -euo pipefail

# test_lease_writers.sh — #577 PR-2（書く側を両方書きにする）の検証
#
# 見るもの:
#   (1) heartbeat の producer は、正しい形の OE_LEASE_ID と OE_GENERATION があるときだけ lease_id と generation を足す
#   (2) events の写し: child_spawned の両端に lease が入る・自分のペインの送信は自分の環境から入る・lease_bound の形
#   (3) oe-delegate: 子を起こしたあと、フォアグラウンドのプロセスが claude なら binding を書き、lease_bound を残す
#   (4) oe-register root は自分の lease を作り、link は相手の lease の親を自分の lease にする
#   (5) oe-lease adopt: registry の記録から lease を作り、親を書き、2回走らせても増えない・claude でないものは外す
#   (6) 本物の ~/.claude/state/ と本物の tmux・ps・ペインに届く経路が無い
#
# tmux・ps・kill は偽物（OE_TPI_* と PATH の先頭の両方）。HOME と state の置き場は一時ディレクトリ。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
BIN="$PROJECT_DIR/bin"
PRODUCER="$REPO_DIR/canonical/claude/statusline/statusline-oe-heartbeat.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
# 本物の置き場を書き換えていないかを比べる印。テストの開始時に作り、以後は触らない（偽の道具の呼び出しの記録は
# 呼ぶたびに更新されるので、比べる相手にすると途中で書いたものを見逃す・Copilot の指摘・PR #581）。
START_MARK="$_TMP_DIR/.start-mark"; : > "$START_MARK"
REAL_HOME="${HOME:-}"
export HOME="$_TMP_DIR/home"; mkdir -p "$HOME"
unset CLAUDE_PID CLAUDE_CODE_SESSION_ID OE_LEASE_ID OE_GENERATION PARENT_TMUX_PANE 2>/dev/null || true

FAKE="$_TMP_DIR/bin"; mkdir -p "$FAKE" "$_TMP_DIR/logs"
PS_TABLE="$_TMP_DIR/ps.table"   # pid|lstart|comm|tty|tpgid
PANES="$_TMP_DIR/panes"         # "%N /dev/ttysNNN"
CALLS="$_TMP_DIR/calls"; : > "$CALLS"
export PS_TABLE PANES CALLS LOGS="$_TMP_DIR/logs"
cat > "$FAKE/ps" <<'EOF'
#!/usr/bin/env bash
echo "fake-ps $*" >> "$CALLS"
mode=""; pid=""; tty=""
while [ $# -gt 0 ]; do
  case "$1" in -o) mode="$2"; shift 2 ;; -p) pid="$2"; shift 2 ;; -t) tty="$2"; shift 2 ;; *) shift ;; esac
done
if [ -n "$tty" ]; then awk -F '|' -v t="$tty" '$4==t {print $1" "$5}' "$PS_TABLE"; exit 0; fi
row="$(awk -F '|' -v p="$pid" '$1==p' "$PS_TABLE")"
[ -n "$row" ] || exit 1
case "$mode" in lstart=) printf '%s\n' "$(printf '%s' "$row" | cut -d'|' -f2)" ;; comm=) printf '%s\n' "$(printf '%s' "$row" | cut -d'|' -f3)" ;; esac
EOF
cat > "$FAKE/kill" <<'EOF'
#!/usr/bin/env bash
echo "fake-kill $*" >> "$CALLS"
awk -F '|' -v p="${2:-}" '$1==p {f=1} END {exit f?0:1}' "$PS_TABLE" && exit 0
echo "kill: (${2:-}) - No such process" >&2; exit 1
EOF
cat > "$FAKE/tmux" <<'EOF'
#!/usr/bin/env bash
echo "fake-tmux $*" >> "$CALLS"
case "${1:-}" in
  split-window) last=""; for a in "$@"; do last="$a"; done; printf '%s\n' "$last" > "$LOGS/split-command.log"; printf '%%9\n'; exit 0 ;;
  list-panes)
    if [[ "$*" == *'#{pane_tty}'* ]]; then cat "$PANES"
    elif [[ "$*" == *'#{pid}'* ]]; then _sp="${TMUX#*,}"; _sp="${_sp%%,*}"; awk -v s="$_sp" '{print $1" "s}' "$PANES"
    else awk '{print $1}' "$PANES"; fi
    exit 0 ;;
  send-keys) printf '%s\n' "$*" >> "$LOGS/send-keys.log"; exit 0 ;;
  display-message) printf '/tmp\n'; exit 0 ;;
  capture-pane) exit 0 ;;
esac
exit 0
EOF
chmod +x "$FAKE/ps" "$FAKE/kill" "$FAKE/tmux"
export PATH="$FAKE:$PATH"
export OE_TPI_PS="$FAKE/ps" OE_TPI_TMUX="$FAKE/tmux" OE_TPI_KILL="$FAKE/kill"
export TMUX="/tmp/fake-tmux,4242,0" TMUX_PANE="%1"
export OE_LEASE_DIR="$_TMP_DIR/lease" OE_DELEGATE_STATE_DIR="$_TMP_DIR/registry" OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
export OE_HEARTBEAT_DIR="$_TMP_DIR/heartbeat" OE_EVENT_DIR="$_TMP_DIR/events"
export OE_DELEGATE_WAIT_SEC=0 OE_SEND_FINALIZE=0 OE_SEND_ENTER_DELAY=0 OE_LEASE_LOCK_RETRY=3
mkdir -p "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR" "$_TMP_DIR/ws"
EVENTS="$OE_EVENT_DIR/oe-events.jsonl"

S1='Sat Nov  7 10:00:00 2026'; S9='Sat Nov  7 10:05:00 2026'; S5='Sat Nov  7 09:00:00 2026'
printf '%s\n' "101|$S1|claude|ttys001|101" "909|$S9|claude|ttys009|909" "505|$S5|claude|ttys005|505" \
  "606|$S5|-bash|ttys006|607" "607|$S5|vim|ttys006|607" > "$PS_TABLE"
printf '%s\n' "%1 /dev/ttys001" "%9 /dev/ttys009" "%5 /dev/ttys005" "%6 /dev/ttys006" > "$PANES"

PASS=0; FAIL=0
ck() { if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
rc_of() { local r=0; "$@" >/dev/null 2>&1 || r=$?; printf '%s' "$r"; }

echo "=== (1) heartbeat の producer ==="
L="AAAAAAAAAAAAAAAAAAAAAAAAAA"
printf '%s' '{"session_id":"sid-p","context_window":{"used_percentage":12}}' | OE_LEASE_ID="$L" OE_GENERATION=3 bash "$PRODUCER" >/dev/null 2>&1 || true
ck "lease_id を足す" "$L" "$(jq -r '.lease_id' "$OE_HEARTBEAT_DIR/sid-p.json")"
ck "generation を数で足す" "3" "$(jq -r '.generation' "$OE_HEARTBEAT_DIR/sid-p.json")"
printf '%s' '{"session_id":"sid-q"}' | OE_LEASE_ID="bad" OE_GENERATION=3 bash "$PRODUCER" >/dev/null 2>&1 || true
ck "形が違えば足さない" "false" "$(jq 'has("lease_id")' "$OE_HEARTBEAT_DIR/sid-q.json")"
printf '%s' '{"session_id":"sid-r"}' | bash "$PRODUCER" >/dev/null 2>&1 || true
ck "環境に無ければ、いままでと同じ項目" "context_pct,model,pane,server_pid,ts" "$(jq -r 'keys | join(",")' "$OE_HEARTBEAT_DIR/sid-r.json")"

echo "=== (2) events の写し ==="
# shellcheck source=../lib/event-bus.sh
. "$PROJECT_DIR/lib/event-bus.sh"
oe_event_child_spawned "%1" "%7" "#1" "" "" "${L}:1" "BBBBBBBBBBBBBBBBBBBBBBBBBB:22"
ck "child_spawned の to に子の lease" "${L}:1" "$(tail -1 "$EVENTS" | jq -r '"\(.to.lease_id):\(.to.generation)"')"
ck "child_spawned の from に親の lease" "BBBBBBBBBBBBBBBBBBBBBBBBBB:22" "$(tail -1 "$EVENTS" | jq -r '"\(.from.lease_id):\(.from.generation)"')"
OE_LEASE_ID="$L" OE_GENERATION=2 oe_event_emit "message_sent" "%1" "child" "#1" "%2" "parent" "cockpit" '{}'
ck "自分のペインの送信は、自分の環境から from に lease が入る" "${L}:2" "$(tail -1 "$EVENTS" | jq -r '"\(.from.lease_id):\(.from.generation)"')"
ck "to には入れない（知らない）" "false" "$(tail -1 "$EVENTS" | jq '.to | has("lease_id")')"
OE_LEASE_ID="$L" OE_GENERATION=2 oe_event_emit "message_sent" "%3" "child" "" "%2" "" "" '{}'
ck "自分のペインでない送信には入れない" "false" "$(tail -1 "$EVENTS" | jq '.from | has("lease_id")')"
oe_event_emit "message_sent" "%1" "" "" "%2" "" "" '{}' "bad:1" ""
ck "形が違う lease は焼き込まない" "false" "$(tail -1 "$EVENTS" | jq '.from | has("lease_id")')"
oe_event_lease_bound "%9" "$L" 1 spawn "#9"
ck "lease_bound の形" "lease_bound:${L}:1:spawn:%9" "$(tail -1 "$EVENTS" | jq -r '"\(.type):\(.lease_id):\(.generation):\(.bind_reason):\(.from.pane)"')"
oe_event_lease_bound "%9" "$L" 1 nonsense "#9"
ck "理由が決まった値でなければ書かない" "spawn" "$(tail -1 "$EVENTS" | jq -r '.bind_reason')"

echo "=== (3) oe-delegate の binding ==="
bash "$BIN/oe-delegate" -w "$_TMP_DIR/ws" --label "#9" "task" >"$_TMP_DIR/d.out" 2>"$_TMP_DIR/d.err" || true
lid="$(sed -nE "s/^OE_LEASE_ID='([0-9A-HJKMNP-TV-Z]{26})' .*/\1/p" "$LOGS/split-command.log")"
ck "子の lease ができた" "26" "${#lid}"
ck "binding は子のペインのフォアグラウンドのプロセス" "909" "$(jq -r '.generations[0].binding.pid' "$OE_LEASE_DIR/$lid.json")"
ck "binding のコマンド名" "claude" "$(jq -r '.generations[0].binding.comm' "$OE_LEASE_DIR/$lid.json")"
ck "lease_bound（spawn）が残る" "spawn" "$(jq -r --arg l "$lid" 'select(.type=="lease_bound" and .lease_id==$l) | .bind_reason' "$EVENTS" | tail -1)"
ck "child_spawned の to に子の lease" "$lid" "$(jq -r 'select(.type=="child_spawned") | .to.lease_id // ""' "$EVENTS" | tail -1)"
ck "registry も書いている（両方書き）" "#9" "$(jq -r '.label' "$OE_DELEGATE_STATE_DIR/4242__9.json")"
ck "子の session_id は登録しない（本人だけが登録する）" "0" "$(jq -r '.generations[0].session_ids | length' "$OE_LEASE_DIR/$lid.json")"
sed -i.bak 's/^909|.*$/909|'"$S9"'|bash|ttys009|909/' "$PS_TABLE"
bash "$BIN/oe-delegate" -w "$_TMP_DIR/ws" --label "#10" "task" >/dev/null 2>"$_TMP_DIR/d2.err" || true
lid2="$(sed -nE "s/^OE_LEASE_ID='([0-9A-HJKMNP-TV-Z]{26})' .*/\1/p" "$LOGS/split-command.log")"
ck "claude でなければ binding を書かない" "null" "$(jq -r '.generations[0].binding' "$OE_LEASE_DIR/$lid2.json")"
ck "書かなかったことを名乗る" "yes" "$(grep -q 'binding は未確定' "$_TMP_DIR/d2.err" && echo yes || echo no)"
mv "$PS_TABLE.bak" "$PS_TABLE"

echo "=== (4) oe-register の root と link ==="
rm -f "$OE_DELEGATE_STATE_DIR"/*.json
out="$(CLAUDE_PID=101 CLAUDE_CODE_SESSION_ID=sid-root bash "$BIN/oe-register" root --label cockpit -w "$_TMP_DIR/ws" 2>&1)" || true
rid="$(OE_LEASE_ID="" CLAUDE_CODE_SESSION_ID=sid-root bash "$BIN/oe-lease" whoami 2>/dev/null | jq -r '.lease_id')"
ck "root は自分の lease を作る" "supervisor" "$(jq -r '.kind' "$OE_LEASE_DIR/$rid.json" 2>/dev/null)"
ck "root の lease の binding は自分" "101" "$(jq -r '.generations[0].binding.pid' "$OE_LEASE_DIR/$rid.json" 2>/dev/null)"
ck "lease_bound（root）が残る" "root" "$(jq -r --arg l "$rid" 'select(.type=="lease_bound" and .lease_id==$l) | .bind_reason' "$EVENTS" | tail -1)"
n_before="$(find "$OE_LEASE_DIR" -name '*.json' | grep -c .)"
CLAUDE_PID=101 CLAUDE_CODE_SESSION_ID=sid-root bash "$BIN/oe-register" root --label cockpit -w "$_TMP_DIR/ws" >/dev/null 2>&1 || true
ck "もう lease があれば作らない" "$n_before" "$(find "$OE_LEASE_DIR" -name '*.json' | grep -c .)"
ck "link の前の子の lease の親は空" "" "$(jq -r '.parent_lease_id' "$OE_LEASE_DIR/$lid.json")"
printf '{"pane":"%%9","label":"#9","workspace":"%s","parent_pane":"","role":"child"}\n' "$_TMP_DIR/ws" > "$OE_DELEGATE_STATE_DIR/4242__9.json"
CLAUDE_CODE_SESSION_ID=sid-root bash "$BIN/oe-register" link %9 --force >/dev/null 2>"$_TMP_DIR/link.err" || true
ck "link は相手の lease の親を自分の lease にする" "$rid" "$(jq -r '.parent_lease_id' "$OE_LEASE_DIR/$lid.json")"

echo "=== (5) oe-lease adopt ==="
rm -rf "$OE_LEASE_DIR" "$OE_DELEGATE_STATE_DIR"; mkdir -p "$OE_DELEGATE_STATE_DIR"
printf '{"pane":"%%5","label":"cockpit","workspace":"%s","parent_pane":"","role":"child"}\n' "$_TMP_DIR/ws" > "$OE_DELEGATE_STATE_DIR/4242__5.json"
printf '{"pane":"%%9","label":"#9","workspace":"%s","parent_pane":"%%5","role":"child"}\n' "$_TMP_DIR/ws" > "$OE_DELEGATE_STATE_DIR/4242__9.json"
printf '{"pane":"%%6","label":"#6","workspace":"%s","parent_pane":"%%5","role":"child"}\n' "$_TMP_DIR/ws" > "$OE_DELEGATE_STATE_DIR/4242__6.json"
printf '{"pane":"%%1","label":"old","workspace":"%s","parent_pane":"","role":"child"}\n' "$_TMP_DIR/ws" > "$OE_DELEGATE_STATE_DIR/1111__1.json"
dry="$(bash "$BIN/oe-lease" adopt --dry-run 2>&1)"
ck "dry-run は作らない" "0" "$(find "$OE_LEASE_DIR" -name '*.json' 2>/dev/null | grep -c . || true)"
ck "dry-run は作るはずのものを出す" "2" "$(printf '%s\n' "$dry" | grep -c '^would-adopt')"
out="$(bash "$BIN/oe-lease" adopt 2>&1)"
ck "生きた claude の2つを取り込む" "2" "$(printf '%s\n' "$out" | grep -c '^adopted')"
ck "claude でないものは外す" "1" "$(printf '%s\n' "$out" | grep -c '^skipped %6')"
ck "別の server の記録は見ない" "0" "$(printf '%s\n' "$out" | grep -c '%1 ')"
sup="$(printf '%s\n' "$out" | awk '$1=="adopted" && $2=="%5" {print $3}')"
chi="$(printf '%s\n' "$out" | awk '$1=="adopted" && $2=="%9" {print $3}')"
ck "親の無いものは統括の lease" "supervisor" "$(jq -r '.kind' "$OE_LEASE_DIR/$sup.json")"
ck "子の lease の親は registry の親" "$sup" "$(jq -r '.parent_lease_id' "$OE_LEASE_DIR/$chi.json")"
ck "取り込みは session_id を登録しない" "0" "$(jq -r '.generations[0].session_ids | length' "$OE_LEASE_DIR/$chi.json")"
ck "lease_bound（adopt）が残る" "2" "$(jq -r 'select(.type=="lease_bound" and .bind_reason=="adopt") | .lease_id' "$EVENTS" | grep -c .)"
out2="$(bash "$BIN/oe-lease" adopt 2>&1)"
ck "2回走らせても増えない" "2" "$(find "$OE_LEASE_DIR" -name '*.json' | grep -c .)"
ck "2回目はもうあると言う" "2" "$(printf '%s\n' "$out2" | grep -c '^exists')"
n_adopted="$(find "$OE_LEASE_DIR" -name '*.json' | grep -c .)"
CLAUDE_PID=505 CLAUDE_CODE_SESSION_ID=sid-sup TMUX_PANE=%5 bash "$BIN/oe-register" root --label cockpit -w "$_TMP_DIR/ws" --force >/dev/null 2>&1 || true
ck "adopt のあとの root は、取り込んだ lease を使い、新しく作らない" "$n_adopted" "$(find "$OE_LEASE_DIR" -name '*.json' | grep -c .)"
ck "root は取り込んだ lease に自分の session_id を登録する" "sid-sup" "$(jq -r '.generations[0].session_ids[0] // ""' "$OE_LEASE_DIR/$sup.json")"
CLAUDE_PID=909 CLAUDE_CODE_SESSION_ID=sid-chi TMUX_PANE=%9 bash "$BIN/oe-lease" bind "$chi" -w "$_TMP_DIR/ws" >/dev/null 2>&1 || true
ck "oe-lease bind は lease_bound（rebind）を残す" "rebind" "$(jq -r --arg l "$chi" 'select(.type=="lease_bound" and .lease_id==$l) | .bind_reason' "$EVENTS" | tail -1)"
ck "bind は本人の session_id を登録する" "sid-chi" "$(jq -r '.generations[0].session_ids[0] // ""' "$OE_LEASE_DIR/$chi.json")"
for f in "$OE_LEASE_DIR"/*.json; do ck "取り込んだ記録が検査を通る（$(basename "$f" .json | cut -c1-8)）" "0" "$(rc_of bash "$PROJECT_DIR/scripts/validate-lease.sh" "$f")"; done

echo "=== (6) 本物に届く経路が無い ==="
ck "偽の道具だけが呼ばれた（記録がある）" "1" "$([ -s "$CALLS" ] && echo 1 || echo 0)"
ck "送る文は偽の tmux にだけ届いた" "1" "$([ -s "$LOGS/send-keys.log" ] && echo 1 || echo 0)"
if [ -n "$REAL_HOME" ]; then
  ck "本物の lease の置き場は、このテストで書き換わっていない" "0" "$(find "$REAL_HOME/.claude/state/oe-lease" -newer "$START_MARK" 2>/dev/null | grep -c . || true)"
fi

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
