#!/usr/bin/env bash
set -euo pipefail

# test_validate_knowledge.sh — scripts/validate-knowledge.sh（#272 段2・knowledge item schema）の検証。
#
# 正例・負例・directory mode・exit code 分離を fixture で網羅する。設計 SO（gate 2）で挙がった負例契約
# （malformed YAML=exit1・source.ref 揮発/絶対/不存在・observations 空必須・prose 可視文字・非 .md）を固定する。
# source.ref の存在確認は OE_KNOWLEDGE_REPO_ROOT を _TMP_DIR に固定して決定化する（実 repo に依存しない）。
# validator は test_validate_board.sh と同じく subprocess で叩き、内側 validator を本テストと同じ
# bash（${BASH}）で起動して bash 3.2 / 5.x 両系ゲートを実効化する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATOR="$PROJECT_DIR/scripts/validate-knowledge.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }
command -v yq >/dev/null 2>&1 || { echo "SKIP: yq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

# source.ref の repo-root 基点を _TMP_DIR に固定し、存在する committed path 用のファイルを置く。
ROOT="$_TMP_DIR/repo"
mkdir -p "$ROOT"
: > "$ROOT/exists.md"

# 固定 ULID（26字・Crockford Base32・I/L/O/U 無し）。ファイル名は <ULID>.md。
ULID="01J0ABCDEFGHJKMNPQRSTVWXYZ"

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3] in: $2)"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

RUN_RC=0; RUN_OUT=""
# run [args...] — OE_KNOWLEDGE_REPO_ROOT=$ROOT 固定で validator を回し stdout+stderr と exit を捕捉。
run() {
  local out rc=0
  out="$(env OE_KNOWLEDGE_REPO_ROOT="$ROOT" "$BASH" "$VALIDATOR" "$@" 2>&1)" || rc=$?
  RUN_RC="$rc"; RUN_OUT="$out"
}

# 完全に valid な item を書き出す（source.ref は URL＝存在検査対象外）。各テストで必要行を崩す。
write_valid_item() {
  cat > "$1" <<EOF
---
id: "$ULID"
type: knowledge
status: active
date: 2026-07-23
trigger: "shell script で構造化 YAML frontmatter を検証するとき"
prediction: "yq を使えばネスト/配列フィールドの検証漏れが起きない"
source:
  ref: "https://github.com/stlwolf/ai-development-hub/issues/272"
landing: guard-candidate
observations: []
exclusions:
  - "自明・一度きりの知見には使わない"
---

grep 単体ではネストしたキーや配列要素を確実に捕捉できない。YAML パーサ（yq 等）を使う。
EOF
}

# ============================================================================
echo "[1] valid item → exit 0 / OK"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
run "$F"
ck  "exit 0"  "0" "$RUN_RC"
ckc "OK 出力" "$RUN_OUT" "OK: $F"

echo "[2] 必須キー欠落（prediction 削除）→ exit 1 / WARN missing"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed '/^prediction:/d' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"        "1" "$RUN_RC"
ckc "WARN missing"  "$RUN_OUT" "missing required key: prediction"

echo "[3] type != knowledge → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's/^type: .*/type: episode/' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"      "1" "$RUN_RC"
ckc "WARN type"   "$RUN_OUT" "type must be 'knowledge'"

echo "[4] status enum 外 → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's/^status: .*/status: stable/' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"        "1" "$RUN_RC"
ckc "WARN status"   "$RUN_OUT" "status not in enum"

echo "[5] id が ULID でない → exit 1"
F="$_TMP_DIR/badid.md"
write_valid_item "$_TMP_DIR/tmp5"; sed 's/^id: .*/id: "not-a-ulid"/' "$_TMP_DIR/tmp5" > "$F"
# ファイル名 badid.md ≠ id なので naming WARN も出るが、ここでは ULID WARN を確認
run "$F"
ck  "exit 1"     "1" "$RUN_RC"
ckc "WARN ULID"  "$RUN_OUT" "id is not a valid ULID"

echo "[6] basename != <id>.md → exit 1 / WARN filename"
F="$_TMP_DIR/wrongname.md"; write_valid_item "$F"
run "$F"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN filename"   "$RUN_OUT" "filename must be <id>.md"

echo "[7] date 形式不正 → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's|^date: .*|date: 2026/07/23|' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"     "1" "$RUN_RC"
ckc "WARN date"  "$RUN_OUT" "date must be YYYY-MM-DD"

