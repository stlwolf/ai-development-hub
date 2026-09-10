#!/usr/bin/env bash
# test_oe_lane_explain.sh — oe-lane-explain（#303 I-1・空返しの原因の読み取り）の検証
#
# 固定する事象（すべて実物で踏んだ・または設計SO が指摘した）:
#   - N1: 故障の文言が散文の中にエコーされているだけのものを故障と読まない（実物で誤検出した）
#   - N2: exit 0 のレーンにはシグネチャを当てない（回答が文言を引用しただけのもの）
#   - D1: 「ファイルが不在」と「ファイルが空」を畳まない（版の証拠を落とさないため）
#   - U1: 分けられない形（claude の無言の空返し）に usage_limit と書かない
#   - E1: レーンの記録が1件も無いときに exit 0 で成功に化かさない
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERB="$SCRIPT_DIR/../bin/oe-lane-explain"
FIX="$SCRIPT_DIR/fixtures/so-lane-failures"
[[ -x "$VERB" ]] || { echo "FAIL: verb not found: $VERB"; exit 1; }
[[ -d "$FIX" ]]  || { echo "FAIL: fixtures not found: $FIX"; exit 1; }

_TMP="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$_TMP"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

# fixture 1件を分類して、指定キーの値を返す（--json の1行から取る）
val_of() {
  local fixture="$1" key="$2"
  "$VERB" --json "$FIX/$fixture" 2>/dev/null | head -1 \
    | sed -n "s/.*\"${key}\":\"\([^\"]*\)\".*/\1/p"
}

echo "[1] 7種の型に期待した原因が付く"
ck "codex 使用量上限"       "usage_limit"   "$(val_of codex-usage-limit failure_reason)"
ck "codex 不正な UTF-8"     "invalid_input" "$(val_of codex-invalid-utf8 failure_reason)"
ck "codex 環境（信頼済み）"  "environment"   "$(val_of codex-untrusted-dir failure_reason)"
ck "claude 上限（旧経路）"   "usage_limit"   "$(val_of claude-session-limit-legacy failure_reason)"
ck "claude 環境（書けない）" "environment"   "$(val_of claude-not-permitted failure_reason)"
ck "codex 時間切れ"         "unknown"       "$(val_of codex-timeout-busy failure_reason)"
ck "cursor 無言の空返し"    "unknown"       "$(val_of cursor-timeout-silent failure_reason)"

echo "[2] U1: 分けられない形に usage_limit と書かない"
ck "claude 無言の空返し = unknown" "unknown" "$(val_of claude-timeout-silent failure_reason)"
ck "証拠も none"                   "none"    "$(val_of claude-timeout-silent failure_evidence)"

echo "[3] 通信断は断定しないが証拠は残す"
ck "claude 通信断 = unknown"        "unknown"                "$(val_of claude-api-error failure_reason)"
ck "証拠は api-error"               "claude-body:api-error"  "$(val_of claude-api-error failure_evidence)"

echo "[4] N1: 文言が散文にエコーされているだけのものを故障と読まない"
# この fixture は exit 124（非ゼロ）で、故障の文言がファイルに実在する。
ckc "fixture に文言が実在する" "$(cat "$FIX/codex-echoed-phrase/codex-stderr.txt")" "invalid UTF-8 was detected"
ck  "それでも unknown"          "unknown" "$(val_of codex-echoed-phrase failure_reason)"
ck  "exit も非ゼロのまま"       "124"     "$(val_of codex-echoed-phrase exit_code)"

echo "[5] N2: exit 0 のレーンにはシグネチャを当てない"
ck "回答が文言を引用しただけ = none" "none" "$(val_of success-quoting-limit-phrase failure_reason)"
ck "証拠も none"                     "none" "$(val_of success-quoting-limit-phrase failure_evidence)"

echo "[6] D1: 「不在」と「空」を畳まない"
ck "旧経路は raw.json が不在"   "absent"  "$(val_of claude-session-limit-legacy raw_state)"
ck "新経路は raw.json が空で実在" "empty" "$(val_of claude-timeout-silent raw_state)"
ck "版の目印（旧）" "claude-raw-absent,limit-not-recorded"  "$(val_of claude-session-limit-legacy era_markers)"
ck "版の目印（新）" "claude-raw-present,limit-not-recorded" "$(val_of claude-timeout-silent era_markers)"

