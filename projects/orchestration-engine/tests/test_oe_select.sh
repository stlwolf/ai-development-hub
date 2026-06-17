#!/usr/bin/env bash
set -uo pipefail

# test_oe_select.sh — oe-select の宛先選択 / pane id 抽出 / oe-send 素通しを検証する
#
# 実 tmux / fzf / oe-send は起動せず、すべて mock する:
#   - tmux: PATH 先頭の mock。list-panes は $MOCK_LIVE_PANES を返す
#   - jq:   PATH 先頭の mock（delegate-registry.sh が要求するため）。
#           pane-issue / spawn-registry を使わず pane-title 経路に倒すため空を返す
#   - fzf:  ある/無いをテストごとに切替（FZF_PRESENT）。あるときは固定行を返す
#   - oe-send: BIN_DIR 隣の stub（exec で呼ばれる）。引数を log に記録する
#
# oe-select は BIN_DIR="$(dirname "$0")" 隣の oe-send を exec する。実体ではなく
# テスト用 bin/ に oe-select をコピーし、隣に stub oe-send を置くことで素通しを観測する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
mkdir -p "$_TMP_DIR/bin" "$_TMP_DIR/lib" "$_TMP_DIR/pathbin" "$_TMP_DIR/logs"

# oe-select をテスト用 bin/ にコピー。lib/ は実体を symlink（delegate-registry.sh を共有）。
cp "$PROJECT_DIR/bin/oe-select" "$_TMP_DIR/bin/oe-select"
chmod +x "$_TMP_DIR/bin/oe-select"
ln -s "$PROJECT_DIR/lib/delegate-registry.sh" "$_TMP_DIR/lib/delegate-registry.sh"

# stub oe-send: 受けた全引数を 1 行ずつ log に記録する（送信はしない）。
cat > "$_TMP_DIR/bin/oe-send" <<'EOF'
#!/usr/bin/env bash
log="${OE_SELECT_TEST_LOG_DIR:?}/oe-send-args.log"
: > "$log"
for a in "$@"; do
  printf '%s\n' "$a" >> "$log"
done
exit 0
EOF
chmod +x "$_TMP_DIR/bin/oe-send"

# mock tmux: list-panes は $MOCK_LIVE_PANES（空白区切り）を返す。
cat > "$_TMP_DIR/pathbin/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "list-panes -a"|"list-panes"*)
    # shellcheck disable=SC2086
    printf '%s\n' ${MOCK_LIVE_PANES:-} ;;
  "display-message"*) printf 'mock-pane-title\n' ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$_TMP_DIR/pathbin/tmux"

# mock jq: delegate-registry.sh は pane-issue/spawn JSON を jq で引く。
# fixture を本物の jq 同様に解釈するのは過剰なので、ここでは「pane-issue ファイルから
# .name を引く呼び出し」だけ最小実装する。引数末尾のファイルから JSON 風 "name" を取り出す。
# それ以外（spawn ラベル等）は空を返し pane-title 経路へ倒す。
cat > "$_TMP_DIR/pathbin/jq" <<'EOF'
#!/usr/bin/env bash
# 末尾引数をファイル候補とみなす。filter に .name が含まれ、ファイルがあれば name を返す。
filter=""
file=""
prev=""
for a in "$@"; do
  case "$a" in
    .name*|*'.name'*) filter="name" ;;
  esac
  prev="$file"; file="$a"
done
if [[ "$filter" == "name" && -f "$file" ]]; then
  # 雑な抽出: "name":"<...>" の値を取り出す（fixture は単純な 1 行 JSON 前提）。
  sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file"
  exit 0
fi
printf ''
exit 0
EOF
chmod +x "$_TMP_DIR/pathbin/jq"

