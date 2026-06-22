#!/usr/bin/env bash
# test_delegate_send.sh — oe_send_line の単体テスト
#
# 改行拒否・pane 検証・list-panes 失敗の環境エラー区別・Enter 発火/--no-enter を
# tmux 関数モックで自動検証する（Issue #142 / Copilot 指摘）。実 tmux サーバ不要。
#
# Issue #144: 観測ベース finalize（Enter 吸収の after-the-fact 回復）の分岐を、
# capture-pane を時系列モック化して発火/不発火・warn で検証する。
# 注: lib は capture を `$(tmux capture-pane)` のサブシェルで読むため、モックの capture
# インデックス/呼び出し数は「ファイル」で持つ（サブシェルの変数代入は親に伝播しないため）。
# 注: mock は tmux 発行と finalize 分岐を見るだけ。実 submit・実 race・二重 submit 不在・
# scrape 領域×レイアウト整合は原理的にユニット検証不能＝dogfood 専管。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="${SCRIPT_DIR}/../lib/delegate-send.sh"

export OE_SEND_ENTER_DELAY=0   # テスト高速化（Enter 前の小休止を 0 に）
export OE_EVENT_LOG=0          # 活動ログ（#206）emit を無効化（本テストは transport が対象）

# --- サブシェル越しに持つ状態（capture の連続返却とコール数） ---
CAP_IDXFILE="$(mktemp)";   echo 0 > "$CAP_IDXFILE"
CAP_CALLSFILE="$(mktemp)"; echo 0 > "$CAP_CALLSFILE"
ERRFILE="$(mktemp)"
trap 'rm -f "$CAP_IDXFILE" "$CAP_CALLSFILE" "$ERRFILE"' EXIT

# --- モック tmux: list-panes は MOCK_LIVE_PANES、send-keys は MOCK_SENDKEYS_LOG に記録 ---
# capture-pane は MOCK_CAP_SEQ（配列・各要素が1画面分）を順に返し、尽きたら最後を反復。
# インデックス/コール数はファイル（CAP_IDXFILE/CAP_CALLSFILE）に持つ＝サブシェル越しでも進む。
MOCK_LIVE_PANES="%5 %7"
MOCK_SENDKEYS_LOG=""
MOCK_CAP_SEQ=()
tmux() {
  case "${1:-} ${2:-}" in
    "list-panes -a"|"list-panes"*)
      if [[ -n "${MOCK_TMUX_FAIL:-}" ]]; then echo "no server running on socket" >&2; return 1; fi
      # shellcheck disable=SC2086
      printf '%s\n' $MOCK_LIVE_PANES ;;
    "capture-pane"*)
      local c; c="$(cat "$CAP_CALLSFILE")"; echo $((c+1)) > "$CAP_CALLSFILE"
      if [[ "${MOCK_CAP_FAIL:-}" == "1" ]]; then return 1; fi
      local n="${#MOCK_CAP_SEQ[@]}"; [[ "$n" -eq 0 ]] && return 0
      local idx; idx="$(cat "$CAP_IDXFILE")"
      local use="$idx"; [[ "$use" -ge "$n" ]] && use=$((n-1))
      printf '%s\n' "${MOCK_CAP_SEQ[$use]}"
      echo $((idx+1)) > "$CAP_IDXFILE" ;;
    "send-keys"*) MOCK_SENDKEYS_LOG+="tmux $*"$'\n'; [[ "${MOCK_SENDKEYS_FAIL:-}" == "1" ]] && return 1 || return 0 ;;
    "display"*) printf '%s\n' "${MOCK_PANE_IN_MODE:-0}" ;;  # display / display-message: #{pane_in_mode}
    *) return 0 ;;
  esac
}
# finalize の sleep を無効化（テストは即時）。
sleep() { :; }

# shellcheck source=../lib/delegate-send.sh
source "$LIB"

pass=0; fail=0
ck() { # <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; pass=$((pass+1));
  else echo "  FAIL: $1 (want='$2' got='$3')"; fail=$((fail+1)); fi
}

# === 既存テスト（transport）: finalize は無効化して transport の挙動のみ検証 ===
export OE_SEND_FINALIZE=0