echo "[8] date がカレンダー不正（2026-13-40）→ exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's/^date: .*/date: 2026-13-40/' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN calendar"   "$RUN_OUT" "not a parseable calendar date"

echo "[9] trigger 空 → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's/^trigger: .*/trigger: ""/' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"        "1" "$RUN_RC"
ckc "WARN trigger"  "$RUN_OUT" "trigger must be a non-empty string"

echo "[10] source が scalar → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
# source: の map（見出し + 次行 ref）を 1 行の scalar に潰す（frontmatter 構造は保つ）
awk '/^source:/{print "source: \"just a string\""; skip=1; next} skip && /^  ref:/{skip=0; next} {print}' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"       "1" "$RUN_RC"
ckc "WARN source"  "$RUN_OUT" "source must be a map"

echo "[11] source.ref 空 → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's|^  ref: .*|  ref: ""|' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN ref empty"  "$RUN_OUT" "source.ref must be a non-empty string"

echo "[12] source.ref が揮発層（.oe/）→ exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's|^  ref: .*|  ref: ".oe/plan-272.md"|' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"            "1" "$RUN_RC"
ckc "WARN volatile"     "$RUN_OUT" "volatile working layer"

echo "[13] source.ref が絶対パス → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's|^  ref: .*|  ref: "/etc/passwd"|' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"        "1" "$RUN_RC"
ckc "WARN abs"      "$RUN_OUT" "must not be an absolute path"

echo "[14] source.ref が repo 相対で不存在 → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's|^  ref: .*|  ref: "docs/nope.md"|' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"           "1" "$RUN_RC"
ckc "WARN not exist"   "$RUN_OUT" "does not exist"

echo "[15] source.ref が repo 相対で存在（ROOT/exists.md）→ exit 0"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's|^  ref: .*|  ref: "exists.md"|' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 0"  "0" "$RUN_RC"

echo "[16] landing enum 外 → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's/^landing: .*/landing: maybe/' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN landing"    "$RUN_OUT" "landing not in enum"

echo "[17] observations 非空 → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's/^observations: .*/observations: ["x"]/' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"              "1" "$RUN_RC"
ckc "WARN observations"   "$RUN_OUT" "observations must be empty"

echo "[18] observations が配列でない → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's/^observations: .*/observations: "nope"/' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"                "1" "$RUN_RC"
ckc "WARN obs not array"    "$RUN_OUT" "observations must be an array"

echo "[19] exclusions が scalar → exit 1 / list なら valid（[1] で既に確認）"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
# exclusions ブロック（見出し + 2 list 行）を scalar に置換
sed '/^exclusions:/,/使わない"$/d' "$F" > "$F.t"
{ head -n "$(grep -n '^exclusions:' "$F" | head -1 | cut -d: -f1)" "$F" | grep -v '^exclusions:' ; } >/dev/null 2>&1 || true
# 単純化: valid を書き直して exclusions を scalar 化
write_valid_item "$F"
awk '/^exclusions:/{print "exclusions: \"scalar\""; skip=1; next} skip && /^  - /{next} {skip=0; print}' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"             "1" "$RUN_RC"
ckc "WARN exclusions"    "$RUN_OUT" "exclusions, if present, must be an array"

echo "[20] 本文 prose が空白のみ → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
# frontmatter 後の本文を空白のみに置換
awk 'f==2{next} {print} /^---$/{c++; if(c==2) f=2}' "$F" > "$F.t"
{ cat "$F.t"; printf '\n   \n'; } > "$F"
rm -f "$F.t"
run "$F"
ck  "exit 1"        "1" "$RUN_RC"
ckc "WARN body"     "$RUN_OUT" "body prose is empty"

