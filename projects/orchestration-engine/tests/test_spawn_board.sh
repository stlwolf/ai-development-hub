#!/usr/bin/env bash
# shellcheck disable=SC2034
# shellcheck disable=SC2317  # wez() mocks are invoked indirectly via the sourced spawn.sh
set -euo pipefail

# test_spawn_board.sh — spawn.sh の board ロジックのユニットテスト
#
# Copilot PR #192 反映:
#   C1: oe_board_apply の partial 分岐が rc 早期 return で到達不能だったバグの repro。
#       realistic な partial（exit 5 + {status:"partial", rollback_failed:[...]}）で
#       rollback_failed orphan が cleanup（OE_BOARD_MANAGED_PANES）に登録されることを確認する。
#   C2: oe_board_wait_ready が非数値 timeout で set -e クラッシュしないことを確認する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJECT_DIR

# spawn.sh が参照するグローバル定数を最小限だけ用意（constants.sh の OE_DATA_DIR 依存を避ける）。
OE_CB_MAX_PANES=5
OE_SPAWN_WAIT_READY_SEC=10
OE_SPAWN_PERCENT=30
OE_BOARD_MANAGED_PANES=()

# shellcheck source=../lib/spawn.sh
source "${PROJECT_DIR}/lib/spawn.sh"

PASS=0
FAIL=0

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    (( PASS++ )) || true
  else
    echo "  FAIL: $label (expected='$expected', actual='$actual')"
    (( FAIL++ )) || true
  fi
}

# ---- C1: partial (rc=5) で rollback_failed orphan が cleanup 登録される ----
echo "=== C1: oe_board_apply partial(rc=5) で rollback_failed を cleanup 登録 ==="

# mock 用の split マーカー（oe_spawn_prepare_pane は $(wez pane split ...) を subshell で呼ぶため、
# 変数フラグは親に伝播しない。観測はファイル経由にする）。
_SPLIT_MARKER="$(mktemp)"
trap 'rm -f "$_SPLIT_MARKER"' EXIT
: > "$_SPLIT_MARKER"

# mock: wez layout apply が realistic な partial 失敗を返す
#   stdout = {status:"partial", rollback_failed:[999]} / exit 5（WEZ_EXIT_PANE_OP_FAILED）。
wez() {
  if [[ "${1:-}" == "layout" && "${2:-}" == "apply" ]]; then
    printf '%s\n' '{"status":"partial","root_pane_id":1,"created":[],"failed_step":0,"rollback_failed":[999]}'
    return 5
  fi
  if [[ "${1:-}" == "pane" && "${2:-}" == "split" ]]; then
    echo "split" >> "$_SPLIT_MARKER"
    echo "1234"
    return 0
  fi
  if [[ "${1:-}" == "pane" && "${2:-}" == "capture" ]]; then
    echo ""
    return 0
  fi
  echo "unexpected wez call: $*" >&2
  return 1
}

OE_BOARD_LAYOUT="parent-children"
OE_BOARD_MANAGED_PANES=()
OE_BOARD_PANE_IDS=()
OE_BOARD_CURSOR=0

# set -e 下で apply がクラッシュせず return 0（fallback）すること
apply_rc=0
oe_board_apply || apply_rc=$?
assert_eq "partial apply は return 0（fallback に静かに劣化）" "0" "$apply_rc"

# C1 のコア: rollback_failed の 999 が cleanup 登録される（到達不能だった分岐が機能する）
assert_eq "OE_BOARD_MANAGED_PANES 件数 = 1" "1" "${#OE_BOARD_MANAGED_PANES[@]}"
assert_eq "rollback_failed orphan 999 が cleanup 登録" "999" "${OE_BOARD_MANAGED_PANES[0]:-}"

# pool は空のまま（partial なので board は使わない → 後段で fallback split に倒れる）
assert_eq "pool は空（partial では board pool を構築しない）" "0" "${#OE_BOARD_PANE_IDS[@]}"

# partial 後に prepare_pane を呼ぶと pool 空 → fallback split される
: > "$_SPLIT_MARKER"
oe_spawn_prepare_pane
assert_eq "partial 後の prepare_pane は fallback split を使う" "true" \
  "$( [[ -s "$_SPLIT_MARKER" ]] && echo true || echo false )"