echo "[1] 改行拒否 → rc 2 / send-keys 未呼び出し"
MOCK_SENDKEYS_LOG=""
rc=0; oe_send_line "%5" "$(printf 'a\nb')" >/dev/null 2>&1 || rc=$?
ck "newline reject rc=2" "2" "$rc"
ck "改行時は send-keys を呼ばない" "" "$MOCK_SENDKEYS_LOG"

echo "[2] pane 未指定 → rc 2"
rc=0; oe_send_line "" "x" >/dev/null 2>&1 || rc=$?
ck "empty pane rc=2" "2" "$rc"

echo "[3] 死ペイン（生存リストに無い）→ rc 1"
rc=0; oe_send_line "%999" "x" >/dev/null 2>&1 || rc=$?
ck "dead pane rc=1" "1" "$rc"

echo "[4] list-panes 失敗 → rc 2（環境エラー・ペイン無し rc1 と区別）"
MOCK_TMUX_FAIL=1; rc=0; oe_send_line "%5" "x" >/dev/null 2>&1 || rc=$?; unset MOCK_TMUX_FAIL
ck "list-panes fail rc=2" "2" "$rc"

echo "[5] 正常送信 + Enter 発火"
MOCK_SENDKEYS_LOG=""
rc=0; oe_send_line "%5" "hello" >/dev/null 2>&1 || rc=$?
ck "send rc=0" "0" "$rc"
ck "literal 'hello' を送信" "yes" "$(echo "$MOCK_SENDKEYS_LOG" | grep -q 'hello' && echo yes || echo no)"
ck "Enter 発火" "yes" "$(echo "$MOCK_SENDKEYS_LOG" | grep -q 'Enter' && echo yes || echo no)"

echo "[6] --no-enter（send_enter=0）→ Enter 撃たない"
MOCK_SENDKEYS_LOG=""
rc=0; oe_send_line "%5" "hello" "0" >/dev/null 2>&1 || rc=$?
ck "send rc=0" "0" "$rc"
ck "literal 'hello' を送信" "yes" "$(echo "$MOCK_SENDKEYS_LOG" | grep -q 'hello' && echo yes || echo no)"
ck "Enter を撃たない" "yes" "$(echo "$MOCK_SENDKEYS_LOG" | grep -q 'Enter' && echo no || echo yes)"

# === Issue #144: 観測ベース finalize の分岐テスト ===
# 画面ビルダ（入力欄＝`❯` 行・最下部に処理インジケータ "esc to interrupt"）
scr_staged()  { printf '────── ws ──\n❯ %s\n──────\n  ? for shortcuts' "$1"; }
scr_empty()   { printf '────── ws ──\n❯ \n──────\n  ? for shortcuts'; }
scr_proc()    { printf '────── ws ──\n❯ \n──────\n  esc to interrupt'; }
scr_content() { printf '────── ws ──\n❯ %s\n──────\n  ? for shortcuts' "$1"; }

# finalize を有効化し、窓を小さく（sleep は no-op なので即時）。max_iter=int(5/1)=5。
export OE_SEND_FINALIZE=1
export OE_SEND_FINALIZE_INTERVAL=1
export OE_SEND_FINALIZE_TIMEOUT=5
export OE_SEND_FINALIZE_STABLE=2

# 各シナリオ: MOCK_CAP_SEQ[0]=送信前 baseline、以降=finalize の poll/最終 capture。
enter_count() { printf '%s' "$MOCK_SENDKEYS_LOG" | grep -c 'send-keys -t %5 Enter'; }
cap_calls()   { cat "$CAP_CALLSFILE"; }
cancel_fired() { printf '%s' "$MOCK_SENDKEYS_LOG" | grep -q -- '-X cancel' && echo yes || echo no; }
reset_fin() { MOCK_SENDKEYS_LOG=""; echo 0 > "$CAP_IDXFILE"; echo 0 > "$CAP_CALLSFILE"; MOCK_CAP_FAIL=""; MOCK_PANE_IN_MODE=0; MOCK_SENDKEYS_FAIL=""; }

echo "[7] finalize: staged_idle（窓終端までstaged・baseline idle）→ Enter を1回再送"
reset_fin
MOCK_CAP_SEQ=( "$(scr_empty)" "$(scr_staged 'PAY7')" )
oe_send_line "%5" "PAY7" >/dev/null 2>&1
ck "Enter は transport+finalize で計2回" "2" "$(enter_count)"

