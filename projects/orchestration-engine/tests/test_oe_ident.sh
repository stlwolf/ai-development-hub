#!/usr/bin/env bash
set -euo pipefail

# test_oe_ident.sh — oe-ident（#202 / c″ read-time ambient 識別子）の検証。
#
# 実 tmux は不要（oe-ident は pane を引数で受け state ファイルだけ読む）。pid override を渡して
# キー名前空間を固定し、mock の pane-issue / spawn-registry を読ませる。jq は実体を使う。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_IDENT="$PROJECT_DIR/bin/oe-ident"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
export OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
export OE_DELEGATE_STATE_DIR="$_TMP_DIR/oe-delegate"
mkdir -p "$OE_PANE_ISSUE_DIR" "$OE_DELEGATE_STATE_DIR"

# キー生成は本体と同じ契約を使う（手書き複製のドリフトを避ける・Copilot 指摘）。
# _oe_reg_key は $TMUX から server pid を導出するため、固定 pid を TMUX 経由で注入する
# （oe-ident の pid-override 経路と同一イディオム）。
# shellcheck source=../lib/delegate-registry.sh
source "$PROJECT_DIR/lib/delegate-registry.sh"

PID=9999
keyfor() { TMUX="oe,${PID},0" _oe_reg_key "$1"; }

PASS=0
FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (want=[$expected] got=[$actual])"; FAIL=$((FAIL + 1))
  fi
}
run() { bash "$OE_IDENT" "$1" "$PID" 2>/dev/null; }

echo "[1] pane-issue のみ -> label（spawn 関係無しなので role 無し）"
printf '{"name":"#202 pane-identity"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %5)"
ck "pane-issue label" "#202 pane-identity" "$(run %5)"

echo "[2] spawn child entry -> child <label>"
jq -cn '{pane:"%6",label:"#179",workspace:"/w",parent_pane:"%5",role:"child"}' \
  > "$OE_DELEGATE_STATE_DIR/$(keyfor %6).json"
ck "child role+label" "child #179" "$(run %6)"

echo "[3] parent（%6 の parent_pane=%5）-> parent + pane-issue label"
ck "parent role + pane-issue label" "parent #202 pane-identity" "$(run %5)"

echo "[4] standalone pane-issue（spawn 関係無し）-> label のみ"
printf '{"name":"#204 toolkit"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %7)"
ck "standalone label only" "#204 toolkit" "$(run %7)"

echo "[5] 未知ペイン（ソース無し）-> 空"
ck "unknown empty" "" "$(run %99)"

echo "[6] 不正引数 -> 空・exit 0（border を壊さない）"
rc=0; out="$(bash "$OE_IDENT" "notapane" "$PID" 2>/dev/null)" || rc=$?
ck "invalid empty" "" "$out"
ck "invalid exit0" "0" "$rc"

echo "[7] pane-issue label が spawn label に優先（role は child のまま）"
printf '{"name":"#179 notify-jump"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %6)"
ck "pane-issue beats spawn label" "child #179 notify-jump" "$(run %6)"

echo "[8] child かつ parent -> parent 優先"
jq -cn '{pane:"%8",label:"#g",workspace:"/w",parent_pane:"%6",role:"child"}' \
  > "$OE_DELEGATE_STATE_DIR/$(keyfor %8).json"
ck "parent beats child" "parent #179 notify-jump" "$(run %6)"

echo "[9] 引数欠落 -> 空・exit 0"
rc=0; out="$(bash "$OE_IDENT" 2>/dev/null)" || rc=$?
ck "missing arg empty" "" "$out"
ck "missing arg exit0" "0" "$rc"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
