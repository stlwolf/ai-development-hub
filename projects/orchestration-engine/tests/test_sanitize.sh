#!/usr/bin/env bash
# test_sanitize.sh — lib/sanitize.sh:oe_sanitize_conversation の単体テスト（#224）
#
# 検証: tool-call タグ列/box-drawing/制御文字の無害化・truncate・**誤爆しない**
#       （court を含む正常英文/コード・比較演算子の < が壊れない）。
# 実 tmux 不要。jq は実体（fallback 経路は PATH からmasking して別途検証）。
#
# fixture 方針（#224 NEGATIVE KNOWLEDGE）: 制御文字/ESC/box-drawing をソースに**リテラル直書き
# しない**。JSON/jq を壊す & レビュー不能になるため、すべて printf の 8 進エスケープで生成する
#   ESC=\033  US=\037  DEL=\177  box(U+2500 系)=\342\224\200 等
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

# shellcheck source=../lib/sanitize.sh
source "$PROJECT_DIR/lib/sanitize.sh"

PASS=0; FAIL=0
ck() { # <label> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1));
  else echo "  FAIL: $1"; echo "     want=[$2]"; echo "     got =[$3]"; FAIL=$((FAIL+1)); fi
}

echo "[1] tool-call タグ列の neutralize（short/名前空間・open/close）"
ck "invoke short open"       '< invoke name="Bash">'  "$(oe_sanitize_conversation '<invoke name="Bash">')"
ck "invoke ns open"          "$(printf '< %s:invoke>' antml)"  "$(oe_sanitize_conversation "$(printf '<%s:invoke>' antml)")"
ck "function_calls open"     '< function_calls>'      "$(oe_sanitize_conversation '<function_calls>')"
ck "invoke short close"      'x < /invoke> y'         "$(oe_sanitize_conversation 'x </invoke> y')"
ck "antml ns close"          "$(printf 'x < /%s:invoke> y' antml)"  "$(oe_sanitize_conversation "$(printf 'x </%s:invoke> y' antml)")"

echo "[2] 誤爆しない（over-capture 防止）"
ck "plain <div> untouched"   '<div>'                  "$(oe_sanitize_conversation '<div>')"
ck "less-than op untouched"  'a < b and c<d'          "$(oe_sanitize_conversation 'a < b and c<d')"

echo "[3] 行頭孤立 court のみ neutralize（DJ-3・誤爆防止が最重要）"
ck "isolated court"          '[court]'                "$(oe_sanitize_conversation 'court')"
ck "court + trailing ws"     '[court]'                "$(oe_sanitize_conversation 'court   ')"
ck "prose court untouched"   'The court ruled today'  "$(oe_sanitize_conversation 'The court ruled today')"
ck "courthouse untouched"    'courthouse'             "$(oe_sanitize_conversation 'courthouse')"
ck "mid court untouched"     'go to court now'        "$(oe_sanitize_conversation 'go to court now')"
ck "code court untouched"    'const court = 1;'       "$(oe_sanitize_conversation 'const court = 1;')"

echo "[4] box-drawing 除去（U+2500 系: ─ │ ┌ ╮ を printf 8進で生成）"
ck "box removed"             'ab'  "$(oe_sanitize_conversation "$(printf 'a\342\224\200\342\224\202\342\224\214\342\225\256b')")"

echo "[5] 制御文字の除去/無害化（ESC/ANSI/US/CR/DEL を printf 8進で生成）"
ck "ANSI CSI removed"        'ared'  "$(oe_sanitize_conversation "$(printf 'a\033[31mred\033[0m')")"
ck "US -> space"             'a b'   "$(oe_sanitize_conversation "$(printf 'a\037b')")"
ck "CR -> space"             'a b'   "$(oe_sanitize_conversation "$(printf 'a\015b')")"
ck "DEL -> space"            'a b'   "$(oe_sanitize_conversation "$(printf 'a\177b')")"

echo "[6] truncate（codepoint 上限・マルチバイト安全）"
ck "truncate fires"          'abcde…'  "$(OE_SANITIZE_MAX_CP=5 oe_sanitize_conversation 'abcdefghij')"
ck "no truncate under max"   'abc'     "$(OE_SANITIZE_MAX_CP=5 oe_sanitize_conversation 'abc')"
ck "truncate multibyte-safe" "$(printf '\343\201\202%.0s' $(seq 1 5))…" "$(OE_SANITIZE_MAX_CP=5 oe_sanitize_conversation "$(printf '\343\201\202%.0s' $(seq 1 10))")"
ck "max=0 disables truncate" 'abcdefghij' "$(OE_SANITIZE_MAX_CP=0 oe_sanitize_conversation 'abcdefghij')"

echo "[7] 複合（1 入力に複数ハザード）"
ck "combined"                '[court]'  "$(oe_sanitize_conversation 'court')"
ck "tag + box + ctrl"        '< invoke x> b'  "$(oe_sanitize_conversation "$(printf '<invoke x>\342\224\200\037b')")"

echo "[8] jq 不在 fallback（tr で制御文字のみ空白化・タグ/box/court は無処理・best-effort）"
# jq は /usr/bin にも在る（システム jq）ため PATH をシステム dir に絞っても jq が残る。
# tr だけを symlink した専用 dir を唯一の PATH にして「jq 不在・tr あり」を厳密に作る。
_FBBIN="$(mktemp -d)"; ln -s "$(command -v tr)" "$_FBBIN/tr"
# 関数は source 済み。引数は printf(builtin) で先に展開し、関数実行時のみ PATH を絞る
# （command -v jq が $_FBBIN に無く失敗→tr fallback へ）。fresh bash を起こさないので bash 解決不要。
_fbin="$(printf 'a\037<invoke>')"
fb="$(PATH="$_FBBIN" oe_sanitize_conversation "$_fbin")"
rm -rf "$_FBBIN"
# fallback は制御文字（US \037）のみ空白化。タグ <invoke> は無処理で残る（best-effort の明示）。
ck "fallback strips control, tags untouched" 'a <invoke>' "$fb"

echo "[9] 環境値ガード: OE_SANITIZE_MAX_CP 非数値でも tag 無害化を silent bypass しない（実装SO 検出）"
# 非数値だと jq --argjson が失敗し tr fallback（制御文字のみ）へ落ちて tag が素通る回帰を防ぐ。
ck "非数値 abc でも tag 無害化"  '< invoke x>' "$(OE_SANITIZE_MAX_CP=abc oe_sanitize_conversation '<invoke x>')"
ck "空白のみでも tag 無害化"     '< invoke x>' "$(OE_SANITIZE_MAX_CP=' ' oe_sanitize_conversation '<invoke x>')"
ck "空値でも tag 無害化"         '< invoke x>' "$(OE_SANITIZE_MAX_CP='' oe_sanitize_conversation '<invoke x>')"
# 負数は無効化(disable)でなく coerce（jq が走り tag 無害化される＝silent bypass しない・Copilot 指摘）
ck "負数は coerce・無効化しない"  '< invoke x>' "$(OE_SANITIZE_MAX_CP=-5 oe_sanitize_conversation '<invoke x>')"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
