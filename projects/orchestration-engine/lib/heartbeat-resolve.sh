# shellcheck shell=bash
# heartbeat-resolve.sh — heartbeat の sidecar からペインと session_id を引く規則を1つにまとめる（#577 PR-1・source 専用）
#
# #577 の N6。いまは読む側がそれぞれに絞り方を持っている（lib/handoff-state.sh はペインと server の両方、
# oe-tree と oe-threads は server が空でも受け、oe-vitals はペインだけ）。読む側は PR-4 と PR-5 でこの lib へ
# 切り替える。計測の道具 scripts/measure-delivery-arrival.py は、#299 の到達率と比べる物差しを変えないために
# 切り替えない（owner の答え Q83）。
#
# 提供する関数:
#   oe_hb_pane_for <server_pid> <max_age_sec> <lease_id> <generation> [<session_id>...]
#       lease の今の generation の候補のペインを1つ選び、"<pane>\t<session_id>" を出す。
#       候補にするのは、server の pid が一致し、鮮度の窓の中にあり、
#       (a) sidecar の lease_id と generation が一致する、か (b) sidecar の session_id が渡した並びにある、もの。
#       rc: 0 選べた / 1 候補が無い / 3 いちばん新しい候補が同じ時刻で別のペインに分かれた / 2 呼び方の誤り
#   oe_hb_session_for_pane <server_pid> <max_age_sec> <pane>
#       そのペインのいちばん新しい sidecar の session_id を出す。rc は上と同じ。
#
# どちらも候補を選ぶための手がかりである。使う前には必ず lib/tmux-pane-identity.sh の oe_tpi_verify_pane で
# ペインのフォアグラウンドのプロセスを binding と照らす（DJ-6）。sidecar は session_id の登録の根拠にしない（DJ-18）。
#
# 置き場: OE_HEARTBEAT_DIR（既定 ~/.claude/state/oe-heartbeat）。now の上書き: OE_HB_NOW_EPOCH（テスト用）。

declare -F _oe_home_usable >/dev/null 2>&1 || _oe_home_usable() { case "${HOME:-}" in /|//) return 1;; /*) return 0;; *) return 1;; esac; }
if   [ -n "${OE_HEARTBEAT_DIR+x}" ]; then :
elif _oe_home_usable; then OE_HEARTBEAT_DIR="${HOME}/.claude/state/oe-heartbeat"
else                       OE_HEARTBEAT_DIR=""
fi

# 1つの sidecar を "<ts>\t<pane>\t<server_pid>\t<lease_id>\t<generation>" に投影する（空は "-"）。読めなければ何も出さない。
_oe_hb_project() {
  # 空の値は "-" で埋める。read の区切りのタブは連続すると1つに畳まれるので、空の項目があると列がずれる。
  jq -r 'def v: (. // "" | tostring) | if . == "" then "-" else . end;
         select(type=="object") | [ (.ts|v), (.pane|v), (.server_pid|v), (.lease_id|v), (.generation|v) ] | @tsv' "$1" 2>/dev/null
}

# 候補の行（"<ts>\t<pane>\t<sid>"）を標準入力から読み、いちばん新しいものを選ぶ。
_oe_hb_pick() {
  awk -F '\t' '
    { if ($1 > best) { best=$1; pane=$2; sid=$3; tie=0 } else if ($1 == best && $2 != pane) { tie=1 } n++ }
    END { if (n == 0) exit 1; if (tie) exit 3; printf "%s\t%s", pane, sid }'
}

_OE_HB_TAB="$(printf '\t')"

_oe_hb_now() { printf '%s' "${OE_HB_NOW_EPOCH:-$(date +%s)}"; }

oe_hb_pane_for() {
  local spid="${1:-}" maxage="${2:-}" lid="${3:-}" gen="${4:-}"
  [ $# -ge 4 ] || return 2
  shift 4
  case "$maxage" in ''|*[!0-9]*) return 2 ;; esac
  [ -n "$spid" ] || return 2
  [ -n "$OE_HEARTBEAT_DIR" ] && [ -d "$OE_HEARTBEAT_DIR" ] || return 1
  command -v jq >/dev/null 2>&1 || return 2
  local now f row ts pane rspid rlid rgen sid s hit cands=""
  now="$(_oe_hb_now)"
  for f in "$OE_HEARTBEAT_DIR"/*.json; do
    [ -f "$f" ] || continue
    row="$(_oe_hb_project "$f")" || continue
    [ -n "$row" ] || continue
    IFS="$_OE_HB_TAB" read -r ts pane rspid rlid rgen <<EOF
$row
EOF
    case "$ts" in ''|*[!0-9]*) continue ;; esac
    [ "$pane" != "-" ] || continue
    [ "$rspid" = "$spid" ] || continue
    [ $((now - ts)) -le "$maxage" ] || continue
    sid="$(basename "$f" .json)"
    hit=0
    if [ -n "$lid" ] && [ "$rlid" = "$lid" ] && [ "$rgen" = "$gen" ]; then hit=1; fi
    if [ "$hit" -eq 0 ]; then
      for s in "$@"; do [ "$s" = "$sid" ] && { hit=1; break; }; done
    fi
    [ "$hit" -eq 1 ] || continue
    cands="${cands}${ts}${_OE_HB_TAB}${pane}${_OE_HB_TAB}${sid}
"
  done
  printf '%s' "$cands" | grep -v '^$' | _oe_hb_pick
}

oe_hb_session_for_pane() {
  local spid="${1:-}" maxage="${2:-}" want="${3:-}"
  case "$maxage" in ''|*[!0-9]*) return 2 ;; esac
  [ -n "$spid" ] && [ -n "$want" ] || return 2
  [ -n "$OE_HEARTBEAT_DIR" ] && [ -d "$OE_HEARTBEAT_DIR" ] || return 1
  command -v jq >/dev/null 2>&1 || return 2
  local now f row ts pane rspid rlid rgen cands="" out rc
  now="$(_oe_hb_now)"
  for f in "$OE_HEARTBEAT_DIR"/*.json; do
    [ -f "$f" ] || continue
    row="$(_oe_hb_project "$f")" || continue
    [ -n "$row" ] || continue
    IFS="$_OE_HB_TAB" read -r ts pane rspid rlid rgen <<EOF
$row
EOF
    case "$ts" in ''|*[!0-9]*) continue ;; esac
    [ "$pane" = "$want" ] || continue
    [ "$rspid" = "$spid" ] || continue
    [ $((now - ts)) -le "$maxage" ] || continue
    cands="${cands}${ts}${_OE_HB_TAB}$(basename "$f" .json)${_OE_HB_TAB}$(basename "$f" .json)
"
  done
  # 同じペインの候補どうしなので、同じ時刻の別の session_id を「分かれた」と数える（3列目で比べる）。
  out="$(printf '%s' "$cands" | grep -v '^$' | awk -F '\t' '
    { if ($1 > best) { best=$1; sid=$3; tie=0 } else if ($1 == best && $3 != sid) { tie=1 } n++ }
    END { if (n == 0) exit 1; if (tie) exit 3; printf "%s", sid }')"; rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  printf '%s' "$out"
}
