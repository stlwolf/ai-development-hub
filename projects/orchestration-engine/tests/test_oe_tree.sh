#!/usr/bin/env bash
#
# test_oe_tree.sh — oe-tree（spawn トポロジ read-only ツリー表示・#221）を検証する
#
# 実 tmux は起動せず PATH 先頭 mock に差し替える（test_oe_jump / test_oe_select と同型）:
#   - tmux: list-panes は $MOCK_LIVE_PANES を返す（$MOCK_TMUX_FAIL=1 で失敗＝liveness ? 経路）。
#           display-message は $MOCK_PANE_TITLE を返す（pane_title fallback 用）。
#   - jq : 実体を使う（oe-tree の entry パースは実 jq のフィルタに依存）。
# state は OE_DELEGATE_STATE_DIR / OE_PANE_ISSUE_DIR の一時 dir に隔離。
# TMUX 偽値 "/tmp/mock-tmux,12345,0" で server pid = 12345 に固定（決定的 key 生成）。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

_TMP_DIR="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
[[ -n "$_TMP_DIR" && -d "$_TMP_DIR" ]] || { echo "FATAL: mktemp -d returned an invalid path: '${_TMP_DIR}'" >&2; exit 1; }
trap 'rm -rf "$_TMP_DIR"' EXIT
mkdir -p "$_TMP_DIR/bin" "$_TMP_DIR/lib" "$_TMP_DIR/pathbin"

cp "$PROJECT_DIR/bin/oe-tree" "$_TMP_DIR/bin/oe-tree"
chmod +x "$_TMP_DIR/bin/oe-tree"
ln -s "$PROJECT_DIR/lib/delegate-registry.sh" "$_TMP_DIR/lib/delegate-registry.sh"

# mock tmux: list-panes / display-message のみ意味を持つ（他は成功で素通し）
cat > "$_TMP_DIR/pathbin/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  list-panes)
    [[ "${MOCK_TMUX_FAIL:-0}" == "1" ]] && exit 1
    # shellcheck disable=SC2086
    printf '%s\n' ${MOCK_LIVE_PANES:-} ;;
  display-message)
    printf '%s\n' "${MOCK_PANE_TITLE:-}" ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$_TMP_DIR/pathbin/tmux"

# 実 jq を厳選 PATH に含める（mock は tmux のみ）
JQ_BIN="$(command -v jq)" || { echo "FATAL: jq is required to run this test" >&2; exit 1; }
JQ_DIR="$(dirname "$JQ_BIN")"
export PATH="${_TMP_DIR}/pathbin:${JQ_DIR}:/usr/bin:/bin"

export OE_DELEGATE_STATE_DIR; OE_DELEGATE_STATE_DIR="$_TMP_DIR/state"
export OE_PANE_ISSUE_DIR;     OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
mkdir -p "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"

export TMUX="/tmp/mock-tmux,12345,0"   # server pid = 12345
export TMUX_PANE="%110"                # self（case [1] の孫）

TREE="$_TMP_DIR/bin/oe-tree"

PASS=0
FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"; FAIL=$((FAIL + 1))
    echo "    --- want ---"; printf '%s\n' "$expected" | sed 's/^/    /'
    echo "    --- got ----"; printf '%s\n' "$actual"   | sed 's/^/    /'
  fi
}
reset_state() {
  rm -rf "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"
  mkdir -p "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"
}
keyfor() { printf '12345_%s' "${1//[^A-Za-z0-9]/_}"; }
mkentry() { # <pane> <label> <workspace> <parent_pane>
  jq -cn --arg pane "$1" --arg label "$2" --arg ws "$3" --arg parent "$4" \
    '{pane:$pane, label:$label, workspace:$ws, parent_pane:$parent, role:"child"}' \
    > "${OE_DELEGATE_STATE_DIR}/$(keyfor "$1").json"
}
fixture_chain() { # 実測 %49(gone)→%83→{%85→%110, %94} 型の 3 世代チェーン
  mkentry %83  "fresh-orch-2" "/w/biz-infra"    %49
  mkentry %85  "#5706"        "/w/attelu.5706"  %83
  mkentry %110 "#5706-u1"     "/w/attelu"       %85
  mkentry %94  "#36"          "/w/ecs"          %83
}

