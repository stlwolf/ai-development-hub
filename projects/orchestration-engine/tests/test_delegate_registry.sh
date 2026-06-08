#!/usr/bin/env bash
# test_delegate_registry.sh — delegate-registry.sh の resolve/list/gc 単体テスト
#
# 誤送信防止の核ロジックを自動検証する（Issue #142 / Copilot 指摘）。
# tmux を関数モックし、state ディレクトリを mktemp で隔離するため、実 tmux サーバ不要。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="${SCRIPT_DIR}/../lib/delegate-registry.sh"

# --- 隔離した state dir ---
export OE_DELEGATE_STATE_DIR; OE_DELEGATE_STATE_DIR="$(mktemp -d)"
export OE_PANE_ISSUE_DIR;     OE_PANE_ISSUE_DIR="$(mktemp -d)"
trap 'rm -rf "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"' EXIT

# --- モック環境 ---
# _oe_reg_server_pid は $TMUX の 2 番目フィールドを pid として読む。
export TMUX="/tmp/mock-tmux-socket,99999,0"
export TMUX_PANE="%1"   # 親（self）

# モック tmux: list-panes は $MOCK_LIVE_PANES（空白区切り）を 1 行ずつ返す。
# display-message は固定の pane title を返す。サブシェル（パイプ/プロセス置換）にも継承される。
MOCK_LIVE_PANES=""
tmux() {
  case "${1:-} ${2:-}" in
    "list-panes -a"|"list-panes"*)
      # shellcheck disable=SC2086
      printf '%s\n' $MOCK_LIVE_PANES ;;
    "display-message"*) echo "mock-pane-title" ;;
    *) return 0 ;;
  esac
}

# shellcheck source=../lib/delegate-registry.sh
source "$LIB"

pass=0; fail=0
ck() { # <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; pass=$((pass+1));
  else echo "  FAIL: $1 (want='$2' got='$3')"; fail=$((fail+1)); fi
}

keyA="$(_oe_reg_key '%5')"   # 99999__5
keyB="$(_oe_reg_key '%7')"   # 99999__7
MOCK_LIVE_PANES="%5 %7"

# A = pane-issue #142、B = spawn ラベル my-task（親 = self %1）
printf '{"name":"#142 redesign"}\n' > "${OE_PANE_ISSUE_DIR}/${keyA}"
oe_reg_record "%7" "my-task" "/ws" "%1"

echo "[1] resolve: pane-issue / spawn / %N passthrough / #N 境界"
ck "resolve #142 -> %5 (pane-issue)" "%5" "$(oe_reg_resolve '#142' 2>/dev/null)"
ck "resolve my-task -> %7 (spawn)"   "%7" "$(oe_reg_resolve 'my-task' 2>/dev/null)"
ck "resolve %999 passthrough"        "%999" "$(oe_reg_resolve '%999' 2>/dev/null)"
ck "resolve #14 (token boundary) empty" "" "$(oe_reg_resolve '#14' 2>/dev/null)"

echo "[2] parent scope: 別親の spawn ラベルは解決しない"
oe_reg_record "%7" "other-task" "/ws" "%99999"   # 別親で上書き
ck "other-task (foreign parent) empty" "" "$(oe_reg_resolve 'other-task' 2>/dev/null)"
oe_reg_record "%7" "my-task" "/ws" "%1"           # 戻す

echo "[3] pane-issue 優先（ドリフト）: %7 に pane-issue #150"
printf '{"name":"#150 switched"}\n' > "${OE_PANE_ISSUE_DIR}/${keyB}"
ck "my-task suppressed by pane-issue" "" "$(oe_reg_resolve 'my-task' 2>/dev/null)"
ck "resolve #150 -> %7"               "%7" "$(oe_reg_resolve '#150' 2>/dev/null)"
rm -f "${OE_PANE_ISSUE_DIR}/${keyB}"

echo "[4] ambiguity: %5,%7 両方に pane-issue #142"
printf '{"name":"#142 dup"}\n' > "${OE_PANE_ISSUE_DIR}/${keyB}"
amb_rc=0; oe_reg_resolve '#142' >/dev/null 2>&1 || amb_rc=$?
ck "ambiguous #142 -> rc 1" "1" "$amb_rc"
rm -f "${OE_PANE_ISSUE_DIR}/${keyB}"

echo "[5] list: source 列"
LIST="$(oe_reg_list 2>/dev/null)"
ck "list shows %5 pane-issue" "yes" "$(echo "$LIST" | grep -q "%5 .*pane-issue .*#142" && echo yes || echo no)"
ck "list shows %7 spawn"      "yes" "$(echo "$LIST" | grep -q "%7 .*spawn-registry .*my-task" && echo yes || echo no)"

echo "[6] gc: 別サーバ pid の stale entry を掃除、生存 %7 は残す"
printf '{"pane":"%%9","label":"stale","parent_pane":"%%1","role":"child"}\n' > "${OE_DELEGATE_STATE_DIR}/00000001__9.json"
oe_reg_gc
ck "stale foreign-pid removed" "no"  "$( [[ -e "${OE_DELEGATE_STATE_DIR}/00000001__9.json" ]] && echo yes || echo no)"
ck "live %7 entry kept"        "yes" "$( [[ -e "${OE_DELEGATE_STATE_DIR}/${keyB}.json" ]] && echo yes || echo no)"

echo "[7] gc: 死んだペインの entry を掃除"
MOCK_LIVE_PANES="%5"   # %7 が消えた
oe_reg_gc
ck "dead %7 entry removed" "no" "$( [[ -e "${OE_DELEGATE_STATE_DIR}/${keyB}.json" ]] && echo yes || echo no)"

echo "=== RESULT: pass=${pass} fail=${fail} ==="
[[ "$fail" -eq 0 ]]
