# shellcheck shell=bash
# tmux-pane-identity.sh — ペインにいまいるのが誰かと、プロセスが生きているかを確かめる（#577 PR-1・source 専用）
#
# #577 の DJ-19（ペインの本人確認を1つの関数にする）と DJ-9（生きていないことの機械の確かめ）の部品である。
# tmux に固有の確かめだけをここに集める。transport を tmux 以外へ替えるときは、lib/delegate-send.sh と
# 一緒にこの lib を見直す。
#
# 提供する関数:
#   oe_tpi_proc_started <pid>            — プロセスの開始時刻（LC_ALL=C の lstart）。無ければ非0
#   oe_tpi_proc_comm <pid>               — プロセスのコマンド名。無ければ非0
#   oe_tpi_proc_state <pid> <started>    — alive / dead / unknown を出す（rc は常に 0）
#   oe_tpi_pane_foreground <pane>        — ペインの端末のフォアグラウンドのプロセスの "<pid>\t<started>"
#                                          rc: 0 取れた / 1 ペインが無い / 2 確かめられない
#   oe_tpi_verify_pane <pane> <pid> <started>
#                                        — 照合。rc: 0 一致 / 1 不一致（ペインが無いを含む）/ 2 確かめられない
#
# 照合（verify）と発見（foreground）を分けて返す。adopt は binding が無いところから最初の binding を
# 見つけるので foreground を使い、送信・retire・oe-jump・oe-select は既にある binding と照らすので
# verify を使う（DJ-19・ゲート2 の Codex のやり直しの指摘）。
#
# 生死は3つの値で返す。ps の失敗や出力の欠けを「無い」に畳むと、生きた binding を死と誤判定して
# 張り替えを許してしまう（DJ-9・ゲート2 の Codex のやり直しの指摘）。
#
# 差し替えの口（テスト用）: OE_TPI_PS（既定 ps）・OE_TPI_TMUX（既定 tmux）

OE_TPI_PS="${OE_TPI_PS:-ps}"
OE_TPI_TMUX="${OE_TPI_TMUX:-tmux}"
_OE_TPI_TAB="$(printf '\t')"

# lstart は「Fri Nov  6 02:44:37 2026」の形。空白の数の揺れで比べ間違えないように、連続した空白を1つに詰める。
_oe_tpi_norm() { printf '%s' "$1" | tr -s ' ' | sed -e 's/^ //' -e 's/ $//'; }

oe_tpi_proc_started() {
  local pid="${1:-}" out rc
  case "$pid" in ''|*[!0-9]*) return 2 ;; esac
  out="$(LC_ALL=C "$OE_TPI_PS" -o lstart= -p "$pid" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  out="$(_oe_tpi_norm "$out")"
  [ -n "$out" ] || return 1
  printf '%s' "$out"
}

oe_tpi_proc_comm() {
  local pid="${1:-}" out rc
  case "$pid" in ''|*[!0-9]*) return 2 ;; esac
  out="$(LC_ALL=C "$OE_TPI_PS" -o comm= -p "$pid" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  out="$(_oe_tpi_norm "$out")"
  [ -n "$out" ] || return 1
  printf '%s' "${out##*/}"
}

# ps -p は「そのプロセスが無い」ときに rc=1 と空を返す。それ以外の失敗（ps が無い・権限など）は unknown にする。
oe_tpi_proc_state() {
  local pid="${1:-}" want="${2:-}" got rc
  case "$pid" in ''|*[!0-9]*) printf 'unknown'; return 0 ;; esac
  [ -n "$want" ] || { printf 'unknown'; return 0; }
  got="$(LC_ALL=C "$OE_TPI_PS" -o lstart= -p "$pid" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 1 ] && [ -z "$got" ]; then printf 'dead'; return 0; fi
  if [ "$rc" -ne 0 ]; then printf 'unknown'; return 0; fi
  got="$(_oe_tpi_norm "$got")"
  [ -n "$got" ] || { printf 'unknown'; return 0; }
  if [ "$got" = "$(_oe_tpi_norm "$want")" ]; then printf 'alive'; else printf 'dead'; fi
  return 0
}

# ペインの端末を一覧の所属で引く。display-message は不在のペインにも rc=0 と空を返すので使わない（#291）。
_oe_tpi_pane_tty() {
  local pane="$1" rows rc
  rows="$("$OE_TPI_TMUX" list-panes -a -F '#{pane_id} #{pane_tty}' 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] || return 2
  printf '%s\n' "$rows" | awk -v p="$pane" '$1==p {print $2; f=1} END {exit f?0:1}' || return 1
}

oe_tpi_pane_foreground() {
  local pane="${1:-}" tty rc rows fg started
  case "$pane" in %[0-9]*) ;; *) return 2 ;; esac
  tty="$(_oe_tpi_pane_tty "$pane")"; rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  [ -n "$tty" ] || return 2
  # pid と tpgid が一致する行が、端末のフォアグラウンドのプロセスグループの長である（claude の子の
  # MCP のサーバなども同じ tpgid で並ぶので、tpgid の値ではなく一致する行を採る）。
  rows="$(LC_ALL=C "$OE_TPI_PS" -t "${tty#/dev/}" -o pid=,tpgid= 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] || return 2
  fg="$(printf '%s\n' "$rows" | awk '$1==$2 {print $1; n++} END {exit (n==1)?0:1}')" || return 2
  started="$(oe_tpi_proc_started "$fg")" || return 2
  printf '%s\t%s' "$fg" "$started"
}

oe_tpi_verify_pane() {
  local pane="${1:-}" pid="${2:-}" want="${3:-}" got rc
  [ -n "$pid" ] && [ -n "$want" ] || return 2
  got="$(oe_tpi_pane_foreground "$pane")"; rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  [ "${got%%"$_OE_TPI_TAB"*}" = "$pid" ] || return 1
  [ "${got#*"$_OE_TPI_TAB"}" = "$(_oe_tpi_norm "$want")" ] || return 1
  return 0
}
