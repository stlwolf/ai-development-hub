#!/usr/bin/env bash
set -uo pipefail

# test_check_orphan_links.sh — 配布先に残った孤児 symlink の検出を検証（#359 PR-2）。
#
# 一時ディレクトリに偽の正本と偽の配布先を組んで走らせる。実 ~/.claude は触らない。
# 検証する軸:
#   - 正本を指すのに実体が無いリンクを orphan-canonical として拾う
#   - ディレクトリのリンクでも拾う（skills はディレクトリ単位）
#   - 正本の外を指す壊れたリンクは報告するが孤児に数えない
#   - 正本の外を指す生きたリンクは別分類で報告する（worktree 固定の検出）
#   - 通常ファイルには触らない
#   - 相対リンクでも正本配下かを正しく判定する
#   - 正本ディレクトリが無いときは緑を名乗らず中止する

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CHECK="$REPO_ROOT/scripts/sync/check-orphan-links.sh"

[[ -x "$CHECK" ]] || { echo "FAIL: check script not found: $CHECK"; exit 1; }

# mktemp の失敗を握り潰すと _TMP_DIR が空になり、fresh() が / 直下に
# ディレクトリを作りにいく。trap でも回収されないのでホストを汚す。
if ! _TMP_DIR="$(mktemp -d)" || [[ -z "$_TMP_DIR" || ! -d "$_TMP_DIR" ]]; then
  echo "FAIL: 一時ディレクトリを作れません"; exit 1
fi
trap 'rm -rf "$_TMP_DIR"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

CASE=""; CANON=""; BASE=""; OUT=""; RC=0
fresh() {
  CASE="$_TMP_DIR/$1"
  CANON="$CASE/canonical"; BASE="$CASE/home/.claude"
  mkdir -p "$CANON/rules" "$CANON/skills" "$BASE/rules" "$BASE/skills"
}
# 検査スクリプトは shebang 任せにせず、いま走っている bash で起動する。
# そうしないと /bin/bash 3.2 でテストを回しても、スクリプト側は PATH の
# bash 5 で動いてしまい、3.2 固有の挙動を踏めない。
run() { OUT="$("$BASH" "$CHECK" claude --base "$BASE" --canonical "$CANON" 2>&1)"; RC=$?; }
run_v() { OUT="$("$BASH" "$CHECK" claude --base "$BASE" --canonical "$CANON" --verbose 2>&1)"; RC=$?; }

# ============================================================================
echo "[1] 正本と一致している配布先 → 孤児なし"
fresh c1
printf 'x' > "$CANON/rules/alpha.md"
ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
run_v
ck  "exit 0" "0" "$RC"
ckc "孤児なしと出る" "$OUT" "正本から消えた配布先はありません"
ckc "1件走査した" "$OUT" "走査した symlink: 1 件"

echo "[2] 正本から消えたファイルの配布先 → orphan-canonical"
fresh c2
printf 'x' > "$CANON/rules/alpha.md"
ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
ln -s "$CANON/rules/retired.md" "$BASE/rules/retired.md"   # 正本に実体が無い
run
ck  "exit 1" "1" "$RC"
ckc "孤児として拾う" "$OUT" "orphan-canonical rules/retired.md"
ncc "生きているリンクは拾わない" "$OUT" "orphan-canonical rules/alpha.md"
ckc "件数を出す" "$OUT" "1 件残っています"

echo "[3] ディレクトリのリンクでも拾う（skills はディレクトリ単位）"
fresh c3
mkdir -p "$CANON/skills/alive"; printf 'x' > "$CANON/skills/alive/SKILL.md"
ln -s "$CANON/skills/alive" "$BASE/skills/alive"
ln -s "$CANON/skills/retired" "$BASE/skills/retired"
run
ck  "exit 1" "1" "$RC"
ckc "ディレクトリの孤児を拾う" "$OUT" "orphan-canonical skills/retired"
ncc "生きたディレクトリは拾わない" "$OUT" "orphan-canonical skills/alive"

