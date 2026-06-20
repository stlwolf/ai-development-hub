#!/usr/bin/env bash
set -euo pipefail

# test_oe_kick.sh — oe-kick の 1 引数判定とフラグ展開を検証する
#
# 実 tmux / Claude / oe-delegate は起動しない。OE_DELEGATE_BIN をモックに差し替え、
# oe-kick が組み立てて exec する argv（モックが 1 引数 1 行で記録）を assert する。
# モック argv の検証で ref 判定 / kickoff-<N> 抽出 / issue task 文 / tmux preflight 順序
# まで覆う（exec 展開のみではない）。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
mkdir -p "$_TMP_DIR/bin" "$_TMP_DIR/ws"

# モック oe-delegate: 受け取った argv を 1 引数 1 行で記録して即終了。
cat > "$_TMP_DIR/bin/oe-delegate-mock" <<'EOF'
#!/usr/bin/env bash
: > "${OE_KICK_TEST_ARGV:?}"
for a in "$@"; do printf '%s\n' "$a" >> "${OE_KICK_TEST_ARGV}"; done
exit 0
EOF
chmod +x "$_TMP_DIR/bin/oe-delegate-mock"

export OE_DELEGATE_BIN="$_TMP_DIR/bin/oe-delegate-mock"
export OE_KICK_TEST_ARGV="$_TMP_DIR/argv.log"
export TMUX_PANE="%1"
WS="$_TMP_DIR/ws"

PASS=0
FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"; printf '    want=[%s]\n    got =[%s]\n' "$expected" "$actual"; FAIL=$((FAIL + 1))
  fi
}

reset() { rm -f "$OE_KICK_TEST_ARGV"; }
run_kick() { bash "$PROJECT_DIR/bin/oe-kick" "$@" >"$_TMP_DIR/out.log" 2>"$_TMP_DIR/err.log"; }
argv() { cat "$OE_KICK_TEST_ARGV" 2>/dev/null; }
called() { [[ -e "$OE_KICK_TEST_ARGV" ]] && echo yes || echo no; }

# 期待 argv を 1 引数 1 行で組む（NUL 不要・改行を含む引数は無い）。
expect() { printf '%s\n' "$@"; }

echo "[1] issue mode: #178 -> --label '#178' + gh task"
reset
run_kick -w "$WS" "#178"
ck "issue #178 argv" \
  "$(expect -w "$WS" --label "#178" -- "Issue #178 の内容を gh issue view 178 で確認して作業を進めて。リポジトリ: $WS")" \
  "$(argv)"

echo "[2] issue mode: 素の番号 178 も #178 と同じ展開"
reset
run_kick -w "$WS" "178"
ck "bare 178 == #178" \
  "$(expect -w "$WS" --label "#178" -- "Issue #178 の内容を gh issue view 178 で確認して作業を進めて。リポジトリ: $WS")" \
  "$(argv)"

echo "[3] issue mode: leading zero 0178 を 178 に正規化"
reset
run_kick -w "$WS" "#0178"
ck "0178 -> #178 (label)"  "#178" "$(argv | sed -n '4p')"
ck "0178 -> view 178 (task)" "Issue #178 の内容を gh issue view 178 で確認して作業を進めて。リポジトリ: $WS" "$(argv | sed -n '6p')"

echo "[4] issue mode: 末尾 ad-hoc を既定 task に連結"
reset
run_kick -w "$WS" "#178" "テストも書いて"
ck "issue ad-hoc appended" \
  "Issue #178 の内容を gh issue view 178 で確認して作業を進めて。リポジトリ: $WS テストも書いて" \
  "$(argv | sed -n '6p')"

echo "[5] kickoff mode: ファイル名 kickoff-<N> から #N ラベル導出"
reset
KO="$_TMP_DIR/2026-06-20-kickoff-178-foo.md"; printf '# k\n' > "$KO"
run_kick -w "$WS" "$KO"
ck "kickoff argv" "$(expect -w "$WS" --label "#178" --kickoff "$KO" --)" "$(argv)"

echo "[6] kickoff mode: 番号無しファイル名 -> ラベル無し"
reset
KO2="$_TMP_DIR/notes.md"; printf '# n\n' > "$KO2"
run_kick -w "$WS" "$KO2"
ck "kickoff no-label argv" "$(expect -w "$WS" --kickoff "$KO2" --)" "$(argv)"

