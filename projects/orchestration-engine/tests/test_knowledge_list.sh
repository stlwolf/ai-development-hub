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
  # write_item <path> <ulid> <status> <landing> <bodyfirst> [observations-yaml]
  # 第6引数は "observations:" の行を含む YAML 断片（既定は空配列）。#274 の集計テスト用に足した
  # 任意引数で、既存の呼び出し（5 引数）は挙動が変わらない。
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
${6:-observations: []}
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

# ============================================================================
# observations の集計と制御候補（#274 段5/段6・gate 2 設計SO で確定した契約）
# ============================================================================

# 観測レコードの YAML 断片を作る（flow 形式で 1 レコード 1 行）。
obs_yaml() {
  # obs_yaml <state> [<state> ...] — date/ref は固定、state だけ変える
  local i=0 out="observations:"
  local s
  for s in "$@"; do
    out="$out
  - {date: 2026-07-25, ref: \"#$((100 + i))\", state: $s}"
    i=$((i + 1))
  done
  printf '%s' "$out"
}

echo "[24] 観測付き item: human に集計行（宣言順・0 件 state は省略）+ control-candidate"
R24="$_TMP_DIR/r24"; mkdir -p "$R24"; git_init "$R24"
write_item "$R24/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "adverse あり。" \
  "$(obs_yaml no_opportunity followed followed harmful)"
write_item "$R24/docs/knowledge/items/$ULID2.md" "$ULID2" active nl "観測ゼロ。"
git_commit "$R24"
run "$R24"
ck  "exit 0" "0" "$RC"
ckc "集計行（宣言順）"        "$OUT" "observations: 4 (no_opportunity:1 followed:2 harmful:1)"
ckc "control-candidate 表示"  "$OUT" "control-candidate: harmful"
ckc "footer に候補件数"       "$OUT" "control-candidates: 1"
ncc "0 件 state は出さない"    "$OUT" "outcome_unknown:0"

echo "[25] 観測ゼロの item は observations 行を出さない（#273 出力との回帰ゼロ）"
R25="$_TMP_DIR/r25"; mkdir -p "$R25"; git_init "$R25"
write_item "$R25/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "観測ゼロ。"
git_commit "$R25"
run "$R25"
ck  "exit 0" "0" "$RC"
ncc "observations 行なし"      "$OUT" "observations:"
ncc "footer に候補行なし"       "$OUT" "control-candidates:"
ncc "footer に integrity なし"  "$OUT" "integrity-issues:"
ck  "footer は #273 と同形"     "listed: 1 / skipped: 0 / source: git-head @ $(git -C "$R25" rev-parse HEAD)" \
    "$(printf '%s' "$OUT" | tail -1)"

echo "[26] --json: 集計フィールドと meta（control_candidates / integrity_issues）"
run "$R24" --json
ck  "exit 0" "0" "$RC"
ck  "observations_count"  "4" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .observations_count' <<<"$OUT")"
ck  "by_state followed"   "2" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .observations_by_state.followed' <<<"$OUT")"
ck  "by_state harmful"    "1" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .observations_by_state.harmful' <<<"$OUT")"
ck  "0 件 state はキーなし" "null" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .observations_by_state.outcome_unknown' <<<"$OUT")"
ck  "control_candidate"   "true" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .control_candidate' <<<"$OUT")"
ck  "reasons"             "harmful" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .control_candidate_reasons | join(",")' <<<"$OUT")"
ck  "malformed false"     "false" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .observations_malformed' <<<"$OUT")"
ck  "観測ゼロ item は count 0" "0" "$(jq -r '.items[] | select(.id == "'"$ULID2"'") | .observations_count' <<<"$OUT")"
ck  "観測ゼロ item は候補外"   "false" "$(jq -r '.items[] | select(.id == "'"$ULID2"'") | .control_candidate' <<<"$OUT")"
ck  "meta control_candidates" "1" "$(jq -r '.control_candidates' <<<"$OUT")"
ck  "meta integrity_issues"   "0" "$(jq -r '.integrity_issues' <<<"$OUT")"
ck  "schema_version は据え置き（additive）" "1" "$(jq -r '.schema_version' <<<"$OUT")"

echo "[27] status が active でない item は候補にしない（制御済みを毎回候補にしない・SO C2）"
R27="$_TMP_DIR/r27"; mkdir -p "$R27"; git_init "$R27"
write_item "$R27/docs/knowledge/items/$ULID1.md" "$ULID1" disabled nl "既に無効化済み。" "$(obs_yaml harmful)"
write_item "$R27/docs/knowledge/items/$ULID2.md" "$ULID2" superseded nl "後継あり。" "$(obs_yaml contradicted)"
git_commit "$R27"
run "$R27" --json
ck  "disabled は候補外"    "false" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .control_candidate' <<<"$OUT")"
ck  "superseded は候補外"  "false" "$(jq -r '.items[] | select(.id == "'"$ULID2"'") | .control_candidate' <<<"$OUT")"
ck  "meta 候補 0 件"       "0" "$(jq -r '.control_candidates' <<<"$OUT")"
run "$R27"
ckc "集計自体は出す"        "$OUT" "observations: 1 (harmful:1)"
ncc "候補表示は出さない"     "$OUT" "control-candidate:"

echo "[28] スキーマ違反レコードは invalid に数え、そこから候補を立てない（SO C3）"
R28="$_TMP_DIR/r28"; mkdir -p "$R28"; git_init "$R28"
# 1 件目は未知キーつき harmful（validator では違反）→ invalid 扱いで候補にしない
write_item "$R28/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "壊れたレコードあり。" 'observations:
  - {date: 2026-07-25, ref: "#101", state: harmful, author: child}
  - {date: 2026-07-25, ref: "#102", state: followed}'
# enum 外 state も invalid
write_item "$R28/docs/knowledge/items/$ULID2.md" "$ULID2" active nl "enum 外。" 'observations:
  - {date: 2026-07-25, ref: "#103", state: helpful_typo}'
git_commit "$R28"
run "$R28" --json
ck  "exit 0（列挙は止めない）" "0" "$RC"
ck  "invalid に数える"         "1" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .observations_by_state.invalid' <<<"$OUT")"
ck  "valid な followed は集計"  "1" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .observations_by_state.followed' <<<"$OUT")"
ck  "invalid harmful から候補を立てない" "false" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .control_candidate' <<<"$OUT")"
ck  "malformed true"           "true" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .observations_malformed' <<<"$OUT")"
ck  "enum 外も invalid"        "1" "$(jq -r '.items[] | select(.id == "'"$ULID2"'") | .observations_by_state.invalid' <<<"$OUT")"
ck  "meta integrity_issues"    "2" "$(jq -r '.integrity_issues' <<<"$OUT")"
run "$R28"
ckc "human に invalid を出す"   "$OUT" "invalid:1"
ckc "human に integrity 注記"   "$OUT" "integrity: 1 invalid record(s); run validate-knowledge"
ckc "footer に integrity 件数"  "$OUT" "integrity-issues: 2"
echo "  → --strict でも exit 0（#273 の skipped>0 契約を広げない・スキーマ完全性は validate-knowledge）"
run "$R28" --strict
ck  "exit 0（--strict の契約不変）" "0" "$RC"

echo "[29] observations が配列でない → human 行は必ず出す（黙殺しない）・count は null"
R29="$_TMP_DIR/r29"; mkdir -p "$R29"; git_init "$R29"
write_item "$R29/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "非配列。" 'observations: "nope"'
git_commit "$R29"
run "$R29"
ck  "exit 0" "0" "$RC"
ckc "human に MALFORMED 行"  "$OUT" "observations: MALFORMED (not a list; run validate-knowledge)"
run "$R29" --json
ck  "count は null"          "null" "$(jq -r '.items[0].observations_count' <<<"$OUT")"
ck  "malformed true"         "true" "$(jq -r '.items[0].observations_malformed' <<<"$OUT")"
ck  "by_state は空"          "0" "$(jq -r '.items[0].observations_by_state | length' <<<"$OUT")"
ck  "skipped には数えない"    "0" "$(jq -r '.skipped' <<<"$OUT")"

echo "[30] followed のみは候補外 / harmful+contradicted は reasons を宣言順で出す"
R30="$_TMP_DIR/r30"; mkdir -p "$R30"; git_init "$R30"
write_item "$R30/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "従っただけ。" "$(obs_yaml followed externally_verified)"
write_item "$R30/docs/knowledge/items/$ULID2.md" "$ULID2" active nl "両方あり。" "$(obs_yaml harmful contradicted)"
git_commit "$R30"
run "$R30" --json
ck  "followed のみは候補外" "false" "$(jq -r '.items[] | select(.id == "'"$ULID1"'") | .control_candidate' <<<"$OUT")"
ck  "reasons は宣言順（contradicted,harmful）" "contradicted,harmful" \
    "$(jq -r '.items[] | select(.id == "'"$ULID2"'") | .control_candidate_reasons | join(",")' <<<"$OUT")"

echo "[31] JSON 回帰: #273 の既存キー集合が不変で、追加は additive のみ（SO C5）"
run "$R25" --json
ck  "meta の既存キーが不変" "head items listed malformed schema_version skipped source" \
    "$(jq -r '. | keys - ["control_candidates","integrity_issues"] | sort | join(" ")' <<<"$OUT")"
ck  "item の既存キーが不変" "date excerpt exclusions id item_ref landing prediction source_ref status trigger" \
    "$(jq -r '.items[0] | keys - ["observations_count","observations_by_state","observations_malformed","control_candidate","control_candidate_reasons"] | sort | join(" ")' <<<"$OUT")"
ck  "既存キーの値も不変（trigger）" "trigger for $ULID1" "$(jq -r '.items[0].trigger' <<<"$OUT")"
ck  "新キーが存在する"      "true" "$(jq -r '.items[0] | has("observations_count") and has("control_candidate")' <<<"$OUT")"

echo "[31b] allow-list 非合致の ref から制御候補を立てない（旧 deny 迂回形の回帰も含む・#274）"
R31B="$_TMP_DIR/r31b"; mkdir -p "$R31B"; git_init "$R31B"
write_item "$R31B/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "allow 非合致 ref + harmful。" 'observations:
  - {date: 2026-07-25, ref: "/tmp/evidence.md#274", state: harmful}
  - {date: 2026-07-25, ref: "../../repo#274", state: contradicted}
  - {date: 2026-07-25, ref: " .oe/plan.md", state: harmful}
  - {date: 2026-07-25, ref: "docs/knowledge/items/X.md", state: harmful}'
git_commit "$R31B"
run "$R31B" --json
ck  "invalid に数える（4 件）"        "4" "$(jq -r '.items[0].observations_by_state.invalid' <<<"$OUT")"
ck  "adverse として集計しない"        "null" "$(jq -r '.items[0].observations_by_state.harmful' <<<"$OUT")"
ck  "制御候補にしない"                "false" "$(jq -r '.items[0].control_candidate' <<<"$OUT")"
ck  "malformed として surface する"   "true" "$(jq -r '.items[0].observations_malformed' <<<"$OUT")"

echo "[31c] note: null の harmful から制御候補を立てない（gate 4 実装SO 指摘・#274）"
R31C="$_TMP_DIR/r31c"; mkdir -p "$R31C"; git_init "$R31C"
write_item "$R31C/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "note が null / 空 / CR。" 'observations:
  - {date: 2026-07-25, ref: "#274", state: harmful, note: null}
  - {date: 2026-07-25, ref: "#275", state: harmful, note: ""}
  - {date: 2026-07-25, ref: "#276", state: contradicted, note: "a\rb"}'
git_commit "$R31C"
run "$R31C" --json
ck  "invalid に数える（3 件）" "3" "$(jq -r '.items[0].observations_by_state.invalid' <<<"$OUT")"
ck  "adverse に数えない"    "null" "$(jq -r '.items[0].observations_by_state.harmful' <<<"$OUT")"
ck  "制御候補にしない"      "false" "$(jq -r '.items[0].control_candidate' <<<"$OUT")"

echo "[32] contract: lister が integrity 判定する集合 == validator が exit 1 にする集合（述語の二重化を縛る）"
R32="$_TMP_DIR/r32"; mkdir -p "$R32/docs/knowledge/items"
# valid（空・1件・7 state 相当）と invalid（未知キー・enum 外・暦不正・ref 揮発・非配列）を混在させる
write_item "$R32/docs/knowledge/items/$ULID1.md" "$ULID1" active nl "valid 空。"
write_item "$R32/docs/knowledge/items/$ULID2.md" "$ULID2" active nl "valid 1件。" "$(obs_yaml followed)"
write_item "$R32/docs/knowledge/items/$ULID3.md" "$ULID3" active nl "invalid 未知キー。" 'observations:
  - {date: 2026-07-25, ref: "#101", state: followed, author: child}'
ULID4="01J0ABCDEFGHJKMNPQRSTVWX22"
ULID5="01J0ABCDEFGHJKMNPQRSTVWX33"
write_item "$R32/docs/knowledge/items/$ULID4.md" "$ULID4" active nl "invalid 暦不正。" 'observations:
  - {date: 2026-02-29, ref: "#102", state: followed}'
write_item "$R32/docs/knowledge/items/$ULID5.md" "$ULID5" active nl "invalid ref（allow 非合致）。" 'observations:
  - {date: 2026-07-25, ref: ".oe/plan.md", state: followed}'
ULID6="01J0ABCDEFGHJKMNPQRSTVWX44"
ULID7="01J0ABCDEFGHJKMNPQRSTVWX55"
write_item "$R32/docs/knowledge/items/$ULID6.md" "$ULID6" active nl "invalid note null。" 'observations:
  - {date: 2026-07-25, ref: "#103", state: harmful, note: null}'
write_item "$R32/docs/knowledge/items/$ULID7.md" "$ULID7" active nl "invalid allow 非合致 ref。" 'observations:
  - {date: 2026-07-25, ref: "/tmp/evidence.md#274", state: harmful}'
lister_flagged="$(env OE_KNOWLEDGE_REPO_ROOT="$R32" "$BASH" "$LISTER" --json "$R32/docs/knowledge/items" \
  | jq -r '[.items[] | select(.observations_malformed == true) | .id] | sort | join(" ")')"
validator_flagged=""
for f in "$R32/docs/knowledge/items"/*.md; do
  if ! env OE_KNOWLEDGE_REPO_ROOT="$R32" "$BASH" "$VALIDATOR" "$f" >/dev/null 2>&1; then
    bn="${f##*/}"; validator_flagged="$validator_flagged ${bn%.md}"
  fi
done
validator_flagged="$(printf '%s' "$validator_flagged" | tr ' ' '\n' | grep -v '^$' | sort | tr '\n' ' ' | sed 's/ $//')"
ck  "両コマンドの判定集合が一致" "$validator_flagged" "$lister_flagged"
ck  "flagged は 5 件"            "5" "$(printf '%s' "$lister_flagged" | wc -w | tr -d ' ')"

# --- サマリ ---
echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
