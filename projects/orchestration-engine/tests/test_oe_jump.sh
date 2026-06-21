#!/usr/bin/env bash
set -uo pipefail

# test_oe_jump.sh — oe-jump（tmux 専用）の解決 / focus 経路 / record-replay を検証する
#
# 実 tmux は起動せず PATH 先頭 mock に差し替える（test_oe_select.sh と同型）:
#   - tmux: 全呼び出しを tmux.log に記録。list-panes は $MOCK_LIVE_PANES、display-message は
#           $MOCK_TMUX_META を返す。switch-client/select-window/select-pane は引数を log に記録。
#   - jq:   delegate-registry.sh が pane-issue から .name を引くため最小実装（test_oe_select と同じ）。
#
# oe-jump は BIN_DIR/../lib/delegate-registry.sh を source する。テスト用 bin/ に oe-jump を
# コピーし、lib/ に実体を symlink して共有する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# mktemp 失敗時に空パスで継続して root 直下へ書き込む事故を防ぐ（実装SO 指摘）。
_TMP_DIR="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
[[ -n "$_TMP_DIR" && -d "$_TMP_DIR" ]] || { echo "FATAL: mktemp -d returned an invalid path: '${_TMP_DIR}'" >&2; exit 1; }
trap 'rm -rf "$_TMP_DIR"' EXIT
mkdir -p "$_TMP_DIR/bin" "$_TMP_DIR/lib" "$_TMP_DIR/pathbin" "$_TMP_DIR/logs"

cp "$PROJECT_DIR/bin/oe-jump" "$_TMP_DIR/bin/oe-jump"
chmod +x "$_TMP_DIR/bin/oe-jump"
ln -s "$PROJECT_DIR/lib/delegate-registry.sh" "$_TMP_DIR/lib/delegate-registry.sh"

export OE_JUMP_TEST_LOG_DIR="$_TMP_DIR/logs"

# mock tmux: 全呼び出しを tmux.log に記録。list-panes/display-message は固定出力を返す。
cat > "$_TMP_DIR/pathbin/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${OE_JUMP_TEST_LOG_DIR:?}/tmux.log"
case "${1:-}" in
  list-panes)
    # shellcheck disable=SC2086
    printf '%s\n' ${MOCK_LIVE_PANES:-} ;;
  display-message)
    printf '%s\n' "${MOCK_TMUX_META:-}" ;;
  switch-client|select-window|select-pane) exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$_TMP_DIR/pathbin/tmux"

# mock jq: delegate-registry.sh は pane-issue/spawn JSON を jq で引く。
# .name を含む filter かつ末尾引数がファイルならその "name" を返す（test_oe_select と同型）。
cat > "$_TMP_DIR/pathbin/jq" <<'EOF'
#!/usr/bin/env bash
filter=""
file=""
for a in "$@"; do
  case "$a" in
    .name*|*'.name'*) filter="name" ;;
  esac
  file="$a"
done
if [[ "$filter" == "name" && -f "$file" ]]; then
  sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file"
  exit 0
fi
printf ''
exit 0
EOF
chmod +x "$_TMP_DIR/pathbin/jq"

# 隔離 state（delegate-registry.sh / oe-jump の record が参照）。
export OE_DELEGATE_STATE_DIR; OE_DELEGATE_STATE_DIR="$_TMP_DIR/state"
export OE_PANE_ISSUE_DIR;     OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
export OE_JUMP_STATE_DIR;     OE_JUMP_STATE_DIR="$_TMP_DIR/oe-jump-state"
mkdir -p "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"

# 厳選 PATH: mock（pathbin）+ システム実体（awk/sed/grep/cat/printf/head）。実 tmux/jq は除外。
export PATH="${_TMP_DIR}/pathbin:/usr/bin:/bin"
export TMUX="/tmp/mock-tmux,12345,0"          # server pid = 12345（key 生成に使う）
export TMUX_PANE="%1"                          # self
# shellcheck disable=SC2016  # 意図的なリテラル $0（tmux session_id 表記・展開させない）
export MOCK_TMUX_META='$0 @0'                  # display-message の固定メタ（session_id window_id）

JUMP="$_TMP_DIR/bin/oe-jump"

PASS=0
FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (want='$expected' got='$actual')"; FAIL=$((FAIL + 1))
  fi
}
reset_logs() { rm -f "$_TMP_DIR/logs/tmux.log"; }
reset_record() { rm -rf "$OE_JUMP_STATE_DIR"; }
tmux_log() { cat "$_TMP_DIR/logs/tmux.log" 2>/dev/null; }
has_line() { printf '%s\n' "$1" | grep -qF -- "$2" && echo yes || echo no; }
fixture_142() { printf '{"name":"#142"}\n' > "${OE_PANE_ISSUE_DIR}/12345__5"; }  # key 12345_%5
rm_fixture_142() { rm -f "${OE_PANE_ISSUE_DIR}/12345__5"; }