echo "[21] malformed YAML → exit 1（schema 違反であって環境エラー exit2 ではない）"
F="$_TMP_DIR/$ULID.md"
cat > "$F" <<EOF
---
id: "$ULID"
type: [unclosed
---

本文
EOF
run "$F"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN malformed"  "$RUN_OUT" "malformed YAML"
ncc "exit2 ではない"  "$RUN_OUT" "is not installed"

echo "[22] frontmatter root が scalar → exit 1"
F="$_TMP_DIR/$ULID.md"
cat > "$F" <<EOF
---
just a bare string
---

本文
EOF
run "$F"
ck  "exit 1"           "1" "$RUN_RC"
ckc "WARN root map"    "$RUN_OUT" "root is not a map"

echo "[23] frontmatter block 無し → exit 1"
F="$_TMP_DIR/$ULID.md"
printf '# no frontmatter\n\n本文だけ\n' > "$F"
run "$F"
ck  "exit 1"            "1" "$RUN_RC"
ckc "WARN no block"     "$RUN_OUT" "frontmatter block not found"

echo "[24] 空 frontmatter block（--- のみ）→ exit 1"
F="$_TMP_DIR/$ULID.md"
printf -- '---\n---\n\n本文\n' > "$F"
run "$F"
ck  "exit 1"             "1" "$RUN_RC"
ckc "WARN empty block"   "$RUN_OUT" "empty frontmatter block"

echo "[25] file not found → exit 2"
run "$_TMP_DIR/does-not-exist.md"
ck  "exit 2"            "2" "$RUN_RC"
ckc "not found メッセージ" "$RUN_OUT" "not found"

echo "[26] directory mode: valid store（2 件）→ exit 0"
D="$_TMP_DIR/store"; mkdir -p "$D"
U2="01J0ABCDEFGHJKMNPQRSTVWXY0"
write_valid_item "$D/$ULID.md"
write_valid_item "$_TMP_DIR/tmp2"; sed "s/$ULID/$U2/" "$_TMP_DIR/tmp2" > "$D/$U2.md"
run "$D"
ck  "exit 0"  "0" "$RUN_RC"
ckc "OK dir"  "$RUN_OUT" "OK: $D"

echo "[27] directory mode: 1 件不正 → exit 1"
sed 's/^status: .*/status: bogus/' "$D/$U2.md" > "$D/$U2.md.t" && mv "$D/$U2.md.t" "$D/$U2.md"
run "$D"
ck  "exit 1"        "1" "$RUN_RC"
ckc "WARN status"   "$RUN_OUT" "status not in enum"

echo "[28] 非 .md ファイルを直接渡す → exit 1（filename 規約違反）"
F="$_TMP_DIR/item.txt"; write_valid_item "$F"
run "$F"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN filename"   "$RUN_OUT" "filename must be <id>.md"

echo "[29] 複数違反を 1 実行で一括 WARN（fail-fast しない）→ exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed -e 's/^type: .*/type: episode/' -e 's/^landing: .*/landing: maybe/' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN type 到達"   "$RUN_OUT" "type must be 'knowledge'"
ckc "WARN landing 到達" "$RUN_OUT" "landing not in enum"

echo "[30] 引数なし → exit 2（usage）"
run
ck  "exit 2"       "2" "$RUN_RC"
ckc "usage 出力"   "$RUN_OUT" "Usage:"

echo "[31] 必須キーが null（id: null）→ exit 1 / WARN null"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's/^id: .*/id: null/' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"      "1" "$RUN_RC"
ckc "WARN null"   "$RUN_OUT" "required key is null: id"

echo "[32] source.ref が tmp/ 揮発 → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's|^  ref: .*|  ref: "tmp/scratch.md"|' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN volatile"   "$RUN_OUT" "volatile working layer"

echo "[33] source が空 map（ref 欠落）→ exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
awk '/^source:/{print "source: {}"; skip=1; next} skip && /^  ref:/{skip=0; next} {print}' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN ref empty"  "$RUN_OUT" "source.ref must be a non-empty string"

echo "[34] exclusions 要素が非文字列（数値）→ exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
awk '/^exclusions:/{print "exclusions:"; print "  - 42"; skip=1; next} skip && /^  - /{next} {skip=0; print}' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"               "1" "$RUN_RC"
ckc "WARN excl element"    "$RUN_OUT" "exclusions elements must all be strings"

echo "[35] directory mode は非再帰: items/nested/ の不正 item を無視 → exit 0"
D="$_TMP_DIR/store2"; mkdir -p "$D/nested"
write_valid_item "$D/$ULID.md"
# nested に不正 item（status 不正）を置くが、非再帰なので検証されない
write_valid_item "$_TMP_DIR/tmpN"; sed 's/^status: .*/status: bogus/' "$_TMP_DIR/tmpN" > "$D/nested/$ULID.md"
run "$D"
ck  "exit 0（nested は無視）"  "0" "$RUN_RC"

# --- サマリ ---
echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
