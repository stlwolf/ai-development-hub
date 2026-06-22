#!/usr/bin/env bash
set -euo pipefail

# test_event_bus.sh — lib/event-bus.sh（#206 増分1 活動ログ emit）の検証。
#
# 実 tmux 不要（emit は file 読みのみ・liveness は viewer 側）。registry/pane-issue は mock し、
# 固定 server pid（TMUX 経由）でキー名前空間を固定する（test_oe_ident と同イディオム）。jq は実体。
# 末尾に oe-delegate を PATH-stub tmux で 1 回起動し、child_spawned が実 bin から emit される
# 結線も検証する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
export OE_EVENT_DIR="$_TMP_DIR/events"
export OE_DELEGATE_STATE_DIR="$_TMP_DIR/oe-delegate"
export OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
mkdir -p "$OE_EVENT_DIR" "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"
EVENTS="$OE_EVENT_DIR/oe-events.jsonl"

# shellcheck source=../lib/delegate-registry.sh
source "$PROJECT_DIR/lib/delegate-registry.sh"
# shellcheck source=../lib/event-bus.sh
source "$PROJECT_DIR/lib/event-bus.sh"

PID=9999
export TMUX="oe,${PID},0"
keyfor() { TMUX="oe,${PID},0" _oe_reg_key "$1"; }

PASS=0; FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then echo "  PASS: $label"; PASS=$((PASS+1));
  else echo "  FAIL: $label (want=[$expected] got=[$actual])"; FAIL=$((FAIL+1)); fi
}
reset_events() { : > "$EVENTS"; }
last() { tail -n 1 "$EVENTS"; }
nlines() { [[ -s "$EVENTS" ]] && wc -l < "$EVENTS" | tr -d '[:space:]' || echo 0; }

# --- mock 状態: parent %59（pane-issue ラベル）、child %66（spawn entry・parent=%59）---
printf '{"name":"#206 inbox"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %59)"
jq -cn '{pane:"%66",label:"#206 impl",workspace:"/w",parent_pane:"%59",role:"child"}' \
  > "$OE_DELEGATE_STATE_DIR/$(keyfor %66).json"

echo "[1] child_spawned: from=parent(label 解決) / to=child(label 引数) / role 固定"
reset_events
oe_event_child_spawned "%59" "%66" "#206 impl"
ck "type"        "child_spawned"  "$(last | jq -r .type)"
ck "from.pane"   "%59"            "$(last | jq -r .from.pane)"
ck "from.role"   "parent"         "$(last | jq -r .from.role)"
ck "from.label"  "#206 inbox"     "$(last | jq -r .from.label)"
ck "to.pane"     "%66"            "$(last | jq -r .to.pane)"
ck "to.role"     "child"          "$(last | jq -r .to.role)"
ck "to.label"    "#206 impl"      "$(last | jq -r .to.label)"
ck "ts present"  "true"           "$(last | jq -r '(.ts|type=="string") and (.ts|length>0)')"

echo "[2] message_sent report（子→親）: 直接 parent リンクで from=child/to=parent に確定"
reset_events
oe_event_message_sent "%66" "%59" "実装完了しました" "none"
ck "type"           "message_sent" "$(last | jq -r .type)"
ck "from.role=child" "child"       "$(last | jq -r .from.role)"
ck "to.role=parent"  "parent"      "$(last | jq -r .to.role)"
ck "preview"         "実装完了しました" "$(last | jq -r .preview)"
ck "delivery none"   "none"        "$(last | jq -r .delivery_signal)"

echo "[3] message_sent kick（親→子）: from=parent/to=child・delivery=suspected_miss"
reset_events
oe_event_message_sent "%59" "%66" "増分1を進めて" "suspected_miss"
ck "from.role=parent" "parent"        "$(last | jq -r .from.role)"
ck "to.role=child"    "child"         "$(last | jq -r .to.role)"
ck "delivery miss"    "suspected_miss" "$(last | jq -r .delivery_signal)"

echo "[4] preview 切り詰め: >100 codepoint → 100 + … (length 101)・末尾 …"
reset_events
LONG="$(printf 'あ%.0s' {1..150})"
oe_event_message_sent "%66" "%59" "$LONG" "none"
ck "preview length 101" "101" "$(last | jq -r '.preview|length')"
ck "preview ends …"     "true" "$(last | jq -r '.preview|endswith("…")')"

echo "[5] preview ≤100 はそのまま（… を付けない）"
reset_events
oe_event_message_sent "%66" "%59" "短い報告" "none"
ck "short unchanged" "短い報告" "$(last | jq -r .preview)"

echo "[6] delivery_signal 未知値は none に正規化"
reset_events
oe_event_message_sent "%66" "%59" "x" "garbage-value"
ck "unknown→none" "none" "$(last | jq -r .delivery_signal)"

echo "[7] OE_EVENT_LOG=0 で kill-switch（書き込まない）"
reset_events
OE_EVENT_LOG=0 oe_event_child_spawned "%59" "%66" "#206 impl"
OE_EVENT_LOG=0 oe_event_message_sent "%59" "%66" "x" "none"
ck "no write when off" "0" "$(nlines)"

echo "[8] label 内の改行（JSON 文字列内エスケープ）は焼く前に畳む（行境界の偽造防止）"
reset_events
printf '%s' '{"name":"#206\ninbox"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %59)"  # JSON 内 escape \n
oe_event_child_spawned "%59" "%66" "#206 impl"
ck "1 physical line" "1" "$(nlines)"
ck "label folded"    "#206 inbox" "$(last | jq -r .from.label)"
printf '%s' '{"name":"#206 inbox"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %59)"  # 復元

echo "[9] 関係不明（spawn 関係の無い 2 ペイン）: role は空・fallback で type は出る"
reset_events
oe_event_message_sent "%80" "%81" "side chat" "none"
ck "from.role empty" "" "$(last | jq -r .from.role)"
ck "to.role empty"   "" "$(last | jq -r .to.role)"
ck "type"            "message_sent" "$(last | jq -r .type)"

echo "[10] 結線: oe-delegate を PATH-stub tmux で起動 → child_spawned が実 bin から emit"
reset_events
STUB_BIN="$_TMP_DIR/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  split-window) printf '%%9\n' ;;
  list-panes)   printf '%%1\n%%9\n' ;;
  send-keys)    : ;;
  display-message) printf '0\n' ;;
  *) : ;;
esac
exit 0
EOF
chmod +x "$STUB_BIN/tmux"
# claude を no-op に（子コマンドは split-window が無視するので不要だが PATH は隔離）。
env PATH="$STUB_BIN:$PATH" TMUX="oe,${PID},0" TMUX_PANE="%1" \
    OE_DELEGATE_WAIT_SEC=0 OE_SEND_FINALIZE=0 OE_SEND_ENTER_DELAY=0 \
    OE_EVENT_DIR="$OE_EVENT_DIR" OE_DELEGATE_STATE_DIR="$OE_DELEGATE_STATE_DIR" OE_PANE_ISSUE_DIR="$OE_PANE_ISSUE_DIR" \
    bash "$PROJECT_DIR/bin/oe-delegate" --label "#child" -- "やること" >/dev/null 2>&1 || true
ck "child_spawned emitted" "1" "$(jq -rs '[.[]|select(.type=="child_spawned" and .to.pane=="%9")]|length' "$EVENTS" 2>/dev/null || echo 0)"
ck "child label burned-in" "#child" "$(jq -rs 'map(select(.type=="child_spawned"))[-1].to.label' "$EVENTS" 2>/dev/null || echo MISSING)"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
