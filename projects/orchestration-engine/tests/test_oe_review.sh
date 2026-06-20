#!/usr/bin/env bash
# test_oe_review.sh — oe-review（#194 / 実装SO diff バインド artifact verb）の
#   diff バインド（reviewed_sha/diff_base/diff_hash/changed_files_count）/ base 解決 /
#   diff 注入 / impl レンズ / conservative 集約 / exit code / JSON 形 / audit /
#   stale 検知の基礎（diff 変化で hash 変化）/ エラー系 を検証する。
#
# 実 so-compare / codex / cursor / claude は絶対に起動しない（遅い・課金）。
# so-compare を PATH 先頭スタブで mock する（test_oe_refute.sh と同方式）。
# oe-review は git 前提なので、各ケースは _TMP_DIR 配下の throwaway git repo を cwd にして実行する。
#   SO_FAKE_<PROV>_VERDICT = refuted | survived | none | empty | survived-suffix | echo-example（既定 survived）
#   SO_FAKE_RC             = スタブ so-compare の exit code（既定 0）
#   SO_FAKE_PROMPT_COPY    = 指定パスへ -f のプロンプト内容をコピー（diff 注入検証用）
#   SO_FAKE_W_COPY         = 指定パスへ受け取った -w 引数を書き出す
#   SO_FAKE_O_COPY         = 指定パスへ受け取った -o 引数を書き出す

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

_TMP_DIR="$(mktemp -d)"
mkdir -p "$_TMP_DIR/pathbin" "$_TMP_DIR/audit"

cleanup() { rm -rf "$_TMP_DIR"; }
trap cleanup EXIT

# --- mock so-compare（PATH 先頭スタブ） ---
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
if [[ -n "${SO_FAKE_PROMPT_COPY:-}" && -n "$prompt_file" ]]; then
  cp "$prompt_file" "$SO_FAKE_PROMPT_COPY"
fi
if [[ -n "${SO_FAKE_W_COPY:-}" ]]; then
  printf '%s\n' "$workspace" > "$SO_FAKE_W_COPY"
fi
if [[ -n "${SO_FAKE_O_COPY:-}" ]]; then
  printf '%s' "$out_dir" > "$SO_FAKE_O_COPY"
fi
IFS=',' read -r -a provs <<< "$providers"
for p in ${provs[@]+"${provs[@]}"}; do
  var="SO_FAKE_$(printf '%s' "$p" | tr '[:lower:]' '[:upper:]')_VERDICT"
  v="${!var:-survived}"
  f="${out_dir}/${p}-stdout.txt"
  case "$v" in
    empty) : > "$f" ;;
    none)  printf 'no verdict line here\nREASON: this lane forgot the verdict\n' > "$f" ;;
    refuted)  printf 'analysis...\nVERDICT: refuted\nREASON: lane %s found a defect\n' "$p" > "$f" ;;
    survived) printf 'analysis...\nVERDICT: survived\nREASON: lane %s found no defect\n' "$p" > "$f" ;;
    survived-suffix) printf 'analysis...\nVERDICT: survived (not refuted)\nREASON: lane %s survived\n' "$p" > "$f" ;;
    echo-example) printf 'analysis...\nVERDICT: survived\nREASON: lane %s survived\nVERDICT: <refuted または survived のいずれか1つ>\nREASON: <1 行の総合判断（改行を含めない）>\n' "$p" > "$f" ;;
    *) printf 'VERDICT: survived\nREASON: default\n' > "$f" ;;
  esac
  printf 'tool=%s\nexit_code=0\n' "$p" > "${out_dir}/${p}-meta.txt"
done
exit "${SO_FAKE_RC:-0}"
EOF
chmod +x "$_TMP_DIR/pathbin/so-compare"

export PATH="${_TMP_DIR}/pathbin:/opt/homebrew/bin:/usr/bin:/bin"
export OE_REVIEW_SO_COMPARE="so-compare"
export OE_DATA_DIR="$_TMP_DIR"

REVIEW="$PROJECT_DIR/bin/oe-review"

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