# mock fzf: FZF_PRESENT=1 のときのみ存在。$FZF_PICK_PANE に一致する行を返す。
make_fzf() {
  cat > "$_TMP_DIR/pathbin/fzf" <<'EOF'
#!/usr/bin/env bash
# stdin から候補を受け、$FZF_PICK_PANE（first-token 一致）の行を返す。
# FZF_CANCEL=1 なら非 0 で抜ける（ESC 相当）。
if [[ -n "${FZF_CANCEL:-}" ]]; then exit 130; fi
pick="${FZF_PICK_PANE:-}"
while IFS= read -r line; do
  tok="$(printf '%s\n' "$line" | awk '{print $1}')"
  if [[ "$tok" == "$pick" ]]; then printf '%s\n' "$line"; exit 0; fi
done
exit 1
EOF
  chmod +x "$_TMP_DIR/pathbin/fzf"
}
rm_fzf() { rm -f "$_TMP_DIR/pathbin/fzf"; }

# 隔離 state（delegate-registry.sh が参照。空ディレクトリにして pane-title 経路へ）。
export OE_DELEGATE_STATE_DIR; OE_DELEGATE_STATE_DIR="$_TMP_DIR/state"
export OE_PANE_ISSUE_DIR;     OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
mkdir -p "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"

# 厳選 PATH: mock の tmux/jq（pathbin）+ システム実体（awk/sed/cat/env/bash）。
# 実 fzf（/opt/homebrew/bin）は意図的に除外する。これにより `command -v fzf` は
# pathbin に mock fzf がある時だけ成功し、make_fzf / rm_fzf で fzf の有無を切替できる。
export PATH="${_TMP_DIR}/pathbin:/usr/bin:/bin"
export TMUX="/tmp/mock-tmux,12345,0"
export OE_SELECT_TEST_LOG_DIR="$_TMP_DIR/logs"

# 番号 read / message read のための tty シーム。テストごとに入力をファイルへ書いて差し替える。
# /dev/tty は非対話環境で開けないため、OE_SELECT_TTY でファイルを指す。
TTY_FILE="$_TMP_DIR/tty-input"
export OE_SELECT_TTY="$TTY_FILE"
feed_tty() { printf '%s\n' "$1" > "$TTY_FILE"; }   # 1 行入力
feed_tty_empty() { : > "$TTY_FILE"; }              # 空入力（即 EOF）

SEL="$_TMP_DIR/bin/oe-select"

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

send_log() { cat "$_TMP_DIR/logs/oe-send-args.log" 2>/dev/null; }
reset_send_log() { rm -f "$_TMP_DIR/logs/oe-send-args.log"; }

# ----------------------------------------------------------------------------
# [1] fzf 経路: 空白ラベル行から first-token %5 を抽出し、--print で stdout に %5 のみ
# ----------------------------------------------------------------------------
echo "[1] fzf --print: 空白ラベル行 '#142 redesign' から first-token %5 抽出 / stdout は %N のみ"
make_fzf
export MOCK_LIVE_PANES="%1 %5 %7"
export TMUX_PANE="%1"
# %5 に空白を含む pane-issue ラベル "#142 redesign" を fixture として直挿しする。
# server pid = 12345（$TMUX の 2 番目）、key = "12345_%5" の非英数を _ に → 12345__5。
printf '{"name":"#142 redesign"}\n' > "${OE_PANE_ISSUE_DIR}/12345__5"
# 一覧行は "%5     pane-issue     #142 redesign"。fzf がこの行を返す → first-token %5。
export FZF_PICK_PANE="%5"
out="$("$SEL" --print 2>/dev/null)"; rc=$?
ck "rc=0" "0" "$rc"
ck "空白ラベル行から first-token %5 を抽出し stdout は %5 のみ" "%5" "$out"
rm -f "${OE_PANE_ISSUE_DIR}/12345__5"

