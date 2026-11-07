#!/usr/bin/env bash
# shellcheck disable=SC2031  # lib() が lib を読む subshell は OE_LEASE_DIR などの export 済みの値を変えない
set -euo pipefail

# test_lease_observe.sh — #577 PR-5（観測する側）の検証
#
# 見るもの:
#   (A) oe-tree --lease: 統括 → 子 → 孫の木を lease の記録から描く。生きたノードは本人を確かめたペインを出す
#   (B) M2: tmux を起こし直したあと（server の pid が替わり、前のプロセスが無い）も、前の統括と子を
#       「プロセスが無い（gone）」として出す。$TMUX が無くても描く
#   (C) 親の lease が閉じた子は、根として出し、親が開いていないことを書く
#   (D) 本物の ~/.claude/state/ と本物の tmux・ps・ペインに届く経路が無い

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$PROJECT_DIR/bin"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
REAL_HOME="${HOME:-}"
export HOME="$_TMP_DIR/home"; mkdir -p "$HOME"
START_MARK="$_TMP_DIR/.start-mark"; : > "$START_MARK"
unset CLAUDE_PID CLAUDE_CODE_SESSION_ID OE_LEASE_ID OE_GENERATION PARENT_TMUX_PANE OE_LEASE_SERVER_PID 2>/dev/null || true

export OE_LEASE_DIR="$_TMP_DIR/lease" OE_DELEGATE_STATE_DIR="$_TMP_DIR/registry" OE_HEARTBEAT_DIR="$_TMP_DIR/heartbeat"
export OE_EVENT_DIR="$_TMP_DIR/events" OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue" OE_LEASE_LOCK_RETRY=3
export TMUX="/tmp/fake-tmux,4242,0" TMUX_PANE="%1"
mkdir -p "$OE_LEASE_DIR" "$OE_DELEGATE_STATE_DIR" "$OE_HEARTBEAT_DIR"
WS="$_TMP_DIR/ws"; mkdir -p "$WS"

# shellcheck source=fixtures/fake-proc.sh
. "$SCRIPT_DIR/fixtures/fake-proc.sh"
fake_proc_setup "$_TMP_DIR/fakeproc"
S1='Sat Nov  7 09:00:00 2026'; S2='Sat Nov  7 09:10:00 2026'; S3='Sat Nov  7 09:20:00 2026'
fake_proc_add 901 "$S1" claude ttys001 901
fake_proc_add 902 "$S2" claude ttys002 902
fake_proc_add 903 "$S3" claude ttys003 903
for n in 1 2 3; do fake_pane_add "%$n" "/dev/ttys00$n"; done

# PATH の tmux も偽物にする（既定の表示が本物の tmux を読まないため）。ペインの一覧だけを返す。
STUB="$_TMP_DIR/stub"; mkdir -p "$STUB"
cat > "$STUB/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in list-panes) printf '%%1\n' ;; esac
exit 0
EOF
chmod +x "$STUB/tmux"; export PATH="$STUB:$PATH"

PASS=0; FAIL=0
ck()  { if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }

lib() { ( set +e
  # shellcheck source=../lib/lease.sh
  . "$PROJECT_DIR/lib/lease.sh"; "$@" ); }
NOW="$(date +%s)"
beat() { jq -cn --arg p "$2" --argjson t "$NOW" --arg s "$3" '{ts:$t, context_pct:10, pane:$p, server_pid:$s}' > "$OE_HEARTBEAT_DIR/$1.json"; }
mk_lease() { # <kind> <label> <pid> <started> <session_id> [parent]
  local id; id="$(lib oe_lease_create "$1" "$2" "$WS" "${6:-}" 1)"
  lib oe_lease_claim "$id" 0 "$3" "$4" claude "$5"; printf '%s' "$id"; }
line_of() { printf '%s\n' "$1" | grep -F -- "lease $2"; }

SUP="$(mk_lease supervisor cockpit 901 "$S1" sid-1)"; beat sid-1 %1 4242
C="$(mk_lease delegation '#900' 902 "$S2" sid-2 "$SUP")"; beat sid-2 %2 4242
G="$(mk_lease delegation '#901' 903 "$S3" sid-3 "$C")"; beat sid-3 %3 4242

