#!/usr/bin/env bash
# test_oe_refute.sh — oe-refute（#183 / Stage A）の frontmatter パース / body 不透明渡し /
#                     conservative 集約 / exit code / JSON 形 / output_dir / --rubric 上書き /
#                     --lanes 不正値 / frontmatter 欠落 を検証する。
#
# 実 so-compare / codex / cursor / claude は絶対に起動しない（遅い・課金）。
# so-compare を PATH 先頭スタブで mock し、-o <dir> に偽の <provider>-stdout.txt を書く。
# スタブの挙動は env var で制御する:
#   SO_FAKE_CODEX_VERDICT / SO_FAKE_CURSOR_VERDICT / SO_FAKE_CLAUDE_VERDICT
#     = refuted | survived | none（VERDICT 行なし）| empty（出力ファイルを空にする）。既定 survived。
#       survived-suffix（VERDICT: survived の後に "(not refuted)" 付帯テキスト・Fix 1 検証用）。
#       echo-example（VERDICT 行の後にプロンプト例プレースホルダをエコー・Fix 3 検証用）。
#   SO_FAKE_RC = スタブ so-compare の exit code（既定 0）。
#   SO_FAKE_PROMPT_COPY = 指定パスへ -f のプロンプト内容をコピー（body 不透明渡しの検証用）。
#   SO_FAKE_W_COPY = 指定パスへ受け取った -w 引数を書き出す（Fix 4・git root 検証用）。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

_TMP_DIR="$(mktemp -d)"
mkdir -p "$_TMP_DIR/pathbin" "$_TMP_DIR/docs" "$_TMP_DIR/audit"

# Fix #2 で oe-refute は output_dir を repo 相対 tmp/oe-refute-<ULID>/ に作る（削除しない＝
# evidence anchor）。テストはこの実 repo の tmp/ 配下に dir を作るため掃除が要る。
# mock so-compare が受け取る -o（= oe-refute が作った実 output_dir）を 1 run 分すべて
# OE_REFUTE_DIRS_LOG に追記し、EXIT でその dir のみを削除する（gitignore 済の throwaway 成果物。
# 時刻ベースの -newer は秒粒度衝突で取りこぼすため、生成した実パスを正確に列挙して掃除する）。
export OE_REFUTE_DIRS_LOG="$_TMP_DIR/created-output-dirs.txt"
: > "$OE_REFUTE_DIRS_LOG"
cleanup() {
  if [[ -s "$OE_REFUTE_DIRS_LOG" ]]; then
    while IFS= read -r d; do
      # 安全策: tmp/oe-refute-* 配下のみ削除（想定外パスは触らない）
      case "$d" in
        */tmp/oe-refute-*) [[ -d "$d" ]] && rm -rf "$d" ;;
      esac
    done < "$OE_REFUTE_DIRS_LOG"
  fi
  rm -rf "$_TMP_DIR"
}
trap cleanup EXIT

# --- mock so-compare（PATH 先頭スタブ） ---
# 実 so-compare の I/F のうち本テストが使う部分だけ再現する: --with / -w / -f / -o。
# -o の dir に <provider>-stdout.txt を VERDICT:/REASON: 付きで書く。
cat > "$_TMP_DIR/pathbin/so-compare" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
providers=""
out_dir=""
prompt_file=""
workspace=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with) providers="$2"; shift 2 ;;
    -o) out_dir="$2"; shift 2 ;;
    -f) prompt_file="$2"; shift 2 ;;
    -w) workspace="$2"; shift 2 ;;
    *) shift ;;
  esac
done
mkdir -p "$out_dir"
# oe-refute が作った実 output_dir（-o）を掃除用ログに追記（EXIT で削除する）
if [[ -n "${OE_REFUTE_DIRS_LOG:-}" && -n "$out_dir" ]]; then
  printf '%s\n' "$out_dir" >> "$OE_REFUTE_DIRS_LOG"
fi
# プロンプト内容を検証用にコピー（body 不透明渡しテスト）
if [[ -n "${SO_FAKE_PROMPT_COPY:-}" && -n "$prompt_file" ]]; then
  cp "$prompt_file" "$SO_FAKE_PROMPT_COPY"
