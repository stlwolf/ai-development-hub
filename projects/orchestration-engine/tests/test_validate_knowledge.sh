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

echo "[8c] jq の評価失敗は環境エラー（exit 2）で落ちる — データ不備（exit 1）に丸めない（Copilot 指摘・#274）"
# 狙った jq プログラムだけ失敗する stub を PATH 先頭に置き、他の jq 呼び出しは実 jq に委譲させる。
# これで「環境側で jq の評価が失敗した」状況だけを再現できる（jq 本体を壊す必要がない）。失敗させる
# プログラムは STUB_JQ_FAIL（case のパターン）で渡し、失敗させた引数を STUB_JQ_LOG へ1行で記録する
# （狙った呼び出しで落ちたことを確かめるため・#283 で [8d] と共用にした）。
_REAL_JQ="$(command -v jq)"
_STUB_DIR="$_TMP_DIR/stubbin"; mkdir -p "$_STUB_DIR"
{
  # stub の中身は literal で出す（$@ や STUB_JQ_FAIL を呼び出し側で展開させない）。
  cat <<'STUB'
#!/usr/bin/env bash
if [ -n "${STUB_JQ_FAIL:-}" ]; then
  for a in "$@"; do
    # shellcheck disable=SC2254
    case "$a" in $STUB_JQ_FAIL) printf '%s\n' "$a" >> "${STUB_JQ_LOG:-/dev/null}"; exit 5 ;; esac
  done
fi
STUB
  # 実 jq のパスは %q で引用する（空白を含む配置でも1語のまま渡す・#424 の実装SO 指摘）。
  # shellcheck disable=SC2016
  printf 'exec %q "$@"\n' "$_REAL_JQ"
} > "$_STUB_DIR/jq"
chmod +x "$_STUB_DIR/jq"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
_STUB_RC=0
_STUB_OUT="$(env PATH="$_STUB_DIR:$PATH" STUB_JQ_FAIL='*cal_ok*' OE_KNOWLEDGE_REPO_ROOT="$ROOT" "$BASH" "$VALIDATOR" "$F" 2>&1)" || _STUB_RC=$?
ck  "exit 2（環境エラー）"     "2" "$_STUB_RC"
ckc "ERROR メッセージ"        "$_STUB_OUT" "failed to evaluate the calendar-validity filter with jq"
ncc "WARN に丸めていない"      "$_STUB_OUT" "date is not a valid calendar date"

echo "[8d] 型を読む jq の評価失敗も環境エラー（exit 2）— root / source / observations / exclusions の4か所（#283）"
# 4か所それぞれの jq プログラムだけを [8c] の stub で失敗させ、exit 2・その箇所の ERROR・その箇所の WARN が
# 出ないことを見る。stub の記録で、狙ったプログラムで落ちたこと（他の呼び出しで落ちたのではないこと）も見る。
_TYPE_PROGS=("type" ".source | type" ".observations | type" ".exclusions | type")
_TYPE_NAMES=("frontmatter root" "source" "observations" "exclusions")
_TYPE_WARNS=("frontmatter root is not a map" "source must be a map" "observations must be an array" "exclusions, if present, must be an array")
i=0
while [[ "$i" -lt 4 ]]; do
  F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
  _STUB_LOG="$_TMP_DIR/stubjq-$i.log"; : > "$_STUB_LOG"
  _STUB_RC=0
  _STUB_OUT="$(env PATH="$_STUB_DIR:$PATH" STUB_JQ_FAIL="${_TYPE_PROGS[$i]}" STUB_JQ_LOG="$_STUB_LOG" OE_KNOWLEDGE_REPO_ROOT="$ROOT" "$BASH" "$VALIDATOR" "$F" 2>&1)" || _STUB_RC=$?
  ck  "${_TYPE_NAMES[$i]}: exit 2（環境エラー）"         "2" "$_STUB_RC"
  ckc "${_TYPE_NAMES[$i]}: ERROR メッセージ"            "$_STUB_OUT" "failed to evaluate the ${_TYPE_NAMES[$i]} type with jq"
  ncc "${_TYPE_NAMES[$i]}: WARN に丸めていない"          "$_STUB_OUT" "${_TYPE_WARNS[$i]}"
  ck  "${_TYPE_NAMES[$i]}: 狙ったプログラムで stub が落とした" "${_TYPE_PROGS[$i]}" "$(cat "$_STUB_LOG")"
  i=$((i + 1))
done

