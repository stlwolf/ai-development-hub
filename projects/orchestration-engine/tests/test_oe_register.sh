#!/usr/bin/env bash
set -uo pipefail

# test_oe_register.sh — oe-register（自己 root 登録 + 委譲 link・#259）の検証。
#
# 実 tmux / Claude は起動せず、PATH 先頭の tmux mock で list-panes / display-message を差し替える
# （test_oe_delegate.sh と同イディオム）。state dir は mktemp で隔離し、キー生成は lib の
# _oe_reg_key を共有する（手書き複製のドリフト回避・test_oe_ident.sh と同方針）。
#
# guard 真理値表（plan §4 rev.2）と設計SO が挙げた縁ケース（target 非生存 no-op / %self
# self-cycle / 自己 root の生きた親 detach）を機械検証する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_REGISTER="$PROJECT_DIR/bin/oe-register"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
export OE_DELEGATE_STATE_DIR="$_TMP_DIR/oe-delegate"
export OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
mkdir -p "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"

# 固定 server pid をキー名前空間に注入（本体 _oe_reg_key と同一契約）。
PID=9999
export TMUX="oe,${PID},0"
# shellcheck source=../lib/delegate-registry.sh
source "$PROJECT_DIR/lib/delegate-registry.sh"
keyfor() { _oe_reg_key "$1"; }

# --- PATH 先頭 tmux mock（MOCK_LIVE_PANES / MOCK_TMUX_FAIL / MOCK_CWD を env で受ける） ---
STUB_BIN="$_TMP_DIR/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  list-panes)
    if [[ -n "${MOCK_TMUX_FAIL:-}" ]]; then echo "no server running" >&2; exit 1; fi
    # shellcheck disable=SC2086
    printf '%s\n' ${MOCK_LIVE_PANES:-} ;;
  display-message) printf '%s\n' "${MOCK_CWD:-/mock/cwd}" ;;
  *) : ;;
esac
exit 0
EOF
chmod +x "$STUB_BIN/tmux"
export PATH="${STUB_BIN}:${PATH}"
export MOCK_LIVE_PANES=""
export MOCK_CWD="/mock/cwd"

PASS=0; FAIL=0
ck() { # <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1));
  else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi
}

