#!/usr/bin/env bash
set -uo pipefail

# test_check_claude_settings.sh — check-claude-settings.sh の判定を end-to-end で検証。
#   （#359 PR-1・検査のみ・適用側には触らない）
#
# 一時ディレクトリの settings.json の複製だけを触る（実 ~/.claude は読まない・書かない）。
# 検証する軸:
#   - 現行の形（拍動 producer そのまま / 包み済み）の両方で緑になること
#   - 宣言の1項目だけを崩したとき、その項目だけが差分に出ること
#   - 値が false / null の項目を持つ settings でも見落とさないこと
#     （jq の paths(scalars) は false と null のパスを静かに落とす。実装がそれに
#       依存していないことをここで担保する）
#   - 上位スコープの同名項目で、マージされる項目と負ける項目の文言が分かれること
#   - settings.json が無い / symlink / 壊れている場合に差分として報告すること

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CHECK="$REPO_ROOT/scripts/sync/check-claude-settings.sh"
HOOKS_SRC="$REPO_ROOT/canonical/hooks/claude.hooks.json"
SL_SRC="$REPO_ROOT/canonical/claude/statusline/claude.statusline.json"

[[ -x "$CHECK" ]] || { echo "FAIL: check script not found: $CHECK"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

CASE=""; ST=""; PROJ=""; OUT=""; RC=0
fresh() {
  CASE="$_TMP_DIR/$1"; mkdir -p "$CASE/.claude"
  ST="$CASE/settings.json"; PROJ="$CASE"
}
run() { OUT="$("$CHECK" --settings "$ST" --project-root "$PROJ" 2>&1)"; RC=$?; }

# 宣言どおりの settings.json を組み立てる（拍動 producer がそのまま入った形）。
build_green() {
  jq -n \
    --argjson hooks "$(jq -c '.hooks' "$HOOKS_SRC")" \
    --argjson sl "$(jq -c '.statusLine' "$SL_SRC")" \
    '{hooks: $hooks, statusLine: $sl}' > "$ST"
}

# ============================================================================
echo "[1] 宣言どおり（拍動 producer がそのまま）→ 緑"
fresh c1; build_green
run
ck  "exit 0" "0" "$RC"
ckc "宣言どおりと出る" "$OUT" "宣言どおり"
ckc "hooks が一致" "$OUT" "一致 /hooks"
ckc "statusLine が一致" "$OUT" "一致 /statusLine"

echo "[2] statusLine が包まれた形 → 緑（値の一致では判定しない）"
fresh c2; build_green
our_cmd="$(jq -r '.statusLine.command' "$SL_SRC")"
wrapped="OE_HEARTBEAT_WRAP_CMD=/Users/someone/mybar.sh ${our_cmd}"
jq --arg c "$wrapped" '.statusLine.command = $c' "$ST" > "$ST.t" && mv "$ST.t" "$ST"
run
ck  "exit 0" "0" "$RC"
ckc "包んでいても一致" "$OUT" "一致 /statusLine"

echo "[3] 包んだ元コマンドが失われている → 差分"
fresh c3; build_green
jq --arg c "OE_HEARTBEAT_WRAP_CMD= $(jq -r '.statusLine.command' "$SL_SRC")" \
   '.statusLine.command = $c' "$ST" > "$ST.t" && mv "$ST.t" "$ST"
run
ck  "exit 1" "1" "$RC"
ckc "元コマンド喪失を指摘" "$OUT" "包んだ元のコマンドが失われています"

echo "[4] hooks だけ崩す → その項目だけが差分に出る"
fresh c4; build_green
jq '.hooks.Stop = []' "$ST" > "$ST.t" && mv "$ST.t" "$ST"
run
ck  "exit 1" "1" "$RC"
ckc "hooks が差分" "$OUT" "差分 /hooks"
ncc "statusLine は巻き込まれない" "$OUT" "差分 /statusLine"

echo "[5] statusLine だけ崩す → その項目だけが差分に出る"
fresh c5; build_green
jq '.statusLine.command = "/bin/echo hi"' "$ST" > "$ST.t" && mv "$ST.t" "$ST"
run
ck  "exit 1" "1" "$RC"
ckc "statusLine が差分" "$OUT" "差分 /statusLine"
ncc "hooks は巻き込まれない" "$OUT" "差分 /hooks"

echo "[6] 値が false / null の項目が同居していても見落とさない"
fresh c6; build_green
jq '. + {remoteControlAtStartup: false, someNullKey: null}' "$ST" > "$ST.t" && mv "$ST.t" "$ST"
run
ck  "exit 0（宣言外の項目は無視）" "0" "$RC"
fresh c6b; build_green
jq '. + {remoteControlAtStartup: false, someNullKey: null} | .hooks.Stop = []' "$ST" > "$ST.t" && mv "$ST.t" "$ST"
run
ck  "false/null 同居でも hooks の差分を拾う" "1" "$RC"
ckc "hooks が差分" "$OUT" "差分 /hooks"

echo "[7] 宣言した項目が丸ごと無い → 未適用として報告"
fresh c7
jq -n --argjson sl "$(jq -c '.statusLine' "$SL_SRC")" '{statusLine: $sl}' > "$ST"
run
ck  "exit 1" "1" "$RC"
ckc "未適用と出る" "$OUT" "未適用 /hooks"

echo "[8] settings.json が無い → 一度も適用されていないと報告"
fresh c8
run
ck  "exit 1" "1" "$RC"
ckc "ファイルが無いと出る" "$OUT" "一度も適用されていません"

echo "[9] settings.json が symlink → 適用できないと報告"
fresh c9; build_green
mv "$ST" "$CASE/real.json"; ln -s "$CASE/real.json" "$ST"
run
ck  "exit 1" "1" "$RC"
ckc "symlink を指摘" "$OUT" "symlink なので適用できません"

echo "[10] settings.json が壊れている → 読めないと報告"
fresh c10
printf '%s' '{ not json' > "$ST"
run
ck  "exit 1" "1" "$RC"
ckc "JSON として読めないと出る" "$OUT" "JSON として読めません"

echo "[11] 上位スコープの同名項目 — マージされる項目と負ける項目で文言が違う"
fresh c11; build_green
mkdir -p "$PROJ/.claude"
printf '%s' '{"hooks":{"Stop":[]}}' > "$PROJ/.claude/settings.local.json"
run
ckc "hooks はマージされると伝える" "$OUT" "この項目はスコープをまたいでマージされるので"
ck  "マージ側だけでは差分にしない" "0" "$RC"
fresh c11b; build_green
mkdir -p "$PROJ/.claude"
printf '%s' '{"statusLine":{"type":"command","command":"x"}}' > "$PROJ/.claude/settings.local.json"
run
ckc "statusLine は負けると伝える" "$OUT" "この項目は上位が勝つので"
ck  "上書き側は差分として数える" "1" "$RC"

echo "[12] 宣言が空 → 緑を名乗らせない"
fresh c12; build_green
printf '%s' '{"version":1,"items":[]}' > "$CASE/empty-decl.json"
OUT="$("$CHECK" --settings "$ST" --project-root "$PROJ" --declaration "$CASE/empty-decl.json" 2>&1)"; RC=$?
ck  "exit 2" "2" "$RC"
ckc "母集団が空だと言う" "$OUT" "宣言に項目がありません"

echo "[13] 見ていないスコープを必ず印字する"
fresh c13; build_green
run
ckc "managed を挙げる" "$OUT" "managed settings"
ckc "起動フラグを挙げる" "$OUT" "--settings"
ckc "セッションの実値は取れないと書く" "$OUT" "走っているセッションの実際の値"

echo "[14] replace の一致判定がキーの順に依存しない（実装SO 指摘の回帰）"
fresh c14; build_green
# hooks のキーを逆順に並べ替えた settings。中身は同じなので一致であるべき。
jq '.hooks |= (to_entries | reverse | from_entries)' "$ST" > "$ST.t" && mv "$ST.t" "$ST"
run
ck  "並べ替えても一致" "0" "$RC"
ckc "hooks が一致" "$OUT" "一致 /hooks"

echo "[15] merge-object が値 false / null の葉を見落とさない（実装SO 指摘の回帰）"
fresh c15
cat > "$CASE/decl.json" <<'DECLEOF'
{
  "version": 1,
  "items": [
    { "pointer": "/autoMode", "op": "merge-object", "scope_behavior": "override",
      "source": { "file": "SRCFILE", "pointer": "/autoMode" } }
  ],
  "unchecked_scopes": ["managed settings", "--settings", "走っているセッションの実際の値"]
}
DECLEOF
printf '%s' '{"autoMode":{"flagFalse":false,"flagNull":null,"flagTrue":true}}' > "$CASE/src.json"
sed -i.bak "s|SRCFILE|$CASE/src.json|" "$CASE/decl.json" && rm -f "$CASE/decl.json.bak"
# 正本どおり → 緑
printf '%s' '{"autoMode":{"flagFalse":false,"flagNull":null,"flagTrue":true,"extra":1}}' > "$ST"
OUT="$("$CHECK" --settings "$ST" --project-root "$PROJ" --declaration "$CASE/decl.json" 2>&1)"; RC=$?
ck  "正本の葉をすべて含む → 緑" "0" "$RC"
# false の葉だけ壊す → 差分でなければ見落とし
printf '%s' '{"autoMode":{"flagFalse":true,"flagNull":null,"flagTrue":true}}' > "$ST"
OUT="$("$CHECK" --settings "$ST" --project-root "$PROJ" --declaration "$CASE/decl.json" 2>&1)"; RC=$?
ck  "false の葉の違いを拾う" "1" "$RC"
# null の葉だけ壊す
printf '%s' '{"autoMode":{"flagFalse":false,"flagNull":"x","flagTrue":true}}' > "$ST"
OUT="$("$CHECK" --settings "$ST" --project-root "$PROJ" --declaration "$CASE/decl.json" 2>&1)"; RC=$?
ck  "null の葉の違いを拾う" "1" "$RC"
# 葉ごと欠けている
printf '%s' '{"autoMode":{"flagTrue":true}}' > "$ST"
OUT="$("$CHECK" --settings "$ST" --project-root "$PROJ" --declaration "$CASE/decl.json" 2>&1)"; RC=$?
ck  "葉の欠落を拾う" "1" "$RC"

echo "[16] op と正本の型が噛み合わないとき緑を名乗らせない（実装SO 指摘の回帰）"
fresh c16
printf '%s' '{"effortLevel":"high"}' > "$CASE/src.json"
cat > "$CASE/decl.json" <<'DECLEOF'
{"version":1,
 "items":[{"pointer":"/effortLevel","op":"merge-object","scope_behavior":"override",
           "source":{"file":"SRCFILE","pointer":"/effortLevel"}}],
 "unchecked_scopes":["x"]}
DECLEOF
sed -i.bak "s|SRCFILE|$CASE/src.json|" "$CASE/decl.json" && rm -f "$CASE/decl.json.bak"
printf '%s' '{"effortLevel":"low"}' > "$ST"
OUT="$("$CHECK" --settings "$ST" --project-root "$PROJ" --declaration "$CASE/decl.json" 2>&1)"; RC=$?
ck  "スカラーに merge-object → exit 2" "2" "$RC"
ckc "型が噛み合わないと言う" "$OUT" "merge-object の正本がオブジェクトではありません"

cat > "$CASE/decl2.json" <<'DECLEOF'
{"version":1,
 "items":[{"pointer":"/effortLevel","op":"union-array","scope_behavior":"override",
           "source":{"file":"SRCFILE","pointer":"/effortLevel"}}],
 "unchecked_scopes":["x"]}
DECLEOF
sed -i.bak "s|SRCFILE|$CASE/src.json|" "$CASE/decl2.json" && rm -f "$CASE/decl2.json.bak"
OUT="$("$CHECK" --settings "$ST" --project-root "$PROJ" --declaration "$CASE/decl2.json" 2>&1)"; RC=$?
ck  "スカラーに union-array → exit 2" "2" "$RC"

cat > "$CASE/decl3.json" <<'DECLEOF'
{"version":1,
 "items":[{"pointer":"/effortLevel","op":"nonsense","scope_behavior":"override",
           "source":{"file":"SRCFILE","pointer":"/effortLevel"}}],
 "unchecked_scopes":["x"]}
DECLEOF
sed -i.bak "s|SRCFILE|$CASE/src.json|" "$CASE/decl3.json" && rm -f "$CASE/decl3.json.bak"
OUT="$("$CHECK" --settings "$ST" --project-root "$PROJ" --declaration "$CASE/decl3.json" 2>&1)"; RC=$?
ck  "知らない op → exit 2" "2" "$RC"
ckc "扱えない op と言う" "$OUT" "扱えない op です"

echo "[17] 正本に値が無い項目は検査を止める（母集団を静かに縮めない）"
fresh c17; build_green
printf '%s' '{"somethingElse":1}' > "$CASE/src.json"
cat > "$CASE/decl.json" <<'DECLEOF'
{"version":1,
 "items":[{"pointer":"/hooks","op":"replace","scope_behavior":"merge",
           "source":{"file":"SRCFILE","pointer":"/hooks"}}],
 "unchecked_scopes":["x"]}
DECLEOF
sed -i.bak "s|SRCFILE|$CASE/src.json|" "$CASE/decl.json" && rm -f "$CASE/decl.json.bak"
OUT="$("$CHECK" --settings "$ST" --project-root "$PROJ" --declaration "$CASE/decl.json" 2>&1)"; RC=$?
ck  "正本に値が無い → exit 2" "2" "$RC"
ckc "正本に値が無いと言う" "$OUT" "正本に値がありません"

echo ""
echo "=== PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
