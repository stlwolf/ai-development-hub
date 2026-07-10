#!/usr/bin/env bash
set -euo pipefail

# test_validate_board.sh — scripts/validate-board.sh（#238 段階1 PR-C・board schema）の検証。
#
# board schema の 3 check を fixture で網羅する:
#   (1) 必須 frontmatter キーの存在 / (2) 鮮度 date が N 日以内 / (3) 必須 section 見出しの存在。
# 鮮度は決定論化のため OE_BOARD_NOW_EPOCH で now を固定する（date +%s は使わない）。
# validator は test_envelope.sh と同じく subprocess で叩き、内側 validator を本テストと同じ
# bash（${BASH}）で起動して bash 3.2 / 5.x 両系ゲートを実効化する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATOR="$PROJECT_DIR/scripts/validate-board.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

# 固定 now = 2026-07-12（UTC）。鮮度 2026-07-10 → age 2（fresh）、2026-06-01 → age 41（stale）。
NOW="$(jq -n '"2026-07-12" | strptime("%Y-%m-%d") | mktime')"

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3] in: $2)"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

RUN_RC=0; RUN_OUT=""
# run <now_epoch> [args...] — 固定 now で validator を回し、stdout+stderr と exit code を捕捉。
run() {
  local now="$1"; shift
  local out rc=0
  out="$(env OE_BOARD_NOW_EPOCH="$now" "$BASH" "$VALIDATOR" "$@" 2>&1)" || rc=$?
  RUN_RC="$rc"; RUN_OUT="$out"
}

# 完全に valid な board を書き出す（各テストで必要な行を削って崩す）。
write_valid_board() {
  cat > "$1" <<'EOF'
---
鮮度: 2026-07-10
現統括: "%144"
succession: 完了
---

# START HERE — cockpit 統括 succession board

## 戦略（不変）
cockpit を早めに整備し運用に回す。

## in-flight（現統括 %144 の担当）
- アクティブな委譲: なし

## repo / 環境 state
- master: `6896289` / worktree: main のみ

## 統括規律
- HG: 子は mutation を自律発火しない。

## succession 手順
1. このボードと MEMORY.md を読む。
EOF
}

# ============================================================================
echo "[1] valid board → exit 0 / OK"
B="$_TMP_DIR/valid.md"; write_valid_board "$B"
run "$NOW" "$B"
ck  "exit 0"    "0" "$RUN_RC"
ckc "OK 出力"   "$RUN_OUT" "OK: $B"

echo "[2] frontmatter 欠落 → exit 1 / WARN frontmatter"
B="$_TMP_DIR/no-frontmatter.md"
cat > "$B" <<'EOF'
# START HERE — cockpit 統括 succession board

## 戦略（不変）
x

## in-flight（現統括）
- なし

## repo / 環境 state
- master: `6896289`

## 統括規律
- HG

## succession 手順
1. read
EOF
run "$NOW" "$B"
ck  "exit 1"          "1" "$RUN_RC"
ckc "WARN frontmatter" "$RUN_OUT" "frontmatter block not found"

echo "[3] 必須 section 欠落（統括規律を削除）→ exit 1 / WARN section"
B="$_TMP_DIR/missing-section.md"; write_valid_board "$B"
# 統括規律 節（見出し + 本文行）を削除
grep -v '統括規律' "$B" | grep -v '子は mutation' > "$B.tmp" && mv "$B.tmp" "$B"
run "$NOW" "$B"
ck  "exit 1"        "1" "$RUN_RC"
ckc "WARN section"  "$RUN_OUT" "missing required section heading: 統括規律"
ncc "戦略 は誤検知しない" "$RUN_OUT" "missing required section heading: 戦略"

echo "[4] 鮮度 古い → exit 1 / WARN stale"
B="$_TMP_DIR/stale.md"; write_valid_board "$B"
sed 's/^鮮度: .*/鮮度: 2026-06-01/' "$B" > "$B.tmp" && mv "$B.tmp" "$B"
run "$NOW" "$B"
ck  "exit 1"      "1" "$RUN_RC"
ckc "WARN stale"  "$RUN_OUT" "board is stale"
ckc "鮮度値を出す" "$RUN_OUT" "2026-06-01"

echo "[5] 必須 frontmatter キー欠落（現統括を削除）→ exit 1 / WARN key"
B="$_TMP_DIR/missing-key.md"; write_valid_board "$B"
sed '/^現統括:/d' "$B" > "$B.tmp" && mv "$B.tmp" "$B"
run "$NOW" "$B"
ck  "exit 1"     "1" "$RUN_RC"
ckc "WARN key"   "$RUN_OUT" "missing required frontmatter key: 現統括"

echo "[6] 鮮度が不正な形式 → exit 1 / WARN format"
B="$_TMP_DIR/bad-date.md"; write_valid_board "$B"
sed 's/^鮮度: .*/鮮度: 2026\/07\/10/' "$B" > "$B.tmp" && mv "$B.tmp" "$B"
run "$NOW" "$B"
ck  "exit 1"        "1" "$RUN_RC"
ckc "WARN 形式"     "$RUN_OUT" "鮮度 must be YYYY-MM-DD"