echo "[7] so-compare 自身の版は meta に無いので、無いと書く"
ck "so_compare_version" "unavailable:not-recorded" "$(val_of codex-usage-limit so_compare_version)"

echo "[8] E1: レーンの記録が無いときに成功に化かさない"
mkdir -p "$_TMP/empty-dir"
OUT="$("$VERB" "$_TMP/empty-dir" 2>&1)"; RC=$?
ck  "exit 2" "2" "$RC"
ckc "理由を stderr に出す" "$OUT" "レーンの記録が1件も見つかりませんでした"

echo "[9] 引数なし・不明オプションは usage エラー"
"$VERB" >/dev/null 2>&1; ck "引数なし = exit 2" "2" "$?"
"$VERB" --bogus >/dev/null 2>&1; ck "不明オプション = exit 2" "2" "$?"
"$VERB" --help >/dev/null 2>&1; ck "--help = exit 0" "0" "$?"

echo "[10] --summary は層別の件数を出す"
OUT="$("$VERB" --summary "$FIX"/*/ 2>/dev/null)"
ckc "見出しがある" "$OUT" "ERA_MARKERS"
ckc "合計が出る"   "$OUT" "合計レーン:"

echo "[11] so-compare を触っていない（配布物を触らない契約）"
if [[ -f "$SCRIPT_DIR/../../../scripts/so-compare.sh" ]]; then
  ncc "verb が so-compare.sh を書かない" "$(cat "$VERB")" "so-compare.sh"
else
  echo "  SKIP: so-compare.sh not found from test dir"
fi

echo "[12] gate 4 の指摘1: 閾値の環境変数からコマンドが走らない"
# bash の (( )) は中の配列添字を再展開するので、未検証の値を入れると任意のコマンドが走る。
SENTINEL="$_TMP/pwned"
OUT="$(OE_LANE_EXPLAIN_SMALL_BYTES="DIRS[\$(touch '$SENTINEL')0]" "$VERB" "$FIX/claude-not-permitted" 2>&1)"; RC=$?
ck  "不正な閾値 = exit 2" "2" "$RC"
ckc "理由を出す" "$OUT" "の整数で指定してください"
if [[ -e "$SENTINEL" ]]; then echo "  FAIL: コマンドが実行された（read-only 契約が破れている）"; FAIL=$((FAIL+1));
else echo "  PASS: コマンドは実行されていない"; PASS=$((PASS+1)); fi
OUT="$(OE_LANE_EXPLAIN_TAIL_LINES='abc' "$VERB" "$FIX/claude-not-permitted" 2>&1)"; RC=$?
ck "非数値の窓 = exit 2" "2" "$RC"
# 正当な値は今までどおり通る（陽性対照）
OE_LANE_EXPLAIN_SMALL_BYTES=4096 OE_LANE_EXPLAIN_TAIL_LINES=50 "$VERB" "$FIX/claude-not-permitted" >/dev/null 2>&1
ck "正当な閾値は通る" "0" "$?"

echo "[13] gate 4 の指摘2: 読めなかった記録を普通のレーンとして数えない"
if [[ "$(id -u)" -eq 0 ]]; then
  echo "  SKIP: root では chmod 000 が効かない"
else
  UR="$_TMP/unreadable"
  mkdir -p "$UR"
  cp "$FIX/claude-not-permitted/claude-meta.txt" "$UR/claude-meta.txt"
  cp "$FIX/codex-untrusted-dir/codex-meta.txt"   "$UR/codex-meta.txt"
  cp "$FIX/codex-untrusted-dir/codex-stderr.txt" "$UR/codex-stderr.txt"
  chmod 000 "$UR/claude-meta.txt"
  OUT="$("$VERB" "$UR" 2>&1)"; RC=$?
  chmod 644 "$UR/claude-meta.txt"
  ck  "読めない meta があれば exit 2" "2" "$RC"
  ckc "1件ずつ stderr に出す"          "$OUT" "meta が読めません"
  ckc "件数も出す"                     "$OUT" "観測できなかった対象が"
  ncc "読めない側を行として出さない"    "$OUT" "claude  "