fi
# 受け取った -w 引数を検証用に書き出す（Fix 4・git root 検証）
if [[ -n "${SO_FAKE_W_COPY:-}" ]]; then
  printf '%s\n' "$workspace" > "$SO_FAKE_W_COPY"
fi
# 受け取った -o 引数を検証用に書き出す（Fix #2・repo 相対 output_dir 検証）
if [[ -n "${SO_FAKE_O_COPY:-}" ]]; then
  printf '%s' "$out_dir" > "$SO_FAKE_O_COPY"
fi
IFS=',' read -r -a provs <<< "$providers"
for p in "${provs[@]}"; do
  var="SO_FAKE_$(printf '%s' "$p" | tr '[:lower:]' '[:upper:]')_VERDICT"
  v="${!var:-survived}"
  f="${out_dir}/${p}-stdout.txt"
  case "$v" in
    empty) : > "$f" ;;
    none)  printf 'no verdict line here\nREASON: this lane forgot the verdict\n' > "$f" ;;
    refuted)  printf 'analysis...\nVERDICT: refuted\nREASON: lane %s says refuted\n' "$p" > "$f" ;;
    survived) printf 'analysis...\nVERDICT: survived\nREASON: lane %s says survived\n' "$p" > "$f" ;;
    # Fix 1: 末尾付帯テキスト付きの survived（行全体 grep だと refuted と誤分類しうる）
    survived-suffix) printf 'analysis...\nVERDICT: survived (not refuted)\nREASON: lane %s survived; refuted claims were weak\n' "$p" > "$f" ;;
    # Fix 3: 実 verdict の後にプロンプト例プレースホルダをエコー（tail/grep が例を拾わないこと）
    echo-example) printf 'analysis...\nVERDICT: survived\nREASON: lane %s survived\nVERDICT: <refuted または survived のいずれか1つ>\nREASON: <1 行の総合判断（改行を含めない）>\n' "$p" > "$f" ;;
    *) printf 'VERDICT: survived\nREASON: default\n' > "$f" ;;
  esac
  printf 'tool=%s\nexit_code=0\n' "$p" > "${out_dir}/${p}-meta.txt"
done
exit "${SO_FAKE_RC:-0}"
EOF
chmod +x "$_TMP_DIR/pathbin/so-compare"

# PATH: mock so-compare（pathbin）+ システム実体（jq/awk/sed/grep/mktemp/date/...）
export PATH="${_TMP_DIR}/pathbin:/opt/homebrew/bin:/usr/bin:/bin"
# oe-refute は OE_REFUTE_SO_COMPARE で so-compare 実体を解決。PATH の mock を指す。
export OE_REFUTE_SO_COMPARE="so-compare"
# audit を隔離
export OE_DATA_DIR="$_TMP_DIR"

REFUTE="$PROJECT_DIR/bin/oe-refute"

PASS=0
FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (want='$expected' got='$actual')"; FAIL=$((FAIL + 1))
  fi
}

# claim doc を書くヘルパ
write_doc() { printf '%s' "$2" > "$1"; }

DOC="$_TMP_DIR/docs/claim.md"

# ----------------------------------------------------------------------------
# [1] frontmatter パース: claim / rubric を抽出して JSON に出る
# ----------------------------------------------------------------------------
echo "[1] frontmatter パース（claim / rubric 抽出）"
write_doc "$DOC" '---
claim: "DJ-3 を案C で確定する"
rubric: exploration
domain: design
context_refs:
  - tmp/so-XXXX/
---

ここが body。探索木の中身そのまま。
案A → 採否 ❌ / 案C → 採用'
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT 2>/dev/null || true
out="$("$REFUTE" --claim "$DOC" 2>/dev/null)"; rc=$?
ck "rc=0（全 survived 既定）" "0" "$rc"
ck "JSON rubric=exploration" "exploration" "$(printf '%s' "$out" | jq -r '.rubric')"
ck "JSON lanes=2" "2" "$(printf '%s' "$out" | jq -r '.lanes')"
ck "JSON verdict=survived" "survived" "$(printf '%s' "$out" | jq -r '.verdict')"