# throwaway git repo: master(base) → feature(変更 2 ファイル) を作る
GIT_AUTHOR=(-c user.email=t@t.test -c user.name=test -c commit.gpgsign=false)
make_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git "${GIT_AUTHOR[@]}" -C "$repo" -c init.defaultBranch=master init -q
  printf 'line1\nline2\n' > "$repo/file.txt"
  git "${GIT_AUTHOR[@]}" -C "$repo" add file.txt
  git "${GIT_AUTHOR[@]}" -C "$repo" commit -q -m "base"
  git "${GIT_AUTHOR[@]}" -C "$repo" checkout -q -b feature
  printf 'line1\nline2\nline3\n' > "$repo/file.txt"
  printf '#!/usr/bin/env bash\necho hi\n' > "$repo/added.sh"
  git "${GIT_AUTHOR[@]}" -C "$repo" add file.txt added.sh
  git "${GIT_AUTHOR[@]}" -C "$repo" commit -q -m "feature change"
}

REPO="$_TMP_DIR/repo"
make_repo "$REPO"
# macOS の mktemp は /var/folders/... (symlink) を返すが git rev-parse --show-toplevel は
# 正規化された /private/var/... を返す。output_dir / -w のパス比較を揃えるため canonical 化する。
REPO="$( cd "$REPO" && git rev-parse --show-toplevel )"

# ----------------------------------------------------------------------------
# [1] 基本: 全 survived → verdict=survived / exit 0 / lens=impl
# ----------------------------------------------------------------------------
echo "[1] 基本（全 survived → survived / exit 0 / lens=impl）"
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT 2>/dev/null || true
out="$( cd "$REPO" && "$REVIEW" --base master 2>/dev/null )"; rc=$?
ck "rc=0" "0" "$rc"
ck "verdict=survived" "survived" "$(printf '%s' "$out" | jq -r '.verdict')"
ck "lens=impl" "impl" "$(printf '%s' "$out" | jq -r '.lens')"
ck "lanes=2" "2" "$(printf '%s' "$out" | jq -r '.lanes')"

# ----------------------------------------------------------------------------
# [2] conservative: 1 レーン refuted（欠陥検出）→ 全体 refuted / exit 3
# ----------------------------------------------------------------------------
echo "[2] conservative（1 レーン refuted → 全体 refuted / exit 3）"
export SO_FAKE_CODEX_VERDICT=refuted
export SO_FAKE_CURSOR_VERDICT=survived
out="$( cd "$REPO" && "$REVIEW" --base master 2>/dev/null )"; rc=$?
ck "verdict=refuted" "refuted" "$(printf '%s' "$out" | jq -r '.verdict')"
ck "exit=3" "3" "$rc"
ck "dissent codex=refuted" "refuted" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="codex") | .verdict')"
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT

# ----------------------------------------------------------------------------
# [3] verdict 欠落レーン → error / survived 確定不可で refuted（保守側）
# ----------------------------------------------------------------------------
echo "[3] verdict 欠落レーン → error / 全体 refuted"
export SO_FAKE_CODEX_VERDICT=survived
export SO_FAKE_CURSOR_VERDICT=none
out="$( cd "$REPO" && "$REVIEW" --base master 2>/dev/null )"; rc=$?
ck "verdict=refuted" "refuted" "$(printf '%s' "$out" | jq -r '.verdict')"
ck "exit=3" "3" "$rc"
ck "dissent cursor=error" "error" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="cursor") | .verdict')"
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT

# ----------------------------------------------------------------------------
# [3b] 空出力レーン（empty・-s 判定分岐）→ error / 全体 refuted
# ----------------------------------------------------------------------------
echo "[3b] 空出力レーン（empty）→ error / 全体 refuted"
export SO_FAKE_CODEX_VERDICT=survived
export SO_FAKE_CURSOR_VERDICT=empty
out="$( cd "$REPO" && "$REVIEW" --base master 2>/dev/null )"; rc=$?
ck "verdict=refuted" "refuted" "$(printf '%s' "$out" | jq -r '.verdict')"
ck "dissent cursor=error" "error" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="cursor") | .verdict')"
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT

# ----------------------------------------------------------------------------
# [3c] so-compare rc=2（全プロバイダ失敗）＋全レーン空 → 全 error / 全体 refuted
# ----------------------------------------------------------------------------
echo "[3c] so-compare rc=2 + 全レーン空 → 全 error / refuted"
export SO_FAKE_RC=2
export SO_FAKE_CODEX_VERDICT=empty
export SO_FAKE_CURSOR_VERDICT=empty
out="$( cd "$REPO" && "$REVIEW" --base master 2>/dev/null )"; rc=$?
ck "verdict=refuted（保守側）" "refuted" "$(printf '%s' "$out" | jq -r '.verdict')"
ck "exit=3" "3" "$rc"
ck "両レーン error" "error error" \
  "$(printf '%s' "$out" | jq -r '[.dissent[].verdict] | join(" ")')"