echo "=== (A) lease の記録から木を描く ==="
OUT="$(bash "$BIN/oe-tree" --lease 2>&1)"; RC=$?
ck  "0 で終わる" "0" "$RC"
ck  "根は統括（1行目）" "cockpit" "$(printf '%s\n' "$OUT" | head -1 | awk '{print $1}')"
ckc "子は統括の下" "$(line_of "$OUT" "$C")" "└─ #900"
ckc "孫は子の下（字下げが1段深い）" "$(line_of "$OUT" "$G")" "   └─ #901"
ckc "生きた統括のペインを出す" "$(line_of "$OUT" "$SUP")" "alive  %1"
ckc "生きた孫のペインを出す" "$(line_of "$OUT" "$G")" "alive  %3"
ckc "generation を出す" "$(line_of "$OUT" "$SUP")" "supervisor gen 1"

echo "=== (B) M2: tmux を起こし直したあとも前の統括と子を出す ==="
# 新しい tmux server（pid 5555）。前のプロセスはどれも終わっている。前の server の拍動は残っている。
: > "$FAKE_PROC_DIR/ps.table"; : > "$FAKE_PROC_DIR/panes"
fake_proc_add 990 'Sat Nov  7 12:00:00 2026' claude ttys001 990; fake_pane_add %1 /dev/ttys001
OUT="$(TMUX="/tmp/fake-tmux2,5555,0" bash "$BIN/oe-tree" --lease 2>&1)"; RC=$?
ck  "0 で終わる" "0" "$RC"
ckc "前の統括を gone で出す" "$(line_of "$OUT" "$SUP")" "gone  -"
ckc "前の子を gone で出す" "$(line_of "$OUT" "$C")" "gone  -"
ckc "前の孫を gone で出す" "$(line_of "$OUT" "$G")" "gone  -"
ck  "木の形は残る（3行）" "3" "$(printf '%s\n' "$OUT" | grep -c ' lease ')"
REGOUT="$(TMUX="/tmp/fake-tmux2,5555,0" bash "$BIN/oe-tree" 2>&1 || true)"
ck  "registry から描く既定の表示には前の server の子は出ない（--lease との違い）" "0" "$(printf '%s\n' "$REGOUT" | grep -c '#900' || true)"
OUT="$(env -u TMUX bash "$BIN/oe-tree" --lease 2>&1)"; RC=$?
ck  "\$TMUX が無くても描く" "0" "$RC"
ck  "\$TMUX が無くても3行" "3" "$(printf '%s\n' "$OUT" | grep -c ' lease ')"

echo "=== (C) 親の lease が閉じた子は根として出す ==="
lib oe_lease_close "$C" "$(lib oe_lease_epoch "$C")" >/dev/null || true
OUT="$(bash "$BIN/oe-tree" --lease 2>&1)"
ckc "親が開いていないと書く" "$OUT" "(親の lease ${C} は開いていない)"
ck  "閉じた子は出さない" "0" "$(printf '%s\n' "$OUT" | grep -c "  lease ${C}\$" || true)"
ckc "孫は根として出る" "$OUT" "#901"
# 親の連鎖が循環している2件（A の親が B、B の親が A）も、黙って落とさずに出す（実装SO の指摘）
CA="$(lib oe_lease_create delegation '#cyc-a' "$WS" "" 1)"; CB="$(lib oe_lease_create delegation '#cyc-b' "$WS" "$CA" 1)"
lib oe_lease_set_parent "$CA" "$(lib oe_lease_epoch "$CA")" "$CB" >/dev/null
OUT="$(bash "$BIN/oe-tree" --lease 2>&1)"; RC=$?
ck  "循環があっても 0 で終わる" "0" "$RC"
ckc "循環していると書く" "$OUT" "(親の lease の連鎖が循環している)"
ck  "循環した2件をどちらも1度ずつ出す" "2" "$(printf '%s\n' "$OUT" | grep -c '#cyc-' || true)"
set +e; OUT="$(bash "$BIN/oe-tree" --lease --watch 2>&1)"; RC=$?; set -e
ck  "ほかの指定とは併用できない（2）" "2" "$RC"

echo "=== (D) 本物に届く経路が無い ==="
if [ -n "$REAL_HOME" ]; then
  ck "本物の lease の置き場は、このテストで書き換わっていない" "0" "$(find "$REAL_HOME/.claude/state/oe-lease" -newer "$START_MARK" 2>/dev/null | grep -c . || true)"
fi

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