# ----------------------------------------------------------------------------
# [2] body 不透明渡し: -f プロンプトに body が丸ごと入る（domain 非依存）
# ----------------------------------------------------------------------------
echo "[2] body 不透明渡し（プロンプトに body 文字列が含まれる）"
export SO_FAKE_PROMPT_COPY="$_TMP_DIR/captured-prompt.txt"
"$REFUTE" --claim "$DOC" >/dev/null 2>&1
ck "プロンプトに body の特徴句が含まれる" "yes" \
  "$(grep -qF '案A → 採否 ❌ / 案C → 採用' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
ck "プロンプトに claim が含まれる" "yes" \
  "$(grep -qF 'DJ-3 を案C で確定する' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
ck "プロンプトに VERDICT 強制指示が含まれる" "yes" \
  "$(grep -qF 'VERDICT: <refuted または survived のいずれか1つ>' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
# Fix 3: プロンプト例は実値（VERDICT: refuted / VERDICT: survived）と同形であってはならない。
# プレースホルダ化により実値の VERDICT 行をエコーしないこと（tail/grep が例を拾わない）。
ck "プロンプトに実値 'VERDICT: refuted' を含まない（例示エコー無害化）" "yes" \
  "$(grep -qE '^[[:space:]]*VERDICT:[[:space:]]*(refuted|survived)[[:space:]]*$' "$SO_FAKE_PROMPT_COPY" && echo no || echo yes)"
unset SO_FAKE_PROMPT_COPY

# ----------------------------------------------------------------------------
# [3] conservative 集約: 1 レーン refuted → 全体 refuted、exit 3
# ----------------------------------------------------------------------------
echo "[3] conservative 集約: 1 レーン refuted → 全体 refuted（exit 3）"
export SO_FAKE_CODEX_VERDICT=refuted
export SO_FAKE_CURSOR_VERDICT=survived
out="$("$REFUTE" --claim "$DOC" 2>/dev/null)"; rc=$?
ck "verdict=refuted" "refuted" "$(printf '%s' "$out" | jq -r '.verdict')"
ck "exit=3" "3" "$rc"
ck "dissent に codex=refuted" "refuted" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="codex") | .verdict')"
ck "dissent に cursor=survived" "survived" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="cursor") | .verdict')"
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT

# ----------------------------------------------------------------------------
# [4] conservative 集約: 全レーン survived → survived、exit 0
# ----------------------------------------------------------------------------
echo "[4] 全レーン survived → survived（exit 0）"
export SO_FAKE_CODEX_VERDICT=survived
export SO_FAKE_CURSOR_VERDICT=survived
out="$("$REFUTE" --claim "$DOC" 2>/dev/null)"; rc=$?
ck "verdict=survived" "survived" "$(printf '%s' "$out" | jq -r '.verdict')"
ck "exit=0" "0" "$rc"
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT

# ----------------------------------------------------------------------------
# [5] verdict 取れないレーン → error 扱い、survived 確定不可で refuted（保守側）
# ----------------------------------------------------------------------------
echo "[5] verdict 欠落レーン → error / survived 確定不可で全体 refuted"
export SO_FAKE_CODEX_VERDICT=survived
export SO_FAKE_CURSOR_VERDICT=none   # VERDICT 行なし → error
out="$("$REFUTE" --claim "$DOC" 2>/dev/null)"; rc=$?
ck "verdict=refuted（survived 確定不可）" "refuted" "$(printf '%s' "$out" | jq -r '.verdict')"
ck "exit=3" "3" "$rc"
ck "dissent に cursor=error" "error" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="cursor") | .verdict')"
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT

