#!/usr/bin/env bash
#
# test_oe_tree.sh — oe-tree（spawn トポロジ read-only ツリー表示・#221 / --watch + 座標 #223）を検証する
#
# 実 tmux は起動せず PATH 先頭 mock に差し替える（test_oe_jump / test_oe_select と同型）:
#   - tmux: list-panes は $MOCK_LIVE_LINES（タブ区切り pane<TAB>座標・verbatim）優先、
#           無ければ $MOCK_LIVE_PANES（pane のみ＝座標 "-" 経路）。$MOCK_TMUX_FAIL=1 で失敗＝liveness ? 経路。
#           display-message は format 引数で分岐: '#{pane_id}' → $MOCK_ACTIVE_PANE（(you) fallback 用）/
#           それ以外 → $MOCK_PANE_TITLE（pane_title fallback 用）。
#   - jq : 実体を使う（oe-tree の entry パースは実 jq のフィルタに依存）。
# state は OE_DELEGATE_STATE_DIR / OE_PANE_ISSUE_DIR の一時 dir に隔離。
# TMUX 偽値 "/tmp/mock-tmux,12345,0" で server pid = 12345 に固定（決定的 key 生成）。
# --watch は非 TTY（stdin=/dev/null）の background 起動 → kill で 1 tick 分を検証
# （EOF-safe sleep 経路の検証を兼ねる。実 popup の視覚・q/Esc 対話終了は自動テストでは
# 覆えない構造的限界 — hg-1 ライブデモ + verify の実測が正・episode 記録）。
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
# --pick は隣接 oe-jump を再利用する（jump ロジック複製なし・#227）。同じ temp/bin に symlink し、
# oe-jump 自身の lib 解決（../lib/delegate-registry.sh）が temp/lib（上の symlink）を指すようにする。
ln -s "$PROJECT_DIR/bin/oe-jump" "$_TMP_DIR/bin/oe-jump"

# mock tmux: list-panes / display-message のみ意味を持つ（他は成功で素通し）
cat > "$_TMP_DIR/pathbin/tmux" <<'EOF'
#!/usr/bin/env bash
# 呼び出しを log（--pick の jump/zoom ターゲット検証用・TMUX_CALL_LOG 設定時のみ）。
[[ -n "${TMUX_CALL_LOG:-}" ]] && printf 'tmux %s\n' "$*" >> "$TMUX_CALL_LOG"
case "${1:-}" in
  list-panes)
    [[ "${MOCK_TMUX_FAIL:-0}" == "1" ]] && exit 1
    if [[ -n "${MOCK_LIVE_LINES:-}" ]]; then
      printf '%s\n' "$MOCK_LIVE_LINES"
    else
      # shellcheck disable=SC2086
      printf '%s\n' ${MOCK_LIVE_PANES:-}
    fi ;;
  display-message)
    if [[ "$*" == *'#{window_zoomed_flag}'* ]]; then
      printf '%s\n' "${MOCK_ZOOM_FLAG:-0}"    # --pick ensure_zoom 用（既定 0=未 zoom）
    elif [[ "$*" == *'#{pid}'* ]]; then
      # 拍動の server 突合用（#327）。分岐を足さないと pid が title 経路へ落ちて突合が壊れる。
      printf '%s\n' "${MOCK_SERVER_PID-99999}"
    elif [[ "$*" == *'#{pane_id}'* ]]; then
      printf '%s\n' "${MOCK_ACTIVE_PANE:-}"
    else
      printf '%s\n' "${MOCK_PANE_TITLE:-}"
    fi ;;
  *) exit 0 ;;                                 # resize-pane / switch-client / select-* は成功で素通し
esac
EOF
chmod +x "$_TMP_DIR/pathbin/tmux"

# 実 jq は pathbin に symlink して使う（mock は tmux/fzf のみ）。JQ_DIR を PATH に足すと、
# そこに同居する実 fzf（/opt/homebrew/bin）まで拾って fzf 有無の切替テストが崩れるため、
# jq だけを隔離 pathbin に持ち込み PATH から JQ_DIR を外す（test_oe_select の実 fzf 除外と同方針）。
JQ_BIN="$(command -v jq)" || { echo "FATAL: jq is required to run this test" >&2; exit 1; }
ln -s "$JQ_BIN" "$_TMP_DIR/pathbin/jq"
export PATH="${_TMP_DIR}/pathbin:/usr/bin:/bin"