reset_state() { rm -f "$OE_DELEGATE_STATE_DIR"/*.json 2>/dev/null; }
put_entry() { # <pane> <parent_pane> [label]
  jq -cn --arg p "$1" --arg pp "$2" --arg l "${3:-}" \
    '{pane:$p,label:$l,workspace:"/w",parent_pane:$pp,role:"child"}' \
    > "$OE_DELEGATE_STATE_DIR/$(keyfor "$1").json"
}
ent_exists() { [[ -f "$OE_DELEGATE_STATE_DIR/$(keyfor "$1").json" ]] && echo yes || echo no; }
ent_parent() { jq -r '.parent_pane // "MISSING"' "$OE_DELEGATE_STATE_DIR/$(keyfor "$1").json" 2>/dev/null || echo MISSING; }
run_reg() { # <self-pane> <args...>  -> sets global RC
  local self="$1"; shift
  RC=0
  TMUX_PANE="$self" bash "$OE_REGISTER" "$@" >/dev/null 2>&1 || RC=$?
}

echo "[1] root: 引数なし相当 -> 自 entry が parent_pane 空で書かれる"
reset_state; export MOCK_LIVE_PANES="%1"
run_reg "%1" root
ck "root exit 0"        "0"  "$RC"
ck "root entry exists"  "yes" "$(ent_exists %1)"
ck "root parent empty"  ""   "$(ent_parent %1)"

echo "[2] link %5: %5 entry が parent_pane=self(%1) で書かれる"
reset_state; export MOCK_LIVE_PANES="%1 %5"
run_reg "%1" link %5 --label "#259 child"
ck "link exit 0"          "0"   "$RC"
ck "link entry exists"    "yes" "$(ent_exists %5)"
ck "link parent = self"   "%1"  "$(ent_parent %5)"

echo "[3] guard: 生存する別親を持つ %5 -> 拒否・entry 不変"
reset_state; export MOCK_LIVE_PANES="%1 %5 %9"
put_entry %5 %9 "#other"        # %5 は生存 %9 の子
run_reg "%1" link %5
ck "steal rejected exit 1" "1"  "$RC"
ck "parent unchanged (%9)"  "%9" "$(ent_parent %5)"

echo "[4] guard: orphan（親 %9 が gone）-> 引き取り可・reparent"
reset_state; export MOCK_LIVE_PANES="%1 %5"   # %9 は非生存
put_entry %5 %9 "#orphan"
run_reg "%1" link %5
ck "orphan adopt exit 0"   "0"  "$RC"
ck "reparented to self"    "%1" "$(ent_parent %5)"

echo "[5] guard: --force で生存別親を上書き（reparent）"
reset_state; export MOCK_LIVE_PANES="%1 %5 %9"
put_entry %5 %9 "#other"
run_reg "%1" link %5 --force
ck "force reparent exit 0"  "0" "$RC"
ck "force parent = self"    "%1" "$(ent_parent %5)"

echo "[6] 冪等: 既に自分の子 %5 を再 link / 既に root を再 root"
reset_state; export MOCK_LIVE_PANES="%1 %5"
put_entry %5 %1 "#mine"
run_reg "%1" link %5
ck "idempotent link exit 0" "0"  "$RC"
ck "still my child"          "%1" "$(ent_parent %5)"
put_entry %1 "" "#sup"          # %1 は既に root
run_reg "%1" root
ck "idempotent root exit 0"  "0" "$RC"
ck "root stays empty parent"  "" "$(ent_parent %1)"

echo "[7] guard: target %5 が非生存 -> 拒否・record しない（無言 no-op 防止・SO 抜け1）"
reset_state; export MOCK_LIVE_PANES="%1"        # %5 は居ない
run_reg "%1" link %5
ck "dead target exit 1"    "1"  "$RC"
ck "no entry written"      "no" "$(ent_exists %5)"

echo "[8] guard: link %self -> 拒否（self-cycle・SO 抜け2）"
reset_state; export MOCK_LIVE_PANES="%1"
run_reg "%1" link %1
ck "self-link exit 1"      "1"  "$RC"
ck "no self-cycle entry"   "no" "$(ent_exists %1)"

echo "[9] guard: 生きた親を持つ委譲子が自己 root -> 拒否（detach 防止・SO 抜け3）/ --force で許可"
reset_state; export MOCK_LIVE_PANES="%1 %9"
put_entry %1 %9 "#delegated"    # %1 は生存 %9 の子
run_reg "%1" root
ck "self-root detach rejected" "1"  "$RC"
ck "parent unchanged (%9)"     "%9" "$(ent_parent %1)"
run_reg "%1" root --force
ck "force re-root exit 0"      "0"  "$RC"
ck "force re-rooted (empty)"   ""   "$(ent_parent %1)"

echo "[10] --label に LF/CR -> exit 2・書込なし"
reset_state; export MOCK_LIVE_PANES="%1 %5"
run_reg "%1" link %5 --label $'bad\nlabel'
ck "LF label exit 2"       "2"  "$RC"
ck "no entry on LF label"  "no" "$(ent_exists %5)"

echo "[11] 形式エラー: 不正 target / 未知 subcommand -> exit 2（typo を silently 通さない・DJ-6）"
reset_state; export MOCK_LIVE_PANES="%1 %5"
run_reg "%1" link 5           ; ck "non-%N target exit 2" "2" "$RC"
run_reg "%1" link "%5x"       ; ck "malformed %N exit 2"  "2" "$RC"
run_reg "%1" bogus            ; ck "unknown subcommand 2" "2" "$RC"
run_reg "%1"                  ; ck "missing subcommand 2" "2" "$RC"

echo "[12] tmux list-panes 失敗 -> exit 2・書込なし"
reset_state; export MOCK_LIVE_PANES="%1 %5"; export MOCK_TMUX_FAIL=1
run_reg "%1" link %5
ck "list-panes fail exit 2" "2"  "$RC"
ck "no entry on tmux fail"  "no" "$(ent_exists %5)"
unset MOCK_TMUX_FAIL

echo "[13] TMUX_PANE 未設定 -> 明示エラー（exit 1）"
reset_state
RC=0; TMUX_PANE="" bash "$OE_REGISTER" root >/dev/null 2>&1 || RC=$?
ck "no TMUX_PANE exit 1" "1" "$RC"

echo "[14] SELF（TMUX_PANE）が非生存 -> 拒否（stale/spoofed TMUX_PANE・実装SO codex 指摘）"
reset_state; export MOCK_LIVE_PANES="%5"        # %1(self) が live 一覧に居ない
run_reg "%1" root
ck "dead self root exit 1"  "1"  "$RC"
ck "no root entry written"  "no" "$(ent_exists %1)"
run_reg "%1" link %5
ck "dead self link exit 1"  "1"  "$RC"
ck "no link entry written"  "no" "$(ent_exists %5)"

echo "[15] 既存 entry が corrupt -> fail-closed（--force で上書き・実装SO codex 指摘）"
reset_state; export MOCK_LIVE_PANES="%1 %5"
printf 'not-json{{{' > "$OE_DELEGATE_STATE_DIR/$(keyfor %5).json"
run_reg "%1" link %5
ck "corrupt target reject exit 1" "1"   "$RC"
ck "corrupt entry not overwritten" "yes" "$(ent_exists %5)"
run_reg "%1" link %5 --force
ck "corrupt target --force exit 0" "0"  "$RC"
ck "force wrote valid parent"      "%1" "$(ent_parent %5)"
# root 側: 自 entry が corrupt
reset_state; export MOCK_LIVE_PANES="%1"
printf 'broken' > "$OE_DELEGATE_STATE_DIR/$(keyfor %1).json"
run_reg "%1" root
ck "corrupt self root reject"   "1" "$RC"
run_reg "%1" root --force
ck "corrupt self root --force"  "0" "$RC"
ck "force wrote valid root"     ""  "$(ent_parent %1)"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