echo "[4] 正本の外を指す壊れたリンク → 報告するが孤児に数えない"
fresh c4
ln -s "$CASE/somewhere-else/gone.md" "$BASE/rules/foreign.md"
run
ck  "exit 0（孤児ではない）" "0" "$RC"
ckc "分類して報告する" "$OUT" "dangling-outside rules/foreign.md"
ckc "触らないと書く" "$OUT" "正本の外なので触りません"
ncc "孤児とは呼ばない" "$OUT" "orphan-canonical rules/foreign.md"

echo "[5] 正本の外を指す生きたリンク → 別分類で報告（worktree 固定の検出）"
fresh c5
mkdir -p "$CASE/other-checkout/canonical/rules"
printf 'x' > "$CASE/other-checkout/canonical/rules/alpha.md"
ln -s "$CASE/other-checkout/canonical/rules/alpha.md" "$BASE/rules/alpha.md"
run
ck  "exit 0" "0" "$RC"
ckc "既定では要約だけ出す" "$OUT" "生きている 1 件"
ncc "既定では1件ずつ出さない" "$OUT" "alive-outside rules/alpha.md"
run_v
ckc "verbose なら別分類で報告" "$OUT" "alive-outside rules/alpha.md"
ckc "固定されている可能性と書く" "$OUT" "別のチェックアウトに固定されている可能性"

echo "[6] 通常ファイルには触らない"
fresh c6
printf 'x' > "$BASE/rules/handwritten.md"
printf 'x' > "$CANON/rules/alpha.md"
ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
run_v
ck  "exit 0" "0" "$RC"
ncc "通常ファイルを孤児にしない" "$OUT" "handwritten.md"
ckc "symlink だけを数える" "$OUT" "走査した symlink: 1 件"

echo "[7] 相対リンクでも正本配下かを判定する"
fresh c7
printf 'x' > "$CANON/rules/alpha.md"
# $BASE/rules/ から $CANON/rules/ までは3段上がる（home/.claude/rules → CASE）
ln -s "../../../canonical/rules/retired.md" "$BASE/rules/retired.md"
run
ck  "exit 1" "1" "$RC"
ckc "相対リンクの孤児を拾う" "$OUT" "orphan-canonical rules/retired.md"

fresh c7b
printf 'x' > "$CANON/rules/alpha.md"
# 正本の外を指す壊れた相対リンクは孤児に数えない
ln -s "../../../elsewhere/gone.md" "$BASE/rules/foreign.md"
run
ck  "外を指す相対リンクは exit 0" "0" "$RC"
ckc "外として分類" "$OUT" "dangling-outside rules/foreign.md"

echo "[8] 正本ディレクトリが無い → 緑を名乗らず中止"
fresh c8
printf 'x' > "$CANON/rules/alpha.md"
ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
rm -rf "$CANON"
run
ck  "exit 2" "2" "$RC"
ckc "中止すると言う" "$OUT" "検査を中止します"
ncc "孤児なしとは言わない" "$OUT" "正本から消えた配布先はありません"

echo "[9] allowlist の外は歩かない"
fresh c9
mkdir -p "$BASE/statsig"
ln -s "$CANON/rules/retired.md" "$BASE/statsig/retired.md"
run_v
ck  "exit 0" "0" "$RC"
ncc "allowlist 外は拾わない" "$OUT" "statsig"
ckc "0件走査" "$OUT" "走査した symlink: 0 件"

echo "[10] ターゲット未指定 / 不正引数"
OUT="$("$CHECK" 2>&1)"; RC=$?
ck  "ターゲットなし → exit 2" "2" "$RC"
OUT="$("$CHECK" nosuchtool 2>&1)"; RC=$?
ck  "知らないターゲット → exit 2" "2" "$RC"

echo "[11] .. がパスの深さを超える相対リンクでも落ちない（実装SO 指摘の回帰）"
fresh c11
# /a/../../gone.md は、正規化の途中で一度スタックが空になる最小の形。
# bash 3.2 では set -u のもとで空配列の "${a[@]}" が unbound になり、
# 修正前はこのリンクが分類されないまま黙って落ちていた。
ln -s "/a/../../gone.md" "$BASE/rules/absup.md"
run
ck  "落ちない" "0" "$RC"
ncc "unbound variable を出さない" "$OUT" "unbound variable"
ckc "分類が落ちない" "$OUT" "dangling-outside rules/absup.md"