echo "[8e] 残る jq の評価失敗も環境エラー（exit 2）— 必須キー・値の代入・exclusions の12か所（#424）"
# [8d] と同じ stub で1か所ずつ失敗させる。変更前は、WARN・exit 1 に化ける（必須キーの has / 要素の型）、
# 検査を飛ばして OK・exit 0 になる（== null / has("exclusions")）、何も出さずに exit 5 で終わる（代入）の
# どれかだった。_E_PATS は stub に渡す case のパターンで、glob の文字（[ ]）を含むプログラムは * で囲んだ
# 一部だけを渡し、_E_PROGS（記録に残るべきプログラムの全文）と照合する。_E_ABSENT は丸めたときに出る文字列、
# _E_FIX は使う item（valid = 正常な item / excl42 = exclusions に数値を持つ item。has("exclusions") を
# 丸めると、この不正な item が OK になる）。
_E_PROGS=('has("source")' '."id" == null' '.type // empty' '.status // empty' '.id // empty' '.date // empty'
  'if (."trigger"|type)=="string" then ."trigger" else "" end'
  'if (."prediction"|type)=="string" then ."prediction" else "" end'
  'if (.source.ref|type)=="string" then .source.ref else "" end'
  '.landing // empty' 'has("exclusions")' '[.exclusions[] | type] | all(. == "string")')
_E_PATS=("${_E_PROGS[@]}")
_E_PATS[11]='*all(. == "string")*'
_E_ERRS=("whether the required key 'source' exists" "whether the required key 'id' is null"
  "the value of 'type'" "the value of 'status'" "the value of 'id'" "the value of 'date'"
  "the value of 'trigger'" "the value of 'prediction'" "the value of 'source.ref'" "the value of 'landing'"
  "whether the optional key 'exclusions' exists" "the element types of 'exclusions'")
_E_ABSENT=("missing required key: source" "OK:" "type must be 'knowledge'" "status not in enum" "id is not a valid ULID"
  "date must be YYYY-MM-DD" "trigger must be a non-empty string" "prediction must be a non-empty string"
  "source.ref must be a non-empty string" "landing not in enum" "OK:" "exclusions elements must all be strings")
_E_FIX=(valid valid valid valid valid valid valid valid valid valid excl42 valid)
i=0
while [[ "$i" -lt "${#_E_PROGS[@]}" ]]; do
  F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
  if [[ "${_E_FIX[$i]}" == "excl42" ]]; then
    awk '/^exclusions:/{print "exclusions:"; print "  - 42"; skip=1; next} skip && /^  - /{next} {skip=0; print}' "$F" > "$F.t" && mv "$F.t" "$F"
  fi
  _STUB_LOG="$_TMP_DIR/stubjq-e$i.log"; : > "$_STUB_LOG"
  _STUB_RC=0
  _STUB_OUT="$(env PATH="$_STUB_DIR:$PATH" STUB_JQ_FAIL="${_E_PATS[$i]}" STUB_JQ_LOG="$_STUB_LOG" OE_KNOWLEDGE_REPO_ROOT="$ROOT" "$BASH" "$VALIDATOR" "$F" 2>&1)" || _STUB_RC=$?
  ck  "${_E_PROGS[$i]}: exit 2（環境エラー）"               "2" "$_STUB_RC"
  ckc "${_E_PROGS[$i]}: ERROR メッセージ"                  "$_STUB_OUT" "ERROR: failed to evaluate ${_E_ERRS[$i]} with jq"
  ncc "${_E_PROGS[$i]}: WARN や OK に丸めていない"          "$_STUB_OUT" "${_E_ABSENT[$i]}"
  ck  "${_E_PROGS[$i]}: 狙ったプログラムで stub が落とした"  "${_E_PROGS[$i]}" "$(cat "$_STUB_LOG")"
  i=$((i + 1))
done
# excl42 の item は、stub なしでは従来どおり要素の型の WARN・exit 1 になる（上の OK が丸めの証拠であることの対照）。
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
awk '/^exclusions:/{print "exclusions:"; print "  - 42"; skip=1; next} skip && /^  - /{next} {skip=0; print}' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "excl42 の対照: exit 1"               "1" "$RUN_RC"
ckc "excl42 の対照: 要素の型の WARN"       "$RUN_OUT" "exclusions elements must all be strings"

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