# ----------------------------------------------------------------------------
# [2] 自ペイン既定除外 / --include-self で含む
# ----------------------------------------------------------------------------
echo "[2] 自ペイン既定除外 / --include-self"
make_fzf
export MOCK_LIVE_PANES="%1 %5"
export TMUX_PANE="%1"
# 既定では %1（self）は候補から除外 → fzf が %1 を選ぼうとしても候補に無い → 非 0 → cancel(130)
export FZF_PICK_PANE="%1"
rc=0; "$SEL" --print >/dev/null 2>&1 || rc=$?
ck "self(%1) は既定で候補外 → 選べず cancel(130)" "130" "$rc"
# --include-self では %1 が候補に入る → 選べる
rc=0; out="$("$SEL" --include-self --print 2>/dev/null)" || rc=$?
ck "--include-self rc=0" "0" "$rc"
ck "--include-self で self(%1) を選べる" "%1" "$out"

# ----------------------------------------------------------------------------
# [3] 候補 0 件 → exit 1
# ----------------------------------------------------------------------------
echo "[3] 候補 0 件 → exit 1"
make_fzf
export MOCK_LIVE_PANES="%1"   # self のみ → 既定除外で 0 件
export TMUX_PANE="%1"
rc=0; "$SEL" --print >/dev/null 2>&1 || rc=$?
ck "candidates empty → exit 1" "1" "$rc"

# ----------------------------------------------------------------------------
# [4] fzf 無しの番号フォールバック: 空白ラベル行から %5 抽出、oe-send へ正しい引数
#     空白ラベル fixture（"#142 redesign"）を pane-issue state に直挿しして検証する。
# ----------------------------------------------------------------------------
echo "[4] fzf 無し 番号フォールバック: 番号 1 → %5、oe-send へ正しい引数で素通し"
rm_fzf
export MOCK_LIVE_PANES="%5 %7"
export TMUX_PANE="%9"   # self は候補外（候補は %5 %7）
reset_send_log
feed_tty "1"            # 番号 1 → 1 行目（%5）を選択
"$SEL" "go ahead" >/dev/null 2>&1
log="$(send_log)"
ck "oe-send 引数に -- 含む" "yes" "$(printf '%s\n' "$log" | grep -qxF -- '--' && echo yes || echo no)"
ck "oe-send に %5 が渡る"   "yes" "$(printf '%s\n' "$log" | grep -qxF -- '%5' && echo yes || echo no)"
ck "oe-send に message が渡る" "yes" "$(printf '%s\n' "$log" | grep -qxF -- 'go ahead' && echo yes || echo no)"

# ----------------------------------------------------------------------------
# [4b] 空白ラベル行の first-token 抽出（純粋な抽出ロジック）を独立に確認する。
#      oe-select の抽出は `awk '{print $1}'` なので "%5 pane-issue #142 redesign" から %5。
# ----------------------------------------------------------------------------
echo "[4b] 番号フォールバックでも空白ラベル行 '#142 redesign' から %5 を抽出（end-to-end）"
rm_fzf
export MOCK_LIVE_PANES="%5 %7"
export TMUX_PANE="%9"
printf '{"name":"#142 redesign"}\n' > "${OE_PANE_ISSUE_DIR}/12345__5"
feed_tty "1"   # 1 行目（%5、ラベル "#142 redesign"）を選択
out="$("$SEL" --print 2>/dev/null)"; rc=$?
ck "rc=0" "0" "$rc"
ck "空白ラベル行から %5 を抽出（first-token）" "%5" "$out"
rm -f "${OE_PANE_ISSUE_DIR}/12345__5"

# ----------------------------------------------------------------------------
# [5] 番号フォールバック: 非数値 → exit 2 / 範囲外 → exit 2 / 空 → 130
# ----------------------------------------------------------------------------
echo "[5] 番号フォールバック: 非数値/範囲外/空 の扱い"
rm_fzf
export MOCK_LIVE_PANES="%5 %7"
export TMUX_PANE="%9"
feed_tty "abc"; rc=0; "$SEL" "m" >/dev/null 2>&1 || rc=$?
ck "非数値 → exit 2" "2" "$rc"
feed_tty "99"; rc=0; "$SEL" "m" >/dev/null 2>&1 || rc=$?
ck "範囲外 → exit 2" "2" "$rc"
feed_tty_empty; rc=0; "$SEL" "m" >/dev/null 2>&1 || rc=$?
ck "空入力 → cancel 130" "130" "$rc"

