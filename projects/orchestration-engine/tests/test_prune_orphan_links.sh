#!/usr/bin/env bash
set -uo pipefail

# test_prune_orphan_links.sh — 孤児 symlink の掃除を検証（#359 PR-5）。
#
# 一時ディレクトリに偽の正本と偽の配布先を組んで走らせる。実 ~/.claude は触らない。
# 削除してよいのは、次を「すべて」満たすものだけという契約を確かめる。
#   1. リンク先を物理的に解決した結果が正本ディレクトリ配下である
#   2. その解決先に実体が無い
#   3. いま配布規則がその名前を配ろうとしていない
# あわせて、既定では何も消さないこと、正本の側が壊れているときは掃除しないことを見る。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CHECK="$REPO_ROOT/scripts/sync/check-orphan-links.sh"

[[ -x "$CHECK" ]] || { echo "FAIL: check script not found: $CHECK"; exit 1; }

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
  mkdir -p "$CANON/rules" "$CANON/skills" "$CANON/hooks/scripts" \
           "$BASE/rules" "$BASE/skills" "$BASE/hooks"
  # 正本の側が空だと掃除を止める仕掛けがあるので、常に何か置いておく
  printf 'x' > "$CANON/rules/alpha.md"
  ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
}
run()   { OUT="$("$BASH" "$CHECK" claude --base "$BASE" --canonical "$CANON" 2>&1)"; RC=$?; }
prune() { OUT="$("$BASH" "$CHECK" claude --base "$BASE" --canonical "$CANON" --prune 2>&1)"; RC=$?; }

# ============================================================================
echo "[1] 既定では何も消さない"
fresh c1
ln -s "$CANON/rules/retired.md" "$BASE/rules/retired.md"
run
ck  "exit 1（孤児あり）" "1" "$RC"
ck  "リンクは残っている" "true" "$([[ -L "$BASE/rules/retired.md" ]] && echo true || echo false)"
ckc "消し方を案内する" "$OUT" "--prune を付けてください"

echo "[2] --prune を付けたときだけ消す"
fresh c2
ln -s "$CANON/rules/retired.md" "$BASE/rules/retired.md"
prune
ck  "exit 0" "0" "$RC"
ck  "リンクが消えた" "false" "$([[ -L "$BASE/rules/retired.md" ]] && echo true || echo false)"
ckc "削除したと言う" "$OUT" "削除: rules/retired.md"
ck  "生きているリンクは残る" "true" "$([[ -L "$BASE/rules/alpha.md" ]] && echo true || echo false)"

echo "[3] 条件3: いま配布規則が配ろうとしている名前は消さない"
fresh c3
# 正本に実体はあるが、リンク先が別の（存在しない）パスを指している状態を作る。
printf 'x' > "$CANON/rules/beta.md"
ln -s "$CANON/rules/beta-old-path.md" "$BASE/rules/beta.md"
prune
ck  "消さない" "true" "$([[ -L "$BASE/rules/beta.md" ]] && echo true || echo false)"
ckc "配布の対象だと言う" "$OUT" "いまも配布の対象なので触りません"
ck  "exit 1（残した孤児がある）" "1" "$RC"

echo "[4] 条件3: skills はディレクトリと SKILL.md の両方を見る"
fresh c4
# 孤児が過半数だと安全側のガードで掃除を止めるので、生きたリンクを足しておく
for n in b c d; do printf 'x' > "$CANON/rules/$n.md"; ln -s "$CANON/rules/$n.md" "$BASE/rules/$n.md"; done
mkdir -p "$CANON/skills/live"; printf 'x' > "$CANON/skills/live/SKILL.md"
ln -s "$CANON/skills/live-old" "$BASE/skills/live"      # 正本にあるので消さない
mkdir -p "$CANON/skills/nosk"                            # SKILL.md が無い
ln -s "$CANON/skills/nosk-old" "$BASE/skills/nosk"       # 配布対象ではないので消す
prune
ck  "SKILL.md がある名前は消さない" "true" "$([[ -L "$BASE/skills/live" ]] && echo true || echo false)"
ck  "SKILL.md が無い名前は消す" "false" "$([[ -L "$BASE/skills/nosk" ]] && echo true || echo false)"

