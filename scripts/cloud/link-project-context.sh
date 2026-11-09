#!/usr/bin/env bash
#
# link-project-context.sh — クラウドのコンテナの作業ツリーにだけ、hub の規則と規約のスキルへの
# リンクを作る（#591）。
#
# なぜ要るか:
#   hub の規則とスキルは sync で手元のホーム（~/.claude/ など）へ配っている。クラウドの
#   エージェントのコンテナには手元のホームが無いので、規則もスキルも届かない（#591）。
#   repo にリンクを commit すると手元の hub で二重に読まれるので、commit はしない。
#   クラウドの環境の setup（Claude）と install script（Codex）からこの script を呼び、
#   そのコンテナの作業ツリーにだけリンクを作る。
#
# 作るもの（すべて canonical/ への相対のシンボリックリンク）:
#   .claude/rules/<name>.md   canonical/rules/*.md の全部（Claude が起動時に読む）
#   .claude/skills/<name>     CONVENTION_SKILLS のスキル（Claude）
#   .agents/skills/<name>     CONVENTION_SKILLS のスキル（Codex）
#   Claude は .agents/ を、Codex は .claude/ を読まないので、両方を作っても互いに影響しない。
#   作ったディレクトリは git の info/exclude に足し、未追跡として見えないようにする
#   （エージェントが誤って commit しないため。info/exclude 自体は commit されない）。
#
# 手元では走らせない:
#   手元の hub で走らせると、~/.claude/ の規則・スキルと二重に読まれる。誤って走らせないよう、
#   --cloud を付けたときだけ動く。
#
# Usage:
#   scripts/cloud/link-project-context.sh --cloud
#   scripts/cloud/link-project-context.sh --cloud --repo /path/to/ai-development-hub
#
# 環境の setup script からの呼び方（repo の checkout を含むディレクトリから走る前提）:
#   if [ -f ai-development-hub/scripts/cloud/link-project-context.sh ]; then
#     bash ai-development-hub/scripts/cloud/link-project-context.sh --cloud
#   fi
#
# 終了コード:
#   0 すべて作った（既に同じリンクがあったものを含む）
#   1 一部を作れなかった（正本に無いスキル・リンクでないファイルが先にある。stderr に出る）
#   2 実行できない（--cloud が無い・引数の誤り・repo が見つからない）

set -euo pipefail

# クラウドで読ませる規約のスキル。増やすときはここに足す（#591）。
CONVENTION_SKILLS=(pr-conventions branch-naming issue-conventions conventional-commits)

# 作業ツリーに作るディレクトリ。info/exclude にもこの形で足す。
LINK_DIRS=(.claude/rules .claude/skills .agents/skills)

usage() {
  sed -n '2,/^set -euo pipefail$/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'
}

err() { printf 'link-project-context: %s\n' "$*" >&2; }

CLOUD=0
REPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cloud) CLOUD=1; shift ;;
    --repo)
      [[ $# -ge 2 && -n "$2" ]] || { err "--repo には repo のパスが要ります"; exit 2; }
      REPO="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) err "知らない引数です: $1"; exit 2 ;;
  esac
done

if [[ "$CLOUD" -ne 1 ]]; then
  err "--cloud が無いので止めます。手元で走らせると、~/.claude/ の規則・スキルと二重に読まれます"
  exit 2
fi

if [[ -z "$REPO" ]]; then
  REPO="$(cd "$(dirname "$0")/../.." && pwd)"
fi
if [[ ! -d "$REPO/canonical/rules" || ! -d "$REPO/canonical/skills" ]]; then
  err "hub の repo が見つかりません（canonical/rules と canonical/skills が要ります）: $REPO"
  exit 2
fi
cd "$REPO"

EXCLUDE=""
if ! EXCLUDE="$(git rev-parse --git-path info/exclude 2>/dev/null)" || [[ -z "$EXCLUDE" ]]; then
  err "git の作業ツリーではありません: $REPO"
  exit 2
fi

PROBLEMS=0
CREATED=0
KEPT=0

# <リンクの場所> <リンクの中身（相対）>
# 既に同じリンクがあれば何もしない。違うリンクなら張り替える。リンクでないものは触らない。
place_link() {
  local link="$1" target="$2" current
  if [[ -L "$link" ]]; then
    current="$(readlink "$link")"
    if [[ "$current" == "$target" ]]; then
      KEPT=$((KEPT + 1))
      return 0
    fi
    ln -sfn "$target" "$link"
    CREATED=$((CREATED + 1))
    return 0
  fi
  if [[ -e "$link" ]]; then
    err "リンクでないものが先にあるので触りません: $link"
    PROBLEMS=$((PROBLEMS + 1))
    return 0
  fi
  ln -s "$target" "$link"
  CREATED=$((CREATED + 1))
}

for d in "${LINK_DIRS[@]}"; do
  mkdir -p "$d"
done

# 正本から消えたものを指して壊れたリンクを外す。canonical/ を指すリンクだけを対象にし、
# 人が置いたほかのリンクやファイルには触らない。
REMOVED=0
for d in "${LINK_DIRS[@]}"; do
  for link in "$d"/* "$d"/.[!.]*; do
    [[ -L "$link" ]] || continue
    [[ -e "$link" ]] && continue
    case "$(readlink "$link")" in
      ../../canonical/*) rm -f "$link"; REMOVED=$((REMOVED + 1)) ;;
    esac
  done
done

# 規則は canonical/rules/*.md の全部を張る。正本に足した規則は、次に走らせたときに入る。
for rule in canonical/rules/*.md; do
  [[ -f "$rule" ]] || continue
  place_link ".claude/rules/$(basename "$rule")" "../../$rule"
done

for skill in "${CONVENTION_SKILLS[@]}"; do
  if [[ ! -f "canonical/skills/$skill/SKILL.md" ]]; then
    err "正本にスキルがありません: canonical/skills/$skill/SKILL.md"
    PROBLEMS=$((PROBLEMS + 1))
    continue
  fi
  place_link ".claude/skills/$skill" "../../canonical/skills/$skill"
  place_link ".agents/skills/$skill" "../../canonical/skills/$skill"
done

# 作ったディレクトリを未追跡として見せない。行が既にあれば足さない。
mkdir -p "$(dirname "$EXCLUDE")"
touch "$EXCLUDE"
for d in "${LINK_DIRS[@]}"; do
  grep -qxF "/$d/" "$EXCLUDE" || printf '/%s/\n' "$d" >> "$EXCLUDE"
done

printf 'link-project-context: 作った %d・そのまま %d・外した壊れたリンク %d・問題 %d（%s）\n' \
  "$CREATED" "$KEPT" "$REMOVED" "$PROBLEMS" "$REPO"

[[ "$PROBLEMS" -eq 0 ]] || exit 1
exit 0
