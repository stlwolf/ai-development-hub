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

# mktemp 失敗時に空パスで継続して root 直下へ書き込む事故を防ぐ（実装SO 指摘・tests/ 確立規約）。
_TMP_DIR="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
[[ -n "$_TMP_DIR" && -d "$_TMP_DIR" ]] || { echo "FATAL: mktemp -d returned an invalid path: '${_TMP_DIR}'" >&2; exit 1; }
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

# observations 要素スキーマ（#274 段5）用の fixture。observations 以外は valid な item を書き、
# observations には渡された YAML 断片（"observations:" の行を含む）をそのまま置く。
write_item_with_obs() {
  local file="$1" obs="$2"
  {
    printf -- '---\n'
    printf 'id: "%s"\n' "$ULID"
    printf 'type: knowledge\nstatus: active\ndate: 2026-07-25\n'
    printf 'trigger: "注入した knowledge の帰結を書き戻すとき"\n'
    printf 'prediction: "要素スキーマ検証が形の崩れを commit 前に落とす"\n'
    printf 'source:\n  ref: "https://github.com/stlwolf/ai-development-hub/issues/274"\n'
    printf 'landing: nl\n'
    printf '%s\n' "$obs"
    printf -- '---\n\n観測レコードの形式例（実データではない）。\n'
  } > "$file"
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
ckc "WARN calendar"   "$RUN_OUT" "date is not a valid calendar date"

# top-level date の暦厳密化（#274 裁定3）。jq の strptime は存在しない日を翌月へ正規化して通すため
# 純 jq の cal_ok で検査する。月13 だけを見る [8] では検出できない穴を固定する。
echo "[8b] top-level date が存在しない日（2026-02-29 / 2026-04-31）→ exit 1・閏年（2024-02-29）は valid"
for bad_date in 2026-02-29 2026-04-31; do
  F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
  sed "s/^date: .*/date: $bad_date/" "$F" > "$F.t" && mv "$F.t" "$F"
  run "$F"
  ck  "exit 1 ($bad_date)"        "1" "$RUN_RC"
  ckc "WARN calendar ($bad_date)" "$RUN_OUT" "date is not a valid calendar date: $bad_date"
done
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's/^date: .*/date: 2024-02-29/' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 0（閏年 2024-02-29 は valid）" "0" "$RUN_RC"

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

echo "[17] observations 要素スキーマ 正例（空配列 / note なし / note あり / 複数件 / 7 state 全部）→ exit 0"
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations: []'
run "$F"; ck "exit 0（空配列＝収穫時の既定）" "0" "$RUN_RC"

write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: followed'
run "$F"; ck "exit 0（1件・note なし）" "0" "$RUN_RC"

write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: followed
    note: "brief slot の item に従い argv でなく stdin で渡した"'
run "$F"; ck "exit 0（1件・note あり）" "0" "$RUN_RC"

write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: no_opportunity
  - date: 2026-07-25
    ref: "owner/repo#274"
    state: injected_not_used
  - date: 2026-07-25
    ref: "https://github.com/org/repo/pull/280"
    state: followed
  - date: 2026-07-25
    ref: "#281"
    state: contradicted
  - date: 2026-07-25
    ref: "#282"
    state: harmful
  - date: 2026-07-25
    ref: "#283"
    state: outcome_unknown
  - date: 2026-07-25
    ref: "#284"
    state: externally_verified'
run "$F"; ck "exit 0（7 state 全部・複数件）" "0" "$RUN_RC"

echo "[18] observations が配列でない → exit 1"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's/^observations: .*/observations: "nope"/' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"                "1" "$RUN_RC"
ckc "WARN obs not array"    "$RUN_OUT" "observations must be an array"

echo "[19] exclusions が scalar → exit 1 / list なら valid（[1] で既に確認）"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
# exclusions（見出し + list 行）を 1 行の scalar に潰す
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

echo "[26] directory mode: valid store（items/ に 2 ULID item）→ exit 0"
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

echo "[36] source.ref に .. を含む（repo escape）→ exit 1（Copilot 指摘）"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
sed 's|^  ref: .*|  ref: "../../etc/passwd"|' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN dotdot"     "$RUN_OUT" "'..' path segments"

echo "[37] directory mode: 誤名（非 ULID）item は skip でなく WARN + exit 1（F6 すり抜け検知）"
D="$_TMP_DIR/store3"; mkdir -p "$D"
write_valid_item "$D/$ULID.md"
# frontmatter は valid だがファイル名が ULID でない誤名 item → 黙って落とさず検出する
write_valid_item "$D/misnamed.md"
run "$D"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN 誤名 item"  "$RUN_OUT" "filename must be <id>.md"

# ============================================================================
# observations 要素スキーマの負例（#274 段5・gate 2 設計SO で確定した契約）
# ============================================================================

echo "[38] 要素が map でない → exit 1（以降のキー検査はしない）"
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations:
  - "not-a-map"'
run "$F"
ck  "exit 1"        "1" "$RUN_RC"
ckc "WARN non-map"  "$RUN_OUT" "observations[0]: element must be a map"
ncc "date 検査はしない" "$RUN_OUT" "observations[0].date is required"

echo "[39] 必須キー欠落（date / ref / state を個別に落とす）→ exit 1"
for miss in date ref state; do
  F="$_TMP_DIR/$ULID.md"
  case "$miss" in
    date)  write_item_with_obs "$F" 'observations:
  - ref: "#274"
    state: followed' ;;
    ref)   write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    state: followed' ;;
    state) write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"' ;;
  esac
  run "$F"
  ck  "exit 1 ($miss 欠落)"   "1" "$RUN_RC"
  ckc "WARN $miss required"   "$RUN_OUT" "observations[0].$miss is required"
