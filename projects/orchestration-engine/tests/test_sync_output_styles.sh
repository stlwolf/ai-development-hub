#!/usr/bin/env bash
set -uo pipefail

# test_sync_output_styles.sh — output style の配布経路を検証（#359 PR-4）。
#
# 一時ディレクトリの HOME だけを触る（実 ~/.claude は読まない・書かない）。
# 検証する軸:
#   - canonical に置いた .md が配布先へ symlink として現れる
#   - .md でないファイル（README.txt 等）は配らない
#   - 配布先に同名の通常ファイルがあれば上書きせず飛ばす（手で置いたものを守る）
#   - 正本のディレクトリが無くても sync が止まらない
#   - --check の走査対象に入る
#   - 孤児 symlink の走査根に入る

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SYNC="$REPO_ROOT/scripts/sync/sync-claude.sh"
ORPHAN="$REPO_ROOT/scripts/sync/check-orphan-links.sh"
CANON="$REPO_ROOT/canonical"

[[ -x "$SYNC" ]] || { echo "FAIL: sync-claude.sh not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

if ! _TMP_DIR="$(mktemp -d)" || [[ -z "$_TMP_DIR" || ! -d "$_TMP_DIR" ]]; then
  echo "FAIL: 一時ディレクトリを作れません"; exit 1
fi
trap 'rm -rf "$_TMP_DIR"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }

HOMEDIR=""; OUT=""; RC=0
fresh() { HOMEDIR="$_TMP_DIR/$1"; mkdir -p "$HOMEDIR/.claude"; }
run()   { OUT="$(env HOME="$HOMEDIR" "$SYNC" 2>&1)"; RC=$?; }

# ============================================================================
echo "[1] canonical の正本ディレクトリが存在する"
ck  "canonical/output-styles がある" "true" "$([[ -d "$CANON/output-styles" ]] && echo true || echo false)"
ck  "README.txt は .md ではない" "true" "$([[ -f "$CANON/output-styles/README.txt" ]] && echo true || echo false)"

echo "[2] .md を配り、.md でないものは配らない"
fresh h2
# 正本へ一時的にスタイルを置く（テストの後で消す）
tmp_style="$CANON/output-styles/.test-style-$$.md"
printf -- '---\nname: Test Style\ndescription: for test\n---\n\nbody\n' > "$tmp_style"
run
rm -f "$tmp_style"
ck  "sync は成功する" "0" "$RC"
ck  "スタイルが symlink で現れる" "true" "$([[ -L "$HOMEDIR/.claude/output-styles/$(basename "$tmp_style")" ]] && echo true || echo false)"
ck  "README.txt は配られない" "false" "$([[ -e "$HOMEDIR/.claude/output-styles/README.txt" ]] && echo true || echo false)"

echo "[3] 配布先の通常ファイルを上書きしない（手で置いたものを守る）"
fresh h3
mkdir -p "$HOMEDIR/.claude/output-styles"
printf 'handwritten' > "$HOMEDIR/.claude/output-styles/mine.md"
tmp_style="$CANON/output-styles/mine.md"
printf 'from-canonical' > "$tmp_style"
run
rm -f "$tmp_style"
ck  "sync は成功する" "0" "$RC"
ck  "通常ファイルのまま" "true" "$([[ -f "$HOMEDIR/.claude/output-styles/mine.md" && ! -L "$HOMEDIR/.claude/output-styles/mine.md" ]] && echo true || echo false)"
ck  "中身が変わらない" "handwritten" "$(cat "$HOMEDIR/.claude/output-styles/mine.md")"
ckc "飛ばしたと言う" "$OUT" "Skipping (regular file exists)"

echo "[4] 正本のディレクトリが無くても sync が止まらない"
fresh h4
alt_canon="$_TMP_DIR/alt-repo"
mkdir -p "$alt_canon/scripts/sync" "$alt_canon/canonical/hooks" "$alt_canon/canonical/claude/statusline"
cp "$SYNC" "$alt_canon/scripts/sync/"
cp "$REPO_ROOT/scripts/sync/apply-claude-settings.sh" "$alt_canon/scripts/sync/" 2>/dev/null
cp "$CANON/hooks/claude.hooks.json" "$alt_canon/canonical/hooks/"
cp "$CANON/claude/statusline/claude.statusline.json" "$alt_canon/canonical/claude/statusline/"
mkdir -p "$alt_canon/canonical/claude"
cp -R "$CANON/claude/settings.harness.json" "$alt_canon/canonical/claude/" 2>/dev/null
# output-styles は作らない
OUT="$(env HOME="$HOMEDIR" "$alt_canon/scripts/sync/sync-claude.sh" 2>&1)"; RC=$?
ck  "止まらない" "0" "$RC"
ck  "配布先も作られない" "false" "$([[ -d "$HOMEDIR/.claude/output-styles" ]] && echo true || echo false)"

echo "[5] --check の走査対象に入っている"
ckc "sync.sh が output-styles を見る" "$(cat "$REPO_ROOT/scripts/sync.sh")" 'output-styles'

echo "[6] 孤児 symlink の走査根に入っている"
ckc "claude の allowlist に output-styles がある" "$(grep '^claude_dirs=' "$ORPHAN")" "output-styles"
fresh h6
mkdir -p "$HOMEDIR/.claude/output-styles"
ln -s "$CANON/output-styles/gone-$$.md" "$HOMEDIR/.claude/output-styles/gone.md"
OUT="$("$BASH" "$ORPHAN" claude --base "$HOMEDIR/.claude" --canonical "$CANON" 2>&1)"; RC=$?
ck  "孤児として拾う" "1" "$RC"
ckc "output-styles の孤児と出る" "$OUT" "orphan-canonical output-styles/gone.md"

echo ""
echo "=== PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
