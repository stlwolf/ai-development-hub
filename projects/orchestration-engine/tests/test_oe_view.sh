#!/usr/bin/env bash
set -uo pipefail

# test_oe_view.sh — oe-view（md=glow viewer / 非md=open）の判定・注入安全化（argv-spawn）・
# allowlist・サニタイズ・viewer replace・degrade・--json を検証する（#210）。
#
# DJ-4/§11: 既定 md 経路は「split したシェルへ glow を send」から「ペインのプログラムとして
# glow を直接 argv-spawn する replace モデル」に改定済。検証も `wez pane split … -- glow -p
# -- <path>` の引数列（PROG が argv で渡る）と replace（同じ GUI のプロセスの viewer と確かめ
# られたときだけ kill→spawn・確かめられないときは閉じずに spawn・#509）を見る。
#
# 実 wez/glow/open は呼ばず PATH 先頭 mock に差し替える（test_oe_jump.sh / test_pane_split_targeting.sh
# と同型）:
#   - wez:  全呼び出しを wez.log に記録（$* を 1 行）。`wez discover --quiet` は $MOCK_SOCKET を返す
#           （$MOCK_DISCOVER_RC が 0 でなければその値で失敗）。`wez pane [--socket <S>] list` は
#           $MOCK_PANE_LIST_JSON、`wez pane [--socket <S>] split` は $MOCK_SPLIT_PANE_ID を返す。
#           kill/activate は引数を log に記録。
#   - ps:   `ps -o lstart= -p <N>` に $MOCK_LSTART_<N> を末尾の空白つきで返す（無ければ失敗）。
#           $MOCK_PS_FAIL=1 なら必ず失敗する。$MOCK_PS_OK_CALLS=<N> なら N 回目より後は失敗する。
#           #509 の「同じ GUI のプロセスか」の照合に使う。
#   - glow: 引数を glow.log に記録（--here の glow -p / 既存 fallback 検証用）。
#   - open: 引数を open.log に記録。
#   - bat:  引数を bat.log に記録（--here の glow 不在フォールバック検証用）。
#   各 shim の在/不在をテストごとに切り替えるため shim は専用ディレクトリに置き、PATH 先頭の
#   "$_TMP_DIR/pathbin" へ symlink を張る/外すで「不在」を再現する。
#
# oe-view は BIN_DIR/../lib/oe-viewer.sh を source する。テスト用 bin/ に oe-view をコピーし、
# lib/ に実体を symlink して共有する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

_TMP_DIR="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
[[ -n "$_TMP_DIR" && -d "$_TMP_DIR" ]] || { echo "FATAL: mktemp -d returned an invalid path: '${_TMP_DIR}'" >&2; exit 1; }
trap 'rm -rf "$_TMP_DIR"' EXIT
mkdir -p "$_TMP_DIR/bin" "$_TMP_DIR/lib" "$_TMP_DIR/pathbin" "$_TMP_DIR/shimsrc" "$_TMP_DIR/logs" "$_TMP_DIR/docroot/sub" "$_TMP_DIR/outside"

cp "$PROJECT_DIR/bin/oe-view" "$_TMP_DIR/bin/oe-view"
chmod +x "$_TMP_DIR/bin/oe-view"
ln -s "$PROJECT_DIR/lib/oe-viewer.sh" "$_TMP_DIR/lib/oe-viewer.sh"

export OE_VIEW_TEST_LOG_DIR="$_TMP_DIR/logs"

# --- mock 実体（shimsrc）。pathbin への symlink 有無で「在/不在」を切り替える ---
cat > "$_TMP_DIR/shimsrc/wez" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${OE_VIEW_TEST_LOG_DIR:?}/wez.log"
if [[ "${1:-}" == "discover" ]]; then
  [[ "${MOCK_DISCOVER_RC:-0}" -eq 0 ]] || exit "${MOCK_DISCOVER_RC}"
  printf '%s\n' "${MOCK_SOCKET:?}"
  exit 0
fi
[[ "${1:-}" == "pane" ]] || exit 0
shift
if [[ "${1:-}" == "--socket" ]]; then shift 2; fi
case "${1:-}" in
  list)     printf '%s\n' "${MOCK_PANE_LIST_JSON:-[]}" ;;
  split)    printf '%s\n' "${MOCK_SPLIT_PANE_ID:-9}" ;;
  *)        exit 0 ;;
esac
EOF
cat > "$_TMP_DIR/shimsrc/ps" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${OE_VIEW_TEST_LOG_DIR:?}/ps.log"
[[ "${MOCK_PS_FAIL:-0}" == "1" ]] && exit 1
# MOCK_PS_OK_CALLS=<N> なら、N 回目までだけ答え、それより後の呼び出しは失敗する。
if [[ -n "${MOCK_PS_OK_CALLS:-}" ]]; then
  calls="$(wc -l < "${OE_VIEW_TEST_LOG_DIR:?}/ps.log" | tr -d ' ')"
  [[ "$calls" -le "$MOCK_PS_OK_CALLS" ]] || exit 1