# ----------------------------------------------------------------------------
# [1] %N 素通し → select-pane が %5 を対象に呼ばれる、exit 0
# ----------------------------------------------------------------------------
echo "[1] %5 素通し → tmux focus（select-pane -t %5）"
export MOCK_LIVE_PANES="%1 %5 %7"
reset_logs
rc=0; "$JUMP" "%5" >/dev/null 2>&1 || rc=$?
ck "rc=0" "0" "$rc"
ck "select-pane -t %5 が呼ばれる" "yes" "$(has_line "$(tmux_log)" 'select-pane -t %5')"

# ----------------------------------------------------------------------------
# [2] tmux idiom: switch-client / select-window / select-pane が ID 系で全て呼ばれる
# ----------------------------------------------------------------------------
echo "[2] tmux idiom: switch-client/select-window/select-pane 全段（ID 系 target）"
export MOCK_LIVE_PANES="%1 %5"
reset_logs
"$JUMP" "%5" >/dev/null 2>&1
log="$(tmux_log)"
# shellcheck disable=SC2016  # 'switch-client -t $0' は意図的リテラル（tmux session_id）
ck "switch-client -t \$0" "yes" "$(has_line "$log" 'switch-client -t $0')"
ck "select-window -t @0"  "yes" "$(has_line "$log" 'select-window -t @0')"
ck "select-pane -t %5"    "yes" "$(has_line "$log" 'select-pane -t %5')"

# ----------------------------------------------------------------------------
# [3] ラベル #142 → pane-issue で %5 に解決 → select-pane -t %5
# ----------------------------------------------------------------------------
echo "[3] ラベル #142 → %5 解決 → select-pane -t %5"
export MOCK_LIVE_PANES="%1 %5 %7"
fixture_142
reset_logs
rc=0; "$JUMP" "#142" >/dev/null 2>&1 || rc=$?
ck "rc=0" "0" "$rc"
ck "select-pane -t %5（ラベル解決）" "yes" "$(has_line "$(tmux_log)" 'select-pane -t %5')"
rm_fixture_142

# ----------------------------------------------------------------------------
# [4] 裸の整数 5 → wez 案内で拒否（exit 2）、focus は一切呼ばれない
# ----------------------------------------------------------------------------
echo "[4] 裸整数 5 → exit 2（wez 案内・focus なし）"
export MOCK_LIVE_PANES="%1 %5"
reset_logs
rc=0; out="$("$JUMP" 5 2>&1)" || rc=$?
ck "裸整数 → exit 2" "2" "$rc"
ck "wez pane activate を案内" "yes" "$(has_line "$out" 'wez pane activate 5')"
ck "tmux focus 呼ばれない" "no" "$([[ -e "$_TMP_DIR/logs/tmux.log" ]] && echo yes || echo no)"

# ----------------------------------------------------------------------------
# [5] wez:5 → wez 案内で拒否（exit 2）、focus なし（registry ラベル衝突の silent 誤 focus を排除）
# ----------------------------------------------------------------------------
echo "[5] wez:5 → exit 2（wez 案内・silent 誤 focus を排除）"
export MOCK_LIVE_PANES="%1 %5"
reset_logs
rc=0; out="$("$JUMP" "wez:5" 2>&1)" || rc=$?
ck "wez:5 → exit 2" "2" "$rc"
ck "wez pane activate 5 を案内" "yes" "$(has_line "$out" 'wez pane activate 5')"
ck "focus 呼ばれない" "no" "$([[ -e "$_TMP_DIR/logs/tmux.log" ]] && echo yes || echo no)"

# ----------------------------------------------------------------------------
# [6] --print %5 → stdout は解決した %5 のみ、focus コマンドは呼ばれない
# ----------------------------------------------------------------------------
echo "[6] --print %5 → stdout '%5'、focus なし"
export MOCK_LIVE_PANES="%1 %5"
reset_logs
out="$("$JUMP" --print "%5" 2>/dev/null)"; rc=$?
ck "rc=0" "0" "$rc"
ck "stdout は '%5'" "%5" "$out"
ck "focus（select-pane）は呼ばれない" "no" "$(has_line "$(tmux_log)" 'select-pane')"

# ----------------------------------------------------------------------------
# [7] ラベル未解決（#999・該当なし）→ exit 1
# ----------------------------------------------------------------------------
echo "[7] 未解決ラベル #999 → exit 1"
export MOCK_LIVE_PANES="%1 %5"
reset_logs
rc=0; "$JUMP" "#999" >/dev/null 2>&1 || rc=$?
ck "未解決ラベル → exit 1" "1" "$rc"

# ----------------------------------------------------------------------------
# [8] %N がライブに無い（%99）→ ペイン無し exit 1（存在確認で select-pane 前に停止）
# ----------------------------------------------------------------------------
echo "[8] %99 がライブに無い → exit 1"
export MOCK_LIVE_PANES="%1 %5"
reset_logs
rc=0; "$JUMP" "%99" >/dev/null 2>&1 || rc=$?
ck "ペイン無し → exit 1" "1" "$rc"
ck "select-pane は呼ばれない" "no" "$(has_line "$(tmux_log)" 'select-pane')"

