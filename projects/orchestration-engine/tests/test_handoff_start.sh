#!/usr/bin/env bash
# test_handoff_start.sh — oe-handoff start が「自分のペイン」を割ることを見る。
#
# 主張は2つある。
#   1. split-window に -t が渡り、その値が自分のペイン（TMUX_PANE）である。
#      -t を渡さない split-window は**フォーカスしているペイン**を割るので、前任が自分の
#      ペインを割るつもりで撃っても別の window に出る（実地で踏んだ・2026-09-14）。
#   2. TMUX_PANE が空なら、割る先が決まらないので **split-window を撃たずに** exit 2 で止まる。
#      黙って撃つと、どのペインを割ったか誰にも分からない形で事故が起きる。
#
# tmux は OE_HANDOFF_TMUX のノブで stub に差し替える。**本物のペインを割らない。**
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_HANDOFF="$PROJECT_DIR/bin/oe-handoff"

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

PASS=0; FAIL=0
ck()  { if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }

WS="$_TMP_DIR/ws"; STUB="$_TMP_DIR/stub"
mkdir -p "$WS/.oe" "$STUB"
CALL_LOG="$_TMP_DIR/calls.log"; : > "$CALL_LOG"

# 引き継ぎ文書。機械の節の開始マークが要る（無いと start は手前で落ちる）。
cat > "$WS/.oe/handoff.md" <<'HANDOFF'
# 引き継ぎ
<!-- oe-handoff:machine:begin -->
- 生成時刻: 2026-09-14 00:00 JST
<!-- oe-handoff:machine:end -->
HANDOFF

# tmux の stub。split-window は引数を記録して固定のペイン id を返す。
# list-panes はその id を含めて返すので、start は「現れた」と判定して先へ進む。
cat > "$STUB/tmux" <<'STUBEOF'
#!/usr/bin/env bash
printf 'tmux %s\n' "$*" >> "$CALL_LOG"
case "${1:-}" in
  split-window) printf '%%99\n'; exit 0 ;;
  list-panes)   printf '%%11\n%%99\n'; exit 0 ;;
esac
exit 0
STUBEOF
# oe-send の stub（送信は本題ではないので成功させる）
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/send"
chmod +x "$STUB"/*
export CALL_LOG
export OE_HANDOFF_TMUX="$STUB/tmux" OE_HANDOFF_SEND="$STUB/send" OE_HANDOFF_CLAUDE="claude"
export OE_HANDOFF_START_WAIT=1 OE_HANDOFF_START_SETTLE=0

echo "[1] split-window に -t が渡り、値が自分のペインである"
: > "$CALL_LOG"
TMUX_PANE="%11" bash "$OE_HANDOFF" start -w "$WS" >/dev/null 2>&1
ck  "split-window を1回呼ぶ" "1" "$(grep -c 'split-window' "$CALL_LOG" | tr -d ' ')"
ckc "-t に自分のペインを渡す" "$(grep 'split-window' "$CALL_LOG")" "-t %11"

echo "[2] TMUX_PANE が空なら撃たずに止まる"
: > "$CALL_LOG"
out="$(TMUX_PANE="" bash "$OE_HANDOFF" start -w "$WS" 2>&1)"; rc=$?
ck  "exit 2 で終わる" "2" "$rc"
ck  "split-window を呼ばない" "0" "$(grep -c 'split-window' "$CALL_LOG" | tr -d ' ')"
ckc "理由を言う" "$out" "自分のペインが分かりません"

echo "[3] dry-run は割る先を表示し、何も割らない"
: > "$CALL_LOG"
out="$(TMUX_PANE="%11" bash "$OE_HANDOFF" start -w "$WS" --dry-run 2>&1)"; rc=$?
ck  "exit 0 で終わる" "0" "$rc"
ck  "split-window を呼ばない" "0" "$(grep -c 'split-window' "$CALL_LOG" | tr -d ' ')"
ckc "割る先を出す" "$out" "割る先"
ckc "割る先が自分のペインである" "$out" "%11"

echo
echo "=== RESULT: pass=$PASS fail=$FAIL ==="
[ "$FAIL" -eq 0 ]