# mock fzf（make_fzf/rm_fzf で有無を切替）。候補は "%N<TAB>表示行"。TAB 区切りの first-field(%N)が
# $FZF_PICK_PANE に一致する行を返す。FZF_CANCEL=130 / FZF_FAIL=<n> / FZF_EMPTY=空 stdout+rc0。
make_fzf() {
  cat > "$_TMP_DIR/pathbin/fzf" <<'EOF'
#!/usr/bin/env bash
[[ -n "${FZF_CANCEL:-}" ]] && exit 130
[[ -n "${FZF_FAIL:-}" ]] && exit "$FZF_FAIL"
[[ -n "${FZF_EMPTY:-}" ]] && exit 0
# stateful（ループ戻り検証用）: 1 回目は $FZF_ONCE_PANE を返し、2 回目以降は cancel(130)。
if [[ -n "${FZF_ONCE_PANE:-}" ]]; then
  if [[ -e "${FZF_ONCE_CF:?FZF_ONCE_CF required}" ]]; then exit 130; fi
  : > "$FZF_ONCE_CF"
  while IFS= read -r line; do
    [[ "${line%%$'\t'*}" == "$FZF_ONCE_PANE" ]] && { printf '%s\n' "$line"; exit 0; }
  done
  exit 1
fi
pick="${FZF_PICK_PANE:-}"
while IFS= read -r line; do
  [[ "${line%%$'\t'*}" == "$pick" ]] && { printf '%s\n' "$line"; exit 0; }
done
exit 1
EOF
  chmod +x "$_TMP_DIR/pathbin/fzf"
}
rm_fzf() { rm -f "$_TMP_DIR/pathbin/fzf"; }

# --pick 番号フォールバックの tty シーム（/dev/tty は非対話で開けない）。OE_TREE_TTY で差し替える。
OE_TREE_TTY_FILE="$_TMP_DIR/tty-input"
feed_tty() { printf '%s\n' "$1" > "$OE_TREE_TTY_FILE"; }
feed_tty_empty() { : > "$OE_TREE_TTY_FILE"; }

export OE_DELEGATE_STATE_DIR; OE_DELEGATE_STATE_DIR="$_TMP_DIR/state"
export OE_PANE_ISSUE_DIR;     OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
mkdir -p "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"

export TMUX="/tmp/mock-tmux,12345,0"   # server pid = 12345
export TMUX_PANE="%110"                # self（case [1] の孫）

# --- 拍動 sidecar の隔離（#327）---
# 隔離しないと実ホームを読む。実ホームには %85 の sidecar が実在するので fixture と衝突し、
# ホスト依存になる。時計と窓も固定して鮮度判定を決定化する（test_oe_threads.sh と同じ形）。
export OE_HEARTBEAT_DIR="$_TMP_DIR/oe-heartbeat"
export OE_TREE_BEAT_WINDOW_SEC=900
export NOW_EPOCH=1700000000
export MOCK_SERVER_PID=12345           # mock tmux の #{pid}（$TMUX の pid と揃える）
mkdir -p "$OE_HEARTBEAT_DIR"
# mkbeat <name> <age秒> <ctx> <pane> <server_pid> <display_name|-none->
mkbeat() {
  jq -nc --argjson ts "$((NOW_EPOCH - $2))" --argjson ctx "$3" --arg pane "$4" --arg spid "$5" --arg dn "$6" \
    '{ts:$ts, context_pct:$ctx, pane:$pane, server_pid:$spid,
      model:(if $dn == "-none-" then {} else {id:"id-x", display_name:$dn} end)}' \
    > "$OE_HEARTBEAT_DIR/${1}.json"
}
reset_beats() { rm -rf "$OE_HEARTBEAT_DIR"; mkdir -p "$OE_HEARTBEAT_DIR"; }

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
# ckc <label> <haystack> <needle> — 部分一致（#327 で追加。既存の ck は完全一致）
ckc() {
  if printf '%s' "$2" | grep -qF -- "$3"; then
    echo "  PASS: $1"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $1"; FAIL=$((FAIL + 1))
    echo "    --- missing ---"; printf '%s\n' "$3" | sed 's/^/    /'
    echo "    --- in -------"; printf '%s\n' "$2" | sed 's/^/    /'
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
  mkentry %83  "fresh-orch-2" "/w/demo-infra"    %49
  mkentry %85  "#902"        "/w/demo-org.902"  %83
  mkentry %110 "#902-u1"     "/w/demo-org"       %85
  mkentry %94  "#36"          "/w/ecs"          %83
}