done

echo "[40] 必須キーが null → 欠落と同じ扱い → exit 1"
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations:
  - date: null
    ref: "#274"
    state: followed'
run "$F"
ck  "exit 1"              "1" "$RUN_RC"
ckc "WARN null は欠落扱い" "$RUN_OUT" "observations[0].date is required"

echo "[41] state が enum 外 → exit 1（enum を WARN に列挙）"
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: helpful_typo'
run "$F"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN state enum" "$RUN_OUT" "observations[0].state not in enum"
ckc "enum 値を出す"    "$RUN_OUT" "externally_verified"

echo "[42] date の形式不正 / 暦不正 → exit 1・閏年は valid"
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations:
  - date: "2026/07/25"
    ref: "#274"
    state: followed'
run "$F"
ck  "exit 1（形式不正）"   "1" "$RUN_RC"
ckc "WARN date 形式"      "$RUN_OUT" "observations[0].date must be a valid calendar date"
for bad_date in 2026-02-29 2026-04-31 2026-13-01; do
  write_item_with_obs "$F" "observations:
  - date: $bad_date
    ref: \"#274\"
    state: followed"
  run "$F"
  ck  "exit 1 (暦不正 ${bad_date})" "1" "$RUN_RC"
done
write_item_with_obs "$F" 'observations:
  - date: 2024-02-29
    ref: "#274"
    state: followed'
run "$F"
ck  "exit 0（閏年 2024-02-29）" "0" "$RUN_RC"

echo "[43] ref が空 / 空白のみ → exit 1"
for empty_ref in '""' '"   "'; do
  F="$_TMP_DIR/$ULID.md"
  write_item_with_obs "$F" "observations:
  - date: 2026-07-25
    ref: $empty_ref
    state: followed"
  run "$F"
  ck  "exit 1 (ref=$empty_ref)"  "1" "$RUN_RC"
  ckc "WARN ref 非空"            "$RUN_OUT" "observations[0].ref must be a non-empty string"
done

echo "[44] ref hygiene 真陽性（揮発層 / 絶対パス / .. セグメント）→ exit 1"
for bad_ref in '.oe/plan-274.md' 'tmp/scratch.md' '/Users/x/evidence.md' '../evidence.md' 'docs/../../etc/passwd'; do
  F="$_TMP_DIR/$ULID.md"
  write_item_with_obs "$F" "observations:
  - date: 2026-07-25
    ref: \"$bad_ref\"
    state: followed"
  run "$F"
  ck  "exit 1 (ref=$bad_ref)"  "1" "$RUN_RC"
  ckc "WARN ref hygiene"       "$RUN_OUT" "observations[0].ref must be a durable work reference"
done

echo "[44b] ref hygiene の迂回路がない（gate 4 実装SO で実測された回帰・#274）"
# issue/PR 形式や "://" を hygiene より先に免除すると、末尾に #N を付けるだけで揮発層・絶対パス・
# .. が通り抜け、その ref を持つ harmful レコードが「valid な adverse 観測」として制御候補になった。
for bypass_ref in '../../repo#274' '/tmp/evidence.md#274' '/tmp/evidence.md://x' '.oe/brief-274.md#1' 'tmp/scratch.md#2' \
                  ' .oe/plan.md' '  tmp/scratch.md' './tmp/scratch.md' '.oe/plan.md ' ' ../evidence.md' './/tmp/x' \
                  'C:/Windows/system32/x.md' '//server/share/x.md'; do
  F="$_TMP_DIR/$ULID.md"
  write_item_with_obs "$F" "observations:
  - date: 2026-07-25
    ref: \"$bypass_ref\"
    state: harmful"
  run "$F"
  ck  "exit 1 (迂回 ref=$bypass_ref)" "1" "$RUN_RC"
  ckc "WARN ref hygiene"              "$RUN_OUT" "observations[0].ref must be a durable work reference"
done