# ----------------------------------------------------------------------------
# [5b] 空出力レーン（empty）も error 扱い
# ----------------------------------------------------------------------------
echo "[5b] 空出力レーン（empty）→ error / 全体 refuted"
export SO_FAKE_CODEX_VERDICT=survived
export SO_FAKE_CURSOR_VERDICT=empty
out="$("$REFUTE" --claim "$DOC" 2>/dev/null)"; rc=$?
ck "verdict=refuted" "refuted" "$(printf '%s' "$out" | jq -r '.verdict')"
ck "dissent に cursor=error" "error" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="cursor") | .verdict')"
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT

# ----------------------------------------------------------------------------
# [6] JSON 形: 必須フィールドが全て揃う / output_dir が JSON に入り実在する
# ----------------------------------------------------------------------------
echo "[6] JSON 形 + output_dir が JSON に入り実在する"
out="$("$REFUTE" --claim "$DOC" 2>/dev/null)"
ck "JSON valid" "ok" "$(printf '%s' "$out" | jq -e '.' >/dev/null 2>&1 && echo ok || echo ng)"
ck "fields 揃う" "ok" \
  "$(printf '%s' "$out" | jq -e 'has("verdict") and has("reason") and has("rubric") and has("lanes") and has("dissent") and has("output_dir") and has("audit_id")' >/dev/null 2>&1 && echo ok || echo ng)"
odir="$(printf '%s' "$out" | jq -r '.output_dir')"
ck "output_dir 非空" "yes" "$( [[ -n "$odir" ]] && echo yes || echo no )"
ck "output_dir が実在" "yes" "$( [[ -d "$odir" ]] && echo yes || echo no )"
ck "audit_id 26 文字" "26" "$(printf '%s' "$out" | jq -r '.audit_id' | awk '{print length}')"

# ----------------------------------------------------------------------------
# [6b] Fix #2: output_dir が repo 相対 tmp/oe-refute-<ULID>/（system temp でない）
# ----------------------------------------------------------------------------
echo "[6b] Fix #2: output_dir が repo 相対 tmp/oe-refute-<ULID>/（/var/folders でない）"
# 呼び出し時 cwd の git root（=このリポジトリルート）配下 tmp/oe-refute-<ULID>/ に作られる。
expected_root="$(cd "$PROJECT_DIR" && { git rev-parse --show-toplevel 2>/dev/null || true; })"
out="$( cd "$PROJECT_DIR" && "$REFUTE" --claim "$DOC" 2>/dev/null )"
odir="$(printf '%s' "$out" | jq -r '.output_dir')"
audit_id="$(printf '%s' "$out" | jq -r '.audit_id')"
ck "output_dir が repo の tmp/oe-refute- 配下" "yes" \
  "$( [[ "$odir" == "${expected_root}/tmp/oe-refute-"* ]] && echo yes || echo no )"
ck "output_dir が system temp（/var/folders）でない" "yes" \
  "$( [[ "$odir" != /var/folders/* && "$odir" != /tmp/* ]] && echo yes || echo no )"
ck "output_dir が実在（repo 相対）" "yes" "$( [[ -d "$odir" ]] && echo yes || echo no )"
# traceability: output_dir 名末尾の ULID と audit_id が一致する（同じ run を 1 ULID で辿れる）
odir_ulid="$(basename "$odir" | sed -E 's/^oe-refute-//')"
ck "output_dir 名の ULID = audit_id（traceability）" "$audit_id" "$odir_ulid"
# mock so-compare が -o で受けた dir = oe-refute が作った repo 相対 output_dir
export SO_FAKE_O_COPY="$_TMP_DIR/captured-o.txt"
out="$( cd "$PROJECT_DIR" && "$REFUTE" --claim "$DOC" 2>/dev/null )"
odir="$(printf '%s' "$out" | jq -r '.output_dir')"
captured_o="$(cat "$SO_FAKE_O_COPY" 2>/dev/null)"
ck "so-compare -o = oe-refute の output_dir" "$odir" "$captured_o"
ck "so-compare -o が repo の tmp/oe-refute- 配下" "yes" \
  "$( [[ "$captured_o" == "${expected_root}/tmp/oe-refute-"* ]] && echo yes || echo no )"
unset SO_FAKE_O_COPY