# ----------------------------------------------------------------------------
# [6] fzf 無し --print: 番号選択 → stdout に %N のみ（プロンプトは stderr）
# ----------------------------------------------------------------------------
echo "[6] fzf 無し --print: stdout は %N のみ"
rm_fzf
export MOCK_LIVE_PANES="%5 %7"
export TMUX_PANE="%9"
feed_tty "2"
out="$("$SEL" --print 2>/dev/null)"; rc=$?
ck "rc=0" "0" "$rc"
ck "番号 2 → %7 を stdout に" "%7" "$out"

# ----------------------------------------------------------------------------
# [7] --print と message 併用 → exit 2
# ----------------------------------------------------------------------------
echo "[7] --print と message / --no-enter / --kickoff 併用 → exit 2"
make_fzf
export MOCK_LIVE_PANES="%5 %7"
export TMUX_PANE="%9"
export FZF_PICK_PANE="%5"
rc=0; "$SEL" --print "a message" >/dev/null 2>&1 || rc=$?
ck "--print + message → exit 2" "2" "$rc"
rc=0; "$SEL" --print --no-enter >/dev/null 2>&1 || rc=$?
ck "--print + --no-enter → exit 2" "2" "$rc"
rc=0; "$SEL" --print --kickoff /tmp/k.md >/dev/null 2>&1 || rc=$?
ck "--print + --kickoff → exit 2" "2" "$rc"

# ----------------------------------------------------------------------------
# [8] fzf キャンセル（ESC 相当）→ exit 130、送信も出力もしない
# ----------------------------------------------------------------------------
echo "[8] fzf キャンセル → exit 130（送信なし）"
make_fzf
export MOCK_LIVE_PANES="%5 %7"
export TMUX_PANE="%9"
reset_send_log
export FZF_CANCEL=1
rc=0; out="$("$SEL" "m" 2>/dev/null)" || rc=$?
unset FZF_CANCEL
ck "fzf cancel → exit 130" "130" "$rc"
ck "送信されない（oe-send log なし）" "no" "$( [[ -e "$_TMP_DIR/logs/oe-send-args.log" ]] && echo yes || echo no )"

# ----------------------------------------------------------------------------
# [9] passthrough: --no-enter / --kickoff が oe-send に渡る（送信モード）
# ----------------------------------------------------------------------------
echo "[9] passthrough: --no-enter / --kickoff が oe-send に渡る"
make_fzf
export MOCK_LIVE_PANES="%5 %7"
export TMUX_PANE="%9"
export FZF_PICK_PANE="%5"
reset_send_log
"$SEL" --no-enter --kickoff /tmp/k.md "task text" >/dev/null 2>&1
log="$(send_log)"
ck "oe-send に --no-enter" "yes" "$(printf '%s\n' "$log" | grep -qxF -- '--no-enter' && echo yes || echo no)"
ck "oe-send に --kickoff"  "yes" "$(printf '%s\n' "$log" | grep -qxF -- '--kickoff' && echo yes || echo no)"
ck "oe-send に kickoff path" "yes" "$(printf '%s\n' "$log" | grep -qxF -- '/tmp/k.md' && echo yes || echo no)"
ck "oe-send に %5"         "yes" "$(printf '%s\n' "$log" | grep -qxF -- '%5' && echo yes || echo no)"
ck "oe-send に task text"  "yes" "$(printf '%s\n' "$log" | grep -qxF -- 'task text' && echo yes || echo no)"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