# ----------------------------------------------------------------------------
echo "[1] 3 世代チェーン: 罫線・世代・gone 合成 root・兄弟数値順・self marker・workspace"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
export MOCK_LIVE_PANES="%83 %85 %94 %110"
expected='%49  gone   ?
└─ %83  alive  fresh-orch-2 ~biz-infra
   ├─ %85  alive  #5706 ~attelu.5706
   │  └─ %110  alive  #5706-u1 ~attelu (you)
   └─ %94  alive  #36 ~ecs'
ck "chain render" "$expected" "$("$TREE")"

# ----------------------------------------------------------------------------
echo "[2] 複数 root の数値順 + parent 空 entry は自身が root"
# ----------------------------------------------------------------------------
reset_state
mkentry %8  "second-tree" "/w/two" %7
mkentry %60 "standalone"  "/w/one" ""
export MOCK_LIVE_PANES="%8 %60"
expected='%7  gone   ?
└─ %8  alive  second-tree ~two
%60  alive  standalone ~one'
ck "multi-root order" "$expected" "$("$TREE")"

# ----------------------------------------------------------------------------
echo "[3] ラベル優先順位: pane-issue(.name) > registry(.label)"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
printf '{"name":"#5706 renamed"}' > "${OE_PANE_ISSUE_DIR}/$(keyfor %85)"
export MOCK_LIVE_PANES="%83 %85 %94 %110"
actual="$("$TREE" | grep -F '%85')"
ck "pane-issue wins" '   ├─ %85  alive  #5706 renamed ~attelu.5706' "$actual"

