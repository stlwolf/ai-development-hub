#!/usr/bin/env bash
# test_so_compare_read_only.sh — SO のレーンが「読むだけ」であることの契約
#
# **なぜ要るか。** 依頼の文面は「ワークスペース配下を参照して回答してください」と読みに
# 行かせる一方で、書かないことをどこにも言っていなかった。実際に cursor レーンが engine の
# verb を直してリポジトリへ直接コミットした（2026-09-14）。原因は3つ重なっていて、
# 依頼に「書くな」が無いこと・cursor に `-f`（`--yolo` の別名）が渡っていたこと・
# 起動時の作業ディレクトリが本体の master だったことである。ここで固定するのは前2つである。
#
# 固定する契約:
#   - **プロンプトの末尾に読み取り専用の制約が付く**（全レーン共通・材料より後ろに置く）。
#   - **codex** は `-s read-only` で起動する。
#   - **claude** は `--permission-mode plan` で起動する。
#   - **cursor** は `--mode ask --sandbox enabled` で起動し、**`-f` を渡さない**。
#
# 実物の AI は呼ばない。PATH の stub に差し替えて、渡された引数を記録して照合する。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SO="$SCRIPT_DIR/../../../scripts/so-compare.sh"
[[ -x "$SO" ]] || { echo "FAIL: so-compare.sh not found: $SO"; exit 1; }

_TMP="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$_TMP"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
nck() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

STUB="$_TMP/stub"; OUT="$_TMP/out"; ARGS="$_TMP/args"
mkdir -p "$STUB" "$ARGS"

# 各レーンの stub。渡された引数を記録して、回答らしきものを返す。
for tool in codex claude agent; do
  cat > "$STUB/$tool" <<STUBEOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$ARGS/$tool.args"
printf 'ok\n'
exit 0
STUBEOF
done
chmod +x "$STUB"/*
export PATH="$STUB:$PATH"

bash "$SO" --with codex,claude,cursor -o "$OUT" "テスト用の問い" >/dev/null 2>&1

echo "[1] プロンプトの末尾に読み取り専用の制約が付く"
prompt="$(cat "$OUT/prompt.txt" 2>/dev/null || true)"
ckc "制約の見出しが在る"       "$prompt" "この依頼の制約（読むだけ）"
ckc "ファイルを変えないと言う" "$prompt" "ファイルを作成・変更・削除しない"
ckc "コミットしないと言う"     "$prompt" "コミットしない"
ckc "見つけたら直さず指摘と言う" "$prompt" "直さずに回答の中で指摘する"
ck  "制約が本文の最後に在る" "1" "$(printf '%s' "$prompt" | tail -1 | grep -c '読む操作')"

echo "[2] codex は read-only のサンドボックスで起動する"
ckc "-s read-only を渡す" "$(cat "$ARGS/codex.args" 2>/dev/null || true)" "-s read-only"

echo "[3] claude は plan モードで起動する"
ckc "--permission-mode plan を渡す" "$(cat "$ARGS/claude.args" 2>/dev/null || true)" "--permission-mode plan"

echo "[4] cursor は ask + sandbox で起動し、-f を渡さない"
cursor_args="$(cat "$ARGS/agent.args" 2>/dev/null || true)"
ckc "--mode ask を渡す"        "$cursor_args" "--mode ask"
ckc "--sandbox enabled を渡す" "$cursor_args" "--sandbox enabled"
nck "-f を渡さない"            "$cursor_args" " -f "

echo
echo "=== RESULT: pass=$PASS fail=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
