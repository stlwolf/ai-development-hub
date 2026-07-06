#!/usr/bin/env bash
set -euo pipefail

# test_oe_task_file.sh — bin/oe --task-file の異常系 validation 検証 (#99)。
#
# 異常系 3 種 (空ファイル / 不在パス / 不正パス=ディレクトリ・非通常ファイル・権限) が
# 明示エラー + exit 2 で弾かれ、暗黙の既定タスクフォールバックや set -e 下の cat 失敗 (exit 1) に
# 陥らないことを検証する。異常系は spawn (oe_board_apply / wez) 到達前に return するため wez 不要
# (temp OE_DATA_DIR で state/audit を隔離)。
#
# bin/oe は末尾で oe_main を無条件実行するため source できない。よって subprocess 実行で検証する。
# 内側の bin/oe は本テストと同じ bash (${BASH}) で起動し、bash 3.2 / 5.x 両系ゲートを実効化する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE="$PROJECT_DIR/bin/oe"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
export OE_DATA_DIR="$_TMP_DIR"   # engine の state/audit を temp に隔離 (実 ~/.claude を汚さない)

PASS=0; FAIL=0
ck()    { if [[ "$2" == "$3"    ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
cksub() { if [[ "$3" == *"$2"*  ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want substr=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }

# 異常系は stdout に何も出さず stderr にエラーを出して exit 2。combined capture で message を検証する。
RUN_RC=0; RUN_ERR=""
run() {
  local out rc=0
  out="$("$BASH" "$OE" "$@" 2>&1)" || rc=$?
  RUN_RC="$rc"; RUN_ERR="$out"
}

echo "[1] 空ファイル: 暗黙に既定タスクへフォールバックせず exit 2"
empty="$_TMP_DIR/empty.md"; : > "$empty"
run --task-file "$empty"
ck    "exit 2"  "2" "$RUN_RC"
cksub "message" "file is empty" "$RUN_ERR"

echo "[2] 不在パス: exit 2"
run --task-file "$_TMP_DIR/does-not-exist.md"
ck    "exit 2"  "2" "$RUN_RC"
cksub "message" "file not found" "$RUN_ERR"

echo "[3] 不正パス (ディレクトリ): 'file not found' でなく 'is a directory' で exit 2"
adir="$_TMP_DIR/adir"; mkdir -p "$adir"
run --task-file "$adir"
ck    "exit 2"  "2" "$RUN_RC"
cksub "message" "is a directory" "$RUN_ERR"

echo "[4] パス引数なし: exit 2"
run --task-file
ck    "exit 2"  "2" "$RUN_RC"
cksub "message" "requires a path argument" "$RUN_ERR"

echo "[5] 不正パス (読めない=権限なし): set -e の cat 失敗 (exit 1) でなく exit 2"
if [[ "$(id -u)" -ne 0 ]]; then
  noread="$_TMP_DIR/noread.md"; echo "task" > "$noread"; chmod 000 "$noread"
  run --task-file "$noread"
  ck    "exit 2"  "2" "$RUN_RC"
  cksub "message" "not readable" "$RUN_ERR"
  chmod u+rwx "$noread" 2>/dev/null || true
else
  echo "  SKIP: root では -r が権限ビットを迂回するため権限ケースを飛ばす"
fi

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
