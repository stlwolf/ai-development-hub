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

echo "[10] gate 4 の指摘: 未知オプションも 4 に寄せる"
run_reject "$SO" --bogus -o "$_TMP/o20" "問い"
ck  "未知オプション = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:unknown-option"

echo "[11] gate 4 の指摘: -c がファイルを1件も取らない形を素通りさせない"
run_reject "$SO" "問い" -c --codex-only -o "$_TMP/o21"
ck  "-c の後ろがオプション = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:missing-argument -c"

echo "[12] gate 4 の指摘: --prev はアクティブなレーンだけを見る"
PSUB="$_TMP/prev-subset"; mkdir -p "$PSUB"
printf '\377\376\377\376\n' > "$PSUB/codex-stdout.txt"
printf '前回の claude の回答\n' > "$PSUB/claude-stdout.txt"
STUB2="$_TMP/stub2"; mkdir -p "$STUB2"
# so-compare は jq があると claude を --output-format json で走らせ、.result から本文を取る。
# 素のテキストを返すスタブでは抽出に失敗して success_empty（部分成功）になるので JSON を返す。
printf '#!/bin/sh\nprintf %%s "{\\"result\\":\\"VERDICT: survived\\"}"\nexit 0\n' > "$STUB2/claude-safe"; chmod +x "$STUB2/claude-safe"
OUT="$(PATH="$STUB2:$PATH" "$SO" --claude-only -o "$_TMP/o22" --prev "$PSUB" "問い" 2>&1)"; RC=$?
ck  "--claude-only は codex の壊れた前回出力で落ちない" "0" "$RC"
run_reject "$SO" --codex-only -o "$_TMP/o23" --prev "$PSUB" "問い"
ck  "--codex-only なら拒否する" "4" "$RC"; ckc "型" "$OUT" "invalid:not-utf8 --prev"

echo "[13] gate 4 の指摘: 自分の切り詰めが原因の全損を拒否しない"
PJP="$_TMP/prev-jp"; mkdir -p "$PJP"
printf '日本語で始まる妥当な前回出力\n' > "$PJP/codex-stdout.txt"
OUT="$(PATH="$STUB:$PATH" PREV_MAX_BYTES=1 "$SO" --codex-only -o "$_TMP/o24" --prev "$PJP" "問い" 2>&1)"; RC=$?
ck  "PREV_MAX_BYTES=1 でも拒否しない" "0" "$RC"
ckc "代わりに警告で伝える" "$OUT" "PREV_MAX_BYTES"

echo "[14] gate 4 の指摘: oe-review も拒否を「反証」と取り違えない"
REVIEW="$SCRIPT_DIR/../bin/oe-review"
if [[ -x "$REVIEW" ]]; then
  RG="$_TMP/reviewrepo"; mkdir -p "$RG"
  ( cd "$RG" && git init -q . && git config user.email t@e && git config user.name t \
    && printf 'a\n' > a.txt && git add a.txt && git commit -qm "test: seed" \
    && git branch -M master && printf 'b\n' >> a.txt && git add a.txt && git commit -qm "test: change" ) >/dev/null 2>&1
  OUT="$(cd "$RG" && OE_REVIEW_SO_COMPARE="$REJ/so-compare" "$REVIEW" --lanes 2 --base master~1 2>&1)"; RC=$?
  ck  "oe-review は refuted(3) にしない" "2" "$RC"
  ckc "理由を出す" "$OUT" "入力を拒否しました"
else
  echo "  SKIP: oe-review が見つからない"
fi

echo "[15] gate 4 2周目の指摘: -o の出力先を先に見る"
run_reject "$SO" --codex-only -o "$OK_CTX" "問い"
ck  "通常ファイルを -o に渡す = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-a-directory -o"
# 正常な -o は今までどおり（陽性対照）
OUT="$(PATH="$STUB:$PATH" "$SO" --codex-only -o "$_TMP/o30/nested" "問い" 2>&1)"; RC=$?
ck "作れる -o は通る" "0" "$RC"

