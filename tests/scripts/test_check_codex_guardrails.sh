#!/usr/bin/env bash
# test_check_codex_guardrails.sh — scripts/check-codex-guardrails.sh が、ルールの置き場の全部を見ることを固定する（#332）
#
# 直した欠陥: 検査する語を検査の側に並べていたので、ルールを足しても検査が追随せず、AGENTS.md から
# 欠けていても緑で通っていた。いまは canonical/rules/ を並べて1本ずつ見る。
#
# 実物の canonical/ は読むだけで、書き換えない。置き場を一時の場所に写し、検査の2つの変数
# （CODEX_GUARDRAILS_RULES_DIR・CODEX_GUARDRAILS_AGENTS_FILE）でそちらへ向ける。
# 検査は、この検査を動かしている bash（${BASH}）で起こす。bash 5 と /bin/bash 3.2 の両方で回す。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$REPO_DIR/scripts/check-codex-guardrails.sh"
[[ -f "$TARGET" ]] || { echo "FAIL: check-codex-guardrails.sh not found: $TARGET"; exit 1; }

PASS=0; FAIL=0
ck() { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
has() { [[ "$OUT" == *"$1"* ]] && echo yes || echo no; }

_TMP_DIR="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
[[ -n "$_TMP_DIR" && -d "$_TMP_DIR" ]] || { echo "FATAL: temp dir is not a directory" >&2; exit 1; }
trap 'rm -rf "$_TMP_DIR"' EXIT

# fresh — 実物の置き場を一時の場所に写し直す。RULES と AGENTS がその写しを指す。
fresh() {
  rm -rf "$_TMP_DIR/rules" "$_TMP_DIR/AGENTS.md"
  mkdir -p "$_TMP_DIR/rules"
  cp "$REPO_DIR"/canonical/rules/*.md "$_TMP_DIR/rules/"
  cp "$REPO_DIR/canonical/codex/AGENTS.md" "$_TMP_DIR/AGENTS.md"
  RULES="$_TMP_DIR/rules"; AGENTS="$_TMP_DIR/AGENTS.md"
}
# run — 写しに向けて検査を起こす。結果は RC と OUT。
run() {
  RC=0
  OUT="$(CODEX_GUARDRAILS_RULES_DIR="$RULES" CODEX_GUARDRAILS_AGENTS_FILE="$AGENTS" "$BASH" "$TARGET" 2>&1)" || RC=$?
}
# drop_lines <語> — 写しの AGENTS.md から、その語を含む行を消す（大文字と小文字は区別しない）。
drop_lines() { grep -vi -- "$1" "$AGENTS" > "$AGENTS.new"; mv "$AGENTS.new" "$AGENTS"; }

echo "[1] 実物の置き場は通り、ルールの本数が置き場の本数と合う"
RC=0; OUT="$("$BASH" "$TARGET" 2>&1)" || RC=$?
ck "実物は rc=0" "0" "$RC"
_n="$(find "$REPO_DIR/canonical/rules" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
ck "見たルールの本数が置き場の本数と同じ" "yes" "$(has "(${_n} rule(s):")"
fresh; run
ck "写しも rc=0" "0" "$RC"

echo "[2] 陽性対照: 載っているルールを AGENTS.md から抜くと落ちる"
# 語の表で見るルール（表の語）と、既定の決め方で見るルール（名前から作った見出しの語）の両方で確かめる。
fresh; drop_lines "Output Contract"; run
ck "表の語（Output Contract）を抜くと rc=1" "1" "$RC"
ck "欠けたルールの名前が出る" "yes" "$(has "output-format-rule")"
fresh; drop_lines "Root Cause"; run
ck "語が複数あるルールは、1つ欠けても rc=1" "1" "$RC"
ck "欠けた語が出る" "yes" "$(has "behavioral-rule (pattern: Root Cause)")"
fresh; drop_lines "Exhaustion Before Conclusion"; run
ck "既定の決め方のルール（exhaustion-before-conclusion-rule）を抜くと rc=1" "1" "$RC"
ck "欠けたルールの名前が出る" "yes" "$(has "exhaustion-before-conclusion-rule")"
fresh; drop_lines "Reframe on Stall"; run
ck "見出しの語の大文字と小文字が違っても載っていると読む（Reframe on Stall）。抜くと rc=1" "1" "$RC"

echo "[3] ルールを1本足すと、検査を直さなくても追随する"
fresh; printf '# New Sample\n' > "$RULES/new-sample-rule.md"; run
ck "足したルールが AGENTS.md に無いと rc=1" "1" "$RC"
ck "足したルールの名前が出る" "yes" "$(has "new-sample-rule")"
printf '\n15. New Sample — a sample.\n' >> "$AGENTS"; run
ck "見出しの語（New Sample）で載せると rc=0" "0" "$RC"
fresh; printf '# New Sample\n' > "$RULES/new-sample-rule.md"
# shellcheck disable=SC2016  # バッククォートは文字として書く
printf '\nSee `new-sample-rule`.\n' >> "$AGENTS"; run
ck "ルールの名前（new-sample-rule）で載せても rc=0" "0" "$RC"

echo "[4] 載せていないルールは、黙って通さず WARN で知らせる"
fresh; run
ck "除外は WARN に出る" "yes" "$(has "Excluded: careful-operations-rule")"
ck "除外の本数が結果の行に出る" "yes" "$(has "excluded)")"
_ex="$(printf '%s\n' "$OUT" | grep -c 'Excluded: ')"
ck "結果の行の除外の本数が WARN の数と同じ" "yes" "$(has "${_ex} excluded)")"

echo "[5] 表に残った古い名前と、空の置き場を通さない"
fresh; rm "$RULES/input-style-rule.md"; run
ck "表にあるルールが置き場に無いと rc=1" "1" "$RC"
ck "表から外すよう知らせる" "yes" "$(has "input-style-rule（表 RULE_TABLE にあるが")"
fresh; rm "$RULES/careful-operations-rule.md"; run
ck "除外の表にあるルールが置き場に無くても rc=1" "1" "$RC"
# 表に名前があるルールは、どれを置き場から消しても落ちる。名前は検査の表から読むので、表に行を足しても
# この検査は追随する（名前の一覧を別に持つ形に戻ると、ここで落ちる）。
_names="$(sed -n "/^RULE_TABLE='/,/'\$/p" "$TARGET" | sed "s/^RULE_TABLE='//" | awk -F'|' 'NF >= 3 && !seen[$1]++ { print $1 }')"
ck "検査の表から名前を読めた" "yes" "$( [[ "$(printf '%s\n' "$_names" | grep -c .)" -ge 8 ]] && echo yes || echo no )"
_bad=""
for _r in $_names; do
  fresh; rm -f "$RULES/${_r}.md"; run
  [[ "$RC" -eq 1 && "$OUT" == *"${_r}（表 RULE_TABLE にあるが"* ]] || _bad="${_bad} ${_r}"
done
ck "表のどのルールを置き場から消しても rc=1 で名前が出る" "" "$_bad"
fresh; rm "$RULES"/*.md; run
ck "ルールが0本の置き場は rc=1" "1" "$RC"
ck "0本であることを知らせる" "yes" "$(has "No rule files")"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