# ----------------------------------------------------------------------------
# [7] --rubric 上書き: frontmatter exploration を consensus で上書き
# ----------------------------------------------------------------------------
echo "[7] --rubric 上書き（frontmatter exploration → consensus）"
out="$("$REFUTE" --claim "$DOC" --rubric consensus 2>/dev/null)"
ck "JSON rubric=consensus（上書き）" "consensus" "$(printf '%s' "$out" | jq -r '.rubric')"

# frontmatter に rubric が無い → 既定 exploration
echo "[7b] frontmatter rubric 欠落 → 既定 exploration"
DOC2="$_TMP_DIR/docs/no-rubric.md"
write_doc "$DOC2" '---
claim: "原因は外部要因でコードパスはこれ以上読まない"
---

hypothesis 群と read-state...'
out="$("$REFUTE" --claim "$DOC2" 2>/dev/null)"
ck "rubric 既定 exploration" "exploration" "$(printf '%s' "$out" | jq -r '.rubric')"

# frontmatter に不正 rubric 値 → exit 2（不在=既定 exploration / 不正値=fail-fast。--rubric と対称）
echo "[7c] frontmatter rubric 不正値 → exit 2（peer review: 非対称解消）"
DOC2B="$_TMP_DIR/docs/bad-rubric.md"
write_doc "$DOC2B" '---
claim: "X を確定する"
rubric: consenssus
---

body...'
rc=0; "$REFUTE" --claim "$DOC2B" >/dev/null 2>&1 || rc=$?
ck "frontmatter rubric 不正 → exit 2" "2" "$rc"

# ----------------------------------------------------------------------------
# [8] --lanes 3 → codex,claude,cursor（3 レーン）
# ----------------------------------------------------------------------------
echo "[8] --lanes 3 → 3 レーン（codex,claude,cursor）"
out="$("$REFUTE" --claim "$DOC" --lanes 3 2>/dev/null)"
ck "JSON lanes=3" "3" "$(printf '%s' "$out" | jq -r '.lanes')"
ck "dissent に claude レーン" "yes" \
  "$(printf '%s' "$out" | jq -e '.dissent[] | select(.lane=="claude")' >/dev/null 2>&1 && echo yes || echo no)"

# ----------------------------------------------------------------------------
# [9] --lanes 不正値 → exit 2
# ----------------------------------------------------------------------------
echo "[9] --lanes 不正値 → exit 2"
rc=0; "$REFUTE" --claim "$DOC" --lanes 5 >/dev/null 2>&1 || rc=$?
ck "--lanes 5 → exit 2" "2" "$rc"
rc=0; "$REFUTE" --claim "$DOC" --lanes abc >/dev/null 2>&1 || rc=$?
ck "--lanes abc → exit 2" "2" "$rc"

# ----------------------------------------------------------------------------
# [10] frontmatter 欠落（claim 無し）→ エラー（exit 2）
# ----------------------------------------------------------------------------
echo "[10] claim 欠落 → exit 2"
DOC3="$_TMP_DIR/docs/no-claim.md"
write_doc "$DOC3" '---
rubric: exploration
---

claim フィールドが無い body'
rc=0; "$REFUTE" --claim "$DOC3" >/dev/null 2>&1 || rc=$?
ck "claim 無し → exit 2" "2" "$rc"

# frontmatter 自体が無い → claim 取れず exit 2
echo "[10b] frontmatter 自体なし → exit 2"
DOC4="$_TMP_DIR/docs/no-fm.md"
write_doc "$DOC4" 'just a plain markdown without frontmatter'
rc=0; "$REFUTE" --claim "$DOC4" >/dev/null 2>&1 || rc=$?
ck "frontmatter なし → exit 2" "2" "$rc"

# ----------------------------------------------------------------------------
# [11] --claim 欠落 / 存在しないファイル → exit 2
# ----------------------------------------------------------------------------
echo "[11] --claim 欠落 / 不在ファイル → exit 2"
rc=0; "$REFUTE" >/dev/null 2>&1 || rc=$?
ck "--claim 欠落 → exit 2" "2" "$rc"
rc=0; "$REFUTE" --claim /no/such/file.md >/dev/null 2>&1 || rc=$?
ck "不在ファイル → exit 2" "2" "$rc"