echo "[16] gate 4 2周目の指摘: NUL を含む入力を読む前に弾く"
# NUL は iconv では弾けない（UTF-8 として妥当なバイト）が、bash のコマンド置換が黙って落とす。
NULF="$_TMP/with-nul.md"
printf 'head\000tail\n' > "$NULF"
run_reject "$SO" --codex-only -o "$_TMP/o31" -f "$NULF"
ck  "-f に NUL = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:contains-nul -f"
run_reject "$SO" --codex-only -o "$_TMP/o32" "問い" -c "$NULF"
ck  "-c に NUL = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:contains-nul -c"
PNUL="$_TMP/prev-nul"; mkdir -p "$PNUL"
printf 'head\000tail\n' > "$PNUL/codex-stdout.txt"
run_reject "$SO" --codex-only -o "$_TMP/o33" --prev "$PNUL" "問い"
ck  "--prev に NUL = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:contains-nul --prev"
# NUL を含まない妥当なファイルは通る（陽性対照）
OUT="$(PATH="$STUB:$PATH" "$SO" --codex-only -o "$_TMP/o34" "問い" -c "$OK_CTX" 2>&1)"; RC=$?
ck "NUL なしの -c は通る" "0" "$RC"

echo "[17] gate 4 2周目の指摘: 検証器の前提確認は UTF-8 検査より前に置く"
# **構造の検査である。** 検証器を PATH から外す実行は、so-compare が使う他のコマンドまで
# 巻き添えにするので、ここでは順序だけを見る。順序が逆だと不在時に
# command-not-found が invalid:not-utf8 に化け、妥当なファイルを拒否する。
GUARD_LINE="$(grep -n 'unavailable:perl' "$SO" | head -1 | cut -d: -f1)"
# shellcheck disable=SC2016  # 展開させずにソース中の文字列そのものを探している
CHECK_LINE="$(grep -n 'is_valid_utf8_file "$_cf"' "$SO" | head -1 | cut -d: -f1)"
if [[ -n "$GUARD_LINE" && -n "$CHECK_LINE" ]] && (( GUARD_LINE < CHECK_LINE )); then
  echo "  PASS: iconv の前提確認が -c の UTF-8 検査より前にある（${GUARD_LINE} < ${CHECK_LINE}）"; PASS=$((PASS+1))
else
  echo "  FAIL: 順序が逆（guard=${GUARD_LINE} check=${CHECK_LINE}）"; FAIL=$((FAIL+1))
fi

echo "[18] gate 4 3周目の指摘: stdin の NUL も読む前に弾く"
OUT="$(printf 'head\000tail\n' | "$SO" --codex-only -o "$_TMP/o40" - 2>&1)"; RC=$?
ck  "stdin に NUL = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:contains-nul stdin"
# NUL の無い stdin は今までどおり通る（陽性対照）
OUT="$(printf '問い\n' | PATH="$STUB:$PATH" "$SO" --codex-only -o "$_TMP/o41" - 2>&1)"; RC=$?
ck  "NUL なしの stdin は通る" "0" "$RC"
ckc "本文が保存されている" "$(cat "$_TMP/o41/prompt.txt" 2>/dev/null)" "問い"

echo "[19] gate 4 3周目の指摘: 受理した数値が算術で意味を変えない"
# 先頭ゼロは bash の算術で8進数として読まれ、head と算術で値が食い違う。
run_reject env PREV_MAX_BYTES=08 "$SO" --codex-only -o "$_TMP/o42" "問い"
ck  "先頭ゼロ = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-a-number PREV_MAX_BYTES"
run_reject env PREV_MAX_BYTES=010 "$SO" --codex-only -o "$_TMP/o43" "問い"
ck  "010 も拒否" "4" "$RC"
# 桁あふれする値も拒否する（受理すると算術で負数になる）
run_reject env PREV_MAX_BYTES=9223372036854775808 "$SO" --codex-only -o "$_TMP/o44" "問い"
ck  "桁あふれ = exit 4" "4" "$RC"
run_reject env SO_TIMEOUT=08 "$SO" --codex-only -o "$_TMP/o45" "問い"
ck  "SO_TIMEOUT の先頭ゼロ = exit 4" "4" "$RC"
run_reject env SO_TIMEOUT=9223372036854775808 "$SO" --codex-only -o "$_TMP/o46" "問い"
ck  "SO_TIMEOUT の桁あふれ = exit 4" "4" "$RC"
# 正当な値は通る（陽性対照）
OUT="$(PATH="$STUB:$PATH" PREV_MAX_BYTES=4000 SO_TIMEOUT=120 "$SO" --codex-only -o "$_TMP/o47" "問い" 2>&1)"; RC=$?
ck "正当な数値は通る" "0" "$RC"

