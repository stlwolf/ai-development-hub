#!/usr/bin/env bash
set -euo pipefail

# test_oe_entry.sh — 入口 bin/oe（#605）の検査。plan の T-1〜T-8。
#
# 入口は検査と同じ bash（${BASH}）で起こす。bash 5 と bash 3.2 の両方で回す:
#   bash tests/test_oe_entry.sh
#   /bin/bash tests/test_oe_entry.sh
# 入口が exec したあとの偽の verb は、shebang（#!/usr/bin/env bash）で PATH の先頭の bash で動く。
#
# 偽物の置き方（negative knowledge 01M5T897YCWY13GFTADD3136EC）: 一時ディレクトリに入口の写しと偽の verb
# だけを置いた「偽の engine の bin」を作り、そこへのリンクから呼ぶ。入口は自分の実体のディレクトリしか
# 見ないので、本物の oe-send などには届かない。届かないことは [T-8] で確かめる。本物の engine の bin を
# 使うのは [T-4] の本体の誤りの経路（spawn の前に返る）と、[一覧] の数の突き合わせだけである。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REAL_BIN="$PROJECT_DIR/bin"
ENTRY_SRC="$REAL_BIN/oe"

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
_TMP_DIR="$(cd -P "$_TMP_DIR" && pwd -P)"   # macOS の /var → /private/var をそろえる
export OE_DATA_DIR="$_TMP_DIR/data"         # [T-4] で本体が state/audit を作る先を隔離する