# ----------------------------------------------------------------------------
echo "[1] 3 世代チェーン: 罫線・世代・gone 合成 root・兄弟数値順・self marker・workspace"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
export MOCK_LIVE_PANES="%83 %85 %94 %110"
expected='-     %49    gone   ?
└─ -     %83    alive  fresh-orch-2 ~demo-infra
   ├─ -     %85    alive  #902 ~demo-org.902
   │  └─ -     %110   alive  #902-u1 ~demo-org (you)
   └─ -     %94    alive  #36 ~ecs'
ck "chain render" "$expected" "$("$TREE")"

# ----------------------------------------------------------------------------
echo "[2] 複数 root の数値順 + parent 空 entry は自身が root"
# ----------------------------------------------------------------------------
reset_state
mkentry %8  "second-tree" "/w/two" %7
mkentry %60 "standalone"  "/w/one" ""
export MOCK_LIVE_PANES="%8 %60"
expected='-     %7     gone   ?
└─ -     %8     alive  second-tree ~two
-     %60    alive  standalone ~one'
ck "multi-root order" "$expected" "$("$TREE")"

# ----------------------------------------------------------------------------
echo "[3] ラベル優先順位: pane-issue(.name) > registry(.label)"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
printf '{"name":"#902 renamed"}' > "${OE_PANE_ISSUE_DIR}/$(keyfor %85)"
export MOCK_LIVE_PANES="%83 %85 %94 %110"
actual="$("$TREE" | grep -F '%85')"
ck "pane-issue wins" '   ├─ -     %85    alive  #902 renamed ~demo-org.902' "$actual"