echo "[20] 自分の観点で洗って見つけた分: meta の行を壊す値を渡さない"
# meta は 1 行 1 組の key=value。モデル名は素の値のまま model_requested= に書かれるので、
# 改行が入ると行が割れて**偽のキーが混入する**（実機で再現した）。
NLMODEL="$(printf 'a\nb=c')"
run_reject env SO_CURSOR_MODEL="$NLMODEL" "$SO" --cursor-only -o "$_TMP/o50" "問い"
ck  "改行入りのモデル名 = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:control-character CURSOR_MODEL"
run_reject env SO_CLAUDE_EFFORT="$(printf 'high\nx=y')" "$SO" --claude-only -o "$_TMP/o51" "問い"
ck  "改行入りのエフォート = exit 4" "4" "$RC"
run_reject "$SO" --codex-only -s "$(printf 'read-only\nz=1')" -o "$_TMP/o52" "問い"
ck  "改行入りの sandbox モード = exit 4" "4" "$RC"
# 正当なモデル名は通る（陽性対照）
OUT="$(PATH="$STUB:$PATH" SO_CODEX_MODEL="gpt-5.6-sol" "$SO" --codex-only -o "$_TMP/o53" "問い" 2>&1)"; RC=$?
ck  "正当なモデル名は通る" "0" "$RC"
ckc "meta にそのまま入る" "$(cat "$_TMP/o53/codex-meta.txt" 2>/dev/null)" "model_requested=gpt-5.6-sol"
# meta の行が壊れていないこと
BADLINES="$(grep -vcE '^[A-Za-z_][A-Za-z0-9_]*=' "$_TMP/o53/codex-meta.txt" 2>/dev/null || true)"
ck  "meta に key=value でない行が無い" "0" "$BADLINES"

echo "[21] gate 4 4周目の指摘: 回すレーンの値だけを見る"
# --codex-only なのに SO_CURSOR_MODEL の改行で落ちてはいけない（陽性対照）
NLMODEL2="$(printf 'a\nb=c')"
OUT="$(PATH="$STUB:$PATH" SO_CURSOR_MODEL="$NLMODEL2" "$SO" --codex-only -o "$_TMP/o60" "問い" 2>&1)"; RC=$?
ck  "--codex-only は cursor の壊れた値で落ちない" "0" "$RC"
# cursor を回すなら拒否する
run_reject env SO_CURSOR_MODEL="$NLMODEL2" "$SO" --cursor-only -o "$_TMP/o61" "問い"
ck  "--cursor-only なら拒否する" "4" "$RC"

echo "[22] gate 4 4周目の指摘: 不正な UTF-8 のモデル名を弾く"
run_reject env SO_CODEX_MODEL="$(printf 'model\377x')" "$SO" --codex-only -o "$_TMP/o62" "問い"
ck  "不正な UTF-8 のモデル名 = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-utf8 CODEX_MODEL"

echo "[23] gate 4 4周目の指摘: 列挙している値は列挙で見る"
run_reject "$SO" --claude-only --claude-effort bogus -o "$_TMP/o63" "問い"
ck  "未知のエフォート = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:bad-value --claude-effort"
OUT="$(PATH="$STUB2:$PATH" "$SO" --claude-only --claude-effort high -o "$_TMP/o64" "問い" 2>&1)"; RC=$?
ck  "正当なエフォートは通る" "0" "$RC"

echo "[24] gate 4 4周目の指摘: --prev のファイルも通常ファイル・可読を見る"
if [[ "$(id -u)" -ne 0 ]]; then
  PUR="$_TMP/prev-unreadable"; mkdir -p "$PUR"
  printf '前回の回答\n' > "$PUR/codex-stdout.txt"; chmod 000 "$PUR/codex-stdout.txt"
  run_reject "$SO" --codex-only -o "$_TMP/o65" --prev "$PUR" "問い"
  chmod 644 "$PUR/codex-stdout.txt"
  ck  "読めない前回出力 = exit 4" "4" "$RC"; ckc "型" "$OUT" "invalid:not-readable --prev"
else
  echo "  SKIP: root では chmod 000 が効かない"
fi

echo "[25] gate 4 4周目の指摘: プロンプトが -n でも空にならない"
OUT="$(PATH="$STUB:$PATH" "$SO" --codex-only -o "$_TMP/o66" -- -n 2>&1)"; RC=$?
if [[ "$RC" == "0" ]]; then
  SAVED="$(cat "$_TMP/o66/prompt.txt" 2>/dev/null)"
  ck "プロンプト -n が空ファイルにならない" "-n" "$SAVED"