echo "[5] 条件3: 拡張子が規則に合わないものは配布対象でないので消す"
fresh c5
printf 'x' > "$CANON/rules/note.txt"
ln -s "$CANON/rules/note.txt.gone" "$BASE/rules/note.txt"
prune
ck  ".txt は配布対象でないので消す" "false" "$([[ -L "$BASE/rules/note.txt" ]] && echo true || echo false)"

echo "[6] 条件1: 正本の外を指すものは消さない"
fresh c6
ln -s "$CASE/elsewhere/gone.md" "$BASE/rules/foreign.md"
prune
ck  "消さない" "true" "$([[ -L "$BASE/rules/foreign.md" ]] && echo true || echo false)"
ncc "削除したとは言わない" "$OUT" "削除: rules/foreign.md"

echo "[7] 条件1: 中間の symlink で外へ抜けるものは消さない"
fresh c7
mkdir -p "$CASE/outside"
ln -s "$CASE/outside" "$CANON/jump"
ln -s "$CANON/jump/gone.md" "$BASE/rules/tricky.md"
prune
ck  "消さない" "true" "$([[ -L "$BASE/rules/tricky.md" ]] && echo true || echo false)"

echo "[8] 通常ファイルは消さない"
fresh c8
printf 'handwritten' > "$BASE/rules/mine.md"
ln -s "$CANON/rules/retired.md" "$BASE/rules/retired.md"
prune
ck  "通常ファイルは残る" "true" "$([[ -f "$BASE/rules/mine.md" && ! -L "$BASE/rules/mine.md" ]] && echo true || echo false)"
ck  "中身も変わらない" "handwritten" "$(cat "$BASE/rules/mine.md")"
ck  "孤児は消えた" "false" "$([[ -L "$BASE/rules/retired.md" ]] && echo true || echo false)"

echo "[9] 正本の根が無いときは掃除しない"
fresh c9
ln -s "$CANON/rules/retired.md" "$BASE/rules/retired.md"
rm -rf "$CANON"
prune
ck  "exit 2" "2" "$RC"
ck  "リンクは残る" "true" "$([[ -L "$BASE/rules/retired.md" ]] && echo true || echo false)"
ckc "中止すると言う" "$OUT" "検査を中止します"

echo "[10] 正本の中身が空のときは掃除しない"
fresh c10
ln -s "$CANON/rules/retired.md" "$BASE/rules/retired.md"
rm -f "$CANON/rules/alpha.md"
rm -f "$BASE/rules/alpha.md"
prune
ck  "exit 2" "2" "$RC"
ck  "リンクは残る" "true" "$([[ -L "$BASE/rules/retired.md" ]] && echo true || echo false)"
ckc "空だと言う" "$OUT" "正本の側が空です"

echo "[11] 孤児が配備物の半分を超えるときは掃除しない"
fresh c11
for n in a b c d; do ln -s "$CANON/rules/gone-$n.md" "$BASE/rules/gone-$n.md"; done
prune
ck  "exit 2" "2" "$RC"
ckc "半分を超えると言う" "$OUT" "半分を超えています"
ck  "リンクは残る" "true" "$([[ -L "$BASE/rules/gone-a.md" ]] && echo true || echo false)"

echo "[12] 削除の直前にやり直す（張り直されていたら消さない）"
fresh c12
printf 'x' > "$CANON/rules/beta.md"
ln -s "$CANON/rules/retired.md" "$BASE/rules/retired.md"
# 検出の後・削除の前に、対象を生きたリンクへ張り替える
sed "s|^    pruned=0|    ln -sfn '$CANON/rules/beta.md' '$BASE/rules/retired.md'\n    pruned=0|" \
    "$CHECK" > "$CASE/prune_race.sh"
chmod +x "$CASE/prune_race.sh"
ck  "割り込みを挿せた" "1" "$(grep -c 'ln -sfn' "$CASE/prune_race.sh" | tr -d ' ')"
OUT="$("$BASH" "$CASE/prune_race.sh" claude --base "$BASE" --canonical "$CANON" --prune 2>&1)"; RC=$?
ck  "張り直された先が残る" "true" "$([[ -L "$BASE/rules/retired.md" ]] && echo true || echo false)"
ckc "解決できるようになったと言う" "$OUT" "解決できるようになったので触りません"