unset SO_FAKE_RC SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT

# ----------------------------------------------------------------------------
# [4] JSON 形: 必須フィールドが全て揃う（diff バインド含む）
# ----------------------------------------------------------------------------
echo "[4] JSON 形（diff バインドフィールド含む）"
out="$( cd "$REPO" && "$REVIEW" --base master 2>/dev/null )"
ck "JSON valid" "ok" "$(printf '%s' "$out" | jq -e '.' >/dev/null 2>&1 && echo ok || echo ng)"
ck "fields 揃う" "ok" \
  "$(printf '%s' "$out" | jq -e 'has("verdict") and has("reason") and has("lens") and has("lanes") and has("dissent") and has("reviewed_sha") and has("diff_base") and has("diff_hash") and has("changed_files_count") and has("output_dir") and has("audit_id")' >/dev/null 2>&1 && echo ok || echo ng)"

# ----------------------------------------------------------------------------
# [5] diff バインド: reviewed_sha=HEAD / diff_base=master / diff_hash 非空 / 変更2件
# ----------------------------------------------------------------------------
echo "[5] diff バインド（reviewed_sha=HEAD / diff_base=master / changed_files_count=2）"
head_sha="$(git "${GIT_AUTHOR[@]}" -C "$REPO" rev-parse HEAD)"
out="$( cd "$REPO" && "$REVIEW" --base master 2>/dev/null )"
ck "reviewed_sha=HEAD" "$head_sha" "$(printf '%s' "$out" | jq -r '.reviewed_sha')"
ck "diff_base=master" "master" "$(printf '%s' "$out" | jq -r '.diff_base')"
ck "diff_hash 非空" "yes" "$( [[ -n "$(printf '%s' "$out" | jq -r '.diff_hash')" ]] && echo yes || echo no )"
ck "changed_files_count=2" "2" "$(printf '%s' "$out" | jq -r '.changed_files_count')"
# diff_hash が将来ゲートの自然な再計算 `git diff <diff_base>...<reviewed_sha> | git hash-object --stdin`
# と一致する（shell 変数経由で末尾改行が落ちると不一致＝stale 誤検知になる退行を検出）。
j_base="$(printf '%s' "$out" | jq -r '.diff_base')"
j_sha="$(printf '%s' "$out" | jq -r '.reviewed_sha')"
j_hash="$(printf '%s' "$out" | jq -r '.diff_hash')"
expect_hash="$(git "${GIT_AUTHOR[@]}" -C "$REPO" diff "${j_base}...${j_sha}" | git "${GIT_AUTHOR[@]}" -C "$REPO" hash-object --stdin)"
ck "diff_hash == ゲート自然再計算（raw diff の hash-object）" "$expect_hash" "$j_hash"

# ----------------------------------------------------------------------------
# [6] output_dir が repo 相対 tmp/oe-review-<ULID>/・実在・audit_id=ULID
# ----------------------------------------------------------------------------
echo "[6] output_dir = repo 相対 tmp/oe-review-<ULID>/ / audit_id 一致"
out="$( cd "$REPO" && "$REVIEW" --base master 2>/dev/null )"
odir="$(printf '%s' "$out" | jq -r '.output_dir')"
audit_id="$(printf '%s' "$out" | jq -r '.audit_id')"
ck "output_dir が repo の tmp/oe-review- 配下" "yes" \
  "$( [[ "$odir" == "${REPO}/tmp/oe-review-"* ]] && echo yes || echo no )"
ck "output_dir 実在" "yes" "$( [[ -d "$odir" ]] && echo yes || echo no )"
ck "audit_id 26 文字" "26" "$(printf '%s' "$audit_id" | awk '{print length}')"
ck "output_dir 名 ULID = audit_id" "$audit_id" "$(basename "$odir" | sed -E 's/^oe-review-//')"