# ----------------------------------------------------------------------------
echo "[4] label sanitize: LF/CR/TAB/US/ESC/C1 を空白へ畳む（端末制御・視覚偽装の遮断）"
# ----------------------------------------------------------------------------
reset_state
mkentry %60 $'bad\nlab\tx\037y' "/w/one" ""
mkentry %61 $'esc\033[2Jwipe\xc2\x9bcsi' "/w/esc" ""
export MOCK_LIVE_PANES="%60 %61"
expected='-     %60    alive  bad lab x y ~one
-     %61    alive  esc [2Jwipe csi ~esc'
ck "sanitized label" "$expected" "$("$TREE")"

# ----------------------------------------------------------------------------
echo "[5] 純粋 cycle: 擬似 root で描画・[cycle] 打ち切り・無限ループなし（liveness ? 経路）"
# ----------------------------------------------------------------------------
reset_state
mkentry %201 "lab201" "" %202
mkentry %202 "lab202" "" %201
export MOCK_TMUX_FAIL=1
expected='-     %201   ?      lab201
└─ -     %202   ?      lab202
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
expected='-     %60    alive  standalone ~one
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
ck "title fallback" '-     %70    alive  picked up title ~seventy' "$("$TREE")"
export MOCK_PANE_TITLE=$'spoof\033]0;t\007end'
ck "title sanitize (OSC/BEL)" '-     %70    alive  spoof ]0;t end ~seventy' "$("$TREE")"
unset MOCK_PANE_TITLE

# ----------------------------------------------------------------------------
echo "[10] gone 中間ノード: 親子とも登記あり・中間だけ gone でも子は描画"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
export MOCK_LIVE_PANES="%83 %94 %110"   # %85 が gone
actual="$("$TREE" | grep -cE '%85[[:space:]]+gone|%110[[:space:]]+alive')"
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
expected='-     %60    alive  standalone ~one
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
echo "[14] 座標列（#223 DJ-223-11/hg-2）: 併記・sanitize・適応セッション前置・画面配置順・gone は末尾"
# ----------------------------------------------------------------------------
# 複数セッション（0 / main / bad<ESC>name の 3 つ）: session: を前置・session→window→pane 順。
# format は pane<TAB>window.pane<TAB>session_name（session_name は最終列 = 内部境界を汚さない）。
reset_state
mkentry %60 "one" "/w/one" ""
mkentry %61 "two" "/w/two" ""
mkentry %62 "thr" "/w/thr" ""
export MOCK_LIVE_LINES=$'%60\t1.1\t0\n%61\t2.3\tmain\n%62\t1.1\tbad\033name'
expected='0:1.1  %60    alive  one ~one
bad name:1.1  %62    alive  thr ~thr
main:2.3  %61    alive  two ~two'
ck "multi-session coords + order" "$expected" "$("$TREE")"
# session_name の最終列 TAB 注入: 内部境界（$1 pane / $2 window.pane）は無傷で liveness/座標が
# 壊れないこと（実装SO#2 codex 指摘の防御）。%63 の session 名に TAB を仕込む
mkentry %63 "tabbed" "/w/tab" ""
export MOCK_LIVE_LINES=$'%60\t1.1\t0\n%63\t1.5\tev\til'
# TAB は最終列で $4 に溢れ、$1(pane)/$2(window.pane=1.5) は無傷 → liveness/座標は正しく、
# session 表示だけ TAB 以降（il）が切れる（ev のみ）。ラベルは registry の tabbed（session 名でない）。
actual="$("$TREE" | grep -F '%63')"
ck "session TAB does not corrupt liveness/coord" 'ev:1.5  %63    alive  tabbed ~tab' "$actual"
reset_state; mkentry %60 "one" "/w/one" ""; mkentry %61 "two" "/w/two" ""; mkentry %62 "thr" "/w/thr" ""
# 単一セッション: session: を落とし window.pane のみ・window→pane 昇順・座標なし（gone）は末尾
mkentry %59 "old" "/w/old" ""
export MOCK_LIVE_LINES=$'%61\t2.3\t0\n%60\t1.1\t0\n%62\t1.2\t0'
expected='1.1   %60    alive  one ~one
1.2   %62    alive  thr ~thr
2.3   %61    alive  two ~two
-     %59    gone   old ~old'
ck "single-session strip + layout order + gone last" "$expected" "$("$TREE")"
unset MOCK_LIVE_LINES

# ----------------------------------------------------------------------------
echo "[15] --watch 引数検証（#223）: interval 不正・--interval 単独は exit 2"
# ----------------------------------------------------------------------------
"$TREE" --interval 3 >/dev/null 2>&1;            ck "interval without watch exit 2" "2" "$?"
"$TREE" --watch --interval 0 >/dev/null 2>&1;    ck "interval 0 exit 2" "2" "$?"
"$TREE" --watch --interval -1 >/dev/null 2>&1;   ck "interval negative exit 2" "2" "$?"
"$TREE" --watch --interval abc >/dev/null 2>&1;  ck "interval non-numeric exit 2" "2" "$?"
"$TREE" --watch --interval >/dev/null 2>&1;      ck "interval missing value exit 2" "2" "$?"
err="$(env -u TMUX -u TMUX_PANE "$TREE" --watch </dev/null 2>&1 >/dev/null)"; rc=$?
ck "watch tmux-less exit 2" "2" "$rc"
ck "watch tmux-less note" "yes" "$(printf '%s' "$err" | grep -q 'not inside tmux' && echo yes || echo no)"

# ----------------------------------------------------------------------------
echo "[16] --watch 1 tick（#223）: 非 TTY background でヘッダ + ツリー内容 + 復元シーケンス"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
export MOCK_LIVE_PANES="%83 %85 %94 %110"
_watch_out="$_TMP_DIR/watch-out.txt"
"$TREE" --watch --interval 1 </dev/null >"$_watch_out" 2>&1 &
_watch_pid=$!
sleep 1.5
kill "$_watch_pid" 2>/dev/null
wait "$_watch_pid" 2>/dev/null
ck "watch header" "yes" "$(grep -q 'oe-tree --watch · interval=1s' "$_watch_out" && echo yes || echo no)"
ck "watch tree content" "yes" "$(grep -q -- '-     %110   alive  #902-u1 ~demo-org (you)' "$_watch_out" && echo yes || echo no)"
ck "watch alt-screen restore" "yes" "$(grep -q $'\033\[?1049l' "$_watch_out" && echo yes || echo no)"

# ----------------------------------------------------------------------------
echo "[17] --watch の (you) fallback（#223 DJ-223-6）: TMUX_PANE unset → display-message の active pane を freeze"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
export MOCK_LIVE_PANES="%83 %85 %94 %110"
export MOCK_ACTIVE_PANE="%94"
_watch_out2="$_TMP_DIR/watch-out2.txt"
env -u TMUX_PANE "$TREE" --watch --interval 1 </dev/null >"$_watch_out2" 2>&1 &
_watch_pid2=$!
sleep 1.5
kill "$_watch_pid2" 2>/dev/null
wait "$_watch_pid2" 2>/dev/null
ck "fallback (you) on active pane" "yes" "$(grep -q -- '-     %94    alive  #36 ~ecs (you)' "$_watch_out2" && echo yes || echo no)"
unset MOCK_ACTIVE_PANE

# ----------------------------------------------------------------------------
# ----------------------------------------------------------------------------
echo "[18] symlink 経由起動でも lib を source できる（#223 配布・symlink 安全化）"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
_oe_link="$_TMP_DIR/pathbin/oe-tree-linked"
ln -sf "$PROJECT_DIR/bin/oe-tree" "$_oe_link"   # 実 hub oe-tree を指す symlink（~/bin 配布と同型）
_direct="$("$TREE" 2>&1)"; _drc=$?              # copy: BIN_DIR=temp/bin → temp/lib
_linked="$("$_oe_link" 2>&1)"; _lrc=$?          # symlink: readlink 解決で hub/bin → hub/lib を source
ck "symlink 起動 rc == 直接起動 rc" "$_drc" "$_lrc"
ck "symlink 起動 出力 == 直接起動 出力" "$_direct" "$_linked"

# ============================================================================
# 対話ナビ --pick / --pick-list（#227）
# 実 fzf は PATH から除外済み（make_fzf/rm_fzf で mock の有無を切替）。jump は隣接 oe-jump を
# 再利用し、mock tmux が select-pane/resize-pane を TMUX_CALL_LOG に記録する。実 popup の
# 対話終了・cross-session focus は自動テストの構造的限界（hg-227-a/b はライブ実測が正・episode 記録）。
# ============================================================================

# ----------------------------------------------------------------------------
echo "[19] モード排他: --pick+--watch / --pick-list+--watch は exit 2"
# ----------------------------------------------------------------------------
"$TREE" --pick --watch      >/dev/null 2>&1; ck "pick+watch exit 2" "2" "$?"
"$TREE" --pick-list --watch >/dev/null 2>&1; ck "pick-list+watch exit 2" "2" "$?"

# ----------------------------------------------------------------------------
echo "[20] --pick-list: 隠しキー列 %N<TAB> を前置・stdout は候補のみ・note は stderr"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
export MOCK_LIVE_PANES="%83 %85 %94 %110"
pl_out="$("$TREE" --pick-list 2>/dev/null)"
ck "pick-list key col + display (%110)" "yes" \
  "$(printf '%s\n' "$pl_out" | awk -F '\t' '$1=="%110" && $2 ~ /%110   alive  #902-u1 ~demo-org \(you\)/ {print "yes"; exit}')"
ck "pick-list 5 nodes = 5 keyed lines" "5" "$(printf '%s\n' "$pl_out" | grep -c $'\t')"
printf '{"pane":"%%7","label":"f","workspace":"/w","parent_pane":"%%1","role":"child"}' \
  > "${OE_DELEGATE_STATE_DIR}/99999__7.json"
ck "pick-list note not in stdout" "" "$("$TREE" --pick-list 2>/dev/null | grep 'note:' || true)"
ck "pick-list note on stderr" "yes" \
  "$("$TREE" --pick-list 2>&1 >/dev/null | grep -q 'not shown (stale)' && echo yes || echo no)"

# ----------------------------------------------------------------------------
echo "[21] --pick (fzf): alive 選択 → oe-jump focus + 対象指定 zoom（resize-pane -Z -t %N）"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
export MOCK_LIVE_PANES="%83 %85 %94 %110"
make_fzf
export TMUX_CALL_LOG="$_TMP_DIR/calls21.log"; : > "$TMUX_CALL_LOG"
FZF_PICK_PANE="%85" MOCK_ZOOM_FLAG="0" "$TREE" --pick </dev/null >/dev/null 2>&1; rc=$?
ck "pick jump+zoom exit 0" "0" "$rc"
ck "pick oe-jump select-pane target" "yes" "$(grep -qF 'select-pane -t %85' "$TMUX_CALL_LOG" && echo yes || echo no)"
ck "pick zoom targets selected pane (-t)" "yes" "$(grep -qF 'resize-pane -Z -t %85' "$TMUX_CALL_LOG" && echo yes || echo no)"
unset TMUX_CALL_LOG

# ----------------------------------------------------------------------------
echo "[22] --pick 冪等 zoom: 既 zoom(flag=1) は再 -Z しない（トグルで解除される事故を防ぐ）"
# ----------------------------------------------------------------------------
export TMUX_CALL_LOG="$_TMP_DIR/calls22.log"; : > "$TMUX_CALL_LOG"
FZF_PICK_PANE="%85" MOCK_ZOOM_FLAG="1" "$TREE" --pick </dev/null >/dev/null 2>&1; rc=$?
ck "pick already-zoomed exit 0" "0" "$rc"
ck "pick no re-zoom when flag=1" "" "$(grep -F 'resize-pane' "$TMUX_CALL_LOG" || true)"
unset TMUX_CALL_LOG

# ----------------------------------------------------------------------------
echo "[23] --pick gone/jump 失敗: exit せず picker に戻る（成功/cancel のみ抜ける・#227 hg 追修正）"
# ----------------------------------------------------------------------------
reset_state; fixture_chain
export MOCK_LIVE_PANES="%83 %85 %94 %110"   # %49 は gone（live 集合に無い）
make_fzf; export MOCK_ZOOM_FLAG="0"
export TMUX_CALL_LOG="$_TMP_DIR/calls23.log"; : > "$TMUX_CALL_LOG"
# stateful fzf: 1 回目 gone(%49) → oe-jump 失敗 → picker に戻る → 2 回目 fzf は cancel → 130。
# 旧挙動なら gone 選択で exit 1。130 になること自体がループ（戻り→再選択）の証拠。
rm -f "$_TMP_DIR/cf23"
FZF_ONCE_PANE="%49" FZF_ONCE_CF="$_TMP_DIR/cf23" "$TREE" --pick </dev/null >/dev/null 2>&1; rc=$?
ck "pick gone loops back then cancel→130 (旧: exit1)" "130" "$rc"
ck "pick gone no zoom" "" "$(grep -F 'resize-pane' "$TMUX_CALL_LOG" || true)"
rm -f "$_TMP_DIR/cf23b"
err23="$(FZF_ONCE_PANE="%49" FZF_ONCE_CF="$_TMP_DIR/cf23b" "$TREE" --pick </dev/null 2>&1 >/dev/null)"
ck "pick gone shows 戻ります on stderr" "yes" "$(printf '%s' "$err23" | grep -q 'picker に戻ります' && echo yes || echo no)"
unset TMUX_CALL_LOG

# ----------------------------------------------------------------------------
echo "[24] --pick (fzf) 分岐: cancel→130 / no-match→130 / fzf error→2 / empty→130"
# ----------------------------------------------------------------------------
FZF_CANCEL=1        "$TREE" --pick </dev/null >/dev/null 2>&1; ck "fzf cancel 130" "130" "$?"
FZF_PICK_PANE="%zz" "$TREE" --pick </dev/null >/dev/null 2>&1; ck "fzf no-match 130" "130" "$?"
FZF_FAIL=3          "$TREE" --pick </dev/null >/dev/null 2>&1; ck "fzf error 2" "2" "$?"
FZF_EMPTY=1         "$TREE" --pick </dev/null >/dev/null 2>&1; ck "fzf empty 130" "130" "$?"

# ----------------------------------------------------------------------------
echo "[25] --pick 番号フォールバック（fzf 非在）: 有効→jump+zoom / 範囲外・非数値→2 / 空→130"
# ----------------------------------------------------------------------------
rm_fzf
export MOCK_ZOOM_FLAG="0"
# 候補順（画面配置順・座標なしは末尾）: 1)%49 gone 2)%83 3)%85 4)%110 5)%94。番号3=%85。
export TMUX_CALL_LOG="$_TMP_DIR/calls25.log"; : > "$TMUX_CALL_LOG"
feed_tty "3"; OE_TREE_TTY="$OE_TREE_TTY_FILE" "$TREE" --pick >/dev/null 2>&1; rc=$?
ck "number select exit 0" "0" "$rc"
ck "number select jump+zoom %85" "yes" "$(grep -qF 'resize-pane -Z -t %85' "$TMUX_CALL_LOG" && echo yes || echo no)"
unset TMUX_CALL_LOG
feed_tty "99";  OE_TREE_TTY="$OE_TREE_TTY_FILE" "$TREE" --pick >/dev/null 2>&1; ck "number out-of-range 2" "2" "$?"
feed_tty "abc"; OE_TREE_TTY="$OE_TREE_TTY_FILE" "$TREE" --pick >/dev/null 2>&1; ck "number non-numeric 2" "2" "$?"
feed_tty_empty; OE_TREE_TTY="$OE_TREE_TTY_FILE" "$TREE" --pick >/dev/null 2>&1; ck "number empty 130" "130" "$?"

# ----------------------------------------------------------------------------
echo "[26] --pick 候補なし（空森）: rc1・stdout 空・メッセージは stderr"
# ----------------------------------------------------------------------------
reset_state
out="$("$TREE" --pick </dev/null 2>/dev/null)"; rc=$?
ck "pick empty forest exit 1" "1" "$rc"
ck "pick empty forest stdout empty" "" "$out"
# stderr を先に変数へ取ってから grep する（`--pick|grep` を直に繋ぐと pipefail が --pick の
# exit 1 を拾い、grep が一致しても && 側に進めない）。
err="$("$TREE" --pick </dev/null 2>&1 >/dev/null)"
ck "pick empty forest msg on stderr" "yes" \
  "$(printf '%s' "$err" | grep -q 'no spawn nodes to pick' && echo yes || echo no)"

# ----------------------------------------------------------------------------
echo "[27] #327: 行末に拍動（モデル名とコンテキスト%）を足す"
# ----------------------------------------------------------------------------
reset_state; reset_beats
mkentry %60 "solo" "/w/one" ""
MOCK_LIVE_PANES="%60"
mkbeat b1 5 61 '%60' 12345 'Opus 5 (1M context)'
ck "beat を行末に足す" '-     %60    alive  solo ~one  Opus 5 (1M context) 61%' "$("$TREE")"

echo "[28] #327: 拍動が無い / gone / 鮮度切れ では何も足さない"
reset_state; reset_beats
mkentry %60 "solo" "/w/one" ""
MOCK_LIVE_PANES="%60"
ck "拍動なし → 素の行" '-     %60    alive  solo ~one' "$("$TREE")"
mkbeat b2 5000 61 '%60' 12345 'Opus 5'
ck "鮮度窓の外 → 足さない" '-     %60    alive  solo ~one' "$("$TREE")"
reset_beats; mkbeat b3 5 61 '%60' 12345 'Opus 5'
MOCK_LIVE_PANES=""
ck "gone なら足さない" '-     %60    gone   solo ~one' "$("$TREE")"

echo "[29] #327: 別 server の sidecar を誤って足さない / 旧 sidecar は pane 単独で突合"
reset_state; reset_beats
mkentry %60 "solo" "/w/one" ""
MOCK_LIVE_PANES="%60"
mkbeat b4 5 61 '%60' 99998 'Haiku 4.5'
ck "別 server → 足さない" '-     %60    alive  solo ~one' "$("$TREE")"
reset_beats; mkbeat b5 5 44 '%60' '' 'Sonnet 5'
ck "server_pid 空（旧 sidecar）→ pane 単独で突合" '-     %60    alive  solo ~one  Sonnet 5 44%' "$("$TREE")"

echo "[30] #327: 帰属が曖昧なら潰さず ambiguous と出す"
reset_state; reset_beats
mkentry %60 "solo" "/w/one" ""
MOCK_LIVE_PANES="%60"
mkbeat d1 5  61 '%60' 12345 'Opus 5'
mkbeat d2 10 33 '%60' 12345 'Fable 5'
ck "候補2件 → ambiguous(2)" '-     %60    alive  solo ~one  ambiguous(2)' "$("$TREE")"

echo "[31] #327: 壊れた sidecar は tree を殺さず note で開示する"
reset_state; reset_beats
mkentry %60 "solo" "/w/one" ""
MOCK_LIVE_PANES="%60"
mkbeat ok1 5 61 '%60' 12345 'Opus 5'
printf '%s' 'not json at all' > "$OE_HEARTBEAT_DIR/broken.json"
OUT="$("$TREE")"; rc=$?
ck  "exit 0（拍動は装飾なので tree を止めない）" "0" "$rc"
ckc "健全な拍動は出る"                            "$OUT" "Opus 5 61%"
ckc "壊れを note で開示する"                      "$OUT" "note: 1 heartbeat files malformed"

echo "[32] #327: 置き場が読めないときも tree は出し、note で開示する"
reset_state; reset_beats
mkentry %60 "solo" "/w/one" ""
MOCK_LIVE_PANES="%60"
_unread="$_TMP_DIR/hb-unreadable"; rm -rf "$_unread"; mkdir -p "$_unread"; chmod 000 "$_unread"
OUT="$(OE_HEARTBEAT_DIR="$_unread" "$TREE")"; rc=$?
chmod 755 "$_unread"
ck  "exit 0"                        "0" "$rc"
ckc "tree 本体は出る"                "$OUT" "%60    alive  solo ~one"
ckc "置き場が読めないことを開示する"  "$OUT" "note: heartbeat dir unreadable"

echo "[33] #327: display_name の制御文字を sanitize し、長すぎる名前は上限で切る"
reset_state; reset_beats
mkentry %60 "solo" "/w/one" ""
MOCK_LIVE_PANES="%60"
jq -nc --argjson ts "$((NOW_EPOCH - 5))" '{ts:$ts, context_pct:61, pane:"%60", server_pid:"12345",
  model:{id:"x", display_name:("Op" + ([27]|implode) + "us 5")}}' > "$OE_HEARTBEAT_DIR/ctl.json"