# ----------------------------------------------------------------------------
# [9] record → replay（無引数）: #142 を記録 → 無引数で %5 へ focus
# ----------------------------------------------------------------------------
echo "[9] --record #142 → 無引数 replay で select-pane -t %5"
export MOCK_LIVE_PANES="%1 %5 %7"
fixture_142
reset_record; reset_logs
rc=0; "$JUMP" --record "#142" >/dev/null 2>&1 || rc=$?
ck "--record rc=0" "0" "$rc"
ck "record はフォーカスしない（select-pane なし）" "no" "$(has_line "$(tmux_log)" 'select-pane')"
ck "state file が書かれる" "yes" "$([[ -f "$OE_JUMP_STATE_DIR/last-target" ]] && echo yes || echo no)"
reset_logs
rc=0; "$JUMP" >/dev/null 2>&1 || rc=$?
ck "無引数 replay rc=0" "0" "$rc"
ck "replay で select-pane -t %5" "yes" "$(has_line "$(tmux_log)" 'select-pane -t %5')"
rm_fixture_142

# ----------------------------------------------------------------------------
# [10] 無引数 + 記録なし → exit 1（replay 対象なし）
# ----------------------------------------------------------------------------
echo "[10] 無引数 + 記録なし → exit 1"
export MOCK_LIVE_PANES="%1 %5"
reset_record; reset_logs
rc=0; "$JUMP" >/dev/null 2>&1 || rc=$?
ck "replay 対象なし → exit 1" "1" "$rc"

# ----------------------------------------------------------------------------
# [11] --record 検証: 裸整数 → exit 2 / target なし → exit 2 / --print 併用 → exit 2
# ----------------------------------------------------------------------------
echo "[11] --record の検証（裸整数 / target 欠如 / --print 併用）→ exit 2"
reset_record
rc=0; "$JUMP" --record 5 >/dev/null 2>&1 || rc=$?
ck "--record 裸整数 → exit 2" "2" "$rc"
ck "拒否時 state は書かれない" "no" "$([[ -f "$OE_JUMP_STATE_DIR/last-target" ]] && echo yes || echo no)"
rc=0; "$JUMP" --record >/dev/null 2>&1 || rc=$?
ck "--record target 欠如 → exit 2" "2" "$rc"
rc=0; "$JUMP" --record --print "%5" >/dev/null 2>&1 || rc=$?
ck "--record + --print → exit 2" "2" "$rc"

# ----------------------------------------------------------------------------
# [12] --record はラベルを「解決せず」形だけ検証（実装SO 反映・回帰）。
#      ライブペイン無し/解決不能でも label token を記録できる（解決は jump 時）。
# ----------------------------------------------------------------------------
echo "[12] --record #179（解決不能でも記録できる・shape のみ検証）"
export MOCK_LIVE_PANES=""          # ライブペイン無し → 解決すれば失敗するはず
reset_record; reset_logs
rc=0; "$JUMP" --record "#179" >/dev/null 2>&1 || rc=$?
ck "未解決ラベルでも --record は成功" "0" "$rc"
ck "記録した token は '#179'" "#179" "$(head -n1 "$OE_JUMP_STATE_DIR/last-target" 2>/dev/null)"
ck "record は解決(list-panes)を呼ばない" "no" "$([[ -e "$_TMP_DIR/logs/tmux.log" ]] && echo yes || echo no)"

# ----------------------------------------------------------------------------
# [13] too many args → exit 2 / unknown option → exit 2 / --help → exit 0
# ----------------------------------------------------------------------------
echo "[13] too many / unknown option / --help"
export MOCK_LIVE_PANES="%1 %5 %7"
rc=0; "$JUMP" "%5" "%7" >/dev/null 2>&1 || rc=$?
ck "too many args → exit 2" "2" "$rc"
rc=0; "$JUMP" --bogus >/dev/null 2>&1 || rc=$?
ck "unknown option → exit 2" "2" "$rc"
rc=0; "$JUMP" --help >/dev/null 2>&1 || rc=$?
ck "--help → exit 0" "0" "$rc"

# ----------------------------------------------------------------------------
# [14] 明示の空文字 target は「省略」と取り違えず拒否する（実装SO R3 反映・回帰）。
#      記録があっても replay へ落とさない / 空文字後の余剰引数を黙って捨てない。
# ----------------------------------------------------------------------------
echo "[14] 明示空文字 target → replay せず exit 2（parser 回帰）"
export MOCK_LIVE_PANES="%1 %5"
reset_record; reset_logs
"$JUMP" --record "%5" >/dev/null 2>&1     # 記録を仕込む（replay 候補あり）
reset_logs
rc=0; "$JUMP" "" >/dev/null 2>&1 || rc=$?
ck "明示空文字 → exit 2（replay しない）" "2" "$rc"
ck "focus（select-pane）は呼ばれない" "no" "$(has_line "$(tmux_log)" 'select-pane')"
reset_logs
rc=0; "$JUMP" "" "%5" >/dev/null 2>&1 || rc=$?
ck "空文字 + 余剰引数 → exit 2（黙って捨てない）" "2" "$rc"
reset_record

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