echo "[12] リンク先に glob 文字が入っていても展開しない（実装SO 指摘の回帰）"
fresh c12
printf 'x' > "$CANON/rules/alpha.md"
printf 'x' > "$CANON/rules/beta.md"
# リンク先に * を含める。展開されると正本の別ファイルに化けて分類が狂う。
ln -s "$CANON/rules/*" "$BASE/rules/star.md"
run
ncc "unbound や error を出さない" "$OUT" "error"
ckc "リンク先をそのまま報告する" "$OUT" "orphan-canonical rules/star.md"
ck  "孤児として exit 1" "1" "$RC"

echo "[13] 配布先を走査できないとき緑を名乗らない（実装SO 指摘の回帰）"
fresh c13
printf 'x' > "$CANON/rules/alpha.md"
ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
chmod 000 "$BASE/rules"
run
chmod 755 "$BASE/rules"
if [[ "$(id -u)" -eq 0 ]]; then
  echo "  SKIP: root では読み取り権限を落としても走査できるため"
else
  ck  "exit 2（孤児ありとは別の状態）" "2" "$RC"
  ckc "判定できないと言う" "$OUT" "孤児の有無を判定できません"
  ncc "孤児なしとは言わない" "$OUT" "正本から消えた配布先はありません"
fi

echo "[14] 綴りだけ違うリンク先でも正本配下と判定する（実装SO 指摘の回帰）"
fresh c14
printf 'x' > "$CANON/rules/alpha.md"
probe="$(dirname "$CANON")/.case-probe.$$"
: > "$probe"
if [[ -e "$(dirname "$CANON")/.CASE-PROBE.$$" ]]; then
  rm -f "$probe"
  upper_canon="$(dirname "$CANON")/CANONICAL"
  ln -s "$upper_canon/rules/retired.md" "$BASE/rules/retired.md"
  run
  ck  "綴り違いでも孤児として拾う" "1" "$RC"
  ckc "孤児として分類" "$OUT" "orphan-canonical rules/retired.md"
else
  rm -f "$probe"
  echo "  SKIP: 大文字小文字を区別するファイルシステムのため"
fi

echo "[15] 名前に改行が入っていても1件として数える（実装SO 指摘の回帰）"
fresh c15
weird="$(printf 'two\nlines.md')"
ln -s "$CANON/rules/retired.md" "$BASE/rules/$weird"
run_v
ck  "exit 1" "1" "$RC"
ckc "1件として数える" "$OUT" "走査した symlink: 1 件"
ckc "孤児として拾う" "$OUT" "orphan-canonical"

echo "[16] 何も無いときは既定では黙る（--check の出力を変えない）"
fresh c16
printf 'x' > "$CANON/rules/alpha.md"
ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
run
ck  "exit 0" "0" "$RC"
ck  "出力は空" "" "$OUT"
run_v
ckc "verbose なら内訳を出す" "$OUT" "走査した symlink: 1 件"

echo "[17] 検査が正本の隣にファイルを作らない（実装SO 指摘の回帰）"
fresh c17
printf 'x' > "$CANON/rules/alpha.md"
ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
before="$(find "$CASE" -maxdepth 1 -mindepth 1 | sort)"
run_v
after="$(find "$CASE" -maxdepth 1 -mindepth 1 | sort)"
ck  "正本の隣に増減がない" "$before" "$after"

echo "[18] 中間の symlink が外を指すリンクを孤児にしない（実装SO 指摘の回帰）"
fresh c18
mkdir -p "$CASE/outside/rules"
printf 'x' > "$CASE/outside/rules/alpha.md"
# 正本配下の名前だが、途中の symlink で外へ抜ける
mkdir -p "$CANON/linked"
ln -s "$CASE/outside" "$CANON/linked/out"
ln -s "$CANON/linked/out/rules/alpha.md" "$BASE/rules/via.md"
run_v
ck  "孤児にしない" "0" "$RC"
ckc "外向きとして数える" "$OUT" "生きている 1 件"
ncc "孤児と呼ばない" "$OUT" "orphan-canonical rules/via.md"

echo "[19] オプションの値が欠けたら exit 2（実装SO 指摘の回帰）"
OUT="$("$BASH" "$CHECK" claude --base 2>&1)"; RC=$?
ck  "--base の値なし → exit 2" "2" "$RC"
ckc "値が無いと言う" "$OUT" "--base に値がありません"
OUT="$("$BASH" "$CHECK" claude --canonical 2>&1)"; RC=$?
ck  "--canonical の値なし → exit 2" "2" "$RC"