echo "[8] finalize: staged 後に submit（空に遷移）→ 早期 exit・再送しない"
reset_fin
MOCK_CAP_SEQ=( "$(scr_empty)" "$(scr_staged 'PAY8')" "$(scr_empty)" )
oe_send_line "%5" "PAY8" >/dev/null 2>&1
ck "Enter は transport の1回のみ" "1" "$(enter_count)"

echo "[9] finalize: K安定後に遅延 submit（staged×2→空）→ 再送しない（読み②・二重submit防止）"
reset_fin
MOCK_CAP_SEQ=( "$(scr_empty)" "$(scr_staged 'PAY9')" "$(scr_staged 'PAY9')" "$(scr_empty)" )
oe_send_line "%5" "PAY9" >/dev/null 2>&1
ck "Enter は1回のみ（遅延submitを二重化しない）" "1" "$(enter_count)"

echo "[10] finalize: baseline busy → 後に staged_idle → base_proc=1 で撃たない（B1）"
reset_fin
MOCK_CAP_SEQ=( "$(scr_proc)" "$(scr_staged 'PAY10')" )
oe_send_line "%5" "PAY10" >/dev/null 2>&1
ck "baseline busy 時は finalize 撃たない" "1" "$(enter_count)"

echo "[11] finalize: processing が edge で出現 → submit 確証・撃たない"
reset_fin
MOCK_CAP_SEQ=( "$(scr_empty)" "$(scr_proc)" )
oe_send_line "%5" "PAY11" >/dev/null 2>&1
ck "edge processing は submitted 扱い・撃たない" "1" "$(enter_count)"

echo "[12] finalize: stage_miss_suspect（一度も staged 観測せず空）→ warn のみ・撃たない・rc 不変"
reset_fin
MOCK_CAP_SEQ=( "$(scr_empty)" "$(scr_empty)" )
# サブシェル($(...))にすると MOCK_SENDKEYS_LOG が親に伝播しないため、stderr はファイルへ。
rc=0; oe_send_line "%5" "PAY12" >/dev/null 2>"$ERRFILE" || rc=$?
ck "stage_miss でも rc=0（rc 透過）" "0" "$rc"
ck "stage_miss は撃たない（transport の1回のみ）" "1" "$(enter_count)"
ck "stage_miss warn を出す" "yes" "$(grep -q 'possible stage miss' "$ERRFILE" && echo yes || echo no)"

echo "[13] finalize: base_staged（送信前から入力欄に内容）→ 無条件 unknown・撃たない"
reset_fin
MOCK_CAP_SEQ=( "$(scr_content 'olddata')" "$(scr_staged 'PAY13')" )
oe_send_line "%5" "PAY13" >/dev/null 2>&1
ck "base_staged 時は finalize 撃たない" "1" "$(enter_count)"

echo "[14] finalize: capture-pane 失敗 → unknown・撃たない・rc 不変"
reset_fin
MOCK_CAP_FAIL=1
MOCK_CAP_SEQ=( "$(scr_empty)" )
rc=0; oe_send_line "%5" "PAY14" >/dev/null 2>&1 || rc=$?
ck "capture 失敗でも rc=0" "0" "$rc"
ck "capture 失敗時は finalize 撃たない" "1" "$(enter_count)"
MOCK_CAP_FAIL=""

echo "[15] finalize: 正規表現メタ文字 payload を grep -F でリテラル一致 → 正しく staged_idle 発火"
reset_fin
META='a.*b[x]?'
MOCK_CAP_SEQ=( "$(scr_empty)" "$(scr_staged "$META")" )
oe_send_line "%5" "$META" >/dev/null 2>&1
ck "メタ文字 payload でも literal 一致で再送" "2" "$(enter_count)"

echo "[16] finalize: OE_SEND_FINALIZE=0 → capture も追加 Enter も発生しない"
reset_fin
MOCK_CAP_SEQ=( "$(scr_staged 'PAY16')" )
OE_SEND_FINALIZE=0 oe_send_line "%5" "PAY16" >/dev/null 2>&1
ck "FINALIZE=0 で capture-pane を呼ばない" "0" "$(cap_calls)"
ck "FINALIZE=0 で Enter は transport の1回のみ" "1" "$(enter_count)"

