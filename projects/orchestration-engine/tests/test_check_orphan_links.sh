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

_TMP_DIR="$(mktemp -d)"
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
run() { OUT="$("$CHECK" claude --base "$BASE" --canonical "$CANON" 2>&1)"; RC=$?; }

# ============================================================================
echo "[1] 正本と一致している配布先 → 孤児なし"
fresh c1
printf 'x' > "$CANON/rules/alpha.md"
ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
run
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
ckc "別分類で報告" "$OUT" "alive-outside rules/alpha.md"
ckc "固定されている可能性と書く" "$OUT" "別のチェックアウトに固定されている可能性"

echo "[6] 通常ファイルには触らない"
fresh c6
printf 'x' > "$BASE/rules/handwritten.md"
printf 'x' > "$CANON/rules/alpha.md"
ln -s "$CANON/rules/alpha.md" "$BASE/rules/alpha.md"
run
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
run
ck  "exit 0" "0" "$RC"
ncc "allowlist 外は拾わない" "$OUT" "statsig"
ckc "0件走査" "$OUT" "走査した symlink: 0 件"

echo "[10] ターゲット未指定 / 不正引数"
OUT="$("$CHECK" 2>&1)"; RC=$?
ck  "ターゲットなし → exit 2" "2" "$RC"
OUT="$("$CHECK" nosuchtool 2>&1)"; RC=$?
ck  "知らないターゲット → exit 2" "2" "$RC"

echo ""
echo "=== PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