echo "[13] 消したものは sync を再実行すれば戻る（symlink しか消さない）"
fresh c13
ln -s "$CANON/rules/retired.md" "$BASE/rules/retired.md"
before_files="$(find "$BASE" -type f | wc -l | tr -d ' ')"
prune
after_files="$(find "$BASE" -type f | wc -l | tr -d ' ')"
ck  "通常ファイルの数は変わらない" "$before_files" "$after_files"
ck  "消えたのは symlink だけ" "0" "$(find "$BASE" -maxdepth 2 -name 'retired.md' | wc -l | tr -d ' ')"

echo "[14] 正本が入れ子でも配布対象と認める（実装SO 指摘の回帰・誤削除の防止）"
fresh c14
# 配布は basename だけを見て平らに置くので、正本が分類ディレクトリの下にあっても
# 配布対象である。表を手で持っていたときは、これを見落として消しにいっていた。
mkdir -p "$CANON/commands/review" "$BASE/commands"
printf 'x' > "$CANON/commands/review/pr-review.md"
ln -s "$CANON/commands/pr-review.md" "$BASE/commands/pr-review.md"   # 旧い平置きのパスを指す
prune
ck  "消さない" "true" "$([[ -L "$BASE/commands/pr-review.md" ]] && echo true || echo false)"
ckc "配布の対象だと言う" "$OUT" "いまも配布の対象なので触りません"

echo "[15] ツール固有の正本（別ディレクトリ）でも配布対象と認める"
fresh c15
mkdir -p "$CANON/cursor/rules" "$BASE/rules"
printf 'x' > "$CANON/cursor/rules/only-cursor.mdc"
ln -s "$CANON/rules/only-cursor.mdc" "$BASE/rules/only-cursor.mdc"
prune
ck  "消さない" "true" "$([[ -L "$BASE/rules/only-cursor.mdc" ]] && echo true || echo false)"

echo "[16] 実機の配布名を当てて誤削除しないことを確かめる（読み取りのみ）"
real_canon="$REPO_ROOT/canonical"
if [[ -d "$real_canon/commands" ]]; then
  miss=0
  while IFS= read -r f; do
    n="$(basename "$f")"
    find "$real_canon" -type f -name "$n" 2>/dev/null | head -1 | grep -q . || miss=$((miss+1))
  done < <(find "$real_canon/commands" -type f -name '*.md')
  ck  "実機の commands はすべて配布対象と判定される" "0" "$miss"
else
  echo "  SKIP: canonical/commands が無い"
fi

echo "[17] 配布対象かを確かめられないときは消さない（実装SO 指摘の回帰・安全弁）"
fresh c17
ln -s "$CANON/rules/retired.md" "$BASE/rules/retired.md"
# 正本の探索を必ず失敗させる複製を作る。安全弁が失敗したら、消してよい側では
# なく残す側へ倒れることを見る。
# shellcheck disable=SC2016  # sed のパターンなのでシェルに展開させない
sed 's|^        found="$(find "${CANONICAL_REAL}" -type f -name "${entry_name}" 2>/dev/null . head -1)" .. rc=$?|        found=""; rc=7|' \
    "$CHECK" > "$CASE/prune_probefail.sh"
chmod +x "$CASE/prune_probefail.sh"
ck  "割り込みを挿せた" "1" "$(grep -cE '^        found=""; rc=7$' "$CASE/prune_probefail.sh" | tr -d ' ')"
OUT="$("$BASH" "$CASE/prune_probefail.sh" claude --base "$BASE" --canonical "$CANON" --prune 2>&1)"; RC=$?
ck  "リンクは残る" "true" "$([[ -L "$BASE/rules/retired.md" ]] && echo true || echo false)"
ckc "確かめられないと言う" "$OUT" "配布対象かを確かめられませんでした"
ckc "安全側に倒すと言う" "$OUT" "安全側に倒して残します"
ck  "exit 1（残した孤児がある）" "1" "$RC"

echo "[18] 掃除も3ターゲットで走る（走査根の脱落の回帰）"
fresh c18
for t in claude cursor codex; do
  o="$("$BASH" "$CHECK" "$t" --base "$BASE" --canonical "$CANON" --prune 2>&1)"; r=$?
  ncc "$t で未定義変数を踏まない" "$o" "unbound variable"
  ck  "$t は 0 か 1 か 2 で返る" "true" "$([[ "$r" -ge 0 && "$r" -le 2 ]] && echo true || echo false)"
done

echo ""
echo "=== PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
