#!/usr/bin/env bash
set -uo pipefail

# test_link_project_context.sh — クラウドの作業ツリーにだけリンクを作る script の検証（#591）。
#
# 一時ディレクトリに偽の hub（git の作業ツリー・canonical/rules・canonical/skills）を組んで走らせる。
# 本物の作業ツリーには触らない。
# 検証する軸:
#   - --cloud が無ければ何も作らずに止まる（手元で二重に読ませない）
#   - 規則の全部と規約のスキルを、canonical/ への相対のリンクとして作る
#   - 2回流しても同じ結果になる
#   - 作ったものが git status に出ない（info/exclude）
#   - 正本から消えたものを指す壊れたリンクを外す。人が置いたファイルには触らない
#   - 正本に無いスキルとリンクでないファイルは、触らずに exit 1 で知らせる

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LINKER="$REPO_ROOT/scripts/cloud/link-project-context.sh"

[[ -f "$LINKER" ]] || { echo "FAIL: script not found: $LINKER"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git required"; exit 0; }

if ! _TMP_DIR="$(mktemp -d)" || [[ -z "$_TMP_DIR" || ! -d "$_TMP_DIR" ]]; then
  echo "FAIL: 一時ディレクトリを作れません"; exit 1
fi
trap 'rm -rf "$_TMP_DIR"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }

SKILLS=(pr-conventions branch-naming issue-conventions conventional-commits)

# <名前> — 偽の hub を作り、HUB に入れる。規則2つと規約の4つのスキルを持つ。
HUB=""
fresh() {
  HUB="$_TMP_DIR/$1/ai-development-hub"
  mkdir -p "$HUB/canonical/rules" "$HUB/canonical/skills"
  printf 'rule a\n' > "$HUB/canonical/rules/a-rule.md"
  printf 'rule b\n' > "$HUB/canonical/rules/b-rule.md"
  local s
  for s in "${SKILLS[@]}"; do
    mkdir -p "$HUB/canonical/skills/$s"
    printf -- '---\nname: %s\n---\n' "$s" > "$HUB/canonical/skills/$s/SKILL.md"
  done
  git -C "$HUB" init -q
  git -C "$HUB" add -A
  git -C "$HUB" -c user.name=t -c user.email=t@example.invalid commit -q -m init
}
# shebang 任せにせず、いま走っている bash で起動する。
run() { OUT="$(bash "$LINKER" "$@" 2>&1)"; RC=$?; }
OUT=""; RC=0

echo "[1] --cloud が無ければ止まり、何も作らない"
fresh no-flag
run --repo "$HUB"
ck  "exit 2"                 "2" "$RC"
ckc "理由を言う"             "$OUT" "--cloud が無い"
ck  ".claude を作らない"     "no" "$([[ -e "$HUB/.claude" ]] && echo yes || echo no)"
ck  ".agents を作らない"     "no" "$([[ -e "$HUB/.agents" ]] && echo yes || echo no)"

echo "[2] 規則の全部と規約のスキルを、相対のリンクとして作る"
fresh basic
run --cloud --repo "$HUB"
ck "exit 0" "0" "$RC"
ck "規則 a のリンク" "../../canonical/rules/a-rule.md" "$(readlink "$HUB/.claude/rules/a-rule.md")"
ck "規則 b のリンク" "../../canonical/rules/b-rule.md" "$(readlink "$HUB/.claude/rules/b-rule.md")"
for s in "${SKILLS[@]}"; do
  ck "Claude の $s" "../../canonical/skills/$s" "$(readlink "$HUB/.claude/skills/$s")"
  ck "Codex の $s"  "../../canonical/skills/$s" "$(readlink "$HUB/.agents/skills/$s")"
  ck "$s の SKILL.md が辿れる" "yes" "$([[ -f "$HUB/.claude/skills/$s/SKILL.md" ]] && echo yes || echo no)"
done

echo "[3] 作ったものが git status に出ない"
ck "git status が空" "" "$(git -C "$HUB" status --short)"
ckc "exclude に .claude/rules" "$(cat "$HUB/.git/info/exclude")" "/.claude/rules/"
ckc "exclude に .agents/skills" "$(cat "$HUB/.git/info/exclude")" "/.agents/skills/"

echo "[4] 2回流しても同じ結果になる"
before="$(cd "$HUB" && find .claude .agents -print0 | sort -z | xargs -0 ls -ld | awk '{print $1, $NF}')"
run --cloud --repo "$HUB"
ck  "exit 0" "0" "$RC"
ckc "作ったのは0" "$OUT" "作った 0"
ck  "リンクが変わらない" "$before" "$(cd "$HUB" && find .claude .agents -print0 | sort -z | xargs -0 ls -ld | awk '{print $1, $NF}')"
ck  "exclude の行が増えない" "1" "$(grep -cxF '/.claude/rules/' "$HUB/.git/info/exclude")"

echo "[5] 正本から消えたものを指すリンクを外し、正本に足したものを張る"
git -C "$HUB" rm -q canonical/rules/b-rule.md
printf 'rule c\n' > "$HUB/canonical/rules/c-rule.md"
printf 'mine\n' > "$HUB/.claude/rules/my-note.md"
run --cloud --repo "$HUB"
ck  "exit 0" "0" "$RC"
ck  "消えた規則のリンクを外す" "no" "$([[ -L "$HUB/.claude/rules/b-rule.md" ]] && echo yes || echo no)"
ck  "足した規則を張る" "../../canonical/rules/c-rule.md" "$(readlink "$HUB/.claude/rules/c-rule.md")"
ck  "人が置いたファイルは残す" "mine" "$(cat "$HUB/.claude/rules/my-note.md")"

echo "[6] 正本に無いスキルと、リンクでないファイルは触らずに知らせる"
fresh problems
git -C "$HUB" rm -q -r canonical/skills/branch-naming
mkdir -p "$HUB/.agents/skills/pr-conventions"
printf 'local\n' > "$HUB/.agents/skills/pr-conventions/SKILL.md"
run --cloud --repo "$HUB"
ck  "exit 1" "1" "$RC"
ckc "無いスキルを言う" "$OUT" "canonical/skills/branch-naming/SKILL.md"
ckc "リンクでないものを言う" "$OUT" ".agents/skills/pr-conventions"
ck  "リンクでないものに触らない" "local" "$(cat "$HUB/.agents/skills/pr-conventions/SKILL.md")"
ck  "ほかのスキルは張る" "../../canonical/skills/issue-conventions" "$(readlink "$HUB/.claude/skills/issue-conventions")"

echo "[7] repo が見つからなければ止まる"
run --cloud --repo "$_TMP_DIR/nowhere"
ck "exit 2" "2" "$RC"

echo "[8] info/exclude の最後が改行で終わっていなくても、前の行につながらない"
fresh no-newline
printf '# last line without newline' > "$HUB/.git/info/exclude"
run --cloud --repo "$HUB"
ck  "exit 0" "0" "$RC"
ck  "git status が空" "" "$(git -C "$HUB" status --short)"
ck  "前の行が残る" "1" "$(grep -cxF '# last line without newline' "$HUB/.git/info/exclude")"
ck  ".claude/rules の行が独立している" "1" "$(grep -cxF '/.claude/rules/' "$HUB/.git/info/exclude")"

echo "[9] 本物の hub の規約のスキルが、正本にそろっている"
for s in "${SKILLS[@]}"; do
  ck "$s が正本にある" "yes" "$([[ -f "$REPO_ROOT/canonical/skills/$s/SKILL.md" ]] && echo yes || echo no)"
done
ck "script の一覧と同じ" "${SKILLS[*]}" \
  "$(sed -n 's/^CONVENTION_SKILLS=(\(.*\))$/\1/p' "$LINKER")"

echo
echo "=== test_link_project_context: PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