ckc "制御文字が畳まれる" "$("$TREE")" "solo ~one  Op us 5 61%"
reset_beats
mkbeat long 5 61 '%60' 12345 'AAAAAAAAAABBBBBBBBBBCCCCCCCCCCDDDDDDDDDDEEEEEEEEEE'
ckc "上限で切って ... を付ける" "$("$TREE")" "AAAAAAAAAABBBBBBBBBBCCCCCCCCCCDDDDDDDDDD... 61%"

echo "[34] #327: --pick-list（popup が読む面）にも同じものが出る"
reset_state; reset_beats
mkentry %60 "solo" "/w/one" ""
MOCK_LIVE_PANES="%60"
mkbeat p1 5 61 '%60' 12345 'Opus 5'
ck "pick-list の候補行にも出る（末尾までアンカー）" \
   "$(printf '%%60\t-     %%60    alive  solo ~one  Opus 5 61%%')" "$("$TREE" --pick-list)"

echo "[35] #327: --watch の1 tick にも出る"
reset_state; reset_beats
mkentry %60 "solo" "/w/one" ""
MOCK_LIVE_PANES="%60"
mkbeat w1 5 61 '%60' 12345 'Opus 5'
_wout="$_TMP_DIR/watch-beat.txt"
"$TREE" --watch --interval 1 > "$_wout" 2>&1 </dev/null &
_wpid=$!
sleep 2
kill "$_wpid" 2>/dev/null || true
wait "$_wpid" 2>/dev/null || true
ckc "watch のフレームに beat が出る" "$(cat "$_wout")" "Opus 5 61%"
reset_beats

echo
echo "PASS=${PASS} FAIL=${FAIL}"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