echo "[44] ref allow-list 非合致は reject（旧 deny-list の禁止形・迂回形をまとめて固定）"
# owner 決定（2026-07-25）で deny-list（禁止パターンの列挙）から closed allow-list へ倒した。
# 旧 deny で拒否していた形と、gate 4 / closure で見つかった迂回形は、いずれも「許可形に合致しない」
# 一本の理由で reject される（禁止を数え上げないので、未知の形も既定で reject）。
for bad_ref in '.oe/plan-274.md' 'tmp/scratch.md' '/Users/x/evidence.md' '../evidence.md' 'docs/../../etc/passwd' \
               '../../repo#274' '/tmp/evidence.md#274' '/tmp/evidence.md://x' '.oe/brief-274.md#1' \
               ' .oe/plan.md' './tmp/scratch.md' './/tmp/x' 'C:/Windows/system32/x.md' '//server/share/x.md'; do
  F="$_TMP_DIR/$ULID.md"
  write_item_with_obs "$F" "observations:
  - date: 2026-07-25
    ref: \"$bad_ref\"
    state: harmful"
  run "$F"
  ck  "exit 1 (ref=$bad_ref)"  "1" "$RUN_RC"
  ckc "WARN allow-list"        "$RUN_OUT" "observations[0].ref must be one of the allowed durable work-reference forms"
done

echo "[44b] allow-list へ倒した結果 reject になる形（自由文・repo 相対 path・部分形）"
# deny-list 時代は「偽陽性を避ける」ために通していた形。allow-list ではいずれも reject になる
# （owner 決定の引き換え条件として明示的に固定する）。observations.ref は作業単位の参照であって
# path ではない。repo 相対 path を許すのは source.ref 側の規則で、そちらは変更していない。
for reject_ref in 'PR #274 の再現手順は foo/tmp/bar 参照' 'tmp-spec/foo.md' 'docs/knowledge/items/X.md' \
                  '#' '#abc' 'http://' 'owner/repo#' 'a/b/c#274' '-owner/repo#274'; do
  F="$_TMP_DIR/$ULID.md"
  write_item_with_obs "$F" "observations:
  - date: 2026-07-25
    ref: \"$reject_ref\"
    state: followed"
  run "$F"
  ck  "exit 1 (ref=$reject_ref)" "1" "$RUN_RC"
done

echo "[45pre] allow-list に内在する曖昧さ: <owner>/<repo>#<数字> と同形なら通る（既知・regex では区別不能）"
# `tmp/scratch.md#2` は「repo 名が scratch.md の cross-repo 参照」と同形。GitHub の repo 名はドットを
# 含めるので（例 owner/foo.js#12）、形だけでは意味のある参照と区別できない。allow-list は「形」を
# 検査する機構なので、この曖昧さは残す（緩和はレビューが担う）。path として解決する消費者は居ない。
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "tmp/scratch.md#2"
    state: followed'
run "$F"
ck  "exit 0（形が合致するので通る・既知の曖昧さ）" "0" "$RUN_RC"

echo "[45] allow-list の正例3形（#<数字> / <owner>/<repo>#<数字> / <scheme>://URL・trim 後に判定）"
for ok_ref in '#274' ' #274 ' 'owner/repo#274' 'stlwolf/ai-development-hub#274' \
              'https://github.com/org/repo/pull/282' 'https://github.com/org/repo/pull/274/files#path=.oe/brief' \
              'https://example.com/projects/.oe/plan.md'; do
  F="$_TMP_DIR/$ULID.md"
  write_item_with_obs "$F" "observations:
  - date: 2026-07-25
    ref: \"$ok_ref\"
    state: followed"
  run "$F"
  ck  "exit 0 (ref=$ok_ref)" "0" "$RUN_RC"
done

echo "[45b] 改行を含む ref は先頭行だけの合致で通さない（\\A / \\z アンカー）"
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274\nevil/repo#1"
    state: harmful'
run "$F"
ck  "exit 1（改行入り ref）" "1" "$RUN_RC"
ckc "WARN allow-list"        "$RUN_OUT" "observations[0].ref must be one of the allowed"

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

echo "[46c] note が空 / 空白のみ / CR 改行 → exit 1（実装SO 指摘・#274）"
F="$_TMP_DIR/$ULID.md"
write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: harmful
    note: ""'
run "$F"
ck  "exit 1（空文字）"    "1" "$RUN_RC"
ckc "WARN note empty"    "$RUN_OUT" "observations[0].note must not be empty when present"
write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: harmful
    note: "   "'
run "$F"
ck  "exit 1（空白のみ）"  "1" "$RUN_RC"
# CR のみの改行は LF 検査だけでは通り抜ける
write_item_with_obs "$F" 'observations:
  - date: 2026-07-25
    ref: "#274"
    state: harmful
    note: "line1\rline2"'
run "$F"
ck  "exit 1（CR 改行）"        "1" "$RUN_RC"
ckc "WARN note single line"   "$RUN_OUT" "observations[0].note must be a single line"

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