# ----------------------------------------------------------------------------
# [7] stale 検知の基礎: 新コミットで reviewed_sha と diff_hash が変わる
# ----------------------------------------------------------------------------
echo "[7] stale 検知の基礎（新コミットで reviewed_sha / diff_hash 変化）"
out1="$( cd "$REPO" && "$REVIEW" --base master 2>/dev/null )"
sha1="$(printf '%s' "$out1" | jq -r '.reviewed_sha')"
hash1="$(printf '%s' "$out1" | jq -r '.diff_hash')"
printf 'line1\nline2\nline3\nline4\n' > "$REPO/file.txt"
git "${GIT_AUTHOR[@]}" -C "$REPO" add file.txt
git "${GIT_AUTHOR[@]}" -C "$REPO" commit -q -m "more change"
out2="$( cd "$REPO" && "$REVIEW" --base master 2>/dev/null )"
sha2="$(printf '%s' "$out2" | jq -r '.reviewed_sha')"
hash2="$(printf '%s' "$out2" | jq -r '.diff_hash')"
ck "reviewed_sha が変化" "yes" "$( [[ "$sha1" != "$sha2" ]] && echo yes || echo no )"
ck "diff_hash が変化" "yes" "$( [[ "$hash1" != "$hash2" ]] && echo yes || echo no )"

# ----------------------------------------------------------------------------
# [8] diff 注入: プロンプトに変更ファイル・diff 本文・impl レンズが入る（設計レンズでない）
# ----------------------------------------------------------------------------
echo "[8] diff 注入＋impl レンズ（プロンプト検証）"
export SO_FAKE_PROMPT_COPY="$_TMP_DIR/captured-prompt.txt"
( cd "$REPO" && "$REVIEW" --base master >/dev/null 2>&1 )
ck "プロンプトに変更ファイル added.sh" "yes" \
  "$(grep -qF 'added.sh' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
ck "プロンプトに diff 本文（+line4 or +line3）" "yes" \
  "$(grep -qE '^\+line[34]' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
ck "プロンプトに impl レンズ（コード欠陥検出）" "yes" \
  "$(grep -qF 'コード欠陥' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
ck "プロンプトに option-expansion しない明示" "yes" \
  "$(grep -qF 'option-expansion はしない' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
ck "プロンプトに設計 breadth レンズを含まない（impl≠設計SO）" "yes" \
  "$(grep -qF 'breadth（軸5）' "$SO_FAKE_PROMPT_COPY" && echo no || echo yes)"
ck "プロンプトに VERDICT 強制指示" "yes" \
  "$(grep -qF 'VERDICT: <refuted または survived のいずれか1つ>' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
# 実値の VERDICT 行（例示エコー無害化）はプロンプトに含めない
ck "プロンプトに実値 'VERDICT: refuted/survived' を含まない" "yes" \
  "$(grep -qE '^[[:space:]]*VERDICT:[[:space:]]*(refuted|survived)[[:space:]]*$' "$SO_FAKE_PROMPT_COPY" && echo no || echo yes)"
unset SO_FAKE_PROMPT_COPY

# ----------------------------------------------------------------------------
# [9] audit: oe-review.jsonl に event_type=oe_review + diff バインド
# ----------------------------------------------------------------------------
echo "[9] audit（oe-review.jsonl / event_type=oe_review / diff バインド）"
rm -f "$_TMP_DIR/audit/oe-review.jsonl"
export SO_FAKE_CODEX_VERDICT=refuted
( cd "$REPO" && "$REVIEW" --base master >/dev/null 2>&1 ) || true
unset SO_FAKE_CODEX_VERDICT
ck "audit jsonl が書かれる" "yes" "$( [[ -s "$_TMP_DIR/audit/oe-review.jsonl" ]] && echo yes || echo no )"
last="$(tail -n 1 "$_TMP_DIR/audit/oe-review.jsonl" 2>/dev/null)"
ck "audit event_type=oe_review" "oe_review" "$(printf '%s' "$last" | jq -r '.event_type')"
ck "audit lens=impl" "impl" "$(printf '%s' "$last" | jq -r '.lens')"
ck "audit verdict=refuted" "refuted" "$(printf '%s' "$last" | jq -r '.verdict')"
ck "audit reviewed_sha 非空" "yes" "$( [[ -n "$(printf '%s' "$last" | jq -r '.reviewed_sha')" ]] && echo yes || echo no )"
ck "audit diff_hash 非空" "yes" "$( [[ -n "$(printf '%s' "$last" | jq -r '.diff_hash')" ]] && echo yes || echo no )"

