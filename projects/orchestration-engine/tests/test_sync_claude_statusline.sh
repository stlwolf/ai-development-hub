#!/usr/bin/env bash
set -euo pipefail

# test_sync_claude_statusline.sh — sync_claude_statusline() の非破壊 merge を end-to-end で検証。
#   （#239 段階1 PR-A・producer 配備の3点セット (3)）
#
# 実 scripts/sync/sync-claude.sh を scratch HOME で回し、settings.json への statusLine merge が
#   - 未設定 → beat producer 設定（他キー保持）
#   - 既存 beat producer → refresh（二重 wrap しない）
#   - ユーザー独自 statusLine → wrap（表示保持・padding 保持）
#   - command が絶対パス化されていても producer と認識し二重 wrap しない（impl SO が検出した回帰）
# を満たすかを確認する。scratch HOME 配下のみを触る（実 ~/.claude は不変）。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SYNC="$REPO_ROOT/scripts/sync/sync-claude.sh"
MARKER="statusline-oe-heartbeat.sh"

[[ -f "$SYNC" ]] || { echo "FAIL: sync-claude.sh not found: $SYNC"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3] in [$2])"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

HOMEDIR=""; ST=""
fresh_home() { HOMEDIR="$_TMP_DIR/$1"; mkdir -p "$HOMEDIR/.claude"; ST="$HOMEDIR/.claude/settings.json"; }
run_sync()   { env HOME="$HOMEDIR" bash "$SYNC" >/dev/null 2>&1; }
sl()         { jq -r "$1" "$ST"; }
# command 中の OE_HEARTBEAT_WRAP_CMD 出現「回数」（行数でなく個数）で二重 wrap を検出。
wrap_count() { sl '.statusLine.command' | grep -o 'OE_HEARTBEAT_WRAP_CMD' | wc -l | tr -d ' '; }

# ============================================================================
echo "[1] statusLine 未設定（hooks あり）→ beat producer 追加・hooks 保持"
fresh_home h1
printf '%s' '{"hooks":{"Stop":[{"matcher":"","hooks":[]}]}}' > "$ST"
run_sync
ck  "hooks 保持" "true" "$(sl '(.hooks.Stop != null)')"
ckc "command は beat producer" "$(sl '.statusLine.command')" "$MARKER"
ck  "refreshInterval=10" "10" "$(sl '.statusLine.refreshInterval')"

echo "[2] 既存 beat producer（\$HOME リテラル）を再 sync → refresh・wrap しない"
run_sync
ck  "wrap しない" "0" "$(wrap_count)"
ckc "command は beat producer のまま" "$(sl '.statusLine.command')" "$MARKER"

echo "[3] ユーザー独自 statusLine → wrap（表示保持・padding 保持）"
fresh_home h3
printf '%s' '{"statusLine":{"type":"command","command":"~/mybar.sh --fancy","padding":2}}' > "$ST"
run_sync
ck  "wrap は1つ" "1" "$(wrap_count)"
ckc "元コマンドを退避" "$(sl '.statusLine.command')" "mybar.sh"
ckc "producer へ call-through" "$(sl '.statusLine.command')" "$MARKER"
ck  "padding 保持（非破壊）" "2" "$(sl '.statusLine.padding')"

echo "[4] wrap 済みを再 sync → 二重 wrap しない"
run_sync
ck  "wrap は1つのまま" "1" "$(wrap_count)"
ckc "元コマンドは退避されたまま" "$(sl '.statusLine.command')" "mybar.sh"

echo "[5] 回帰(impl SO): command が絶対パス化済みでも producer と認識し wrap しない"
fresh_home h5
printf '%s' "{\"statusLine\":{\"type\":\"command\",\"command\":\"$HOMEDIR/.claude/statusline/$MARKER\"}}" > "$ST"
run_sync
ck  "絶対パス producer を wrap しない" "0" "$(wrap_count)"
ckc "command は producer のまま" "$(sl '.statusLine.command')" "$MARKER"

echo "[6] settings.json 無し → statusLine のみで新規作成"
fresh_home h6
rm -f "$ST"
run_sync
ckc "新規作成 command は producer" "$(sl '.statusLine.command')" "$MARKER"
ck  "refreshInterval=10" "10" "$(sl '.statusLine.refreshInterval')"

# ============================================================================
echo ""
echo "=== RESULT: PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]] || exit 1