fi
pid=""
while [[ $# -gt 0 ]]; do
  case "$1" in -p) pid="${2:-}"; shift ;; esac
  shift
done
[[ "$pid" =~ ^[0-9]+$ ]] || exit 1
var="MOCK_LSTART_${pid}"
val="${!var:-}"
[[ -n "$val" ]] || exit 1
printf '%s    \n' "$val"
EOF
cat > "$_TMP_DIR/shimsrc/glow" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${OE_VIEW_TEST_LOG_DIR:?}/glow.log"
EOF
cat > "$_TMP_DIR/shimsrc/open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${OE_VIEW_TEST_LOG_DIR:?}/open.log"
EOF
cat > "$_TMP_DIR/shimsrc/bat" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${OE_VIEW_TEST_LOG_DIR:?}/bat.log"
EOF
chmod +x "$_TMP_DIR/shimsrc/wez" "$_TMP_DIR/shimsrc/ps" "$_TMP_DIR/shimsrc/glow" "$_TMP_DIR/shimsrc/open" "$_TMP_DIR/shimsrc/bat"

# 厳選 PATH: mock（pathbin）+ システム最小（/usr/bin:/bin・awk/sed/grep/cat/head 等）。
# 実 wez/glow/open/bat を確実に除外する（/usr/bin/open・homebrew bat・~/bin/wez の漏れ防止。
# test_oe_jump.sh と同型）。realpath / jq は実体を pathbin に symlink して常時供給する
# （macOS 標準に realpath が無く、本テストは canonical 前提＝allowlist/送信パスのため必須）。
export PATH="${_TMP_DIR}/pathbin:/usr/bin:/bin"
_link_real() {  # <name> — 実体を探して pathbin に symlink（無ければ FATAL）
  local name="$1" p
  for p in /opt/homebrew/bin /usr/local/bin /usr/bin /bin; do
    if [[ -x "$p/$name" ]]; then ln -sf "$p/$name" "$_TMP_DIR/pathbin/$name"; return 0; fi
  done
  echo "FATAL: required tool '$name' not found for test isolation" >&2; exit 1
}
_link_real realpath
_link_real jq

# 各 shim の在/不在を切り替える。
shim_on()  { ln -sf "$_TMP_DIR/shimsrc/$1" "$_TMP_DIR/pathbin/$1"; }
shim_off() { rm -f "$_TMP_DIR/pathbin/$1"; }
all_shims_on() { shim_on wez; shim_on ps; shim_on glow; shim_on open; shim_on bat; }

# 隔離 state / allowlist root。
export OE_VIEW_STATE_DIR="$_TMP_DIR/oe-view-state"
export OE_VIEW_ROOTS="$_TMP_DIR/docroot"
export WEZTERM_PANE="3"            # source pane（activate-back 検証）
export MOCK_PANE_LIST_JSON="[]"
export MOCK_SPLIT_PANE_ID="9"

# WezTerm のソケットの fixtures（#509）。GUI のソケットは gui-sock-<GUI のプロセス番号>。
# 中身は使わないので通常のファイルで代える。mktemp の /var は /private/var への symlink なので、
# 記録に書かれる値（実体のパス）は realpath で求めておく。
SOCK_DIR="$_TMP_DIR/wsock"
mkdir -p "$SOCK_DIR"
: > "$SOCK_DIR/gui-sock-100"
: > "$SOCK_DIR/gui-sock-200"
: > "$SOCK_DIR/sock"                         # mux サーバのソケット（名前にプロセス番号が無い）
ln -s gui-sock-100 "$SOCK_DIR/default-org"   # GUI のソケットを指す symlink
ln -s sock "$SOCK_DIR/link-to-sock"          # 名前にプロセス番号の無いソケットを指す symlink
S100="$(realpath "$SOCK_DIR/gui-sock-100")"
S200="$(realpath "$SOCK_DIR/gui-sock-200")"
SMUX="$(realpath "$SOCK_DIR/sock")"
T1="Tue Nov 18 10:00:00 2026"
T2="Wed Nov 19 08:30:00 2026"
export MOCK_SOCKET="$SOCK_DIR/gui-sock-100"
export MOCK_LSTART_100="$T1"
export MOCK_LSTART_200="$T2"
export MOCK_DISCOVER_RC=0
export MOCK_PS_FAIL=0

VIEW="$_TMP_DIR/bin/oe-view"

# fixtures。
MD_IN_ROOT="$_TMP_DIR/docroot/sub/plan.md"            # allowlist 内 md
MD_INJECT="$_TMP_DIR/docroot/sub/a\$(whoami).md"      # 注入メタ文字名（実在 md・allowlist 内）
TXT_IN_ROOT="$_TMP_DIR/docroot/sub/note.txt"          # 非 md
MD_OUTSIDE="$_TMP_DIR/outside/leak.md"                # allowlist 外 md
printf '# plan\n'  > "$MD_IN_ROOT"
printf '# inject\n' > "$MD_INJECT"
printf 'plain\n'   > "$TXT_IN_ROOT"
printf '# leak\n'  > "$MD_OUTSIDE"

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
reset_logs() { rm -f "$_TMP_DIR/logs/"*.log; }
reset_state() { rm -rf "$OE_VIEW_STATE_DIR"; }
wez_log()  { cat "$_TMP_DIR/logs/wez.log"  2>/dev/null; }
glow_log() { cat "$_TMP_DIR/logs/glow.log" 2>/dev/null; }
open_log() { cat "$_TMP_DIR/logs/open.log" 2>/dev/null; }
bat_log()  { cat "$_TMP_DIR/logs/bat.log"  2>/dev/null; }
has_line() { printf '%s\n' "$1" | grep -qF -- "$2" && echo yes || echo no; }
# has_sub <log> <sub と引数> — `wez pane [--socket <S>] <sub と引数>` の行があるか（#509 で
# すべての pane の呼び出しに --socket が付くので、付いていても付いていなくても数える）。
has_sub() { printf '%s\n' "$1" | grep -qE -- "^pane( --socket [^ ]+)? $2( |\$)" && echo yes || echo no; }
# pane_lines_without_socket <log> <S> — `--socket <S>` を付けずに呼んだ pane の行の数。
pane_lines_without_socket() {
  printf '%s\n' "$1" | grep -E '^pane ' | grep -cvF -- "pane --socket $2 " || true
}
# 記録（#509 の新しい形・key=value の3行）を置く / 読む。
write_rec() { mkdir -p "$OE_VIEW_STATE_DIR"; printf '%s' "$1" > "$OE_VIEW_STATE_DIR/viewer-pane-id"; }
good_rec() { printf 'pane_id=%s\nsocket=%s\nmux_started=%s\n' "$1" "$2" "$3"; }
rec_get() { sed -n "s/^$1=//p" "$OE_VIEW_STATE_DIR/viewer-pane-id" 2>/dev/null | head -n 1; }
rec_exists() { [[ -e "$OE_VIEW_STATE_DIR/viewer-pane-id" ]] && echo yes || echo no; }
# reset_mocks — #509 の照合に関わる mock の値を既定に戻す。
reset_mocks() {
  export MOCK_SOCKET="$SOCK_DIR/gui-sock-100" MOCK_LSTART_100="$T1" MOCK_LSTART_200="$T2"
  export MOCK_DISCOVER_RC=0 MOCK_PS_FAIL=0 WEZTERM_PANE="3"
  unset MOCK_PS_OK_CALLS
}

# ----------------------------------------------------------------------------
# [1] md 既定 → viewer 解決（state 無し=spawn）。glow を argv で渡す。新規時 source(3) へ activate。
#     argv-spawn replace モデル: `wez pane split … -- glow -p -- <path>`（PROG が argv で渡る）。
# ----------------------------------------------------------------------------
echo "[1] md 既定 → spawn（-- glow -p -- <path>）+ activate(source)"
all_shims_on; reset_state; reset_logs
export MOCK_PANE_LIST_JSON="[]"; export MOCK_SPLIT_PANE_ID="9"
rc=0; "$VIEW" -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
log="$(wez_log)"
ck "rc=0" "0" "$rc"
ck "pane split が呼ばれる"               "yes" "$(has_sub "$log" 'split')"
# PROG が argv で渡る: split 行に "-- glow -p --" と canonical path が含まれる（送信文字列でない）。
ck "split に PROG (-- glow -p --)"        "yes" "$(has_line "$log" '-- glow -p --')"
ck "split に対象 md path が argv で渡る"  "yes" "$(has_line "$log" "$MD_IN_ROOT")"
ck "source(3) へ activate（#111）"        "yes" "$(has_sub "$log" 'activate 3')"
ck "pane send は呼ばれない（argv-spawn）" "no"  "$(has_sub "$log" 'send')"
ck "state 無し→kill されない"            "no"  "$(has_sub "$log" 'kill')"
ck "記録に新 pane 9 が書かれる"          "9"   "$(rec_get pane_id)"
ck "pane の呼び出しはすべて --socket <実体のパス>（初回）" "0" "$(pane_lines_without_socket "$log" "$S100")"

# ----------------------------------------------------------------------------
# [2] 注入: メタ文字名 'a$(whoami).md' が **argv 要素**として渡る（shell 非経由・%q 不要）。
#     argv-spawn では送信文字列を一切組まないため、path は `wez pane split … -- glow -p --
#     <path>` の引数としてリテラルに渡る。受信シェルで再トークナイズされないので注入面が無い。
#     mock wez は受け取った引数値（$*）をそのまま記録するため、リテラル 'a$(whoami).md' が
#     split 行に現れ、`pane send` 経路は存在しない（送信文字列を組まないことの証跡）。
# ----------------------------------------------------------------------------
echo "[2] 注入: path が argv 要素として渡る（送信文字列を組まない・shell 非経由）"
all_shims_on; reset_state; reset_logs
export MOCK_PANE_LIST_JSON="[]"; export MOCK_SPLIT_PANE_ID="9"
rc=0; "$VIEW" -- "$MD_INJECT" >/dev/null 2>&1 || rc=$?
log="$(wez_log)"
ck "rc=0" "0" "$rc"
# path はメタ文字を含むファイル名そのもの。argv で渡るのでリテラルが split 行に在る。
split_line="$(printf '%s\n' "$log" | grep -E '^pane( --socket [^ ]+)? split ' || true)"
# shellcheck disable=SC2016  # 単一引用は grep -F のリテラルパターン（展開させない）
ck "split 行に 'a\$(whoami).md' が argv で渡る" "yes" \
  "$(printf '%s\n' "$split_line" | grep -qF 'a$(whoami).md' && echo yes || echo no)"
# 送信文字列を組む経路（pane send）が存在しないこと＝再トークナイズ面が無いことの証跡。
ck "pane send は呼ばれない（注入面なし）" "no" "$(has_sub "$log" 'send')"

# ----------------------------------------------------------------------------
# [3] viewer replace: 記録の viewer が同じ GUI のプロセスにある → kill → 新 glow ペインを spawn → 記録の更新。
#     glow -p はページャ（シェルでない）ため send 再利用できず、毎回 replace する（DJ-4）。
#     #509: 閉じるのは、記録のソケット・GUI のプロセスの開始時刻が今と同じで、番号が list に
#     あるときだけ。1回の resolve の中の pane の呼び出しは、すべて同じ --socket に固定する。
# ----------------------------------------------------------------------------
echo "[3] replace: 同じ GUI の viewer 7 → kill 7 → spawn（新 pane 9）・すべて --socket 固定"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(good_rec 7 "$S100" "$T1")"
export MOCK_PANE_LIST_JSON='[{"pane_id":7,"is_active":true}]'
export MOCK_SPLIT_PANE_ID="9"
rc=0; "$VIEW" -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
log="$(wez_log)"
ck "rc=0" "0" "$rc"
ck "pane list で生存確認"      "yes" "$(has_sub "$log" 'list')"
ck "生存 viewer 7 を kill"     "yes" "$(has_sub "$log" 'kill 7')"
ck "kill は1回だけ"            "1"   "$(printf '%s\n' "$log" | grep -cE '^pane( --socket [^ ]+)? kill ' || true)"
ck "新 glow ペインを spawn"    "yes" "$(has_sub "$log" 'split')"
ck "source(3) へ activate"     "yes" "$(has_sub "$log" 'activate 3')"
ck "pane の呼び出しはすべて --socket <実体のパス>" "0" "$(pane_lines_without_socket "$log" "$S100")"
ck "ps はソケットの名前の番号 100 を引く" "yes" "$(has_line "$(cat "$_TMP_DIR/logs/ps.log" 2>/dev/null)" '-p 100')"
ck "記録の pane_id が新 pane 9"          "9"     "$(rec_get pane_id)"
ck "記録の socket が実体のパス"          "$S100" "$(rec_get socket)"
ck "記録の mux_started は空白を削った値" "$T1"   "$(rec_get mux_started)"
ck "記録は3行"                           "3"     "$(wc -l < "$OE_VIEW_STATE_DIR/viewer-pane-id" | tr -d ' ')"
ck "pane send は呼ばれない"    "no"  "$(has_sub "$log" 'send')"

# ----------------------------------------------------------------------------
# [3b] replace（symlink）: discover が GUI のソケットを指す symlink を返しても、実体のパスで
#      照らして閉じる（#509）。
# ----------------------------------------------------------------------------
echo "[3b] replace: discover が symlink（→ gui-sock-100）を返す → 実体で照らして kill 7"
all_shims_on; reset_state; reset_logs; reset_mocks
export MOCK_SOCKET="$SOCK_DIR/default-org"
write_rec "$(good_rec 7 "$S100" "$T1")"
export MOCK_PANE_LIST_JSON='[{"pane_id":7,"is_active":true}]'
export MOCK_SPLIT_PANE_ID="9"
rc=0; "$VIEW" -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
log="$(wez_log)"
ck "rc=0" "0" "$rc"
ck "symlink でも viewer 7 を kill" "yes" "$(has_sub "$log" 'kill 7')"
ck "pane の呼び出しはすべて --socket <実体のパス>" "0" "$(pane_lines_without_socket "$log" "$S100")"
ck "記録の socket は実体のパス" "$S100" "$(rec_get socket)"

# ----------------------------------------------------------------------------
# [4] viewer stale: 同じ GUI でも、記録の番号が list に無い → kill なし・spawn + 記録の更新。
# ----------------------------------------------------------------------------
echo "[4] stale: 記録の pane 7 が list に無い → kill なし・spawn + 記録の更新"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(good_rec 7 "$S100" "$T1")"
export MOCK_PANE_LIST_JSON='[{"pane_id":99,"is_active":true}]'   # 7 は不在
export MOCK_SPLIT_PANE_ID="11"
rc=0; "$VIEW" -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
log="$(wez_log)"
ck "rc=0" "0" "$rc"
ck "stale → kill されない"       "no"  "$(has_sub "$log" 'kill')"
ck "spawn で新規作成"            "yes" "$(has_sub "$log" 'split')"
ck "記録が新 pane 11 に更新"     "11"  "$(rec_get pane_id)"

# ----------------------------------------------------------------------------
# [4b]〜[4i] #509: 記録の番号のペインが list にあっても、同じ GUI のプロセスと確かめられなければ
#      閉じない。どの場面でも新しい viewer は開く。
# ----------------------------------------------------------------------------
# _no_kill_case <label> — 記録と mock を置いたあとに呼ぶ。list に記録の番号 7 を置いて resolve し、
#   kill されないことと、新しい viewer を開くことを確かめる。
_no_kill_case() {
  local label="$1"
  export MOCK_PANE_LIST_JSON='[{"pane_id":7,"is_active":false},{"pane_id":3,"is_active":true}]'
  export MOCK_SPLIT_PANE_ID="9"
  rc=0; "$VIEW" -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
  log="$(wez_log)"
  ck "${label}: rc=0"            "0"   "$rc"
  ck "${label}: kill されない"   "no"  "$(has_sub "$log" 'kill')"
  ck "${label}: 新しい viewer を開く" "yes" "$(has_sub "$log" 'split')"
}

echo "[4b] 別の GUI: 記録のソケットは gui-sock-200、今の接続先は gui-sock-100 → kill しない"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(good_rec 7 "$S200" "$T2")"
_no_kill_case "別の GUI"
ck "別の GUI: 記録は今の接続先に変わる" "$S100" "$(rec_get socket)"

echo "[4c] プロセス番号の使い回し: 同じ gui-sock-100 でも開始時刻が違う → kill しない"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(good_rec 7 "$S100" "$T1")"
export MOCK_LSTART_100="$T2"
_no_kill_case "開始時刻が違う"
ck "開始時刻が違う: 記録は今の開始時刻に変わる" "$T2" "$(rec_get mux_started)"

echo "[4d] 古い形の記録（番号だけ）→ kill しない"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec $'7\n'
_no_kill_case "古い形"
ck "古い形: 記録は新しい形に変わる" "$S100" "$(rec_get socket)"

echo "[4e] 壊れた記録（キーが欠ける・pane_id が数字でない・値が空）→ kill しない"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(printf 'pane_id=7\nsocket=%s\n' "$S100")"
_no_kill_case "mux_started が欠ける"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(good_rec x7 "$S100" "$T1")"
_no_kill_case "pane_id が数字でない"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(good_rec 7 "" "$T1")"
_no_kill_case "socket が空"

echo "[4f] ソケットの名前にプロセス番号が無い（mux サーバ・symlink の先も同じ）→ kill せず記録を消す"
all_shims_on; reset_state; reset_logs; reset_mocks
export MOCK_SOCKET="$SOCK_DIR/sock"
write_rec "$(good_rec 7 "$SMUX" "$T1")"
_no_kill_case "名前が sock"
ck "名前が sock: 記録を書かない" "no" "$(rec_exists)"
all_shims_on; reset_state; reset_logs; reset_mocks
export MOCK_SOCKET="$SOCK_DIR/link-to-sock"
write_rec "$(good_rec 7 "$SMUX" "$T1")"
_no_kill_case "symlink の先が sock"
ck "symlink の先が sock: 記録を書かない" "no" "$(rec_exists)"

echo "[4g] ps が失敗する → kill せず、spawn のあとも開始時刻が取れないので記録を消す"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(good_rec 7 "$S100" "$T1")"
export MOCK_PS_FAIL=1
_no_kill_case "ps が失敗"
ck "ps が失敗: 記録を書かない" "no" "$(rec_exists)"

echo "[4g2] ps は成功するが空白だけを返す → kill せず記録を消す"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(good_rec 7 "$S100" "$T1")"
export MOCK_LSTART_100="   "
_no_kill_case "ps が空白だけ"
ck "ps が空白だけ: 記録を書かない" "no" "$(rec_exists)"

echo "[4g3] spawn の前は開始時刻が取れ、spawn のあとは取れない → kill はするが記録を消す"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(good_rec 7 "$S100" "$T1")"
export MOCK_PS_OK_CALLS=1
export MOCK_PANE_LIST_JSON='[{"pane_id":7,"is_active":false}]'
export MOCK_SPLIT_PANE_ID="9"
rc=0; "$VIEW" -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
log="$(wez_log)"
ck "spawn のあと取れない: rc=0"            "0"   "$rc"
ck "spawn のあと取れない: viewer 7 を kill" "yes" "$(has_sub "$log" 'kill 7')"
ck "spawn のあと取れない: ps は2回呼ばれる" "2"   "$(wc -l < "$_TMP_DIR/logs/ps.log" | tr -d ' ')"
ck "spawn のあと取れない: 記録を書かない"   "no"  "$(rec_exists)"

echo "[4h] 記録の番号が呼び出し元のペイン（WEZTERM_PANE=3）と同じ → kill しない"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(good_rec 3 "$S100" "$T1")"
export MOCK_PANE_LIST_JSON='[{"pane_id":3,"is_active":true}]'
export MOCK_SPLIT_PANE_ID="9"
rc=0; "$VIEW" -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
log="$(wez_log)"
ck "呼び出し元: rc=0"          "0"   "$rc"
ck "呼び出し元: kill されない" "no"  "$(has_sub "$log" 'kill')"
ck "呼び出し元: 新しい viewer を開く" "yes" "$(has_sub "$log" 'split')"

echo "[4i] wez discover が失敗する → kill も split もせず rc 2"
all_shims_on; reset_state; reset_logs; reset_mocks
write_rec "$(good_rec 7 "$S100" "$T1")"
export MOCK_DISCOVER_RC=1
export MOCK_PANE_LIST_JSON='[{"pane_id":7,"is_active":true}]'
rc=0; "$VIEW" -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
log="$(wez_log)"
ck "discover 失敗: rc=2"          "2"  "$rc"
ck "discover 失敗: kill されない" "no" "$(has_sub "$log" 'kill')"
ck "discover 失敗: split されない" "no" "$(has_sub "$log" 'split')"
reset_mocks

# ----------------------------------------------------------------------------
# [5] 非 md 直叩き → open -- <path>（canonical パス）。
# ----------------------------------------------------------------------------
echo "[5] 非 md 直叩き → open -- <path>"
all_shims_on; reset_state; reset_logs
rc=0; "$VIEW" -- "$TXT_IN_ROOT" >/dev/null 2>&1 || rc=$?
ck "rc=0" "0" "$rc"
# open shim は引数（$*）のみ記録する＝"-- <canonical path>"。canonical な basename を含むこと。
ck "open に -- 付きで渡る"     "yes" "$(has_line "$(open_log)" '-- ')"
ck "open に note.txt が渡る"   "yes" "$(has_line "$(open_log)" 'note.txt')"
ck "glow は呼ばれない（非md）" "no"  "$([[ -e "$_TMP_DIR/logs/glow.log" ]] && echo yes || echo no)"

# ----------------------------------------------------------------------------
# [6] --from-link で非 md → 拒否（exit 1）・open しない。
# ----------------------------------------------------------------------------
echo "[6] --from-link 非 md → exit 1（open しない）"
all_shims_on; reset_state; reset_logs
rc=0; "$VIEW" --from-link -- "$TXT_IN_ROOT" >/dev/null 2>&1 || rc=$?
ck "--from-link 非 md → exit 1" "1" "$rc"
ck "open は呼ばれない"          "no" "$([[ -e "$_TMP_DIR/logs/open.log" ]] && echo yes || echo no)"

# ----------------------------------------------------------------------------
# [7] allowlist: --from-link で root 外 md → exit 1。
# ----------------------------------------------------------------------------
echo "[7] allowlist: --from-link root 外 md → exit 1"
all_shims_on; reset_state; reset_logs
rc=0; "$VIEW" --from-link -- "$MD_OUTSIDE" >/dev/null 2>&1 || rc=$?
ck "root 外 → exit 1" "1" "$rc"
ck "send されない"    "no" "$([[ -e "$_TMP_DIR/logs/wez.log" ]] && echo yes || echo no)"

# ----------------------------------------------------------------------------
# [8] allowlist: symlink で root 内 → root 外実体を指す → realpath 解決後 exit 1。
# ----------------------------------------------------------------------------
echo "[8] allowlist: root 内 symlink → root 外実体 → exit 1（realpath 解決）"
all_shims_on; reset_state; reset_logs
ln -sf "$MD_OUTSIDE" "$_TMP_DIR/docroot/sub/link-to-outside.md"
rc=0; "$VIEW" --from-link -- "$_TMP_DIR/docroot/sub/link-to-outside.md" >/dev/null 2>&1 || rc=$?
ck "symlink で root 外実体 → exit 1" "1" "$rc"
rm -f "$_TMP_DIR/docroot/sub/link-to-outside.md"

# ----------------------------------------------------------------------------
# [8b] allowlist: realpath 不在フォールバックでも root 内 symlink → root 外実体 → exit 1。
#      oe-review（#210 実装SO）検出の P0 バイパス回帰: フォールバックが最終要素の symlink を
#      解かないと、許可 root 内の symlink で root 外 md を開けてしまう。fail-safe で塞ぐ。
# ----------------------------------------------------------------------------
echo "[8b] allowlist: realpath 不在でも symlink → root 外実体 → exit 1（フォールバック）"
all_shims_on; reset_state; reset_logs
ln -sf "$MD_OUTSIDE" "$_TMP_DIR/docroot/sub/link-to-outside.md"
rm -f "$_TMP_DIR/pathbin/realpath"   # realpath を外してフォールバック経路を強制
rc=0; "$VIEW" --from-link -- "$_TMP_DIR/docroot/sub/link-to-outside.md" >/dev/null 2>&1 || rc=$?
ck "realpath 不在 symlink → exit 1" "1" "$rc"
ck "send されない" "no" "$([[ -e "$_TMP_DIR/logs/wez.log" ]] && echo yes || echo no)"
_link_real realpath                  # 後続テストのため realpath を復帰
rm -f "$_TMP_DIR/docroot/sub/link-to-outside.md"

# ----------------------------------------------------------------------------
# [9] allowlist: '..' トラバーサルで root 外 → exit 1。
# ----------------------------------------------------------------------------
echo "[9] allowlist: '..' トラバーサルで root 外 → exit 1"
all_shims_on; reset_state; reset_logs
rc=0; "$VIEW" --from-link -- "$_TMP_DIR/docroot/sub/../../outside/leak.md" >/dev/null 2>&1 || rc=$?
ck "'..' で root 外 → exit 1" "1" "$rc"

# ----------------------------------------------------------------------------
# [9b] allowlist: --from-link で root 内 md → 許可（exit 0・send される）。
# ----------------------------------------------------------------------------
echo "[9b] allowlist: --from-link root 内 md → 許可（exit 0・spawn）"
all_shims_on; reset_state; reset_logs
export MOCK_PANE_LIST_JSON="[]"; export MOCK_SPLIT_PANE_ID="9"
rc=0; "$VIEW" --from-link -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
ck "root 内 → exit 0" "0" "$rc"
ck "pane split（spawn）が呼ばれる" "yes" "$(has_sub "$(wez_log)" 'split')"

# ----------------------------------------------------------------------------
# [10] 入力サニタイズ: 改行・CR・制御文字を含むパス → 拒否（exit 1）。
# ----------------------------------------------------------------------------
echo "[10] サニタイズ: 改行/CR/制御文字 → exit 1"
all_shims_on; reset_state; reset_logs
rc=0; "$VIEW" -- $'foo\nbar.md' >/dev/null 2>&1 || rc=$?
ck "改行入りパス → exit 1" "1" "$rc"
rc=0; "$VIEW" -- $'foo\rbar.md' >/dev/null 2>&1 || rc=$?
ck "CR 入りパス → exit 1" "1" "$rc"
rc=0; "$VIEW" -- $'foo\x01bar.md' >/dev/null 2>&1 || rc=$?
ck "制御文字入りパス → exit 1" "1" "$rc"

# ----------------------------------------------------------------------------
# [11] 不在パス → exit 1 / ディレクトリ（非通常ファイル）→ exit 1。
# ----------------------------------------------------------------------------
echo "[11] 不在パス → exit 1 / ディレクトリ → exit 1"
all_shims_on; reset_state; reset_logs
rc=0; "$VIEW" -- "$_TMP_DIR/docroot/sub/nope.md" >/dev/null 2>&1 || rc=$?
ck "不在パス → exit 1" "1" "$rc"
rc=0; "$VIEW" -- "$_TMP_DIR/docroot" >/dev/null 2>&1 || rc=$?
ck "ディレクトリ → exit 1" "1" "$rc"

# ----------------------------------------------------------------------------
# [12] usage: 引数なし → 2 / unknown option → 2 / too many → 2 / --help → 0。
# ----------------------------------------------------------------------------
echo "[12] usage: 引数なし / unknown / too many / --help"
all_shims_on
rc=0; "$VIEW" >/dev/null 2>&1 || rc=$?
ck "引数なし → exit 2" "2" "$rc"
rc=0; "$VIEW" --bogus -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
ck "unknown option → exit 2" "2" "$rc"
rc=0; "$VIEW" -- "$MD_IN_ROOT" "$TXT_IN_ROOT" >/dev/null 2>&1 || rc=$?
ck "too many args → exit 2" "2" "$rc"
rc=0; "$VIEW" --help >/dev/null 2>&1 || rc=$?
ck "--help → exit 0" "0" "$rc"

# ----------------------------------------------------------------------------
# [13] 環境エラー: glow 不在（md 既定）→ exit 2 + 案内 / wez 不在（md 既定）→ exit 2 + 案内。
# ----------------------------------------------------------------------------
echo "[13] 環境エラー: glow 不在 / wez 不在 → exit 2 + 案内"
all_shims_on; reset_state; reset_logs
shim_off glow
rc=0; out="$("$VIEW" -- "$MD_IN_ROOT" 2>&1)" || rc=$?
ck "glow 不在 → exit 2" "2" "$rc"
ck "glow 導入案内"     "yes" "$(has_line "$out" 'glow')"
all_shims_on
shim_off wez
rc=0; out="$("$VIEW" -- "$MD_IN_ROOT" 2>&1)" || rc=$?
ck "wez 不在 → exit 2" "2" "$rc"
ck "--here 案内"       "yes" "$(has_line "$out" '--here')"
all_shims_on

# ----------------------------------------------------------------------------
# [14] --here: glow 在 → glow -p / glow 不在 + bat 在 → bat / 両方不在 → exit 2。
# ----------------------------------------------------------------------------
echo "[14] --here: glow -p / bat フォールバック / 両不在 → exit 2"
all_shims_on; reset_logs
rc=0; "$VIEW" --here -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
ck "--here glow 在 → exit 0" "0" "$rc"
ck "glow -p が呼ばれる"      "yes" "$(has_line "$(glow_log)" '-p')"
ck "split は呼ばれない（here）" "no" "$([[ -e "$_TMP_DIR/logs/wez.log" ]] && echo yes || echo no)"
reset_logs
shim_off glow
rc=0; "$VIEW" --here -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
ck "--here glow 不在 + bat → exit 0" "0" "$rc"
ck "bat が呼ばれる"                  "yes" "$(has_line "$(bat_log)" "$MD_IN_ROOT")"
jb="$("$VIEW" --here --json -- "$MD_IN_ROOT" 2>/dev/null)"
echo "$jb" | jq -e '.action=="bat"' >/dev/null 2>&1 && r=yes || r=no
ck "--here bat 時 JSON action=bat"   "yes" "$r"
reset_logs
shim_off bat
rc=0; "$VIEW" --here -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
ck "--here glow/bat 両不在 → exit 2" "2" "$rc"
all_shims_on

# ----------------------------------------------------------------------------
# [15] --json: md（glow・pane_id 付き）/ 非 md（open）の schema を jq -e で検証。
# ----------------------------------------------------------------------------
echo "[15] --json schema（jq -e）"
all_shims_on; reset_state; reset_logs
export MOCK_PANE_LIST_JSON="[]"; export MOCK_SPLIT_PANE_ID="9"
json="$("$VIEW" --json -- "$MD_IN_ROOT" 2>/dev/null)"; rc=$?
ck "md --json rc=0" "0" "$rc"
echo "$json" | jq -e '.status=="ok" and .kind=="md" and .action=="glow" and .pane_id==9' >/dev/null 2>&1 \
  && r=yes || r=no
ck "md JSON schema 一致（pane_id=9）" "yes" "$r"
json="$("$VIEW" --json -- "$TXT_IN_ROOT" 2>/dev/null)"; rc=$?
ck "非md --json rc=0" "0" "$rc"
echo "$json" | jq -e '.status=="ok" and .kind=="other" and .action=="open" and (has("pane_id")|not)' >/dev/null 2>&1 \
  && r=yes || r=no
ck "非md JSON schema 一致（pane_id 無し）" "yes" "$r"

# ----------------------------------------------------------------------------
# [16] split 失敗（環境エラー）→ exit 2。
# ----------------------------------------------------------------------------
echo "[16] split 失敗 → exit 2"
all_shims_on; reset_state; reset_logs
export MOCK_PANE_LIST_JSON="[]"   # state pane を不在にして split 経路へ
# wez split を失敗させる専用 shim を別ファイルに置く（pathbin/wez は symlink なので
# 上書きでなく symlink を外してから実体ファイルを置く＝共有 shimsrc を壊さない）。
shim_off wez
cat > "$_TMP_DIR/pathbin/wez" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${OE_VIEW_TEST_LOG_DIR:?}/wez.log"
if [[ "${1:-}" == "discover" ]]; then printf '%s\n' "${MOCK_SOCKET:?}"; exit 0; fi
[[ "${1:-}" == "pane" ]] || exit 0
shift
if [[ "${1:-}" == "--socket" ]]; then shift 2; fi
case "${1:-}" in
  list)  printf '[]\n' ;;
  split) exit 5 ;;     # split 失敗（環境エラー）
  *)     exit 0 ;;
