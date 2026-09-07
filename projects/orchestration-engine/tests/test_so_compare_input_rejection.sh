#!/usr/bin/env bash
# test_so_compare_input_rejection.sh — so-compare の入力拒否の契約（#344 / #303 の I-3）
#
# **終了コードは走らせて確かめる。** 「この経路で N を返す」と書いてから外した前例があるので、
# 経路ごとに実際に起動して観測する（knowledge item 01KZRTSJ2VP8BZR0MF7QZRNYH7）。
#
# 固定する契約:
#   - 入力を拒否したときは **exit 4**（レーンを1本も起動していない）。
#   - **3 は使わない。** oe-refute / oe-review が反証に割り当てているため、入力の不備が
#     「設計が反証された」として上位に届いてしまう。
#   - 理由は stderr に型で出る（invalid:<種別> / unavailable:<コマンド>）。
#   - **正当な入力は今までどおり通る**（陽性対照）。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SO="$SCRIPT_DIR/../../../scripts/so-compare.sh"
REFUTE="$SCRIPT_DIR/../bin/oe-refute"
[[ -x "$SO" ]] || { echo "FAIL: so-compare.sh not found: $SO"; exit 1; }

_TMP="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$_TMP"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }

# 拒否経路を1つ走らせ、exit code と stderr を返す
run_reject() {
  OUT="$("$@" 2>&1)"; RC=$?
}

OK_CTX="$_TMP/ok-context.md"
printf 'これは妥当な UTF-8 のコンテキストである。\n' > "$OK_CTX"
BAD_UTF8="$_TMP/bad-utf8.md"
printf 'head \377\376 tail\n' > "$BAD_UTF8"
EMPTY_CTX="$_TMP/empty.md"
: > "$EMPTY_CTX"

echo "[1] -f の経路"
run_reject "$SO" -f "$_TMP/does-not-exist.txt" --codex-only -o "$_TMP/o1"
ck  "不在 = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-found -f"
run_reject "$SO" -f "$_TMP" --codex-only -o "$_TMP/o2"
ck  "ディレクトリ = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-a-file -f"

echo "[2] -c の経路"
run_reject "$SO" --codex-only -o "$_TMP/o3" "問い" -c "$_TMP/nope.md"
ck  "不在 = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-found -c"
run_reject "$SO" --codex-only -o "$_TMP/o4" "問い" -c "$EMPTY_CTX"
ck  "空 = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:empty -c"
run_reject "$SO" --codex-only -o "$_TMP/o5" "問い" -c "$BAD_UTF8"
ck  "非 UTF-8 = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-utf8 -c"

echo "[3] -c が問いを食う形を名指しする"
run_reject "$SO" --codex-only -o "$_TMP/o6" -c "$OK_CTX" "問い"
ck  "exit 4" "4" "$RC"
ckc "型" "$OUT" "invalid:ambiguous-args -c"
ncc_msg="プロンプトが指定されていません"
if printf '%s' "$OUT" | grep -qF -- "$ncc_msg"; then
  echo "  FAIL: 原因の分からないメッセージで終わっている"; FAIL=$((FAIL+1))
else
  echo "  PASS: なぜそうなったかを名指ししている"; PASS=$((PASS+1))
fi

echo "[4] -w の経路"
run_reject "$SO" --codex-only -o "$_TMP/o7" -w "$_TMP/no-such-dir" "問い"
ck  "不在 = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-found -w"
run_reject "$SO" --codex-only -o "$_TMP/o8" -w "$OK_CTX" "問い"
ck  "ファイルを渡した = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-a-directory -w"

echo "[5] 数値の環境変数"
run_reject env SO_TIMEOUT=abc "$SO" --codex-only -o "$_TMP/o9" "問い"
ck  "SO_TIMEOUT = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-a-number SO_TIMEOUT"
run_reject env PREV_MAX_BYTES=abc "$SO" --codex-only -o "$_TMP/o10" "問い"
ck  "PREV_MAX_BYTES = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-a-number PREV_MAX_BYTES"

echo "[6] 呼び方の誤り"
run_reject "$SO" --codex-only -o "$_TMP/o11"
ck  "プロンプト無し = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:empty プロンプト"
run_reject "$SO" --with "codex,bogus" -o "$_TMP/o12" "問い"
ck  "未知のプロバイダ = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:bad-value --with"
run_reject "$SO" --with -o "$_TMP/o13" "問い"
ck  "--with の引数欠落 = exit 4" "4" "$RC"

echo "[7] --prev の全損は拒否に倒す"
PREV="$_TMP/prev-broken"; mkdir -p "$PREV"
printf '\377\376\377\376\n' > "$PREV/codex-stdout.txt"
run_reject "$SO" --codex-only -o "$_TMP/o14" --prev "$PREV" "問い"
ck  "全損 = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-utf8 --prev"

echo "[8] 陽性対照: 正当な入力は今までどおり通る"
# codex をスタブに差し替える（実際の CLI を叩かない）
STUB="$_TMP/stub"; mkdir -p "$STUB"
cat > "$STUB/codex" <<'STUBEOF'
#!/bin/sh
echo "VERDICT: survived"
echo "REASON: stub"
exit 0
STUBEOF
chmod +x "$STUB/codex"
OUT="$(PATH="$STUB:$PATH" "$SO" --codex-only -o "$_TMP/ok1" "問い" 2>&1)"; RC=$?
ck "プロンプトだけ = exit 0" "0" "$RC"
OUT="$(PATH="$STUB:$PATH" "$SO" --codex-only -o "$_TMP/ok2" "問い" -c "$OK_CTX" 2>&1)"; RC=$?
ck "妥当な -c つき = exit 0" "0" "$RC"
OUT="$(PATH="$STUB:$PATH" "$SO" --codex-only -o "$_TMP/ok3" -w "$_TMP" "問い" 2>&1)"; RC=$?
ck "実在する -w つき = exit 0" "0" "$RC"
ckc "本文が保存されている" "$(cat "$_TMP/ok3/prompt.txt" 2>/dev/null)" "問い"

echo "[9] 消費者が拒否を「反証」と取り違えない"
if [[ -x "$REFUTE" ]]; then
  REJ="$_TMP/rejstub"; mkdir -p "$REJ"
  printf '#!/bin/sh\nexit 4\n' > "$REJ/so-compare"; chmod +x "$REJ/so-compare"
  CLAIM="$_TMP/claim.md"
  printf -- '---\nclaim: "テスト用の主張"\nrubric: exploration\n---\n\n本文\n' > "$CLAIM"
  OUT="$(cd "$_TMP" && git init -q . 2>/dev/null; OE_REFUTE_SO_COMPARE="$REJ/so-compare" "$REFUTE" --claim "$CLAIM" --lanes 2 2>&1)"; RC=$?
  ck  "oe-refute は refuted(3) にしない" "2" "$RC"
  ckc "理由を出す" "$OUT" "入力を拒否しました"
else
  echo "  SKIP: oe-refute が見つからない"
fi

echo "=== RESULT: pass=$PASS fail=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
