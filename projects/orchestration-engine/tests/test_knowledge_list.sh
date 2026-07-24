#!/usr/bin/env bash
set -euo pipefail

# test_knowledge_list.sh — scripts/knowledge-list.sh（#273 段3 突合・read-only 列挙 verb）の検証。
#
# gate 2 設計SO（3レーン・2026-07-24）で確定した契約（plan §9）を fixture で固定する:
#   - 既定は git HEAD tree snapshot 列挙（index/working-tree でなく commit tree）・蒸留木横断。
#   - path は items/ 直下 ULID .md のみ（非再帰・厳密 regex）。nested は列挙しない。
#   - malformed / 非 ULID は stdout に flagged row で surface（stderr のみに落とさない）+ skipped 計上。
#   - 既定 exit 0・--strict で skipped>0 は exit 1・環境エラー（git 非在/HEAD 不成立/usage）は exit 2。
#   - --include-uncommitted は disk（未 commit 含む）を find・.oe/tmp/node_modules を prune。
#   - explicit positional は git 不要（可搬）。
#   - discovery 整合: 列挙が surface する items/ .md 集合 == その木で validate-knowledge が対象にする集合。
# validator は test_validate_knowledge.sh と同じく subprocess で ${BASH} 起動し bash 3.2/5.x を実効化する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LISTER="$PROJECT_DIR/scripts/knowledge-list.sh"
VALIDATOR="$PROJECT_DIR/scripts/validate-knowledge.sh"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }
command -v yq  >/dev/null 2>&1 || { echo "SKIP: yq required"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git required"; exit 0; }

_TMP_DIR="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
[[ -n "$_TMP_DIR" && -d "$_TMP_DIR" ]] || { echo "FATAL: mktemp -d returned an invalid path: '${_TMP_DIR}'" >&2; exit 1; }
trap 'rm -rf "$_TMP_DIR"' EXIT
ERRFILE="$_TMP_DIR/.stderr"

ULID1="01J0ABCDEFGHJKMNPQRSTVWXYZ"
ULID2="01J0ABCDEFGHJKMNPQRSTVWXY0"
ULID3="01J0ABCDEFGHJKMNPQRSTVWX11"

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3] in: $2)"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

OUT=""; ERR=""; RC=0
# run <root> [args...] — OE_KNOWLEDGE_REPO_ROOT=<root> で回し stdout/stderr/exit を分離捕捉。
run() {
  local root="$1"; shift
  RC=0
  OUT="$(env OE_KNOWLEDGE_REPO_ROOT="$root" "$BASH" "$LISTER" "$@" 2>"$ERRFILE")" || RC=$?
  ERR="$(cat "$ERRFILE")"
}

# --- fixture helpers ---
git_init() { git -C "$1" init -q; git -C "$1" config user.email t@example.com; git -C "$1" config user.name test; }
git_commit() { git -C "$1" add -A; git -C "$1" commit -qm "${2:-c}"; }

write_item() {
  # write_item <path> <ulid> <status> <landing> <bodyfirst>
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<EOF
---
id: "$2"
type: knowledge
status: $3
date: 2026-07-24
trigger: "trigger for $2"
prediction: "prediction for $2"
source:
  ref: "https://github.com/org/repo/issues/272"
landing: $4
observations: []
exclusions:
  - "自明な知見には使わない"
---

$5
EOF
}

# ============================================================================
echo "[1] 蒸留木横断（2木・committed）→ exit0・両方列挙"
R="$_TMP_DIR/r1"; mkdir -p "$R"; git_init "$R"
write_item "$R/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "本文先頭 prose one."
write_item "$R/projects/eng/docs/knowledge/items/$ULID2.md" "$ULID2" active guard-candidate "本文先頭 prose two."
git_commit "$R"
run "$R"
ck  "exit 0" "0" "$RC"
ckc "ULID1 列挙"    "$OUT" "$ULID1"
ckc "ULID2 列挙"    "$OUT" "$ULID2"
ckc "item_ref 1木"  "$OUT" "docs/knowledge/items/$ULID1.md"
ckc "item_ref 2木"  "$OUT" "projects/eng/docs/knowledge/items/$ULID2.md"
ckc "summary 行"    "$OUT" "listed: 2 / skipped: 0 / source: git-head"