esac
EOF
chmod +x "$_TMP_DIR/pathbin/wez"
rc=0; "$VIEW" -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
ck "split 失敗 → exit 2" "2" "$rc"
ck "split まで進んで失敗した" "yes" "$(has_sub "$(wez_log)" 'split')"
shim_off wez; shim_on wez   # 実体 shim（symlink）に戻す

# ----------------------------------------------------------------------------
# [17] 既定 OE_VIEW_ROOTS: 未設定時は $HOME。$HOME 配下の md は許可・$HOME 外は拒否。
#      HOME をテスト用ディレクトリに差し替えて決定的に検証する（実 $HOME/$TMPDIR に依存しない）。
# ----------------------------------------------------------------------------
echo "[17] 既定 OE_VIEW_ROOTS=\$HOME（配下=許可 / 外=拒否）"
all_shims_on; reset_state; reset_logs
mkdir -p "$_TMP_DIR/fakehome/sub"
printf '# h\n' > "$_TMP_DIR/fakehome/sub/inhome.md"
rc=0; env -u OE_VIEW_ROOTS HOME="$_TMP_DIR/fakehome" "$VIEW" --from-link -- "$_TMP_DIR/fakehome/sub/inhome.md" >/dev/null 2>&1 || rc=$?
ck "\$HOME 配下 md → 許可(exit 0)" "0" "$rc"
rc=0; env -u OE_VIEW_ROOTS HOME="$_TMP_DIR/fakehome" "$VIEW" --from-link -- "$MD_IN_ROOT" >/dev/null 2>&1 || rc=$?
ck "\$HOME 外 md → 拒否(exit 1)" "1" "$rc"