echo "[7] kickoff mode: 末尾 ad-hoc は oe-delegate task として渡る"
reset
run_kick -w "$WS" "$KO" "補足あり"
ck "kickoff ad-hoc argv" "$(expect -w "$WS" --label "#178" --kickoff "$KO" -- "補足あり")" "$(argv)"

echo "[8] --claude-arg passthrough（issue より前・repeatable）"
reset
run_kick -w "$WS" --claude-arg --permission-mode --claude-arg auto "#178"
ck "claude-arg passthrough argv" \
  "$(expect -w "$WS" --claude-arg --permission-mode --claude-arg auto --label "#178" -- "Issue #178 の内容を gh issue view 178 で確認して作業を進めて。リポジトリ: $WS")" \
  "$(argv)"

echo "[9] workspace 既定（-w 省略時は cwd）"
reset
( cd "$WS" && bash "$PROJECT_DIR/bin/oe-kick" "#178" >/dev/null 2>&1 )
ck "default workspace = cwd" "$WS" "$(argv | sed -n '2p')"

echo "[10] 第三分類（非ファイル・非数値）-> rc2・oe-delegate 未呼出"
reset
rc=0; run_kick -w "$WS" "abc" || rc=$?
ck "third-class rc=2" "2" "$rc"
ck "third-class did not call delegate" "no" "$(called)"

echo "[11] 数字混じり 178a も第三分類"
reset
rc=0; run_kick -w "$WS" "178a" || rc=$?
ck "178a rc=2" "2" "$rc"
ck "178a did not call delegate" "no" "$(called)"

echo "[12] ref 省略 -> rc2・未呼出"
reset
rc=0; run_kick -w "$WS" || rc=$?
ck "missing ref rc=2" "2" "$rc"
ck "missing ref did not call delegate" "no" "$(called)"

echo "[13] tmux 外（TMUX_PANE 未設定）-> rc1・未呼出（task 組立前に fail）"
reset
rc=0; ( unset TMUX_PANE; bash "$PROJECT_DIR/bin/oe-kick" -w "$WS" "#178" >/dev/null 2>"$_TMP_DIR/err.log" ) || rc=$?
ck "no tmux rc=1" "1" "$rc"
ck "no tmux did not call delegate" "no" "$(called)"

echo "[14] -h -> rc0・未呼出"
reset
rc=0; run_kick -h || rc=$?
ck "help rc=0" "0" "$rc"
ck "help did not call delegate" "no" "$(called)"

echo "[15] file 優先: 番号名ファイルが cwd にあれば kickoff 扱い"
reset
NUMF="$_TMP_DIR/178"; printf 'x\n' > "$NUMF"
run_kick -w "$WS" "$NUMF"
# basename=178 は kickoff-<N> に当たらない -> ラベル無し・kickoff 経路
ck "numeric-name file -> kickoff path" "$NUMF" "$(argv | sed -n '4p')"
ck "numeric-name file -> --kickoff verb" "--kickoff" "$(argv | sed -n '3p')"

echo "[16] unknown option -> rc2・未呼出"
reset
rc=0; run_kick --bogus "#178" || rc=$?
ck "unknown option rc=2" "2" "$rc"
ck "unknown option did not call delegate" "no" "$(called)"

echo "[17] 巨大番号: 算術 overflow による silent 別 issue 化を防ぐ（番号を欠損なく保持）"
reset
BIG="999999999999999999999999999999999999999"
run_kick -w "$WS" "#$BIG"
ck "issue huge label preserved (no overflow)" "#$BIG" "$(argv | sed -n '4p')"
ck "issue huge task preserved" \
  "Issue #$BIG の内容を gh issue view $BIG で確認して作業を進めて。リポジトリ: $WS" \
  "$(argv | sed -n '6p')"
reset
KOBIG="$_TMP_DIR/kickoff-$BIG-x.md"; printf 'x\n' > "$KOBIG"
run_kick -w "$WS" "$KOBIG"
ck "kickoff huge label preserved (no overflow)" "#$BIG" "$(argv | sed -n '4p')"

echo "[18] 先頭ゼロ正規化は文字列操作で（巨大でも崩れない）"
reset
run_kick -w "$WS" "#0000178"
ck "0000178 -> #178" "#178" "$(argv | sed -n '4p')"
reset
run_kick -w "$WS" "#000"
ck "all-zeros -> #0 (最低1桁)" "#0" "$(argv | sed -n '4p')"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