echo "[20] 配布先の親を辿れないとき緑を名乗らない（実装SO 指摘の回帰）"
fresh c20
printf 'x' > "$CANON/rules/alpha.md"
ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
chmod 000 "$BASE"
run
chmod 755 "$BASE"
if [[ "$(id -u)" -eq 0 ]]; then
  echo "  SKIP: root では権限を落としても辿れるため"
else
  ck  "exit 2（孤児ありとは別の状態）" "2" "$RC"
  ncc "孤児なしとは言わない" "$OUT" "正本から消えた配布先はありません"
fi

echo "[21] 走査ルート自体が symlink でも中を見る（実装SO 指摘の回帰）"
fresh c21
printf 'x' > "$CANON/rules/alpha.md"
rmdir "$BASE/rules"
mkdir -p "$CASE/real_rules"
ln -s "$CASE/real_rules" "$BASE/rules"
ln -s "$CANON/rules/retired.md" "$CASE/real_rules/retired.md"
run
ck  "孤児を見つける" "1" "$RC"
ckc "孤児として分類" "$OUT" "orphan-canonical rules/retired.md"

echo "[22] 中間 symlink で外へ抜ける壊れたリンクを孤児にしない（実装SO 指摘の回帰）"
fresh c22
mkdir -p "$CASE/outside" "$CANON/linked"
ln -s "$CASE/outside" "$CANON/linked/out"
# 字句的には正本配下だが、実体は正本の外。しかも解決先は存在しない。
ln -s "$CANON/linked/out/gone.md" "$BASE/rules/via.md"
run_v
ck  "孤児にしない" "0" "$RC"
ckc "外向きとして分類" "$OUT" "dangling-outside rules/via.md"
ncc "孤児と呼ばない" "$OUT" "orphan-canonical rules/via.md"

echo "[23] realpath が解決できないときの経路（存在する祖先まで遡る）"
fresh c23
# 中間が壊れた symlink だと realpath は空を返す。この場合だけ字句の遡りが走る。
ln -s "$CASE/nowhere" "$CANON/broken_mid"
ln -s "$CANON/broken_mid/leaf.md" "$BASE/rules/x.md"
run
ck  "孤児として拾う" "1" "$RC"
ckc "孤児として分類" "$OUT" "orphan-canonical rules/x.md"

echo "[24] 終了コードの3値が区別できる"
fresh c24
printf 'x' > "$CANON/rules/alpha.md"
ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
run
ck  "孤児なし → 0" "0" "$RC"
ln -s "$CANON/rules/retired.md" "$BASE/rules/retired.md"
run
ck  "孤児あり → 1" "1" "$RC"
OUT="$("$BASH" "$CHECK" claude --base "$BASE" --canonical "$CASE/no-such-canonical" 2>&1)"; RC=$?
ck  "正本が無い → 2" "2" "$RC"

echo "[25] 途中の symlink を挟んだ .. を字句で畳まない（実装SO 指摘の回帰）"
fresh c25
mkdir -p "$CASE/outside/subdir"
ln -s "$CASE/outside/subdir" "$CANON/jump"
# canonical/jump/../missing の実体は outside/missing であって canonical/missing ではない。
# 字句で畳むと正本配下と誤り、掃除の対象に混ざる。
ln -s "$CANON/jump/../missing" "$BASE/rules/tricky.md"
run_v
ncc "孤児と呼ばない" "$OUT" "orphan-canonical rules/tricky.md"
ckc "外向きとして分類" "$OUT" "dangling-outside rules/tricky.md"
ck  "孤児なしで exit 0" "0" "$RC"

echo "[26] リンク先のバックスラッシュを解釈しない（実装SO 指摘の回帰）"
fresh c26
weird="$(printf 'we\\ntwo.md')"
ln -s "$CANON/rules/$weird" "$BASE/rules/bs.md"
run
ck  "孤児として拾う" "1" "$RC"
ckc "リンク先をそのまま出す" "$OUT" 'we\ntwo.md'

echo ""
echo "=== PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