fi
# 中身がレーンの記録でない meta も数えない
BAD="$_TMP/bad-meta"
mkdir -p "$BAD"
printf 'これは meta ではありません\n' > "$BAD/codex-meta.txt"
OUT="$("$VERB" "$BAD" 2>&1)"; RC=$?
ck  "壊れた meta = exit 2" "2" "$RC"
ckc "理由を出す" "$OUT" "レーンの記録ではありません"

echo "[14] gate 4 の指摘3: --json が制御文字で壊れない"
WEIRD="$_TMP/$(printf 'dir\twith\ttab')"
mkdir -p "$WEIRD"
cp "$FIX/codex-untrusted-dir/codex-meta.txt"   "$WEIRD/codex-meta.txt"
cp "$FIX/codex-untrusted-dir/codex-stderr.txt" "$WEIRD/codex-stderr.txt"
: > "$WEIRD/codex-stdout.txt"
OUT="$("$VERB" --json "$WEIRD" 2>/dev/null)"
ck  "1 レーン 1 行のまま" "1" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')"
ckc "タブがエスケープされている" "$OUT" 'dir\twith\ttab'
if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$OUT" | jq -e . >/dev/null 2>&1
  ck "JSON として妥当" "0" "$?"
else
  echo "  SKIP: jq が無いので JSON の妥当性は見ない"
fi

echo "[15] gate 4 2周目の指摘: 巨大な閾値で静かに偽陰性にならない"
# 9223372036854775808 は正の整数の形だが bash の算術で負数へ overflow し、
# 既知の environment が unknown へ落ちていた（実装SO が実証）。
OUT="$(OE_LANE_EXPLAIN_SMALL_BYTES=9223372036854775808 "$VERB" "$FIX/claude-not-permitted" 2>&1)"; RC=$?
ck  "桁あふれする値 = exit 2" "2" "$RC"
ckc "理由を出す" "$OUT" "の整数で指定してください"
ck  "既定では今までどおり environment" "environment" "$(val_of claude-not-permitted failure_reason)"

echo "[16] gate 4 2周目の指摘: meta が別レーンや壊れた値でも数えない"
MM="$_TMP/meta-mismatch"; mkdir -p "$MM"
printf 'tool=claude\nattempt_state=finished\nexit_code=1\n' > "$MM/codex-meta.txt"
OUT="$("$VERB" "$MM" 2>&1)"; RC=$?
ck  "codex-meta.txt に tool=claude = exit 2" "2" "$RC"
ckc "理由を出す" "$OUT" "このレーンの記録ではありません"
MG="$_TMP/meta-garbage"; mkdir -p "$MG"
printf 'tool=garbage\n' > "$MG/codex-meta.txt"
"$VERB" "$MG" >/dev/null 2>&1
ck "tool=garbage = exit 2" "2" "$?"
# 古い形式（attempt_state が無い #328 より前の記録）は今までどおり数える（陽性対照）
MO="$_TMP/meta-old"; mkdir -p "$MO"
printf 'tool=codex\nexit_code=1\ntimeout_status=error\nelapsed_seconds=0\n' > "$MO/codex-meta.txt"
: > "$MO/codex-stdout.txt"; : > "$MO/codex-stderr.txt"
"$VERB" "$MO" >/dev/null 2>&1
ck "attempt_state の無い古い meta は数える" "0" "$?"

echo "[17] gate 4 2周目の指摘: 根拠のファイルが読めないものも数えない"
if [[ "$(id -u)" -eq 0 ]]; then
  echo "  SKIP: root では chmod 000 が効かない"