echo "[51] 空白だけの値は空・空白以外を含めば空でない（#419 で書き換えた空白判定4か所の意味）"
# 不正な UTF-8 のバイト（\xff）だけの値は、どのロケールでも「空でない」が正しい。空白判定を正規表現
# =~ [^[:space:]] へ書き換えると、UTF-8 ロケールではここが「空」に倒れる（#419）。trigger/prediction と
# source.ref は yq を通った値（正しい UTF-8）しか来ないので、正規表現と判定が分かれる入力を作れない。
# 全角空白（U+3000）を空白に数えるかはロケールで決まる（UTF-8 なら数え、C なら数えない）。旧い置換
# ${x//[[:space:]]/} の判定を基準に確かめ、数えるロケールでだけ fixture に混ぜる（数えないロケールで混ぜると、
# 意味を保った実装まで落ちる）。
WSX=$'\xe3\x80\x80'
if [[ -n "${WSX//[[:space:]]/}" ]]; then
  WSX=""; echo "  NOTE: このロケールは全角空白を空白に数えないので、全角空白を混ぜずに確かめる"
fi
F="$_TMP_DIR/$ULID.md"
printf -- '---\n \t%s\n\n---\n\n本文\n' "$WSX" > "$F"
run "$F"
ck  "frontmatter が空白だけ → exit 1"  "1" "$RUN_RC"
ckc "WARN empty block（空白だけ）"      "$RUN_OUT" "empty frontmatter block"
printf -- '---\n\xff\n---\n\n本文\n' > "$F"
run "$F"
ckc "frontmatter が不正なバイトだけ → YAML の検査まで進む" "$RUN_OUT" "malformed YAML frontmatter"
ncc "frontmatter が不正なバイトだけ → 空扱いしない"       "$RUN_OUT" "empty frontmatter block"

F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
awk -v l="trigger: \" \\t$WSX\"" '/^trigger:/{print l; next} {print}' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "trigger が空白だけ → exit 1"  "1" "$RUN_RC"
ckc "WARN trigger（空白だけ）"      "$RUN_OUT" "trigger must be a non-empty string"
F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
awk -v l="prediction: \"$WSX x \\t\"" '/^prediction:/{print l; next} {print}' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "prediction が空白に囲まれた1文字 → exit 0"  "0" "$RUN_RC"

F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
awk -v l="  ref: \"\\t $WSX\"" '/^  ref:/{print l; next} {print}' "$F" > "$F.t" && mv "$F.t" "$F"
run "$F"
ck  "source.ref が空白だけ → exit 1"  "1" "$RUN_RC"
ckc "WARN ref empty（空白だけ）"       "$RUN_OUT" "source.ref must be a non-empty string"

F="$_TMP_DIR/$ULID.md"; write_valid_item "$F"
awk 'f==2{next} {print} /^---$/{c++; if(c==2) f=2}' "$F" > "$F.t"
{ cat "$F.t"; printf '\n\t%s\n' "$WSX"; } > "$F"
run "$F"
ck  "本文が空白だけ → exit 1"   "1" "$RUN_RC"
ckc "WARN body（空白だけ）"     "$RUN_OUT" "body prose is empty"
{ cat "$F.t"; printf '\n\xff\n'; } > "$F"
rm -f "$F.t"
run "$F"
ck  "本文が不正なバイトだけ → exit 0"     "0" "$RUN_RC"
ncc "本文が不正なバイトだけ → 空扱いしない" "$RUN_OUT" "body prose is empty"

# --- サマリ ---
echo ""
echo "[52] 対象を2つ渡したら exit 2（2つ目を黙って捨てて OK を出さない・#531）"
# 1つ目が valid・2つ目が壊れた item。2つ目を捨てると 1つ目だけ見て OK / exit 0 になる。
D52="$_TMP_DIR/two-targets"; mkdir -p "$D52"
F52="$D52/$ULID.md"; write_valid_item "$F52"
printf -- '---\nid: bad\n---\n' > "$D52/bad.md"
run "$F52" "$D52/bad.md"
ck  "exit 2"                    "2" "$RUN_RC"
ncc "OK を出さない"             "$RUN_OUT" "OK:"
ckc "余分な引数を名指しする"    "$RUN_OUT" "unexpected extra argument: $D52/bad.md"
ckc "使い方の行を出す"          "$RUN_OUT" "Usage:"
# 2つ目が valid でも同じ（中身でなく呼び方で弾く）。
run "$F52" "$F52"
ck  "2つとも valid でも exit 2" "2" "$RUN_RC"
# --verbose を挟んでも2つ目は2つ目。
run "$F52" --verbose "$D52/bad.md"
ck  "--verbose を挟んでも exit 2" "2" "$RUN_RC"
# 対象1つ + --verbose は今までどおり通る。
run "$F52" --verbose
ck  "対象1つ + --verbose は exit 0" "0" "$RUN_RC"

echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