# ----------------------------------------------------------------------------
# [12] --rubric 不正値 → exit 2 / unknown option → exit 2 / --help → exit 0
# ----------------------------------------------------------------------------
echo "[12] --rubric 不正値 / unknown option / --help"
rc=0; "$REFUTE" --claim "$DOC" --rubric bogus >/dev/null 2>&1 || rc=$?
ck "--rubric bogus → exit 2" "2" "$rc"
rc=0; "$REFUTE" --bogus >/dev/null 2>&1 || rc=$?
ck "--bogus → exit 2" "2" "$rc"
rc=0; "$REFUTE" --help >/dev/null 2>&1 || rc=$?
ck "--help → exit 0" "0" "$rc"

# ----------------------------------------------------------------------------
# [13] 最小 audit 記録: oe-refute.jsonl に 1 行（audit_id / verdict / output_dir）
# ----------------------------------------------------------------------------
echo "[13] 最小 audit 記録（oe-refute.jsonl）"
rm -f "$_TMP_DIR/audit/oe-refute.jsonl"
export SO_FAKE_CODEX_VERDICT=refuted
"$REFUTE" --claim "$DOC" >/dev/null 2>&1 || true
unset SO_FAKE_CODEX_VERDICT
ck "audit jsonl が書かれる" "yes" "$( [[ -s "$_TMP_DIR/audit/oe-refute.jsonl" ]] && echo yes || echo no )"
last="$(tail -n 1 "$_TMP_DIR/audit/oe-refute.jsonl" 2>/dev/null)"
ck "audit に verdict=refuted" "refuted" "$(printf '%s' "$last" | jq -r '.verdict')"
ck "audit に audit_id" "yes" "$( [[ -n "$(printf '%s' "$last" | jq -r '.audit_id')" ]] && echo yes || echo no )"
ck "audit に output_dir" "yes" "$( [[ -n "$(printf '%s' "$last" | jq -r '.output_dir')" ]] && echo yes || echo no )"

# ----------------------------------------------------------------------------
# [14] claim 内 '#' を保持（コメント誤剥がしをしない）
# ----------------------------------------------------------------------------
echo "[14] claim 内 '#' を保持（行内コメント誤剥がしなし）"
DOC5="$_TMP_DIR/docs/hash.md"
write_doc "$DOC5" '---
claim: "#142 を案C で確定する"
rubric: exploration
---
body'
out="$("$REFUTE" --claim "$DOC5" 2>/dev/null)"
ck "rubric=exploration（パース成功）" "exploration" "$(printf '%s' "$out" | jq -r '.rubric')"

# ----------------------------------------------------------------------------
# [15] Fix 1: VERDICT: survived (not refuted) を refuted と誤分類しない
# ----------------------------------------------------------------------------
echo "[15] Fix 1: 'VERDICT: survived (not refuted)' → survived（誤って refuted にしない）"
export SO_FAKE_CODEX_VERDICT=survived-suffix
export SO_FAKE_CURSOR_VERDICT=survived-suffix
out="$("$REFUTE" --claim "$DOC" 2>/dev/null)"; rc=$?
ck "codex レーン=survived（付帯テキスト無視）" "survived" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="codex") | .verdict')"
ck "cursor レーン=survived（付帯テキスト無視）" "survived" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="cursor") | .verdict')"
ck "全体 verdict=survived" "survived" "$(printf '%s' "$out" | jq -r '.verdict')"
ck "exit=0" "0" "$rc"
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT

# ----------------------------------------------------------------------------
# [16] Fix 2: 先頭 --- ありで閉じ --- 無し → fail loud（exit 2）
# ----------------------------------------------------------------------------
echo "[16] Fix 2: 閉じ --- 欠落 → exit 2（body 空での静かな劣化を防ぐ）"
DOC_NOCLOSE="$_TMP_DIR/docs/no-close.md"
write_doc "$DOC_NOCLOSE" '---
claim: "閉じ --- が無い claim doc"
rubric: exploration