else
  UF="$_TMP/unreadable-stderr"; mkdir -p "$UF"
  cp "$FIX/codex-untrusted-dir/codex-meta.txt"   "$UF/codex-meta.txt"
  cp "$FIX/codex-untrusted-dir/codex-stderr.txt" "$UF/codex-stderr.txt"
  : > "$UF/codex-stdout.txt"
  chmod 000 "$UF/codex-stderr.txt"
  OUT="$("$VERB" "$UF" 2>&1)"; RC=$?
  chmod 644 "$UF/codex-stderr.txt"
  ck  "読めない stderr があれば exit 2" "2" "$RC"
  ckc "理由を出す" "$OUT" "分類の根拠になるファイルが読めないか通常ファイルではありません"
fi

echo "[18] gate 4 2周目の指摘: .result の経路も末尾窓を通る"
RW="$_TMP/raw-window"; mkdir -p "$RW"
printf 'tool=claude\nattempt_state=finished\nexit_code=1\ntimeout_status=error\nelapsed_seconds=9\n' > "$RW/claude-meta.txt"
: > "$RW/claude-stdout.txt"; : > "$RW/claude-stderr.txt"
# 先頭で故障の文言を引用し、その後ろに窓（既定 200 行）を超える本文を置く
{ printf 'You'"'"'ve hit your usage limit — これは引用である\n'
  for i in $(seq 1 250); do printf 'line %s\n' "$i"; done
} > "$_TMP/raw-body.txt"
jq -Rs '{result: .}' "$_TMP/raw-body.txt" > "$RW/claude-raw.json"
OUT="$("$VERB" --json "$RW" 2>/dev/null | head -1 | sed -n 's/.*"failure_reason":"\([^"]*\)".*/\1/p')"
ck "窓の外の引用は当たらない（直接指定）" "unknown" "$OUT"
# 窓の中にあれば当たる（陽性対照）
{ for i in $(seq 1 5); do printf 'line %s\n' "$i"; done
  printf 'You'"'"'ve hit your usage limit — 末尾に出た本物\n'
} > "$_TMP/raw-body2.txt"
jq -Rs '{result: .}' "$_TMP/raw-body2.txt" > "$RW/claude-raw.json"
OUT="$("$VERB" --json "$RW" 2>/dev/null | head -1 | sed -n 's/.*"failure_reason":"\([^"]*\)".*/\1/p')"
ck "窓の中なら当たる（陽性対照）" "usage_limit" "$OUT"

echo "[19] gate 4 3周目の指摘: symlink と特殊ファイルを数えない"
SL="$_TMP/symlink-case"; mkdir -p "$SL"
cp "$FIX/codex-untrusted-dir/codex-meta.txt" "$SL/codex-meta.txt"
: > "$SL/codex-stdout.txt"
printf 'ディレクトリの外にある秘密\n' > "$_TMP/outside-secret.txt"
ln -s "$_TMP/outside-secret.txt" "$SL/codex-stderr.txt"
OUT="$("$VERB" "$SL" 2>&1)"; RC=$?
ck  "symlink の根拠ファイル = exit 2" "2" "$RC"
ncc "外のファイルの中身を読んでいない" "$OUT" "ディレクトリの外にある秘密"
rm -f "$SL/codex-stderr.txt"
# meta 自体が symlink の場合も数えない
MS="$_TMP/symlink-meta"; mkdir -p "$MS"
ln -s "$FIX/codex-untrusted-dir/codex-meta.txt" "$MS/codex-meta.txt"
OUT="$("$VERB" "$MS" 2>&1)"; RC=$?
ck  "symlink の meta = exit 2" "2" "$RC"
ckc "理由を出す" "$OUT" "meta が symlink です"
# FIFO は待たずに落とす（待つとテストごと止まる）
if command -v mkfifo >/dev/null 2>&1; then
  FF="$_TMP/fifo-case"; mkdir -p "$FF"
  cp "$FIX/codex-untrusted-dir/codex-meta.txt" "$FF/codex-meta.txt"
  : > "$FF/codex-stdout.txt"
  mkfifo "$FF/codex-stderr.txt"
  OUT="$( { "$VERB" "$FF" 2>&1; } & BGPID=$!; ( sleep 10; kill -9 "$BGPID" 2>/dev/null ) & WPID=$!; wait "$BGPID"; RC=$?; kill "$WPID" 2>/dev/null; exit "$RC" )"; RC=$?
  ck "FIFO で止まらず exit 2" "2" "$RC"
  rm -f "$FF/codex-stderr.txt"
else
  echo "  SKIP: mkfifo が無い"
fi

echo "[20] gate 4 3周目の指摘: --scan が改行入りの名前で割れない"
SR="$_TMP/scanroot"; mkdir -p "$SR/tmp"
NL="$SR/tmp/$(printf 'so-name\nwith-newline')"
mkdir -p "$NL"
cp "$FIX/codex-untrusted-dir/codex-meta.txt"   "$NL/codex-meta.txt"
cp "$FIX/codex-untrusted-dir/codex-stderr.txt" "$NL/codex-stderr.txt"
: > "$NL/codex-stdout.txt"
OUT="$("$VERB" --json --scan "$SR" 2>&1)"; RC=$?
ck  "改行入りの名前でも exit 0" "0" "$RC"
ck  "1 レーン 1 行のまま"       "1" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')"
ncc "パスが無いという苦情を出さない" "$OUT" "ディレクトリがありません"
if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$OUT" | jq -e . >/dev/null 2>&1
  ck "JSON として妥当" "0" "$?"
fi

echo "[21] gate 4 4周目の指摘: dangling symlink を「不在」と読まない"
DS="$_TMP/dangling"; mkdir -p "$DS"
cp "$FIX/codex-untrusted-dir/codex-meta.txt"   "$DS/codex-meta.txt"
cp "$FIX/codex-untrusted-dir/codex-stderr.txt" "$DS/codex-stderr.txt"
ln -s "$_TMP/does-not-exist-at-all" "$DS/codex-stdout.txt"
OUT="$("$VERB" "$DS" 2>&1)"; RC=$?
ck  "参照先の無い symlink = exit 2" "2" "$RC"
ckc "どのファイルかを stderr に出す" "$OUT" "分類の根拠になるファイルが読めないか通常ファイルではありません"
# meta 自体が dangling symlink の場合も同じ
DM="$_TMP/dangling-meta"; mkdir -p "$DM"
ln -s "$_TMP/nothing-here" "$DM/codex-meta.txt"
OUT="$("$VERB" "$DM" 2>&1)"; RC=$?
ck  "dangling な meta = exit 2" "2" "$RC"
ckc "理由を出す" "$OUT" "meta が symlink です"

echo "[22] gate 4 4周目の指摘: symlink のディレクトリと symlink の tmp を拒否する"
REAL="$_TMP/real-lane-dir"; mkdir -p "$REAL"
cp "$FIX/codex-untrusted-dir/codex-meta.txt"   "$REAL/codex-meta.txt"
cp "$FIX/codex-untrusted-dir/codex-stderr.txt" "$REAL/codex-stderr.txt"
: > "$REAL/codex-stdout.txt"
ln -s "$REAL" "$_TMP/linked-lane-dir"
OUT="$("$VERB" "$_TMP/linked-lane-dir" 2>&1)"; RC=$?
ck  "symlink のディレクトリ = exit 2" "2" "$RC"
ckc "理由を出す" "$OUT" "対象ディレクトリが symlink です"
# 実体を直接渡せば今までどおり通る（陽性対照）
"$VERB" "$REAL" >/dev/null 2>&1
ck "実体のディレクトリは通る" "0" "$?"
# --scan の tmp が symlink なら止める
ER="$_TMP/evilroot"; mkdir -p "$ER" "$_TMP/outside-tmp/so-payload"
cp "$FIX/codex-untrusted-dir/codex-meta.txt" "$_TMP/outside-tmp/so-payload/codex-meta.txt"
ln -s "$_TMP/outside-tmp" "$ER/tmp"
OUT="$("$VERB" --scan "$ER" 2>&1)"; RC=$?
ck  "tmp が symlink = exit 2" "2" "$RC"
ckc "理由を出す" "$OUT" "が symlink です"
ncc "外の so-* を読んでいない" "$OUT" "so-payload"

echo "=== RESULT: pass=$PASS fail=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