# ----------------------------------------------------------------------------
# [18] HOME も OE_VIEW_ROOTS も無いとき: allowlist は空 = 全拒否（fail-closed・#322 gate 3 裁定 4）
#      allowlist が決まらないときに通すのは境界の意味が逆になる。--from-link 以外
#      （--here / 直叩き）は allowlist を要求しないので巻き添えにしない。
# ----------------------------------------------------------------------------
echo "[18] HOME 不在で OE_VIEW_ROOTS が空 → --from-link は全拒否（#322）"
all_shims_on; reset_state; reset_logs
mkdir -p "$_TMP_DIR/nohome"
printf '# n\n' > "$_TMP_DIR/nohome/x.md"
rc=0; env -u OE_VIEW_ROOTS -u HOME OE_VIEW_STATE_DIR="$_TMP_DIR/vstate" "$VIEW" --from-link -- "$_TMP_DIR/nohome/x.md" >/dev/null 2>&1 || rc=$?
ck "HOME 不在 + roots 空 → --from-link 拒否" "1" "$rc"
rc=0; env -u OE_VIEW_ROOTS -u HOME OE_VIEW_STATE_DIR="$_TMP_DIR/vstate" "$VIEW" --help >/dev/null 2>&1 || rc=$?
ck "HOME 不在でも --help は 0" "0" "$rc"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