echo "[17] finalize: --no-enter（send_enter=0）→ finalize 不発火・capture しない"
reset_fin
MOCK_CAP_SEQ=( "$(scr_staged 'PAY17')" )
oe_send_line "%5" "PAY17" "0" >/dev/null 2>&1
ck "--no-enter で capture-pane を呼ばない" "0" "$(cap_calls)"
ck "--no-enter で Enter を撃たない" "0" "$(enter_count)"

echo "[18] finalize: staged_idle の finalize Enter は最大1回（単発ガード）"
reset_fin
MOCK_CAP_SEQ=( "$(scr_empty)" "$(scr_staged 'PAY18')" )
oe_send_line "%5" "PAY18" >/dev/null 2>&1
ck "finalize 追加 Enter は1回（計2回）" "2" "$(enter_count)"

echo "[19] finalize: max_iter は ceil（floor で総待機が TIMEOUT 未満にならない・Copilot 指摘）"
reset_fin
MOCK_CAP_SEQ=( "$(scr_empty)" "$(scr_staged 'PAY19')" )
# TIMEOUT=1/INTERVAL=0.3 → ceil=4（floor なら3）。baseline(1)+poll(4)+最終(1)=6 capture。
OE_SEND_FINALIZE_TIMEOUT=1 OE_SEND_FINALIZE_INTERVAL=0.3 OE_SEND_FINALIZE_STABLE=2 \
  oe_send_line "%5" "PAY19" >/dev/null 2>&1
ck "ceil で capture 回数 = baseline+4+final = 6（floor なら5）" "6" "$(cap_calls)"
ck "staged_idle で再送（計2回）" "2" "$(enter_count)"

# === Issue #154: copy-mode ガード + silent-failure signal（opt-in） ===

echo "[20] copy-mode ガード: pane_in_mode=1 → 送信前に -X cancel で解除し transport は継続（#154）"
reset_fin
MOCK_CAP_SEQ=( "$(scr_empty)" "$(scr_staged 'PAY20')" )
MOCK_PANE_IN_MODE=1
oe_send_line "%5" "PAY20" >/dev/null 2>&1
ck "copy-mode 時は -X cancel を撃つ" "yes" "$(cancel_fired)"
ck "copy-mode 解除後も literal を送信する" "yes" "$(printf '%s' "$MOCK_SENDKEYS_LOG" | grep -q 'PAY20' && echo yes || echo no)"

echo "[21] copy-mode 非該当: pane_in_mode=0 → -X cancel を撃たない（not in a mode 回避・#154）"
reset_fin
MOCK_CAP_SEQ=( "$(scr_empty)" "$(scr_staged 'PAY21')" )
oe_send_line "%5" "PAY21" >/dev/null 2>&1
ck "非 copy-mode 時は -X cancel を撃たない" "no" "$(cancel_fired)"

echo "[22] silent-failure signal: OE_SEND_SIGNAL_MISS=1 + stage_miss → rc=4（既定 off は[12]・#154）"
reset_fin
MOCK_CAP_SEQ=( "$(scr_empty)" "$(scr_empty)" )
rc=0; OE_SEND_SIGNAL_MISS=1 oe_send_line "%5" "PAY22" >/dev/null 2>"$ERRFILE" || rc=$?
ck "opt-in 時の未着候補は rc=4" "4" "$rc"
ck "rc=4 でも追加 submit しない（transport の Enter 1回のみ）" "1" "$(enter_count)"

echo "[23] transport 失敗の明示伝播: send-keys 失敗 → rc=2（|| rc=\$? 文脈でも握り潰さない・#154 SO 指摘）"
reset_fin
MOCK_CAP_SEQ=( "$(scr_empty)" )
rc=0; MOCK_SENDKEYS_FAIL=1 oe_send_line "%5" "PAY23" >/dev/null 2>&1 || rc=$?
ck "send-keys 失敗は rc=2 で伝播（errexit に頼らない）" "2" "$rc"

echo "=== RESULT: pass=${pass} fail=${fail} ==="
[[ "$fail" -eq 0 ]]