else
  # -- を区切りとして扱わない parser なので、この形は拒否される。空ファイルを作らないことだけ見る。
  OUT="$(printf -- '-n\n' | PATH="$STUB:$PATH" "$SO" --codex-only -o "$_TMP/o67" - 2>&1)"; RC=$?
  ck  "stdin から -n を渡しても通る" "0" "$RC"
  ck  "空ファイルにならない" "-n" "$(cat "$_TMP/o67/prompt.txt" 2>/dev/null)"
fi

echo "[26] 実運用の呼び方が全部通る（陽性対照の組・統括指示）"
# **これまで4回、拒否を足すたびに正当な入力を落とす形を作った。**
# （PREV_MAX_BYTES=1 の全損誤判定 / 非アクティブなレーンの --prev / iconv の順序 /
#   回さないレーンの設定値）。**通す側を測る組をここに固定する。**
#
# 形は oe-refute / oe-review が実際に渡すものに揃える:
#   so-compare --with <providers> -w <workspace> -f <prompt file> -o <out dir>
PC="$_TMP/positive"; mkdir -p "$PC/ws" "$PC/prev"
ALLSTUB="$_TMP/allstub"; mkdir -p "$ALLSTUB"
printf '#!/bin/sh\necho "VERDICT: survived"\necho "REASON: stub"\nexit 0\n' > "$ALLSTUB/codex"
printf '#!/bin/sh\necho "VERDICT: survived"\nexit 0\n' > "$ALLSTUB/agent"
printf '#!/bin/sh\nprintf %%s "{\\"result\\":\\"VERDICT: survived\\"}"\nexit 0\n' > "$ALLSTUB/claude-safe"
chmod +x "$ALLSTUB/codex" "$ALLSTUB/agent" "$ALLSTUB/claude-safe"

# レビュー級の大きさのプロンプト（日本語を含む・複数行）
{ printf '# 設計の妥当性を検証してください\n\n'
  for i in $(seq 1 60); do printf -- '- 観点 %s: 日本語を含む行である。境界のバイトを踏ませる。\n' "$i"; done
} > "$PC/prompt.md"
# 実サイズの前回出力（既定の PREV_MAX_BYTES=4000 を超えるので切り詰めが起きる）
for t in codex claude cursor; do
  { for i in $(seq 1 200); do printf -- '前回の %s の回答の %s 行目である。日本語で書かれている。\n' "$t" "$i"; done
  } > "$PC/prev/${t}-stdout.txt"
done
printf 'ワークスペースのファイル\n' > "$PC/ws/note.md"

pc_run() {
  local label="$1"; shift
  local out rc
  out="$(PATH="$ALLSTUB:$PATH" "$@" 2>&1)"; rc=$?
  ck "$label" "0" "$rc"
  if [[ "$rc" != "0" ]]; then printf '%s\n' "$out" | tail -3 | sed 's/^/      /'; fi
}

# 1) oe-refute / oe-review が渡す形そのまま（3レーン）
pc_run "oe-refute 相当（--with codex,claude,cursor）" \
  env SO_TIMEOUT=120 "$SO" --with codex,claude,cursor -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/out1"
# 2) 実装SO の既定（2レーン）
pc_run "oe-review 相当（--with codex,cursor）" \
  env SO_TIMEOUT=120 "$SO" --with codex,cursor -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/out2"
# 3) 非アクティブなレーンの設定が入っていても通る（モデル・エフォート・**タイムアウト**）
pc_run "非アクティブなレーンの設定つき" \
  env SO_TIMEOUT=120 SO_CLAUDE_EFFORT=bogus SO_CLAUDE_MODEL="$(printf 'a\nb=c')" \
      SO_CLAUDE_TIMEOUT=bogus \
      "$SO" --with codex,cursor -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/out3"
# 3b) 逆向き: claude だけ回すなら codex/cursor 用のタイムアウトが不正でも通る
pc_run "逆向き（--claude-only + 不正な SO_TIMEOUT）" \
  env SO_TIMEOUT=bogus SO_CLAUDE_TIMEOUT=120 \
      "$SO" --claude-only -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/out3b"
# 3c) 回すレーンのタイムアウトが不正なら拒否する（陰性側）
run_reject env SO_TIMEOUT=bogus "$SO" --codex-only -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/out3c"
ck  "回すレーンのタイムアウトが不正 = exit 4" "4" "$RC"
ckc "型" "$OUT" "invalid:not-a-number SO_TIMEOUT"
# 4) 実サイズの --prev つき（既定の上限で切り詰めが起きる）
pc_run "実サイズの --prev つき" \
  env SO_TIMEOUT=120 "$SO" --with codex,cursor -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/out4" --prev "$PC/prev"