assert_eq "fallback split の pane_id が OE_SPAWN_PANE_ID に入る" "1234" "${OE_SPAWN_PANE_ID:-}"

# ---- C1 補強: status==ok は従来どおり pool を構築する（回帰防止） ----
echo ""
echo "=== C1 回帰: status==ok は pool 構築 + 全 board ペイン cleanup 登録 ==="
wez() {
  if [[ "${1:-}" == "layout" && "${2:-}" == "apply" ]]; then
    printf '%s\n' '{"status":"ok","root_pane_id":1,"window_id":1,"panes":[{"id":"w1","pane_id":777,"index":0},{"id":"w2","pane_id":888,"index":1}]}'
    return 0
  fi
  echo "unexpected wez call: $*" >&2
  return 1
}
OE_BOARD_LAYOUT="parent-children"
OE_BOARD_MANAGED_PANES=()
OE_BOARD_PANE_IDS=()
OE_BOARD_CURSOR=0
oe_board_apply
assert_eq "ok: pool 件数 = 2" "2" "${#OE_BOARD_PANE_IDS[@]}"
assert_eq "ok: pool[0] = 777" "777" "${OE_BOARD_PANE_IDS[0]:-}"
assert_eq "ok: pool[1] = 888" "888" "${OE_BOARD_PANE_IDS[1]:-}"
assert_eq "ok: cleanup 登録件数 = 2" "2" "${#OE_BOARD_MANAGED_PANES[@]}"

# ---- C1 補強: stdout 空（コマンド不在/ハードエラー）は fallback、partial 分岐に入らない ----
echo ""
echo "=== C1 回帰: stdout 空（ハードエラー）は fallback（partial 登録しない） ==="
wez() {
  if [[ "${1:-}" == "layout" && "${2:-}" == "apply" ]]; then
    return 127
  fi
  echo "unexpected wez call: $*" >&2
  return 1
}
OE_BOARD_LAYOUT="parent-children"
OE_BOARD_MANAGED_PANES=()
OE_BOARD_PANE_IDS=()
OE_BOARD_CURSOR=0
empty_rc=0
oe_board_apply || empty_rc=$?
assert_eq "空 stdout apply は return 0" "0" "$empty_rc"
assert_eq "空 stdout は cleanup 登録なし" "0" "${#OE_BOARD_MANAGED_PANES[@]}"
assert_eq "空 stdout は pool 空" "0" "${#OE_BOARD_PANE_IDS[@]}"

# ---- C2: 非数値 timeout で oe_board_wait_ready がクラッシュせず default 適用 ----
echo ""
echo "=== C2: oe_board_wait_ready 非数値 timeout で set -e クラッシュしない ==="

# capture が即座に安定（2 連続一致）して return 0 する mock。timeout 経路の算術が走る前に
# return するが、非数値 timeout の算術展開（timeout_ms=$(( timeout * 1000 ))）は関数冒頭で
# 実行されるため、非数値検証が無いと set -e でここに到達する前にクラッシュする。
wez() {
  if [[ "${1:-}" == "pane" && "${2:-}" == "capture" ]]; then
    echo "stable line"
    return 0
  fi
  echo "unexpected wez call: $*" >&2
  return 1
}

# 非数値 timeout（"abc"）でクラッシュしないこと。set -e 下で関数がクラッシュすれば
# このサブシェルは非 0 で落ち、wait_rc に拾われる。
wait_rc=0
( oe_board_wait_ready "777" "abc" ) >/dev/null 2>&1 || wait_rc=$?
assert_eq "非数値 timeout でクラッシュしない（return 0）" "0" "$wait_rc"

# 空文字 timeout でも default にフォールバックしてクラッシュしないこと
wait_rc2=0
( oe_board_wait_ready "777" "" ) >/dev/null 2>&1 || wait_rc2=$?
assert_eq "空文字 timeout でもクラッシュしない（return 0）" "0" "$wait_rc2"

# 数値 timeout は従来どおり動作すること（回帰防止）
wait_rc3=0
( oe_board_wait_ready "777" "2" ) >/dev/null 2>&1 || wait_rc3=$?
assert_eq "数値 timeout は従来どおり return 0" "0" "$wait_rc3"

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