# ----------------------------------------------------------------------------
# [10] base 自動解決: --base 無し → master（origin 無し repo で master へ）
# ----------------------------------------------------------------------------
echo "[10] base 自動解決（--base 無し → master）"
out="$( cd "$REPO" && "$REVIEW" 2>/dev/null )"; rc=$?
ck "diff_base=master（自動）" "master" "$(printf '%s' "$out" | jq -r '.diff_base')"
ck "rc=0" "0" "$rc"

# ----------------------------------------------------------------------------
# [11] OE_REVIEW_BASE env で base 指定
# ----------------------------------------------------------------------------
echo "[11] OE_REVIEW_BASE env で base 指定"
out="$( cd "$REPO" && OE_REVIEW_BASE=master "$REVIEW" 2>/dev/null )"
ck "diff_base=master（env）" "master" "$(printf '%s' "$out" | jq -r '.diff_base')"

# ----------------------------------------------------------------------------
# [11b] base 自動解決: master 不在・main のみ repo → main にフォールバック
# ----------------------------------------------------------------------------
echo "[11b] base 自動解決（master 不在・main のみ → main）"
MAINREPO="$_TMP_DIR/mainrepo"
mkdir -p "$MAINREPO"
git "${GIT_AUTHOR[@]}" -C "$MAINREPO" -c init.defaultBranch=main init -q
printf 'a\n' > "$MAINREPO/f.txt"
git "${GIT_AUTHOR[@]}" -C "$MAINREPO" add f.txt
git "${GIT_AUTHOR[@]}" -C "$MAINREPO" commit -q -m base
git "${GIT_AUTHOR[@]}" -C "$MAINREPO" checkout -q -b feature
printf 'a\nb\n' > "$MAINREPO/f.txt"
git "${GIT_AUTHOR[@]}" -C "$MAINREPO" add f.txt
git "${GIT_AUTHOR[@]}" -C "$MAINREPO" commit -q -m chg
out="$( cd "$MAINREPO" && "$REVIEW" 2>/dev/null )"; rc=$?
ck "diff_base=main（自動フォールバック）" "main" "$(printf '%s' "$out" | jq -r '.diff_base')"
ck "rc=0" "0" "$rc"

# ----------------------------------------------------------------------------
# [12] --lanes 3 → 3 レーン（claude 含む）
# ----------------------------------------------------------------------------
echo "[12] --lanes 3 → 3 レーン"
out="$( cd "$REPO" && "$REVIEW" --base master --lanes 3 2>/dev/null )"
ck "lanes=3" "3" "$(printf '%s' "$out" | jq -r '.lanes')"
ck "dissent に claude" "yes" \
  "$(printf '%s' "$out" | jq -e '.dissent[] | select(.lane=="claude")' >/dev/null 2>&1 && echo yes || echo no)"

# ----------------------------------------------------------------------------
# [13] 大きい diff → inline せず workspace フォールバック
# ----------------------------------------------------------------------------
echo "[13] 大きい diff → inline せず workspace フォールバック"
export SO_FAKE_PROMPT_COPY="$_TMP_DIR/captured-big.txt"
( cd "$REPO" && OE_REVIEW_DIFF_MAX_BYTES=10 "$REVIEW" --base master >/dev/null 2>&1 )
ck "プロンプトに inline せず指示" "yes" \
  "$(grep -qF 'inline せず' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
ck "プロンプトに diff fence を含まない" "yes" \
  "$(grep -qF '```diff' "$SO_FAKE_PROMPT_COPY" && echo no || echo yes)"
# C3: fallback の git diff 指示が reviewed_sha（master...<sha>）に固定され、bare HEAD でない
fb_sha="$(git "${GIT_AUTHOR[@]}" -C "$REPO" rev-parse HEAD)"
ck "fallback が reviewed_sha に固定（master...<sha>）" "yes" \
  "$(grep -qF "git diff master...${fb_sha}" "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
ck "fallback が bare HEAD を指示しない" "yes" \
  "$(grep -qE 'git diff[^`]*\.\.\.HEAD' "$SO_FAKE_PROMPT_COPY" && echo no || echo yes)"
unset SO_FAKE_PROMPT_COPY