# 5) 既定のモデル名のまま（cursor の既定は composer-2.5）
pc_run "既定のモデル名のまま（--cursor-only）" \
  env SO_TIMEOUT=120 "$SO" --cursor-only -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/out5"
ckc "cursor の既定が meta に入る" "$(cat "$PC/out5/cursor-meta.txt" 2>/dev/null)" "model_requested=composer-2.5"
# 6) 明示したモデル名も通る
pc_run "モデルを明示（--cursor-model auto）" \
  env SO_TIMEOUT=120 "$SO" --cursor-only --cursor-model auto -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/out6"
# 7) 位置引数のプロンプト（-f を使わない形）
pc_run "位置引数のプロンプト" \
  env SO_TIMEOUT=120 "$SO" --codex-only -w "$PC/ws" -o "$PC/out7" "この設計を検証してください。"
# 8) 出力先を省略（既定の tmp/so-... を使う）
( cd "$PC" && PATH="$ALLSTUB:$PATH" SO_TIMEOUT=120 "$SO" --codex-only "問い" >/dev/null 2>&1 )
ck "出力先を省略しても通る" "0" "$?"

# どの実行でも meta の行が壊れていないこと
BAD_TOTAL=0
for f in "$PC"/out*/**-meta.txt "$PC"/out*/*-meta.txt; do
  [[ -f "$f" ]] || continue
  n="$(grep -vcE '^[A-Za-z_][A-Za-z0-9_]*=' "$f" || true)"
  BAD_TOTAL=$(( BAD_TOTAL + n ))
done
ck "全 meta に key=value でない行が無い" "0" "$BAD_TOTAL"

echo "[27] 性質: 回さないレーンの設定は、どんな値でも exit に影響しない"
# **個別の検査を並べるのではなく、非アクティブ側に不正値を全部入れて通ることを見る。**
# この癖（回さないレーンの入力まで見て落とす）は個別修正で7回潰しても別の場所で出た。
# 位置で構造的に塞いだうえで、**性質そのもの**をここで固定する。
NL="$(printf 'a\nb=c')"
pc_run "codex を回さない（codex 用の値は全部不正）" \
  env SO_CODEX_MODEL="$NL" SO_TIMEOUT=99999999999999999999 \
      SO_CLAUDE_TIMEOUT=120 \
      "$SO" --claude-only -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/p1"
pc_run "claude を回さない（claude 用の値は全部不正）" \
  env SO_CLAUDE_MODEL="$NL" SO_CLAUDE_EFFORT=bogus SO_CLAUDE_TIMEOUT=08 \
      SO_TIMEOUT=120 \
      "$SO" --with codex,cursor -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/p2"
pc_run "cursor を回さない（cursor 用の値は全部不正）" \
  env SO_CURSOR_MODEL="$NL" SO_TIMEOUT=120 SO_CLAUDE_TIMEOUT=120 \
      "$SO" --with codex,claude -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/p3"
pc_run "cursor だけ回す（他レーンの値は全部不正）" \
  env SO_CODEX_MODEL="$NL" SO_CLAUDE_MODEL="$NL" SO_CLAUDE_EFFORT=bogus \
      SO_CLAUDE_TIMEOUT=9223372036854775808 SO_TIMEOUT=120 \
      "$SO" --cursor-only -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/p4"
# 裏返し: 回すレーンの値が不正なら必ず落ちる（性質の対）
for pair in "codex:SO_CODEX_MODEL" "cursor:SO_CURSOR_MODEL"; do
  lane="${pair%%:*}"; var="${pair##*:}"
  OUT="$(env "$var=$NL" SO_TIMEOUT=120 "$SO" "--${lane}-only" -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/p5-$lane" 2>&1)"; RC=$?
  ck "${lane} を回すなら ${var} の不正で落ちる" "4" "$RC"
done
OUT="$(env SO_CLAUDE_EFFORT=bogus SO_CLAUDE_TIMEOUT=120 "$SO" --claude-only -w "$PC/ws" -f "$PC/prompt.md" -o "$PC/p6" 2>&1)"; RC=$?
ck "claude を回すなら SO_CLAUDE_EFFORT の不正で落ちる" "4" "$RC"

echo "=== RESULT: pass=$PASS fail=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
