#!/usr/bin/env bash
set -euo pipefail

# test_oe_report.sh — bin/oe-report（legacy 申し送り verb）の oe_send_line 載せ替え検証（#206A S9）。
#
# 生 send-keys 時代は message_sent を emit せず活動ログの盲点だった。載せ替え後は
# oe-send と同じ transport（1 行保証・死ペイン検知・emit）に乗ることを PATH-stub tmux で検証する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_REPORT="$PROJECT_DIR/bin/oe-report"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
export OE_EVENT_DIR="$_TMP_DIR/events"
export OE_DELEGATE_STATE_DIR="$_TMP_DIR/oe-delegate"
export OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
mkdir -p "$OE_EVENT_DIR" "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"
EVENTS="$OE_EVENT_DIR/oe-events.jsonl"

# stub tmux: %1(親)/%9(子) が生存。send-keys は no-op。
STUB_BIN="$_TMP_DIR/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  list-panes)      printf '%%1\n%%9\n' ;;
  display-message) printf '0\n' ;;
  *) : ;;
esac
exit 0
EOF
chmod +x "$STUB_BIN/tmux"

PASS=0; FAIL=0
ck() { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
last() { tail -n 1 "$EVENTS"; }
nlines() { [[ -s "$EVENTS" ]] && wc -l < "$EVENTS" | tr -d '[:space:]' || echo 0; }
run() {
  env PATH="$STUB_BIN:$PATH" TMUX="oe,9999,0" TMUX_PANE="%9" PARENT_TMUX_PANE="%1" \
      OE_SEND_FINALIZE=0 OE_SEND_ENTER_DELAY=0 bash "$OE_REPORT" "$@"
}

echo "[1] 申し送り: message_sent が emit される（載せ替え前は emit ゼロ＝盲点）"
rc=0; run "実装が完了しました" >/dev/null 2>&1 || rc=$?
ck "rc=0"        "0" "$rc"
ck "emitted"     "1" "$(nlines)"
ck "type"        "message_sent" "$(last | jq -r .type)"
ck "from=子 %9"   "%9" "$(last | jq -r .from.pane)"
ck "to=親 %1"     "%1" "$(last | jq -r .to.pane)"
ck "preview に prefix" "申し送り: 実装が完了しました" "$(last | jq -r .preview)"

echo "[2] --review: プレフィックスが変わる"
run --review "PR #999 を見てください" >/dev/null 2>&1
ck "preview" "レビュー依頼: PR #999 を見てください" "$(last | jq -r .preview)"

echo "[3] 改行入り message は送信拒否（oe_send_line の 1 行保証・emit もされない）"
before="$(nlines)"
rc=0; run "$(printf 'line1\nline2')" >/dev/null 2>&1 || rc=$?
ck "rc=2（fail-fast）" "2" "$rc"
ck "emit されない"     "$before" "$(nlines)"

echo "[4] 死ペイン宛て（PARENT_TMUX_PANE が list-panes に無い）: 無言送信せず非0"
rc=0; env PATH="$STUB_BIN:$PATH" TMUX="oe,9999,0" TMUX_PANE="%9" PARENT_TMUX_PANE="%404" \
      OE_SEND_FINALIZE=0 bash "$OE_REPORT" "x" >/dev/null 2>&1 || rc=$?
ck "rc=1（pane not found）" "1" "$rc"

echo "[5] 親未解決（env も file も無し）: exit 1"
rc=0; env -u PARENT_TMUX_PANE -u TMUX_PANE PATH="$STUB_BIN:$PATH" bash "$OE_REPORT" "x" >/dev/null 2>&1 || rc=$?
ck "rc=1" "1" "$rc"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]