# ----------------------------------------------------------------------------
echo "[4] label sanitize: LF/CR/TAB/US/ESC/C1 を空白へ畳む（端末制御・視覚偽装の遮断）"
# ----------------------------------------------------------------------------
reset_state
mkentry %60 $'bad\nlab\tx\037y' "/w/one" ""
mkentry %61 $'esc\033[2Jwipe\xc2\x9bcsi' "/w/esc" ""
export MOCK_LIVE_PANES="%60 %61"
expected='%60  alive  bad lab x y ~one
%61  alive  esc [2Jwipe csi ~esc'
ck "sanitized label" "$expected" "$("$TREE")"

# ----------------------------------------------------------------------------
echo "[5] 純粋 cycle: 擬似 root で描画・[cycle] 打ち切り・無限ループなし（liveness ? 経路）"
# ----------------------------------------------------------------------------
reset_state
mkentry %201 "lab201" "" %202
mkentry %202 "lab202" "" %201
export MOCK_TMUX_FAIL=1
expected='%201  ?      lab201
└─ %202  ?      lab202
   └─ %201  [cycle]'
ck "cycle cut + degrade ?" "$expected" "$("$TREE")"
unset MOCK_TMUX_FAIL

# ----------------------------------------------------------------------------
echo "[6] 異 server entry: 非表示 + footer 件数開示"
# ----------------------------------------------------------------------------
reset_state
mkentry %60 "standalone" "/w/one" ""
printf '{"pane":"%%7","label":"foreign","workspace":"/w","parent_pane":"%%1","role":"child"}' \
  > "${OE_DELEGATE_STATE_DIR}/99999__7.json"
export MOCK_LIVE_PANES="%60"
expected='%60  alive  standalone ~one
note: 1 entries from other tmux servers not shown (stale)'
ck "foreign hidden + footer" "$expected" "$("$TREE")"

# ----------------------------------------------------------------------------
echo "[7] 登記 0 件（現 server）: 空表示メッセージ + exit 0（foreign のみでも同様）"
# ----------------------------------------------------------------------------
reset_state
out="$("$TREE")"; rc=$?
ck "empty message" '(no spawn entries for this tmux server)' "$out"
ck "empty exit 0" "0" "$rc"
printf '{"pane":"%%7","label":"foreign","workspace":"/w","parent_pane":"%%1","role":"child"}' \
  > "${OE_DELEGATE_STATE_DIR}/99999__7.json"
expected='(no spawn entries for this tmux server)
note: 1 entries from other tmux servers not shown (stale)'
ck "foreign-only message" "$expected" "$("$TREE")"

# ----------------------------------------------------------------------------
echo "[8] TMUX 不在: stderr note + exit 2（scoping も liveness も成立しない）"
# ----------------------------------------------------------------------------
reset_state
mkentry %60 "standalone" "/w/one" ""
err="$(env -u TMUX -u TMUX_PANE "$TREE" 2>&1 >/dev/null)"; rc=$?
ck "tmux-less exit 2" "2" "$rc"
ck "tmux-less note" "yes" "$(printf '%s' "$err" | grep -q 'not inside tmux' && echo yes || echo no)"

# ----------------------------------------------------------------------------
echo "[9] pane_title fallback: 空 label + alive のみ（pane-issue > registry > title の最後段）"
# ----------------------------------------------------------------------------
reset_state
mkentry %70 "" "/w/seventy" ""
export MOCK_LIVE_PANES="%70"
export MOCK_PANE_TITLE="picked up title"
ck "title fallback" '%70  alive  picked up title ~seventy' "$("$TREE")"
export MOCK_PANE_TITLE=$'spoof\033]0;t\007end'
ck "title sanitize (OSC/BEL)" '%70  alive  spoof ]0;t end ~seventy' "$("$TREE")"
unset MOCK_PANE_TITLE

# ----------------------------------------------------------------------------
echo "[10] gone 中間ノード: 親子とも登記あり・中間だけ gone でも子は描画"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
export MOCK_LIVE_PANES="%83 %94 %110"   # %85 が gone
actual="$("$TREE" | grep -cE '%85  gone|%110  alive')"
ck "gone mid keeps child" "2" "$actual"

# ----------------------------------------------------------------------------
echo "[11] 壊れ JSON / 不正 pane / 重複 pane: skip 件数を footer 開示・有効 entry は描画"
# ----------------------------------------------------------------------------
reset_state
mkentry %60 "standalone" "/w/one" ""
printf '{broken' > "${OE_DELEGATE_STATE_DIR}/12345__901.json"
printf '{"pane":"nope","label":"x","workspace":"","parent_pane":"","role":"child"}' \
  > "${OE_DELEGATE_STATE_DIR}/12345__902.json"
printf '{"pane":"%%60","label":"dup","workspace":"","parent_pane":"","role":"child"}' \
  > "${OE_DELEGATE_STATE_DIR}/12345__903.json"
export MOCK_LIVE_PANES="%60"
expected='%60  alive  standalone ~one
note: 3 entries skipped (unreadable or duplicate pane)'
ck "partial skip disclosed" "$expected" "$("$TREE")"

# ----------------------------------------------------------------------------
echo "[12] 現 server entry が全滅（壊れのみ）: 「登記なし」と偽らず readable 無しを明示 + exit 0"
# ----------------------------------------------------------------------------
reset_state
printf '{broken' > "${OE_DELEGATE_STATE_DIR}/12345__901.json"
out="$("$TREE")"; rc=$?
expected='(no readable spawn entries for this tmux server)
note: 1 entries skipped (unreadable or duplicate pane)'
ck "all-broken message" "$expected" "$out"
ck "all-broken exit 0" "0" "$rc"

# ----------------------------------------------------------------------------
echo "[13] 引数: --help は exit 0 / 未知引数は exit 2"
# ----------------------------------------------------------------------------
"$TREE" --help >/dev/null 2>&1; ck "help exit 0" "0" "$?"
"$TREE" bogus  >/dev/null 2>&1; ck "unknown arg exit 2" "2" "$?"

# ----------------------------------------------------------------------------
echo
echo "PASS=${PASS} FAIL=${FAIL}"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