# ----------------------------------------------------------------------------
# [14] --context doc が prompt に inline される
# ----------------------------------------------------------------------------
echo "[14] --context doc が prompt に inline"
CTX="$_TMP_DIR/ctx.md"
printf 'issue 要件: 到達可能性に注意せよ\n' > "$CTX"
export SO_FAKE_PROMPT_COPY="$_TMP_DIR/captured-ctx.txt"
( cd "$REPO" && "$REVIEW" --base master --context "$CTX" >/dev/null 2>&1 )
ck "プロンプトに context 本文" "yes" \
  "$(grep -qF 'issue 要件: 到達可能性に注意せよ' "$SO_FAKE_PROMPT_COPY" && echo yes || echo no)"
unset SO_FAKE_PROMPT_COPY

# ----------------------------------------------------------------------------
# [15] so-compare に渡る -w = repo の git root
# ----------------------------------------------------------------------------
echo "[15] -w = git root（repo ルート）"
export SO_FAKE_W_COPY="$_TMP_DIR/captured-w.txt"
( cd "$REPO" && "$REVIEW" --base master >/dev/null 2>&1 )
ck "-w = repo git root" "$REPO" "$(cat "$SO_FAKE_W_COPY" 2>/dev/null)"
unset SO_FAKE_W_COPY

# ----------------------------------------------------------------------------
# [16] Fix 1/3 踏襲: survived-suffix / echo-example を誤抽出しない
# ----------------------------------------------------------------------------
echo "[16] VERDICT 抽出堅牢性（survived-suffix / echo-example → survived）"
export SO_FAKE_CODEX_VERDICT=survived-suffix
export SO_FAKE_CURSOR_VERDICT=echo-example
out="$( cd "$REPO" && "$REVIEW" --base master 2>/dev/null )"; rc=$?
ck "codex=survived（付帯テキスト無視）" "survived" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="codex") | .verdict')"
ck "cursor=survived（例示エコー無視）" "survived" \
  "$(printf '%s' "$out" | jq -r '.dissent[] | select(.lane=="cursor") | .verdict')"
ck "全体 verdict=survived / exit 0" "survived 0" \
  "$(printf '%s' "$out" | jq -r '.verdict') $rc"
unset SO_FAKE_CODEX_VERDICT SO_FAKE_CURSOR_VERDICT

# ----------------------------------------------------------------------------
# [17] エラー系: --lanes 不正 / 不正 base / 変更なし / 非 git / unknown / --help
# ----------------------------------------------------------------------------
echo "[17] エラー系"
rc=0; ( cd "$REPO" && "$REVIEW" --base master --lanes 5 >/dev/null 2>&1 ) || rc=$?
ck "--lanes 5 → exit 2" "2" "$rc"
rc=0; ( cd "$REPO" && "$REVIEW" --base no-such-ref >/dev/null 2>&1 ) || rc=$?
ck "不正 base → exit 2" "2" "$rc"
# 変更なし repo（feature==master）
NODIFF="$_TMP_DIR/nodiff"
mkdir -p "$NODIFF"
git "${GIT_AUTHOR[@]}" -C "$NODIFF" -c init.defaultBranch=master init -q
printf 'x\n' > "$NODIFF/f.txt"
git "${GIT_AUTHOR[@]}" -C "$NODIFF" add f.txt
git "${GIT_AUTHOR[@]}" -C "$NODIFF" commit -q -m base
git "${GIT_AUTHOR[@]}" -C "$NODIFF" checkout -q -b feature
rc=0; ( cd "$NODIFF" && "$REVIEW" --base master >/dev/null 2>&1 ) || rc=$?
ck "変更なし → exit 2" "2" "$rc"
# 非 git ディレクトリ
NONGIT="$_TMP_DIR/nongit"
mkdir -p "$NONGIT"
rc=0; ( cd "$NONGIT" && "$REVIEW" --base master >/dev/null 2>&1 ) || rc=$?
ck "非 git → exit 2" "2" "$rc"
rc=0; ( cd "$REPO" && "$REVIEW" --bogus >/dev/null 2>&1 ) || rc=$?
ck "--bogus → exit 2" "2" "$rc"
rc=0; ( cd "$REPO" && "$REVIEW" --help >/dev/null 2>&1 ) || rc=$?
ck "--help → exit 0" "0" "$rc"
rc=0; ( cd "$REPO" && "$REVIEW" --context /no/such/file.md --base master >/dev/null 2>&1 ) || rc=$?
ck "不在 context → exit 2" "2" "$rc"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