echo "[2] --json: オブジェクト形（schema_version/source/listed/skipped/items）"
run "$R" --json
ck  "exit 0" "0" "$RC"
ck  "schema_version" "1" "$(jq -r '.schema_version' <<<"$OUT")"
ck  "source"         "git-head" "$(jq -r '.source' <<<"$OUT")"
ck  "listed"         "2" "$(jq -r '.listed' <<<"$OUT")"
ck  "skipped"        "0" "$(jq -r '.skipped' <<<"$OUT")"
ck  "item exclusions 出力" "自明な知見には使わない" "$(jq -r '.items[0].exclusions[0]' <<<"$OUT")"
ck  "item source_ref 出力" "https://github.com/org/repo/issues/272" "$(jq -r '.items[0].source_ref' <<<"$OUT")"
ckc "excerpt フィールド" "$OUT" "本文先頭 prose"
ck  "head == 実 HEAD SHA（pinning）" "$(git -C "$R" rev-parse HEAD)" "$(jq -r '.head' <<<"$OUT")"

echo "[3] excerpt: 見出し行を skip して先頭 prose を採る"
R3="$_TMP_DIR/r3"; mkdir -p "$R3"; git_init "$R3"
write_item "$R3/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "## 教訓
grep 単体では配列を捕捉できない。"
git_commit "$R3"
run "$R3" --json
ck  "excerpt は見出しでなく prose" "grep 単体では配列を捕捉できない。" "$(jq -r '.items[0].excerpt' <<<"$OUT")"

echo "[4] 空 store（commit あり item 無し）→ 空リスト+exit0"
R4="$_TMP_DIR/r4"; mkdir -p "$R4"; git_init "$R4"; git -C "$R4" commit -q --allow-empty -m e
run "$R4"
ck  "exit 0" "0" "$RC"
ckc "listed 0" "$OUT" "listed: 0 / skipped: 0"

echo "[5] HEAD 不成立（commit 無し）→ exit2"
R5="$_TMP_DIR/r5"; mkdir -p "$R5"; git_init "$R5"
run "$R5"
ck  "exit 2" "2" "$RC"
ckc "HEAD メッセージ" "$ERR" "HEAD is not resolvable"

echo "[6] git 非在（非 git dir を root 指定）→ exit2"
R6="$_TMP_DIR/r6"; mkdir -p "$R6/docs/knowledge/items"
run "$R6"
ck  "exit 2" "2" "$RC"