echo "[7] file not found → exit 2"
run "$NOW" "$_TMP_DIR/does-not-exist.md"
ck  "exit 2"          "2" "$RUN_RC"
ckc "file not found"  "$RUN_OUT" "file not found"

echo "[8] 鮮度しきい値の境界: age==N は fresh / age==N+1 は stale"
B="$_TMP_DIR/edge-fresh.md"; write_valid_board "$B"
sed 's/^鮮度: .*/鮮度: 2026-07-05/' "$B" > "$B.tmp" && mv "$B.tmp" "$B"   # age=7（既定 N=7）
run "$NOW" "$B"
ck  "age==7 fresh exit 0" "0" "$RUN_RC"
B="$_TMP_DIR/edge-stale.md"; write_valid_board "$B"
sed 's/^鮮度: .*/鮮度: 2026-07-04/' "$B" > "$B.tmp" && mv "$B.tmp" "$B"   # age=8
run "$NOW" "$B"
ck  "age==8 stale exit 1" "1" "$RUN_RC"

echo "[9] OE_BOARD_MAX_AGE_DAYS 上書きで古い board も fresh 扱い"
B="$_TMP_DIR/override.md"; write_valid_board "$B"
sed 's/^鮮度: .*/鮮度: 2026-06-01/' "$B" > "$B.tmp" && mv "$B.tmp" "$B"   # age=41
rc=0
OUT="$(env OE_BOARD_NOW_EPOCH="$NOW" OE_BOARD_MAX_AGE_DAYS=60 "$BASH" "$VALIDATOR" "$B" 2>&1)" || rc=$?
ck  "MAX=60 で fresh exit 0" "0" "$rc"
ckc "OK 出力" "$OUT" "OK: $B"

echo "[10] frontmatter あり・鮮度 欠落 → set -e で落ちず section 検査に到達（全 WARN 一括）"
B="$_TMP_DIR/no-fresh.md"; write_valid_board "$B"
sed '/^鮮度:/d' "$B" > "$B.tmp" && mv "$B.tmp" "$B"
# section も1つ落とし「鮮度欠落でも section WARN が出る＝途中終了していない」を確認
grep -v 'succession 手順' "$B" | grep -v 'このボードと MEMORY' > "$B.tmp" && mv "$B.tmp" "$B"
run "$NOW" "$B"
ck  "exit 1"                       "1" "$RUN_RC"
ckc "鮮度 欠落 WARN"               "$RUN_OUT" "missing required frontmatter key: 鮮度"
ckc "鮮度欠落でも section 検査到達" "$RUN_OUT" "missing required section heading: succession 手順"
ckc "INVALID summary 到達"         "$RUN_OUT" "INVALID:"

echo "[11] 空 frontmatter block（--- のみ）→ 必須キー 3 つを WARN（valid 扱いしない）"
B="$_TMP_DIR/empty-fm.md"
{
  printf -- '---\n---\n\n# START HERE\n\n'
  printf '## 戦略\nx\n## in-flight\nx\n## repo / 環境 state\nx\n## 統括規律\nx\n## succession 手順\nx\n'
} > "$B"
run "$NOW" "$B"
ck  "exit 1"              "1" "$RUN_RC"
ckc "鮮度 欠落 WARN"      "$RUN_OUT" "missing required frontmatter key: 鮮度"
ckc "現統括 欠落 WARN"    "$RUN_OUT" "missing required frontmatter key: 現統括"
ckc "succession 欠落 WARN" "$RUN_OUT" "missing required frontmatter key: succession"

echo "[12] 非数値 env → exit 2（環境エラー・cryptic な arithmetic エラーにしない）"
B="$_TMP_DIR/valid2.md"; write_valid_board "$B"
rc=0; OUT="$(env OE_BOARD_MAX_AGE_DAYS=abc "$BASH" "$VALIDATOR" "$B" 2>&1)" || rc=$?
ck  "MAX_AGE_DAYS 非数値 exit 2" "2" "$rc"
ckc "env エラーメッセージ"       "$OUT" "OE_BOARD_MAX_AGE_DAYS must be"
rc=0; OUT="$(env OE_BOARD_NOW_EPOCH=notanumber "$BASH" "$VALIDATOR" "$B" 2>&1)" || rc=$?
ck  "NOW_EPOCH 非数値 exit 2" "2" "$rc"

echo "[13] 鮮度 キーあり・値が空 → exit 1 / WARN empty（date check を素通りさせない）"
B="$_TMP_DIR/empty-fresh.md"; write_valid_board "$B"
sed 's/^鮮度: .*/鮮度:/' "$B" > "$B.tmp" && mv "$B.tmp" "$B"
run "$NOW" "$B"
ck  "exit 1"        "1" "$RUN_RC"
ckc "WARN empty 値" "$RUN_OUT" "鮮度 has an empty value"
ncc "missing key の二重 WARN を出さない" "$RUN_OUT" "missing required frontmatter key: 鮮度"

# --- サマリ ---
echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