echo "[45] ref hygiene 偽陽性なし（issue / PR 参照・URL・自由文・tmp- 接頭の別語）→ exit 0"
# source.ref の */tmp/* 部分一致をそのまま写すと誤爆する集合（gate 2 設計SO C1）。
for ok_ref in '#274' 'owner/repo#274' 'https://github.com/org/repo/pull/274/files#path=.oe/brief' \
              'https://example.com/projects/.oe/plan.md' 'PR #274 の再現手順は foo/tmp/bar 参照' 'tmp-spec/foo.md'; do
  F="$_TMP_DIR/$ULID.md"
  write_item_with_obs "$F" "observations:
  - date: 2026-07-25
    ref: \"$ok_ref\"
    state: followed"
  run "$F"
  ck  "exit 0 (ref=$ok_ref)" "0" "$RUN_RC"
done

echo "[46] note が非 string / 改行を含む → exit 1（改行入りでも WARN は 1 行）"
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: followed
    note: 42'
run "$F"
ck  "exit 1（非 string）"   "1" "$RUN_RC"
ckc "WARN note string"     "$RUN_OUT" "observations[0].note, if present, must be a string"
write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: followed
    note: "line1\nline2"'
run "$F"
ck  "exit 1（改行あり）"        "1" "$RUN_RC"
ckc "WARN note 1行"            "$RUN_OUT" "observations[0].note must be a single line"
ck  "WARN は 1 行（tojson でエスケープ）" "1" "$(printf '%s' "$RUN_OUT" | grep -c 'observations\[0\].note must be a single line')"

echo "[46b] note が present-but-null（null / 空値）→ exit 1（gate 4 実装SO 指摘・#274）"
# 「書かない」なら *キーを省く*。null を省略と同一視すると、書き手が note を書いたつもりで
# 空になった記録が黙って valid になる（spec は「任意・存在時は string」）。
for null_note in 'note: null' 'note:'; do
  F="$_TMP_DIR/$ULID.md"
  write_item_with_obs "$F" "observations:
  - date: 2026-07-25
    ref: \"#274\"
    state: harmful
    $null_note"
  run "$F"
  ck  "exit 1 (${null_note})"  "1" "$RUN_RC"
  ckc "WARN note null"         "$RUN_OUT" "observations[0].note must be a string when present"
done

echo "[47] 未知キーを拒否 → exit 1（キー名を出す・空白入りキーでも 1 違反 1 行）"
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: followed
    author: "child"'
run "$F"
ck  "exit 1"            "1" "$RUN_RC"
ckc "WARN unknown key"  "$RUN_OUT" "unknown key(s) not allowed"
ckc "キー名を出す"       "$RUN_OUT" "author"
write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: followed
    "weird key": "x"'
run "$F"
ck  "exit 1（空白入りキー）"  "1" "$RUN_RC"
ck  "WARN は 1 行"           "1" "$(printf '%s' "$RUN_OUT" | grep -c 'unknown key(s) not allowed')"

echo "[48] 1 要素に複数違反 → 違反ごとに WARN・index は 0 始まりで決定的"
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations:
  - date: 2026-02-29
    ref: ".oe/x.md"
    state: bogus
    note: 7
    extra: y
  - date: 2026-07-25
    ref: "#274"
    state: followed'
run "$F"
ck  "exit 1"                     "1" "$RUN_RC"
ck  "WARN 5 件（date/ref/state/note/未知キー）" "5" "$(printf '%s' "$RUN_OUT" | grep -c 'observations\[0\]')"
ncc "valid な 2 番目は WARN なし" "$RUN_OUT" "observations[1]"

echo "[49] 2 番目の要素だけ不正 → index 1 で報告（0 始まりの決定性）"
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: followed
  - date: 2026-07-25
    ref: "#275"
    state: bogus'
run "$F"
ck  "exit 1"              "1" "$RUN_RC"
ckc "index 1 で報告"       "$RUN_OUT" "observations[1].state not in enum"
ncc "index 0 は報告しない"  "$RUN_OUT" "observations[0]"

echo "[50] 巨大な observations 配列（400 件）→ exit 0・argv 落ち（exit 126）しない"
F="$_TMP_DIR/$ULID.md"
{
  printf 'observations:\n'
  i=0
  while [[ "$i" -lt 400 ]]; do
    printf '  - date: 2026-07-25\n    ref: "#%s"\n    state: followed\n    note: "%s"\n' "$i" "$(printf 'x%.0s' $(seq 1 200))"
    i=$((i + 1))
  done
} > "$_TMP_DIR/obs-big.yaml"
write_item_with_obs "$F" "$(cat "$_TMP_DIR/obs-big.yaml")"
run "$F"
ck  "exit 0（stdin 経由・argv 落ちしない）" "0" "$RUN_RC"

# --- サマリ ---
echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