ここは閉じ --- が無いので frontmatter が確定しない。body も取れない。'
rc=0; err_out="$("$REFUTE" --claim "$DOC_NOCLOSE" 2>&1 >/dev/null)" || rc=$?
ck "閉じ --- 欠落 → exit 2" "2" "$rc"
ck "エラーメッセージに closing '---' 欠落" "yes" \
  "$(printf '%s' "$err_out" | grep -qF "no closing '---'" && echo yes || echo no)"

# ----------------------------------------------------------------------------
# [17] Fix 3: lane stdout 末尾にプロンプト例プレースホルダを含んでも実 verdict を拾う
# ----------------------------------------------------------------------------
echo "[17] Fix 3: 末尾のプロンプト例プレースホルダを誤抽出しない（実 verdict=survived を拾う）"
export SO_FAKE_CODEX_VERDICT=echo-example
export SO_FAKE_CURSOR_VERDICT=echo-example
out="$("$REFUTE" --claim "$DOC" 2>/dev/null)"; rc=$?
ck "codex レーン=survived（プレースホルダ例を拾わない）" "survived" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="codex") | .verdict')"
ck "全体 verdict=survived" "survived" "$(printf '%s' "$out" | jq -r '.verdict')"
ck "exit=0" "0" "$rc"
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT

# ----------------------------------------------------------------------------
# [18] Fix 4: so-compare に渡る -w が git root（リポジトリルート）
# ----------------------------------------------------------------------------
echo "[18] Fix 4: -w に git root（リポジトリルート）が渡る"
export SO_FAKE_W_COPY="$_TMP_DIR/captured-w.txt"
# claim doc は _TMP_DIR/docs 配下（git 管理外）だが、-w は呼び出し時 cwd の git root を渡す。
expected_root="$(cd "$PROJECT_DIR" && { git rev-parse --show-toplevel 2>/dev/null || true; })"
( cd "$PROJECT_DIR" && "$REFUTE" --claim "$DOC" >/dev/null 2>&1 )
captured_w="$(cat "$SO_FAKE_W_COPY" 2>/dev/null)"
ck "-w = git root（リポジトリルート）" "$expected_root" "$captured_w"
ck "-w ≠ claim doc 親 dir（旧挙動でない）" "yes" \
  "$( [[ "$captured_w" != "$_TMP_DIR/docs" ]] && echo yes || echo no )"
unset SO_FAKE_W_COPY

# ----------------------------------------------------------------------------
# [19] Fix 5: CRLF（---\r）の claim doc を frontmatter として正しくパースする
# ----------------------------------------------------------------------------
echo "[19] Fix 5: CRLF（--- + CR）frontmatter を正しくパース"
DOC_CRLF="$_TMP_DIR/docs/crlf.md"
# CRLF 行末で frontmatter を書く（--- にも \r が付く）
printf '%s\r\n' '---' 'claim: "CRLF frontmatter の claim"' 'rubric: consensus' '---' '' 'CRLF body content' > "$DOC_CRLF"
out="$("$REFUTE" --claim "$DOC_CRLF" 2>/dev/null)"; rc=$?
ck "CRLF: rubric=consensus（frontmatter 認識）" "consensus" "$(printf '%s' "$out" | jq -r '.rubric')"
ck "CRLF: rc=0（全 survived 既定）" "0" "$rc"
# body が反証プロンプトに渡る（frontmatter が無視されず body が空にならない）
export SO_FAKE_PROMPT_COPY="$_TMP_DIR/captured-crlf-prompt.txt"
"$REFUTE" --claim "$DOC_CRLF" >/dev/null 2>&1
ck "CRLF: プロンプトに body が含まれる" "yes" \
  "$(grep -qF 'CRLF body content' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
ck "CRLF: プロンプトに claim が含まれる" "yes" \
  "$(grep -qF 'CRLF frontmatter の claim' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
unset SO_FAKE_PROMPT_COPY

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