PASS=0; FAIL=0
ck()    { if [[ "$2" == "$3"   ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
cksub() { if [[ "$3" == *"$2"* ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want substr=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
cknot() { if [[ "$3" != *"$2"* ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (unwanted substr=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }

echo "bash: ${BASH} (${BASH_VERSION})"

# ---- 偽の engine の bin ----
FAKE="$_TMP_DIR/fake engine/bin"     # 空白を含むディレクトリ
mkdir -p "$FAKE"
cp "$ENTRY_SRC" "$FAKE/oe"

mkverb() {  # mkverb <name> <本文>（1行目は shebang・2行目は説明）
  local f="$FAKE/oe-$1"
  printf '#!/usr/bin/env bash\n# oe-%s — %s\n%s\n' "$1" "偽の verb $1" "$2" > "$f"
  chmod +x "$f"
}
# shellcheck disable=SC2016  # 本文は展開せずに verb のファイルへ書く
mkverb args  'printf "argc=%s\n" "$#"; for a in "$@"; do printf "<%s>\n" "$a"; done'
mkverb io    'cat | sed "s/^/out:/"; echo "err-line" >&2'
# shellcheck disable=SC2016
mkverb exit  'exit "$1"'
mkverb pid   'echo "$$"'
mkverb pwd   'pwd -P'
mkverb envs  'env | grep -Ev "^(_|SHLVL|OLDPWD)=" | LC_ALL=C sort'
mkverb loop  'while :; do sleep 0.1; done'
mkverb a     'echo one-char'
# 2行目の説明に % を含む（説明を printf の書式にしていないことを見る）
printf '#!/usr/bin/env bash\n# oe-pct — 100%%s done %%d\necho pct\n' > "$FAKE/oe-pct"; chmod +x "$FAKE/oe-pct"
# 説明の行が無い verb
printf '#!/usr/bin/env bash\necho nodesc\n' > "$FAKE/oe-nodesc"; chmod +x "$FAKE/oe-nodesc"
# 候補にならないもの
printf '#!/usr/bin/env bash\necho bak\n' > "$FAKE/oe-foo.bak"; chmod +x "$FAKE/oe-foo.bak"
printf '#!/usr/bin/env bash\necho upper\n' > "$FAKE/oe-Upper"; chmod +x "$FAKE/oe-Upper"
printf '#!/usr/bin/env bash\necho noexec\n' > "$FAKE/oe-noexec"
mkdir "$FAKE/oe-dirverb"
ln -s "$FAKE/does-not-exist" "$FAKE/oe-broken"
ln -s /bin/echo "$FAKE/oe-outlink"
echo "readme" > "$FAKE/README.md"
# 名前 help は入口の help に使うので、oe-help を置いても候補にならない（実装SO の指摘 2）
printf '#!/usr/bin/env bash\n# oe-help — 偽の verb help\necho fake-help\n' > "$FAKE/oe-help"; chmod +x "$FAKE/oe-help"

# 入口へのリンク（~/bin に張られた形）
HOMEBIN="$_TMP_DIR/home/bin"
mkdir -p "$HOMEBIN"
ln -s "$FAKE/oe" "$HOMEBIN/oe"
OE="$HOMEBIN/oe"

RC=0; OUT=""; ERR=""
run() {  # run <入口のパス> [引数...] — 標準出力と標準エラーを分けて受ける
  local entry="$1"; shift
  RC=0
  OUT="$("$BASH" "$entry" "$@" 2>"$_TMP_DIR/stderr")" || RC=$?
  ERR="$(cat "$_TMP_DIR/stderr")"
}

echo "[T-1] リンクの解決"
run "$OE" a
ck "絶対パスのリンク（空白を含むディレクトリへ）" "0:one-char" "$RC:$OUT"
mkdir -p "$_TMP_DIR/rel/bin"
ln -s "../../fake engine/bin/oe" "$_TMP_DIR/rel/bin/oe"
run "$_TMP_DIR/rel/bin/oe" a
ck "相対パスのリンク" "0:one-char" "$RC:$OUT"
( cd "$_TMP_DIR/rel" && "$BASH" bin/oe a ) > "$_TMP_DIR/o" 2>&1 && r=0 || r=$?
ck "相対パスで呼んだ相対パスのリンク" "0:one-char" "$r:$(cat "$_TMP_DIR/o")"
ln -s "$HOMEBIN/oe" "$_TMP_DIR/link2"
ln -s "$_TMP_DIR/link2" "$_TMP_DIR/link3"
run "$_TMP_DIR/link3" a
ck "3段のリンク（既定の上限）" "0:one-char" "$RC:$OUT"
ln -s "$FAKE" "$_TMP_DIR/bindir-link"
run "$_TMP_DIR/bindir-link/oe" a
ck "親のディレクトリが symlink" "0:one-char" "$RC:$OUT"
run "$_TMP_DIR/bindir-link/oe" --help
ck "親のディレクトリが symlink でも help の1行目は実体のパス" "bin: $FAKE" "$(printf '%s\n' "$OUT" | sed -n 1p)"
RC=0; OUT="$(OE_ENTRY_LINK_LIMIT=2 "$BASH" "$_TMP_DIR/link3" a 2>"$_TMP_DIR/stderr")" || RC=$?; ERR="$(cat "$_TMP_DIR/stderr")"
ck    "段の上限を超えると exit 1" "1" "$RC"
cksub "段の上限の誤りは入口の文" "symlink の段が上限（2）を超えました" "$ERR"
ck    "段の上限を超えたら verb を呼ばない" "" "$OUT"

echo "[T-2] 引数・入出力・終了コード・作業ディレクトリ"
nl=$'\n'
run "$OE" args "a b" "" "--opt" "-h" "x${nl}y"
want="argc=5${nl}<a b>${nl}<>${nl}<--opt>${nl}<-h>${nl}<x${nl}y>"
ck "引数の数と中身がそのまま" "$want" "$OUT"
RC=0; OUT="$(printf 'l1\nl2\n' | "$BASH" "$OE" io 2>"$_TMP_DIR/stderr")" || RC=$?; ERR="$(cat "$_TMP_DIR/stderr")"
ck "標準入力が届き、標準出力に返る" "out:l1${nl}out:l2" "$OUT"
ck "標準エラーは分かれたまま" "err-line" "$ERR"
for code in 0 1 2 3 42; do
  run "$OE" exit "$code"
  ck "終了コード ${code} がそのまま" "$code" "$RC"
done
mkdir -p "$_TMP_DIR/caller"
got="$(cd "$_TMP_DIR/caller" && "$BASH" "$OE" pwd)"
ck "verb の作業ディレクトリは呼び出し元のまま" "$_TMP_DIR/caller" "$got"
got="$(cd "$_TMP_DIR/caller" && CDPATH="$_TMP_DIR:." "$BASH" "$OE" pwd)"
ck "CDPATH があっても作業ディレクトリは呼び出し元のまま" "$_TMP_DIR/caller" "$got"
got="$(cd "$_TMP_DIR/caller" && CDPATH="$_TMP_DIR:." "$BASH" "$OE" --help | sed -n 1p)"
ck "CDPATH があっても実体のパスに混ざらない" "bin: $FAKE" "$got"

echo "[T-3] プロセスの受け渡し"
got="$(sh -c 'echo "$$"; exec "$1" "$2" pid' sh "$BASH" "$OE")"
first="$(printf '%s\n' "$got" | sed -n 1p)"; second="$(printf '%s\n' "$got" | sed -n 2p)"
ck "verb の pid は呼び出し元のシェルの pid と同じ（1段も増えない）" "$first" "$second"
direct="$(CLAUDE_PID=4242 TMUX_PANE=%9 CLAUDE_CODE_SESSION_ID=sid-x OE_LEASE_ID=lease-x "$BASH" "$FAKE/oe-envs")"
via="$(CLAUDE_PID=4242 TMUX_PANE=%9 CLAUDE_CODE_SESSION_ID=sid-x OE_LEASE_ID=lease-x "$BASH" "$OE" envs)"
ck "環境変数は直に呼んだときと同じ（入口は足さない）" "$direct" "$via"
# 呼び出し元が、入口の中で使う名前と同じ変数を export していても、そのまま verb に届く（実装SO の指摘 1）
same="dir=caller-dir verb=caller-verb src=caller-src limit=caller-limit n=caller-n target=caller-target name=caller-name f=caller-f desc=caller-desc line2=caller-line2 count=caller-count re=caller-re OE_ENTRY_NAME_RE=caller-re2"
# shellcheck disable=SC2086  # 変数の並びを単語に分けて env に渡す
direct_same="$(env $same "$BASH" "$FAKE/oe-envs")"
# shellcheck disable=SC2086
via_same="$(env $same "$BASH" "$OE" envs)"
ck "入口の中と同じ名前の export 済みの変数も、直に呼んだときと同じ" "$direct_same" "$via_same"
cksub "export 済みの dir は呼び出し元の値のまま" "dir=caller-dir" "$via_same"
cksub "export 済みの verb は呼び出し元の値のまま" "verb=caller-verb" "$via_same"
cksub "CLAUDE_PID が届く" "CLAUDE_PID=4242" "$via"
cksub "TMUX_PANE が届く" "TMUX_PANE=%9" "$via"
cksub "CLAUDE_CODE_SESSION_ID が届く" "CLAUDE_CODE_SESSION_ID=sid-x" "$via"
cksub "OE_LEASE_ID が届く" "OE_LEASE_ID=lease-x" "$via"
"$BASH" "$OE" loop >/dev/null 2>&1 &   # 出力をつながない（入口が exec しない壊れ方で verb が残っても検査が止まらないように）
bg=$!
sleep 0.5
kill -TERM "$bg"
r=0; wait "$bg" || r=$?
ck "verb に送った TERM が verb に届き 143 で終わる" "143" "$r"

echo "[T-4] 本体の移動（本物の engine の bin）"
: > "$_TMP_DIR/caller/empty.md"
run "$REAL_BIN/oe" run --task-file "$_TMP_DIR/caller/empty.md"
ck    "oe run の空の task-file は exit 2" "2" "$RC"
cksub "oe run の空の task-file の誤り" "file is empty" "$ERR"
cksub "誤りの前置きは oe run" "oe run: --task-file" "$ERR"
RC=0; ERR="$(cd "$_TMP_DIR/caller" && "$BASH" "$REAL_BIN/oe" run --task-file empty.md 2>&1 >/dev/null)" || RC=$?
ck    "相対パスの task-file は呼び出し元から解かれる" "2" "$RC"
cksub "相対パスの task-file は見つかる（file is empty）" "file is empty" "$ERR"
run "$REAL_BIN/oe" run --help
cksub "oe run --help は oe run の使い方" "usage: oe run" "$ERR"

echo "[T-5] 一覧と help"
run "$OE"
ck    "引数なしは exit 2" "2" "$RC"
ck    "引数なしは標準出力に出さない" "" "$OUT"
cksub "引数なしは標準エラーに一覧" "verbs:" "$ERR"
for h in -h --help help; do
  run "$OE" "$h"
  ck    "$h は exit 0" "0" "$RC"
  ck    "$h の1行目は実体のパス" "bin: $FAKE" "$(printf '%s\n' "$OUT" | sed -n 1p)"
done
LIST="$(printf '%s\n' "$OUT" | sed -n '/^verbs:/,/^$/p')"
for v in args io exit pid a pct nodesc; do
  cksub "一覧に $v" "  $(printf '%-16s' "$v")" "$LIST"
done
for v in foo.bak Upper noexec dirverb broken outlink README oe help; do
  cknot "一覧に $v を出さない" " ${v} " "$LIST"
done
cksub "説明が出る" "偽の verb args" "$LIST"
run "$OE" help
ck "oe-help を置いても oe help は入口の help（偽の verb を呼ばない）" "0:bin: $FAKE" "$RC:$(printf '%s\n' "$OUT" | sed -n 1p)"
cksub "説明の % は書式にならない" "100%s done %d" "$LIST"
for extra in "help send" "--help send"; do
  # shellcheck disable=SC2086
  run "$OE" $extra
  ck "oe ${extra} は exit 2" "2" "$RC"
done
EMPTY="$_TMP_DIR/empty-bin"; mkdir -p "$EMPTY"; cp "$ENTRY_SRC" "$EMPTY/oe"
run "$EMPTY/oe" --help
ck    "候補が0件でも exit 0" "0" "$RC"
cksub "候補が0件の知らせ" "verb がありません" "$OUT"
# 本物の engine の bin: 一覧の数が、実行できる oe-* のファイルの数と同じ（どの verb も名前の検査を通る）
run "$REAL_BIN/oe" --help
n_list="$(printf '%s\n' "$OUT" | sed -n '/^verbs:/,/^$/p' | grep -c '^  [a-z0-9]')"
n_files=0; for f in "$REAL_BIN"/oe-*; do [ -f "$f" ] && [ -x "$f" ] && n_files=$((n_files+1)); done
ck "本物の bin の一覧の数は oe-* の数と同じ" "$n_files" "$n_list"
cksub "本物の bin の一覧に run" "  $(printf '%-16s' run)" "$OUT"

echo "[T-6] 誤り"
run "$OE" a
ck "1文字の名前は呼べる" "0:one-char" "$RC:$OUT"
for bad in nosuch "../x" "a/b" "abc/def" "ab/../../x" "a${nl}b" "Upper" "foo.bak" ""; do
  run "$OE" "$bad"
  ck    "'${bad}' は exit 127" "127" "$RC"
  cksub "'${bad}' は no such verb" "no such verb" "$ERR"
done
run "$OE" oe-args
ck    "前置き付きは exit 127" "127" "$RC"
cksub "前置き付きは案内付き" "oe args と打ちます" "$ERR"
for opt in -x --nope -; do
  run "$OE" "$opt"
  ck "知らないオプション ${opt} は exit 2" "2" "$RC"
done

echo "[T-7] 足すだけで呼べる"
run "$OE" newverb
ck "足す前は exit 127" "127" "$RC"
mkverb newverb 'echo added'
run "$OE" newverb
ck "oe-newverb を足すと呼べる" "0:added" "$RC:$OUT"
run "$OE" --help
cksub "足した verb が一覧に出る" "  $(printf '%-16s' newverb)" "$OUT"

echo "[T-8] 本物に届かない"
run "$OE" send
ck "偽の bin へのリンクから oe send は exit 127（本物の oe-send を呼ばない）" "127" "$RC"
RC=0; PATH="$REAL_BIN:$PATH" "$BASH" "$OE" send >/dev/null 2>&1 || RC=$?
ck "PATH の先頭に本物の bin を置いても exit 127" "127" "$RC"

echo "[T-10] 配布（scripts/sync/sync-bin.sh を一時的な HOME で走らせる）"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
SYNC_BIN="$REPO_ROOT/scripts/sync/sync-bin.sh"
if [ -f "$SYNC_BIN" ]; then
  list="$(bash "$SYNC_BIN" --list)"
  cksub "--list に oe が出る" "${nl}oe${nl}" "${nl}${list}${nl}"
  cksub "--list に互換の oe-tree が残る" "${nl}oe-tree${nl}" "${nl}${list}${nl}"
  cksub "--list に互換の oe-hookfire が残る" "${nl}oe-hookfire${nl}" "${nl}${list}${nl}"
  SYNC_HOME="$_TMP_DIR/sync-home"; mkdir -p "$SYNC_HOME"
  r=0; HOME="$SYNC_HOME" bash "$SYNC_BIN" >/dev/null 2>&1 || r=$?
  ck "配置は exit 0" "0" "$r"
  ck "配布先の bin/oe は symlink（写しでない）" "true" "$([ -L "$SYNC_HOME/bin/oe" ] && echo true || echo false)"
  ck "配布先の bin/oe は engine の bin/oe を指す" "$(cd -P "$REAL_BIN" && pwd -P)/oe" "$(readlink "$SYNC_HOME/bin/oe")"
  r=0; HOME="$SYNC_HOME" bash "$SYNC_BIN" --check >/dev/null 2>&1 || r=$?
  ck "--check は全件一致" "0" "$r"
  run "$SYNC_HOME/bin/oe" --help
  ck "配布先の bin/oe から help の1行目は engine の bin" "bin: $(cd -P "$REAL_BIN" && pwd -P)" "$(printf '%s\n' "$OUT" | sed -n 1p)"
  run "$SYNC_HOME/bin/oe" run --help
  cksub "配布先の bin/oe から verb（oe run --help）が動く" "usage: oe run" "$ERR"
else
  echo "  SKIP: $SYNC_BIN が無い（engine を hub の外で回している）"
fi

echo ""
echo "RESULT: pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
