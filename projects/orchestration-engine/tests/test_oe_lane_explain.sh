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
ckc "理由を出す" "$OUT" "正の整数で指定してください"
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

echo "=== RESULT: pass=$PASS fail=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
