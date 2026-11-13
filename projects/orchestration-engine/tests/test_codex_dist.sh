#!/usr/bin/env bash
set -uo pipefail
# test_codex_dist.sh — #562 T-11: Codex の配布物（PR-2）の検査。
#   (1) codex.hooks.json に取り込み印と拍動の配線がある（PreToolUse の3本はそのまま）
#   (2) sync-codex.sh の sync_rules が canonical/codex/rules/*.rules を通常のファイルとして写し、内容が同じなら書き直さず、
#       symlink の残りは通常のファイルに置き換え、owner のほかの .rules には触らない
#   (3) scripts/check-codex-guardrails.sh が通る
#   実 ~/.codex には触らない（sync_rules は関数だけを取り出して一時ディレクトリに向ける）。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
PASS=0; FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then echo "  PASS: $label"; PASS=$((PASS+1));
  else echo "  FAIL: $label (want=[$expected] got=[$actual])"; FAIL=$((FAIL+1)); fi
}

echo "[1] codex.hooks.json の配線"
H="$REPO_DIR/canonical/hooks/codex.hooks.json"
ck "JSON として読める" "0" "$(jq -e . "$H" >/dev/null 2>&1; echo $?)"
ck "PreToolUse の3本はそのまま" "block-destructive.sh block-force-push.sh cc-lint.sh" "$(jq -r '[.hooks.PreToolUse[0].hooks[].command | split("/") | last] | join(" ")' "$H")"
ck "UserPromptSubmit に取り込み印と拍動" "oe-prompt-receipt.sh oe-heartbeat-hook.sh" "$(jq -r '[.hooks.UserPromptSubmit[0].hooks[].command | split("/") | last] | join(" ")' "$H")"
ck "PostModelRequest に拍動" "oe-heartbeat-hook.sh" "$(jq -r '[.hooks.PostModelRequest[0].hooks[].command | split("/") | last] | join(" ")' "$H")"
ck "UserPromptSubmit と PostModelRequest に matcher は無い（Codex は使わない）" "null null" "$(jq -r '"\(.hooks.UserPromptSubmit[0].matcher) \(.hooks.PostModelRequest[0].matcher)"' "$H")"
ck "拍動の hook のスクリプトが在って実行できる" "yes" "$([[ -x "$REPO_DIR/canonical/hooks/scripts/oe-heartbeat-hook.sh" ]] && echo yes || echo no)"

echo "[2] sync_rules: 通常のファイルとして写す"
SRC="$_TMP_DIR/src"; DST="$_TMP_DIR/dst"; mkdir -p "$SRC" "$DST"
printf 'prefix_rule(pattern=["oe"], decision="allow")\n' > "$SRC/oe-child.rules"
printf 'prefix_rule(pattern=["gh"], decision="allow")\n' > "$DST/default.rules"   # owner のもの
# sync-codex.sh から sync_rules だけを取り出す（main は呼ばない）。info / warn は検査の側で定義する。
sed -n '/^sync_rules()/,/^}/p' "$REPO_DIR/scripts/sync/sync-codex.sh" > "$_TMP_DIR/fn.sh"
grep -q '^sync_rules()' "$_TMP_DIR/fn.sh" || { echo "  FAIL: sync_rules が sync-codex.sh に無い"; FAIL=$((FAIL+1)); }
ck "取り出した関数は sync_rules だけ" "1" "$(grep -c '^[a-z_]*()' "$_TMP_DIR/fn.sh")"
info() { :; }; warn() { :; }
# shellcheck disable=SC1090
. "$_TMP_DIR/fn.sh"
# 本番と同じ set -euo pipefail の下で動くことも見る
( set -euo pipefail; sync_rules "$SRC" "$DST" "rules" >/dev/null 2>&1 ); ck "set -euo pipefail の下でも終了コード 0" "0" "$?"
ck "通常のファイルとして写す" "yes" "$([[ -f "$DST/oe-child.rules" && ! -L "$DST/oe-child.rules" ]] && echo yes || echo no)"
ck "内容が同じ" "0" "$(cmp -s "$SRC/oe-child.rules" "$DST/oe-child.rules"; echo $?)"
ck "owner の default.rules には触らない" 'prefix_rule(pattern=["gh"], decision="allow")' "$(cat "$DST/default.rules")"
m1="$(stat -f %m "$DST/oe-child.rules" 2>/dev/null || stat -c %Y "$DST/oe-child.rules")"
sleep 1
sync_rules "$SRC" "$DST" "rules" >/dev/null 2>&1
m2="$(stat -f %m "$DST/oe-child.rules" 2>/dev/null || stat -c %Y "$DST/oe-child.rules")"
ck "内容が同じなら書き直さない" "$m1" "$m2"
printf 'prefix_rule(pattern=["oe"], decision="allow")\nprefix_rule(pattern=["git", "commit"], decision="allow")\n' > "$SRC/oe-child.rules"
sync_rules "$SRC" "$DST" "rules" >/dev/null 2>&1
ck "内容が変われば写し直す" "0" "$(cmp -s "$SRC/oe-child.rules" "$DST/oe-child.rules"; echo $?)"
rm -f "$DST/oe-child.rules"; ln -s "$SRC/oe-child.rules" "$DST/oe-child.rules"
printf 'prefix_rule(pattern=["x"], decision="allow")\n' > "$DST/oe-old.rules"
sync_rules "$SRC" "$DST" "rules" >/dev/null 2>&1
ck "hub に無くなった oe-*.rules は消す" "no" "$([[ -e "$DST/oe-old.rules" ]] && echo yes || echo no)"
ck "owner の default.rules はそのまま" "yes" "$([[ -f "$DST/default.rules" ]] && echo yes || echo no)"
ck "symlink の残りは通常のファイルに置き換える" "yes" "$([[ -f "$DST/oe-child.rules" && ! -L "$DST/oe-child.rules" ]] && echo yes || echo no)"
ck "hub の規則のファイルは oe の1行だけ（H10）" "1" "$(grep -c '^prefix_rule' "$REPO_DIR/canonical/codex/rules/oe-child.rules")"
ck "hub の規則に git の行は無い（git は起こす1行で渡す）" "0" "$(grep -c '"git"' "$REPO_DIR/canonical/codex/rules/oe-child.rules")"
ck "hub の規則に gh と git push は無い" "0" "$(grep -c '"gh"\|"push"' "$REPO_DIR/canonical/codex/rules/oe-child.rules")"

echo "[3] check-codex-guardrails.sh が通る"
ck "guardrails" "0" "$(bash "$REPO_DIR/scripts/check-codex-guardrails.sh" >/dev/null 2>&1; echo $?)"
ck "AGENTS.md に委譲の子の1行（engine の約束ごとは書かない）" "1" "$(grep -c '^## Delegated Child' "$REPO_DIR/canonical/codex/AGENTS.md")"
ck "AGENTS.md に受領の印の約束は書かない" "0" "$(grep -c '\[oe:' "$REPO_DIR/canonical/codex/AGENTS.md")"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