echo "[7] malformed frontmatter（committed）→ stdout に flagged row・skipped 計上・既定 exit0"
R7="$_TMP_DIR/r7"; mkdir -p "$R7"; git_init "$R7"
write_item "$R7/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "valid one."
cat > "$R7/docs/knowledge/items/$ULID2.md" <<EOF
---
id: "$ULID2"
type: [unclosed
---
本文
EOF
git_commit "$R7"
run "$R7"
ck  "exit 0（非 strict）" "0" "$RC"
ckc "MALFORMED は stdout" "$OUT" "MALFORMED"
ckc "MALFORMED の id 復元" "$OUT" "$ULID2"
ckc "skipped 1" "$OUT" "listed: 1 / skipped: 1"
ncc "MALFORMED は stderr のみではない" "$ERR" "MALFORMED"

echo "[8] --strict かつ skipped>0 → exit1"
run "$R7" --strict
ck  "exit 1" "1" "$RC"

echo "[9] --strict かつ clean store → exit0"
run "$R" --strict
ck  "exit 0" "0" "$RC"

echo "[10] 非 ULID 名の .md（items/ 直下・committed）→ flagged（non-ULID）+ skipped"
R10="$_TMP_DIR/r10"; mkdir -p "$R10"; git_init "$R10"
write_item "$R10/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "ok."
mkdir -p "$R10/docs/knowledge/items"
printf -- '---\nid: x\n---\nnote\n' > "$R10/docs/knowledge/items/README.md"
git_commit "$R10"
run "$R10"
ck  "exit 0" "0" "$RC"
ckc "non-ULID flagged" "$OUT" "non-ULID filename"
ckc "skipped 1" "$OUT" "listed: 1 / skipped: 1"

echo "[11] items/ の下位ディレクトリ（nested）は列挙しない（非再帰）"
R11="$_TMP_DIR/r11"; mkdir -p "$R11"; git_init "$R11"
write_item "$R11/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "direct."
write_item "$R11/docs/knowledge/items/sub/$ULID2.md" "$ULID2" active nl "nested."
git_commit "$R11"
run "$R11" --json
ck  "listed 1（nested 除外）" "1" "$(jq -r '.listed' <<<"$OUT")"
ncc "nested は列挙されない" "$OUT" "$ULID2"

echo "[12] HEAD snapshot 意味論: working-tree の dirty 変更でなく commit 内容を出す"
R12="$_TMP_DIR/r12"; mkdir -p "$R12"; git_init "$R12"
write_item "$R12/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "committed body."
git_commit "$R12"
# commit 後に trigger を dirty に書き換え（未 commit）
sed 's/^trigger: .*/trigger: "DIRTY-UNCOMMITTED"/' "$R12/docs/knowledge/items/$ULID1.md" > "$R12/.t" && mv "$R12/.t" "$R12/docs/knowledge/items/$ULID1.md"
run "$R12" --json
ck  "commit の trigger を出す" "trigger for $ULID1" "$(jq -r '.items[0].trigger' <<<"$OUT")"
ncc "dirty は出さない" "$OUT" "DIRTY-UNCOMMITTED"

echo "[13] --include-uncommitted: 未 commit item を disk 列挙・source=worktree"
R13="$_TMP_DIR/r13"; mkdir -p "$R13"; git_init "$R13"; git -C "$R13" commit -q --allow-empty -m e
write_item "$R13/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "uncommitted."
run "$R13"
ck  "既定 git-head では未 commit を出さない（listed 0）" "0" "$(env OE_KNOWLEDGE_REPO_ROOT="$R13" "$BASH" "$LISTER" --json | jq -r '.listed')"
run "$R13" --include-uncommitted
ck  "include-uncommitted で列挙" "1" "$(env OE_KNOWLEDGE_REPO_ROOT="$R13" "$BASH" "$LISTER" --include-uncommitted --json | jq -r '.listed')"
ckc "source=worktree" "$OUT" "source: worktree"

echo "[14] --include-uncommitted: .oe/ tmp/ は prune"
R14="$_TMP_DIR/r14"; mkdir -p "$R14"; git_init "$R14"; git -C "$R14" commit -q --allow-empty -m e
write_item "$R14/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "real."
write_item "$R14/.oe/knowledge/items/$ULID2.md" "$ULID2" active nl "volatile oe."
write_item "$R14/tmp/knowledge/items/$ULID3.md" "$ULID3" active nl "volatile tmp."
run "$R14" --include-uncommitted --json
ck  "listed 1（.oe/tmp prune）" "1" "$(jq -r '.listed' <<<"$OUT")"
ncc "oe item 除外" "$OUT" "$ULID2"
ncc "tmp item 除外" "$OUT" "$ULID3"

echo "[15] explicit positional（git 不要・可搬）: items dir を指定"
R15="$_TMP_DIR/r15"; mkdir -p "$R15/docs/knowledge/items"   # git init しない
write_item "$R15/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "explicit."
OUT="$("$BASH" "$LISTER" "$R15/docs/knowledge/items" 2>"$ERRFILE")"; RC=$?
ck  "exit 0（git 無し）" "0" "$RC"
ckc "explicit で列挙" "$OUT" "$ULID1"
ckc "source=explicit-paths" "$OUT" "source: explicit-paths"

echo "[16] explicit positional: 単一 item file"
OUT="$("$BASH" "$LISTER" "$R15/docs/knowledge/items/$ULID1.md" 2>/dev/null)"; RC=$?
ck  "exit 0" "0" "$RC"
ckc "単一 file 列挙" "$OUT" "$ULID1"

echo "[17] 不正フラグ → exit2 usage"
run "$R" --bogus
ck  "exit 2" "2" "$RC"
ckc "usage" "$ERR" "Usage:"

echo "[18] discovery 整合: 列挙が surface する items/ .md 集合 == validate-knowledge 対象集合"
# clean item + malformed + 非 ULID を混在させ、全 items/ .md が listed か malformed で必ず現れることを assert。
R18="$_TMP_DIR/r18"; mkdir -p "$R18"; git_init "$R18"
write_item "$R18/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "clean."
printf -- '---\nid: "%s"\ntype: [bad\n---\nx\n' "$ULID2" > "$R18/docs/knowledge/items/$ULID2.md"
printf -- '---\nid: y\n---\nz\n' > "$R18/docs/knowledge/items/note.md"
git_commit "$R18"
run "$R18" --json
# knowledge-list が surface した items/ 直下 basename 集合（listed + malformed）
KL_SET="$(jq -r '[.items[].item_ref, .malformed[].item_ref] | map(sub(".*/";"")) | sort | .[]' <<<"$OUT")"
# validate-knowledge が directory mode で実際に検査する file 集合を --verbose の "checking" ログから観測する
# （別実装の git ls-tree|grep で再実装せず、validator の実挙動を oracle にする・実装SO 指摘）。
# validator は malformed 混在で exit 1 になる（--verbose ログだけ使いたい）。pipefail+set -e で
# 落ちないよう exit code を中和する（観測目的の実行）。
VK_SET="$( { env OE_KNOWLEDGE_REPO_ROOT="$R18" "$BASH" "$VALIDATOR" "$R18/docs/knowledge/items" --verbose 2>&1 || true; } \
  | grep 'checking ' | sed 's#.*checking ##; s#.*/##' | sort)"
ck  "surface 集合 == validate 実対象集合" "$VK_SET" "$KL_SET"
# 追加: clean な items/ dir に validate-knowledge を回すと OK（同じ集合を検証している傍証）
Rc="$_TMP_DIR/r18c"; mkdir -p "$Rc"; git_init "$Rc"
write_item "$Rc/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "clean."
git_commit "$Rc"
VKRC=0; env OE_KNOWLEDGE_REPO_ROOT="$Rc" "$BASH" "$VALIDATOR" "$Rc/docs/knowledge/items" >/dev/null 2>&1 || VKRC=$?
ck  "validate-knowledge が clean 木で OK" "0" "$VKRC"
KLC="$(env OE_KNOWLEDGE_REPO_ROOT="$Rc" "$BASH" "$LISTER" --json | jq -r '.listed')"
ck  "knowledge-list も同木で 1 件" "1" "$KLC"

echo "[19] git blob 読み出し失敗（object 欠損）→ exit2（環境エラー・MALFORMED に誤分類しない）"
R19="$_TMP_DIR/r19"; mkdir -p "$R19"; git_init "$R19"
git -C "$R19" config gc.auto 0
write_item "$R19/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "committed body."
git_commit "$R19"
BLOB="$(git -C "$R19" rev-parse "HEAD:docs/knowledge/items/$ULID1.md")"
rm -f "$R19/.git/objects/${BLOB:0:2}/${BLOB:2}"   # loose blob を落とし読み出し不能にする
run "$R19"
ck  "exit 2（env error）"        "2" "$RC"
ckc "blob 失敗メッセージ"        "$ERR" "failed to read blob"
ncc "MALFORMED に誤分類しない"   "$OUT" "MALFORMED"
run "$R19" --strict
ck  "strict でも exit 2（1 でない）" "2" "$RC"

echo "[20] 閉じ '---' 欠落（以降が valid YAML でも）→ MALFORMED（偽成功しない・validator と整合）"
R20="$_TMP_DIR/r20"; mkdir -p "$R20/docs/knowledge/items"; git_init "$R20"
# opening '---' のみ・閉じ '---' なし・以降が valid YAML object（閉じ検査が無いと valid 扱いされうる）
printf -- '---\nid: "%s"\ntype: knowledge\nstatus: active\nextra: value\n' "$ULID1" > "$R20/docs/knowledge/items/$ULID1.md"
git_commit "$R20"
run "$R20" --json
ck  "listed 0（valid 扱いしない）" "0" "$(jq -r '.listed' <<<"$OUT")"
ck  "skipped 1"                    "1" "$(jq -r '.skipped' <<<"$OUT")"
ckc "delimiter 欠落 reason"        "$OUT" "frontmatter delimiter block not found"

echo "[21] 巨大な無空白 excerpt → 文字数で切り詰め argv DoS を防ぐ（exit 0・列挙成功・bound）"
R21="$_TMP_DIR/r21"; mkdir -p "$R21/docs/knowledge/items"; git_init "$R21"
BIG="$(awk 'BEGIN{for(i=0;i<500000;i++)printf "あ"}')"   # ~1.5MB の無空白日本語 1 行（argv 上限超）
write_item "$R21/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "$BIG"
git_commit "$R21"
run "$R21" --json
ck  "exit 0（argv 落ちしない）" "0" "$RC"
ck  "listed 1"                  "1" "$(jq -r '.listed' <<<"$OUT")"
EXC="$(jq -r '.items[0].excerpt' <<<"$OUT")"
ck  "excerpt が bound される（<=210 文字）" "yes" "$([[ "${#EXC}" -le 210 ]] && echo yes || echo no)"

echo "[22] 巨大 frontmatter フィールド（~1.5MB prediction）→ jq は stdin 経由で argv 落ちしない"
R22="$_TMP_DIR/r22"; mkdir -p "$R22/docs/knowledge/items"; git_init "$R22"
BIGF="$(awk 'BEGIN{for(i=0;i<1500000;i++)printf "x"}')"   # ARG_MAX 超の 1 フィールド
{ printf -- '---\nid: "%s"\ntype: knowledge\nstatus: active\ndate: 2026-07-24\ntrigger: "t"\nprediction: "' "$ULID1"
  printf '%s' "$BIGF"
  printf '"\nsource:\n  ref: "https://x/y"\nlanding: nl\nobservations: []\n---\n\nbody first line.\n'
} > "$R22/docs/knowledge/items/$ULID1.md"
git_commit "$R22"
run "$R22" --json
ck  "exit 0（argv 落ちしない）" "0" "$RC"
ck  "listed 1"                  "1" "$(jq -r '.listed' <<<"$OUT")"

echo "[23] repo-root 末尾スラッシュでも item_ref は repo 相対（絶対パス漏れなし）"
R23="$_TMP_DIR/r23"; mkdir -p "$R23/docs/knowledge/items"
write_item "$R23/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "x."
OUT="$(env OE_KNOWLEDGE_REPO_ROOT="$R23/" "$BASH" "$LISTER" --json "$R23/docs/knowledge/items")"
ck  "item_ref は repo 相対（先頭 / でない）" "docs/knowledge/items/$ULID1.md" "$(jq -r '.items[0].item_ref' <<<"$OUT")"

# --- サマリ ---
echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
