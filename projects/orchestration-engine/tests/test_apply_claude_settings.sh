#!/usr/bin/env bash
set -uo pipefail

# test_apply_claude_settings.sh — 宣言駆動の適用を検証（#359 PR-3）。
#
# 一時ディレクトリの settings.json と、[22] が作る使い捨ての HOME だけを触る
# （実 ~/.claude は読まない・書かない）。
# 検証する軸:
#   - 宣言に無い項目（個人層）を一切変えない
#   - 書き込みは1回。バックアップも1回
#   - 変更が無いときは書かない（バックアップも作らない）
#   - 書けない相手（symlink / 通常ファイル以外 / 壊れた JSON）には触らず、止めない
#   - 読んでから書くまでに他が書き換えたら読み直す
#   - 1項目でも正本が解けなければ何も書かない（部分適用を作らない）
#   - replace / merge-object / union-array / absent / statusline-wrap の各動作
#   - full sync（sync-claude.sh）から宣言が当たり、宣言の外のキーを変えないこと。
#     判定は check-claude-settings.sh と前後の不変で行う（[22]・#401）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
APPLY="$REPO_ROOT/scripts/sync/apply-claude-settings.sh"
CHECK="$REPO_ROOT/scripts/sync/check-claude-settings.sh"
DECL="$REPO_ROOT/canonical/claude/settings.harness.json"
HOOKS_SRC="$REPO_ROOT/canonical/hooks/claude.hooks.json"

[[ -x "$APPLY" ]] || { echo "FAIL: apply script not found: $APPLY"; exit 1; }
[[ -x "$CHECK" ]] || { echo "FAIL: check script not found: $CHECK"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

if ! _TMP_DIR="$(mktemp -d)" || [[ -z "$_TMP_DIR" || ! -d "$_TMP_DIR" ]]; then
  echo "FAIL: 一時ディレクトリを作れません"; exit 1
fi
trap 'rm -rf "$_TMP_DIR"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

CASE=""; ST=""; OUT=""; RC=0
fresh() { CASE="$_TMP_DIR/$1"; mkdir -p "$CASE"; ST="$CASE/settings.json"; }
run()   { OUT="$("$BASH" "$APPLY" --settings "$ST" 2>&1)"; RC=$?; }
run_d() { OUT="$("$BASH" "$APPLY" --settings "$ST" --declaration "$1" 2>&1)"; RC=$?; }
backups() { find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | wc -l | tr -d ' '; }
bkline()  { printf '%s' "$OUT" | grep -c 'Backup:' | tr -d ' '; }
# 宣言から、apply の結果に現れるはずの最上位のキーを導く（absent は消す指定なので除く）。
# 項目を名指しで並べると、宣言に項目を足すたびにここを書き換えることになる（#401）。
decl_keys() { jq -r '[.items[] | select(.op != "absent") | .pointer | ltrimstr("/") | split("/")[0] | gsub("~1"; "/") | gsub("~0"; "~")] | unique | join(" ")' "$DECL"; }

# ============================================================================
echo "[1] 宣言に無い項目を一切変えない"
fresh c1
printf '%s' '{"theme":"dark","tui":"fullscreen","model":"claude-opus-5","remoteControlAtStartup":false,"skipWorkflowUsageWarning":true,"enabledPlugins":{"x@y":true}}' > "$ST"
run
ck  "exit 0" "0" "$RC"
ck  "theme 保持" "dark" "$(jq -r '.theme' "$ST")"
ck  "tui 保持" "fullscreen" "$(jq -r '.tui' "$ST")"
ck  "model 保持" "claude-opus-5" "$(jq -r '.model' "$ST")"
ck  "false の値も保持" "false" "$(jq -r '.remoteControlAtStartup' "$ST")"
ck  "未文書のキーも保持" "true" "$(jq -r '.skipWorkflowUsageWarning' "$ST")"
ck  "enabledPlugins 保持" "true" "$(jq -r '.enabledPlugins["x@y"]' "$ST")"
ck  "hooks は入る" "true" "$(jq -r '(.hooks != null)' "$ST")"
ck  "statusLine は入る" "true" "$(jq -r '(.statusLine != null)' "$ST")"

echo "[2] 書き込みは1回・バックアップも1回"
fresh c2
printf '%s' '{"theme":"dark"}' > "$ST"
run
ck  "Backup の行は1つ" "1" "$(bkline)"
ck  "バックアップファイルも1つ" "1" "$(backups)"

echo "[3] 変更が無ければ書かない（バックアップも作らない）"
fresh c3
printf '%s' '{"theme":"dark"}' > "$ST"
run
before_mtime="$(stat -f %m "$ST" 2>/dev/null || stat -c %Y "$ST")"
rm -f "$CASE"/settings.json.bak.*
run
ck  "2回目は exit 0" "0" "$RC"
ckc "変更なしと言う" "$OUT" "変更はありません"
ck  "バックアップを作らない" "0" "$(backups)"
after_mtime="$(stat -f %m "$ST" 2>/dev/null || stat -c %Y "$ST")"
ck  "ファイルを書き換えない" "$before_mtime" "$after_mtime"

echo "[4] settings.json が無ければ作る（バックアップは無し）"
fresh c4
run
ck  "exit 0" "0" "$RC"
ck  "作られる" "true" "$([[ -f "$ST" ]] && echo true || echo false)"
ck  "バックアップは無い" "0" "$(backups)"
ck  "宣言の項目だけ（宣言から導く）" "$(decl_keys)" "$(jq -r 'keys | join(" ")' "$ST")"

echo "[5] symlink には触らず、止めない"
fresh c5
printf '%s' '{"theme":"dark"}' > "$CASE/real.json"
ln -s "$CASE/real.json" "$ST"
run
ck  "exit 0（止めない）" "0" "$RC"
ckc "symlink だと言う" "$OUT" "symlink なので触りません"
ck  "実体は変わらない" "dark" "$(jq -r '.theme' "$CASE/real.json")"
ck  "symlink のまま" "true" "$([[ -L "$ST" ]] && echo true || echo false)"

echo "[6] 通常ファイル以外には触らず、止めない"
fresh c6
mkdir -p "$ST"
run
ck  "exit 0（止めない）" "0" "$RC"
ckc "通常ファイルでないと言う" "$OUT" "通常ファイルではないので触りません"
ck  "ディレクトリのまま" "true" "$([[ -d "$ST" ]] && echo true || echo false)"

echo "[7] 壊れた JSON には触らず、止めない（現行は hooks 側で sync 全体が止まっていた）"
fresh c7
printf '%s' '{ not json' > "$ST"
run
ck  "exit 0（止めない）" "0" "$RC"
ckc "読めないと言う" "$OUT" "JSON として読めないので触りません"
ck  "中身は元のまま" '{ not json' "$(cat "$ST")"
ck  "バックアップも作らない" "0" "$(backups)"

echo "[8] 正本が1つでも解けなければ何も書かない（部分適用を作らない）"
fresh c8
printf '%s' '{"theme":"dark"}' > "$ST"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[
   {"pointer":"/hooks","op":"replace","scope_behavior":"merge",
    "source":{"file":"$HOOKS_SRC","pointer":"/hooks"}},
   {"pointer":"/statusLine","op":"handler","handler":"statusline-wrap","scope_behavior":"override",
    "source":{"file":"$CASE/no-such-source.json","pointer":"/statusLine"}}
 ],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 2" "2" "$RC"
ck  "hooks も書かれていない" "false" "$(jq -r '(.hooks != null)' "$ST")"
ck  "theme はそのまま" "dark" "$(jq -r '.theme' "$ST")"
ck  "バックアップも作らない" "0" "$(backups)"

echo "[9] merge-object は手元にしかない下位キーを残す"
fresh c9
printf '%s' '{"autoMode":{"environment":["keep"],"mine":1}}' > "$ST"
printf '%s' '{"autoMode":{"environment":["from-canon"],"added":2}}' > "$CASE/src.json"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/autoMode","op":"merge-object","scope_behavior":"override",
           "source":{"file":"$CASE/src.json","pointer":"/autoMode"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 0" "0" "$RC"
ck  "手元だけの下位キーが残る" "1" "$(jq -r '.autoMode.mine' "$ST")"
ck  "正本の値が入る" "2" "$(jq -r '.autoMode.added' "$ST")"
ck  "配列は正本で置き換わる" "from-canon" "$(jq -r '.autoMode.environment[0]' "$ST")"

echo "[10] union-array は手元の項目を残したまま正本の項目を足す"
fresh c10
printf '%s' '{"listy":["mine"]}' > "$ST"
printf '%s' '{"listy":["canon","mine"]}' > "$CASE/src.json"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/listy","op":"union-array","scope_behavior":"merge",
           "source":{"file":"$CASE/src.json","pointer":"/listy"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 0" "0" "$RC"
ck  "重複しない" "2" "$(jq -r '.listy | length' "$ST")"
ck  "手元の項目が残る" "true" "$(jq -r '[.listy[]] | index("mine") != null' "$ST")"
ck  "正本の項目が入る" "true" "$(jq -r '[.listy[]] | index("canon") != null' "$ST")"

echo "[11] absent は消す"
fresh c11
printf '%s' '{"gone":1,"stay":2}' > "$ST"
cat > "$CASE/decl.json" <<'DECLEOF'
{"version":1,
 "items":[{"pointer":"/gone","op":"absent","scope_behavior":"override"}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 0" "0" "$RC"
ck  "消える" "false" "$(jq -r 'has("gone")' "$ST")"
ck  "他は残る" "2" "$(jq -r '.stay' "$ST")"

echo "[12] statusline-wrap の3分岐"
fresh c12a
printf '%s' '{}' > "$ST"
run
ckc "未設定 → 正本を載せる" "$(jq -r '.statusLine.command' "$ST")" "statusline-oe-heartbeat.sh"
ck  "包んでいない" "0" "$(jq -r '.statusLine.command' "$ST" | grep -c 'OE_HEARTBEAT_WRAP_CMD' | tr -d ' ')"
fresh c12b
printf '%s' '{"statusLine":{"type":"command","command":"~/mybar.sh --fancy","padding":2}}' > "$ST"
run
ck  "独自 → 1回だけ包む" "1" "$(jq -r '.statusLine.command' "$ST" | grep -c 'OE_HEARTBEAT_WRAP_CMD' | tr -d ' ')"
ckc "元コマンドを退避" "$(jq -r '.statusLine.command' "$ST")" "mybar.sh"
ck  "padding を保持" "2" "$(jq -r '.statusLine.padding' "$ST")"
run
ck  "再適用でも二重に包まない" "1" "$(jq -r '.statusLine.command' "$ST" | grep -c 'OE_HEARTBEAT_WRAP_CMD' | tr -d ' ')"

echo "[13] 読んでから書くまでに他が書き換えたら読み直す"
fresh c13
printf '%s' '{"theme":"dark"}' > "$ST"
run
ck  "1回目 exit 0" "0" "$RC"
printf '%s' "$(jq -c '. + {injected: 1}' "$ST")" > "$ST"
run
ck  "外の追記があっても適用できる" "0" "$RC"
ck  "外の追記は消えない" "1" "$(jq -r '.injected' "$ST")"

echo "[13b] 横取りを実際に起こす（1回だけ割り込む → 読み直して成功する）"
# 適用スクリプト本体に試験用の分岐は置かない（本番経路に任意コマンドの実行口を
# 残さないため）。代わりに、テストがスクリプトの複製へ割り込みを1行挿して走らせる。
fresh c13b
printf '%s' '{"theme":"dark"}' > "$ST"
marker="$CASE/raced"
sed "s|^    # (c) 最後の確認。|    if [[ ! -e '$marker' ]]; then touch '$marker'; jq -c '. + {raced: 1}' '$ST' > '$ST.r' \&\& mv '$ST.r' '$ST'; fi\n    # (c) 最後の確認。|" \
    "$APPLY" > "$CASE/apply_race.sh"
chmod +x "$CASE/apply_race.sh"
ck  "割り込みを挿せた" "1" "$(grep -c "raced" "$CASE/apply_race.sh" | tr -d ' ')"
OUT="$("$BASH" "$CASE/apply_race.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ck  "読み直して成功する" "0" "$RC"
ckc "読み直したと言う" "$OUT" "読み直します"
ck  "割り込みの追記が残る" "1" "$(jq -r '.raced' "$ST")"
ck  "宣言の項目も入る" "true" "$(jq -r '(.hooks != null)' "$ST")"
ck  "個人層も残る" "dark" "$(jq -r '.theme' "$ST")"
ck  "試行ごとに写しが残る（1回やり直したので2つ）" "2" "$(find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | wc -l | tr -d ' ')"

echo "[13c] 横取りが続くなら中止する（書かない）"
fresh c13c
printf '%s' '{"theme":"dark"}' > "$ST"
sed "s|^    # (c) 最後の確認。|    jq -c '.n = ((.n // 0) + 1)' '$ST' > '$ST.r' \&\& mv '$ST.r' '$ST'\n    # (c) 最後の確認。|" \
    "$APPLY" > "$CASE/apply_race.sh"
chmod +x "$CASE/apply_race.sh"
OUT="$("$BASH" "$CASE/apply_race.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ck  "exit 1" "1" "$RC"
ckc "中止すると言う" "$OUT" "中止します"
ck  "宣言の項目は書かれていない" "false" "$(jq -r '(.hooks != null)' "$ST")"
ck  "個人層は無傷" "dark" "$(jq -r '.theme' "$ST")"
ck  "諦めたときも写しは残る" "true" "$([[ "$(find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | wc -l | tr -d ' ')" -ge 1 ]] && echo true || echo false)"
ckc "残したと言う" "$OUT" "読んだ時点の内容を残しました"

echo "[14] 宣言が空 → 何も書かない"
fresh c14
printf '%s' '{"theme":"dark"}' > "$ST"
printf '%s' '{"version":1,"items":[]}' > "$CASE/empty.json"
run_d "$CASE/empty.json"
ck  "exit 2" "2" "$RC"
ck  "theme はそのまま" "dark" "$(jq -r '.theme' "$ST")"
ck  "hooks は入らない" "false" "$(jq -r '(.hooks != null)' "$ST")"

echo "[15] 知らないハンドラ名を通さない（実装SO 指摘の回帰）"
fresh c15
printf '%s' '{"theme":"dark"}' > "$ST"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/statusLine","op":"handler","handler":"statusline-warp","scope_behavior":"override",
           "source":{"file":"$REPO_ROOT/canonical/claude/statusline/claude.statusline.json","pointer":"/statusLine"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 2" "2" "$RC"
ckc "知らないハンドラだと言う" "$OUT" "知らないハンドラです"
ck  "何も書かない" "false" "$(jq -r '(.statusLine != null)' "$ST")"
ck  "個人層は無傷" "dark" "$(jq -r '.theme' "$ST")"

echo "[16] union-array はキーの順が違うだけのオブジェクトを重複扱いする"
fresh c16
printf '%s' '{"listy":[{"a":1,"b":2}]}' > "$ST"
printf '%s' '{"listy":[{"b":2,"a":1},{"c":3}]}' > "$CASE/src.json"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/listy","op":"union-array","scope_behavior":"merge",
           "source":{"file":"$CASE/src.json","pointer":"/listy"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 0" "0" "$RC"
ck  "同値は重複しない" "2" "$(jq -r '.listy | length' "$ST")"
ck  "手元の並びは先頭のまま" "1" "$(jq -r '.listy[0].a' "$ST")"

echo "[17] 親ディレクトリが無くても作れる（実装SO 指摘の回帰）"
fresh c17
ST="$CASE/nested/deeper/settings.json"
run
ck  "exit 0" "0" "$RC"
ck  "作られる" "true" "$([[ -f "$ST" ]] && echo true || echo false)"
ck  "宣言の項目が入る（宣言から導く）" "$(decl_keys)" "$(jq -r 'keys | join(" ")' "$ST")"

echo "[19] ポインタの妥当性（実装SO 指摘の回帰）"
fresh c19
printf '%s' '{"theme":"dark","model":"m"}' > "$ST"
for badptr in "" "hooks" "/items/0"; do
  cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"$badptr","op":"replace","scope_behavior":"override",
           "source":{"file":"$REPO_ROOT/canonical/hooks/claude.hooks.json","pointer":"/hooks"}}],
 "unchecked_scopes":["x"]}
DECLEOF
  run_d "$CASE/decl.json"
  ck  "ポインタ [$badptr] を拒む" "2" "$RC"
done
ck  "個人層は無傷" "dark" "$(jq -r '.theme' "$ST")"
ck  "根を潰していない" "m" "$(jq -r '.model' "$ST")"

echo "[20] 正本の値が null でも適用できる（実装SO 指摘の回帰）"
fresh c20
printf '%s' '{"theme":"dark"}' > "$ST"
printf '%s' '{"nullable":null}' > "$CASE/src.json"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/nullable","op":"replace","scope_behavior":"override",
           "source":{"file":"$CASE/src.json","pointer":"/nullable"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 0" "0" "$RC"
ck  "キーが作られる" "true" "$(jq -r 'has("nullable")' "$ST")"
ck  "値は null" "null" "$(jq -r '.nullable' "$ST")"
printf '%s' '{"other":1}' > "$CASE/src2.json"
cat > "$CASE/decl2.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/missing","op":"replace","scope_behavior":"override",
           "source":{"file":"$CASE/src2.json","pointer":"/missing"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl2.json"
ck  "パスが無ければ止める" "2" "$RC"
ckc "そのパスが無いと言う" "$OUT" "正本にそのパスがありません"

echo "[21] 途中で symlink に差し替わっても置き換えない（実装SO 指摘の回帰）"
fresh c21
printf '%s' '{"theme":"dark"}' > "$ST"
printf '%s' '{"theme":"real"}' > "$CASE/real.json"
# 1回目の確認を失敗させ、その隙に対象を symlink へ差し替える。
sed "s|^    # (c) 最後の確認。|    if [[ ! -L '$ST' ]]; then rm -f '$ST'; ln -s '$CASE/real.json' '$ST'; fi\n    # (c) 最後の確認。|" \
    "$APPLY" > "$CASE/apply_swap.sh"
chmod +x "$CASE/apply_swap.sh"
OUT="$("$BASH" "$CASE/apply_swap.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ck  "symlink のまま残る" "true" "$([[ -L "$ST" ]] && echo true || echo false)"
ck  "リンク先を書き換えていない" "real" "$(jq -r '.theme' "$CASE/real.json")"
ckc "symlink だと言う" "$OUT" "symlink なので触りません"

echo "[22] sync の結果に check を当て、宣言の外のキーが変わらないことを見る（#401・撤去した等価性の代わり）"
# 撤去した旧 [22]（2026-09-16・#338）は、git の履歴から取り出した旧実装と結果を
# 8つの fixture で比べていた。旧実装は hooks と statusLine しか知らないので、宣言に
# 項目を足すと原理的に一致しなくなり、owner 裁定で外した。ここはその代わりである。
# 判定の基準: 宣言の内側は check-claude-settings.sh が見て、外側は sync の前後で
#   変わらないことを見る。check は apply と判定ロジックを共有しない別の読み手なので、
#   apply の基準になれる。この成立条件は M6 と構造の確かめで毎回見る。
# 起動: sync-claude.sh を shebang に任せて起動する（"$BASH" を付けない）。本番と同じく
#   sync は /bin/bash、apply は env bash で動く。これは本番の組み合わせを走らせる
#   主張で、bash の版ごとの主張ではない（版ごとはこのファイルの他の項目が見ている）。
# 隔離: HOME は $_TMP_DIR の下の使い捨てで、本物の ~/.claude には触れない。
#   本物の木で走らせるので、配る .sh に実行権が無いと sync がリポジトリへ chmod を
#   当てる。その場合は走らせずに落とす。
# 陽性対照: apply や宣言を差し替えた写しの木で、期待した fixture が期待した理由で
#   落ちることを見る（M1〜M6）。項目を足してもこの節を書き換えずに済むのは、
#   最上位の pointer に replace の項目を足す場合までである（入れ子は赤に倒れる）。
#   設計は docs/harness/plans/2026-10-18-plan-401-settings-apply-check.md にある。
_TMP_PHYS="$(cd "$_TMP_DIR" && pwd -P)"
# shellcheck disable=SC2016  # jq プログラムなのでシェルに展開させない
EQ_JQ_PTR='def ptr2path($p): $p | ltrimstr("/") | split("/") | map(gsub("~1"; "/") | gsub("~0"; "~"));'

# 撤去前の旧 [22] の8つをそのまま写し、宣言から作る stale_replace を足す。
declare -a FIX_NAMES=(missing hooks_only own_statusline wrapped broken_json symlink personal_keys dir stale_replace)
# shellcheck disable=SC2016  # fixture の中身は literal のまま渡す
declare -a FIX_INITS=(
  'NONE'
  '{"hooks":{"Stop":[{"matcher":"","hooks":[]}]}}'
  '{"statusLine":{"type":"command","command":"~/mybar.sh --fancy","padding":2}}'
  '{"statusLine":{"type":"command","command":"OE_HEARTBEAT_WRAP_CMD=/x/mybar.sh $HOME/.claude/statusline/statusline-oe-heartbeat.sh","refreshInterval":10}}'
  '{ not json'
  'SYMLINK'
  '{"theme":"dark","tui":"fullscreen","model":"claude-opus-5","remoteControlAtStartup":false,"skipWorkflowUsageWarning":true}'
  'DIR'
  'STALE'
)

# 書けない相手では、sync は止めず、check は理由つきで 1 を返すのが正しい。
eq_unwritable_reason() {
  case "$1" in
    broken_json) echo "JSON として読めません" ;;
    symlink)     echo "symlink なので適用できません" ;;
    dir)         echo "通常ファイルではないので適用できません" ;;
    *)           return 1 ;;
  esac
}

eq_init_of() {
  local i
  for i in "${!FIX_NAMES[@]}"; do
    [[ "${FIX_NAMES[$i]}" == "$1" ]] && { printf '%s' "${FIX_INITS[$i]}"; return 0; }
  done
  return 1
}

eq_replace_ptrs() { jq -r '.items[] | select(.op == "replace") | .pointer' "$1/canonical/claude/settings.harness.json"; }

# 写しの木を作る。中身は宣言から引いて集める（手で並べると、宣言に項目を
# 足したときに写しだけ取り残される。#338 で test_sync_output_styles.sh が踏んだ）。
eq_make_tree() {
  local dst="$1" rel
  mkdir -p "$dst/scripts/sync" "$dst/canonical/claude" || return 1
  cp "$REPO_ROOT/scripts/sync/sync-claude.sh" "$APPLY" "$CHECK" "$dst/scripts/sync/" || return 1
  cp "$DECL" "$REPO_ROOT/canonical/claude/settings-known-keys.txt" "$dst/canonical/claude/" || return 1
  cp -R "$REPO_ROOT/canonical/claude/statusline" "$dst/canonical/claude/" || return 1
  while IFS= read -r rel; do
    [[ -z "$rel" || "$rel" == /* ]] && continue
    if ! mkdir -p "$dst/$(dirname "$rel")" || ! cp "$REPO_ROOT/$rel" "$dst/$rel"; then return 1; fi
  done < <(jq -r '.items[].source.file // empty' "$DECL")
}

# eq_inv <宣言> <前> <後> — 宣言の外で変わった最上位のキーと、handler / merge-object の
#   pointer の中で消えたキー（statusLine.padding のように書く）を、カンマでつないで出す。
#   何も無ければ空。比べられなければ非0で返す（「何も無い」に倒さない）。
eq_inv() {
  jq -rn --slurpfile d "$1" --slurpfile b "$2" --slurpfile a "$3" "$EQ_JQ_PTR"'
    ($d[0].items | map({path: ptr2path(.pointer), op: .op})) as $its
    | ($its | map(.path)) as $ps
    | ($b[0] | delpaths($ps)) as $B
    | ($a[0] | delpaths($ps)) as $A
    | ([$B, $A] | map(keys) | add | unique
       | map(. as $k | select((($B | has($k)) != ($A | has($k))) or ($B[$k] != $A[$k])))) as $outside
    | ([$its[] | select(.op == "handler" or .op == "merge-object") | .path as $p
        | ($b[0] | getpath($p)) as $bv
        | ($a[0] | getpath($p)) as $av
        | select(($bv | type) == "object")
        | if ($av | type) != "object" then ($p | join("."))
          else ($bv | keys[] | select(. as $k | $av | has($k) | not) | ($p + [.]) | join("."))
          end]) as $inside
    | ($outside + $inside) | join(",")'
}

# eq_run <木> <名札> <fixture 名> <初期値> — 1件を走らせ、結果を EQ_* に入れる。
#   出力は $_TMP_DIR/eq/<名札>/<fixture 名>/ に残す（sync.out・check.out・before.json）。
EQ_DIR=""; EQ_ST=""; EQ_SYNC_RC=""; EQ_CHECK_RC=""; EQ_INV=""; EQ_KEPT=""
eq_run() {
  local tree="$1" label="$2" name="$3" init="$4" home phys
  EQ_DIR="$_TMP_DIR/eq/$label/$name"; home="$EQ_DIR/home"; EQ_ST="$home/.claude/settings.json"
  EQ_SYNC_RC="skip"; EQ_CHECK_RC="skip"; EQ_INV="!not-run"; EQ_KEPT="!not-run"
  mkdir -p "$home/.claude" "$EQ_DIR/proj" || return 1
  # 使い捨ての置き場の下を指しているかを物理パスで確かめる（変数が空になる等の
  # 書き間違いで、本物の HOME へ向けて sync を走らせない）。
  phys="$(cd "$home" && pwd -P)" || return 1
  case "$phys" in
    "$_TMP_PHYS"/*) ;;
    *) echo "  FAIL: HOME が使い捨ての置き場の外を指している: $phys"; FAIL=$((FAIL+1)); return 1 ;;
  esac
  case "$init" in
    NONE)    printf '%s' '{}' > "$EQ_DIR/before.json" ;;
    SYMLINK) printf '%s' '{"hooks":{}}' > "$home/.claude/real.json"; ln -s "$home/.claude/real.json" "$EQ_ST" ;;
    DIR)     mkdir -p "$EQ_ST" ;;
    STALE)
      # 宣言の replace の項目すべてに、正本と違う値を入れる。オブジェクトにしておくと、
      # 置き換えでなく重ね合わせにする誤りも捕まる。
      jq -c "$EQ_JQ_PTR"' reduce (.items[] | select(.op == "replace") | .pointer) as $p
            ({}; setpath(ptr2path($p); {"__stale401__": true}))' \
          "$tree/canonical/claude/settings.harness.json" > "$EQ_ST" || return 1
      cp "$EQ_ST" "$EQ_DIR/before.json" ;;
    *)       printf '%s' "$init" > "$EQ_ST"; cp "$EQ_ST" "$EQ_DIR/before.json" ;;
  esac
  # shebang に任せて起動する。テストの環境の起動時のファイル（BASH_ENV / ENV）は引き継がない。
  env -u BASH_ENV -u ENV HOME="$home" "$tree/scripts/sync/sync-claude.sh" > "$EQ_DIR/sync.out" 2>&1
  EQ_SYNC_RC=$?
  env -u BASH_ENV -u ENV HOME="$home" "$tree/scripts/sync/check-claude-settings.sh" \
      --settings "$EQ_ST" --project-root "$EQ_DIR/proj" > "$EQ_DIR/check.out" 2>&1
  EQ_CHECK_RC=$?
  case "$init" in
    SYMLINK)
      if [[ -L "$EQ_ST" && "$(cat "$home/.claude/real.json")" == '{"hooks":{}}' ]]; then EQ_KEPT=yes; else EQ_KEPT=no; fi ;;
    DIR)
      if [[ -d "$EQ_ST" && -z "$(find "$EQ_ST" -mindepth 1 -print 2>/dev/null)" ]]; then EQ_KEPT=yes; else EQ_KEPT=no; fi ;;
    *)
      if cmp -s "$EQ_DIR/before.json" "$EQ_ST"; then EQ_KEPT=yes; else EQ_KEPT=no; fi ;;
  esac
  EQ_INV="$(eq_inv "$tree/canonical/claude/settings.harness.json" "$EQ_DIR/before.json" "$EQ_ST" 2>/dev/null)" || EQ_INV="!error"
}

# eq_matrix <木> <名札> — fixture をすべて走らせ、期待から外れたものを一覧にする。
#   EQ_L_SYNC:  sync が 0 でなかった fixture
#   EQ_L_CHECK: check が 0 でなかった書ける相手
#   EQ_L_INV:   不変の検査が何かを拾った書ける相手（名前:拾ったもの）
#   EQ_L_UNW:   書けない相手のうち、中身が変わったか、check が理由つきの 1 でなかったもの
#   EQ_RAN:     最後まで走らせた件数
EQ_L_SYNC=""; EQ_L_CHECK=""; EQ_L_INV=""; EQ_L_UNW=""; EQ_RAN=0
eq_matrix() {
  local tree="$1" label="$2" i n reason
  EQ_L_SYNC=""; EQ_L_CHECK=""; EQ_L_INV=""; EQ_L_UNW=""; EQ_RAN=0
  for i in "${!FIX_NAMES[@]}"; do
    n="${FIX_NAMES[$i]}"
    eq_run "$tree" "$label" "$n" "${FIX_INITS[$i]}" || continue
    EQ_RAN=$((EQ_RAN+1))
    [[ "$EQ_SYNC_RC" -ne 0 ]] && EQ_L_SYNC="${EQ_L_SYNC:+$EQ_L_SYNC }$n"
    if reason="$(eq_unwritable_reason "$n")"; then
      if [[ "$EQ_KEPT" != yes || "$EQ_CHECK_RC" -ne 1 ]] || ! grep -qF -- "$reason" "$EQ_DIR/check.out"; then
        EQ_L_UNW="${EQ_L_UNW:+$EQ_L_UNW }$n"
      fi
    else
      [[ "$EQ_CHECK_RC" -ne 0 ]] && EQ_L_CHECK="${EQ_L_CHECK:+$EQ_L_CHECK }$n"
      [[ -n "$EQ_INV" ]] && EQ_L_INV="${EQ_L_INV:+$EQ_L_INV }$n:$EQ_INV"
    fi
  done
  return 0
}

eq_tree_or_fail() { eq_make_tree "$1" || { echo "  FAIL: 写しの木を作れない: $1"; FAIL=$((FAIL+1)); }; }

# --- 本物の木 ---
eq_nonexec=""
while IFS= read -r -d '' f; do
  [[ -x "$f" ]] || eq_nonexec="${eq_nonexec:+$eq_nonexec }${f#"$REPO_ROOT"/}"
done < <(find "$REPO_ROOT/canonical/hooks/scripts" "$REPO_ROOT/canonical/claude/statusline" -type f -name '*.sh' -print0 2>/dev/null)
ck  "配る .sh はすべて実行可能（本物の木で sync にリポジトリへ chmod させない）" "" "$eq_nonexec"
if [[ -z "$eq_nonexec" ]]; then
  eq_matrix "$REPO_ROOT" base
  ck  "本物の木: fixture をすべて走らせた" "${#FIX_NAMES[@]}" "$EQ_RAN"
  ck  "本物の木: sync はどれも 0 を返す" "" "$EQ_L_SYNC"
  ck  "本物の木: 書ける相手で check はどれも 0 を返す" "" "$EQ_L_CHECK"
  ck  "本物の木: 書ける相手で宣言の外のキーが変わらない" "" "$EQ_L_INV"
  ck  "本物の木: 書けない相手は中身を保ち、check が理由つきで 1 を返す" "" "$EQ_L_UNW"
fi

# --- 成立条件の構造の確かめ ---
ncc "構造: check は apply のファイル名を含まない" "$(cat "$CHECK")" "apply-claude-settings"
ncc "構造: apply は check のファイル名を含まない" "$(cat "$APPLY")" "check-claude-settings"
ck  "構造: apply と check に、別のファイルを読み込む行が無い" "0" "$(cat "$APPLY" "$CHECK" | grep -cE "^[[:space:]]*(source|\\.)[[:space:]]+[\"'\$./~]" || true)"

# --- M1: replace が手元の値を残す誤りを、check が見つける（issue の反証1） ---
T1="$_TMP_DIR/tree-m1"; eq_tree_or_fail "$T1"
# shellcheck disable=SC2016  # sed のパターンなのでシェルに展開させない
sed 's|if \$item.op == "replace" then setpath(\$path; \$item.expected)|if $item.op == "replace" then setpath($path; (getpath($path) // $item.expected))|' \
    "$APPLY" > "$T1/scripts/sync/apply-claude-settings.sh"
chmod +x "$T1/scripts/sync/apply-claude-settings.sh"
# shellcheck disable=SC2016  # grep のパターンなのでシェルに展開させない
ck  "M1: 差し替えを挿せた" "1" "$(grep -cF 'setpath($path; (getpath($path) // $item.expected))' "$T1/scripts/sync/apply-claude-settings.sh" | tr -d ' ')"
eq_matrix "$T1" m1
ck  "M1: fixture をすべて走らせた" "${#FIX_NAMES[@]}" "$EQ_RAN"
ck  "M1: check が落とす書ける相手は hooks_only と stale_replace だけ" "hooks_only stale_replace" "$EQ_L_CHECK"
ckc "M1: hooks_only を落とした理由は /hooks の置き換え" "$(cat "$_TMP_DIR/eq/m1/hooks_only/check.out" 2>/dev/null)" "差分 /hooks (replace)"
ck  "M1: 宣言に replace の項目がある" "true" "$([[ -n "$(eq_replace_ptrs "$T1")" ]] && echo true || echo false)"
while IFS= read -r p; do
  ckc "M1: stale_replace を落とした理由に $p がある" "$(cat "$_TMP_DIR/eq/m1/stale_replace/check.out" 2>/dev/null)" "差分 $p (replace)"
done < <(eq_replace_ptrs "$T1")
ck  "M1: 不変の検査は何も拾わない（落としたのは check）" "" "$EQ_L_INV"
ck  "M1: sync は止まらない" "" "$EQ_L_SYNC"
ck  "M1: 書けない相手は期待どおり" "" "$EQ_L_UNW"

# --- M2: check が見ない変更を、不変の検査が見つける（issue の反証2） ---
# 宣言の外のキー（theme）を消す誤りと、独自の statusLine を包むときに手元のキー
# （padding）を落とす誤りを入れる。どちらも check の述語には現れない。
T2="$_TMP_DIR/tree-m2"; eq_tree_or_fail "$T2"
# shellcheck disable=SC2016  # sed のパターンなのでシェルに展開させない
sed -e 's|^reduce \$decl\[0\]\[\] as \$item (.; apply_item(\$item))$|& \| del(.theme)|' \
    -e 's|(\$cur + \$item.expected + {command: (\$wrap_prefix|($item.expected + {command: ($wrap_prefix|' \
    "$APPLY" > "$T2/scripts/sync/apply-claude-settings.sh"
chmod +x "$T2/scripts/sync/apply-claude-settings.sh"
# shellcheck disable=SC2016  # grep のパターンなのでシェルに展開させない
ck  "M2: theme を消す差し替えを挿せた" "1" "$(grep -cF 'apply_item($item)) | del(.theme)' "$T2/scripts/sync/apply-claude-settings.sh" | tr -d ' ')"
# shellcheck disable=SC2016  # grep のパターンなのでシェルに展開させない
ck  "M2: padding を落とす差し替えを挿せた" "1" "$(grep -cF 'setpath($path; ($item.expected + {command: ($wrap_prefix' "$T2/scripts/sync/apply-claude-settings.sh" | tr -d ' ')"
eq_matrix "$T2" m2
ck  "M2: fixture をすべて走らせた" "${#FIX_NAMES[@]}" "$EQ_RAN"
ck  "M2: 書ける相手で check はどれも 0 を返す（check だけでは見えない）" "" "$EQ_L_CHECK"
ck  "M2: 不変の検査が拾うのは own_statusline の padding と personal_keys の theme だけ" \
    "own_statusline:statusLine.padding personal_keys:theme" "$EQ_L_INV"
ck  "M2: sync は止まらない" "" "$EQ_L_SYNC"

# --- M3: 宣言に項目を1つ足しても、この節を書き換えずに緑のまま（issue の反証3） ---
T3="$_TMP_DIR/tree-m3"; eq_tree_or_fail "$T3"
printf '%s' '{"hub401Probe":{"nested":{"k":[1,"two",null,false]}}}' > "$T3/canonical/claude/probe401.values.json"
jq '.items += [{"pointer":"/hub401Probe","op":"replace","scope_behavior":"override",
                "source":{"file":"canonical/claude/probe401.values.json","pointer":"/hub401Probe"}}]' \
   "$DECL" > "$T3/canonical/claude/settings.harness.json"
ck  "M3: 宣言が1項目増えた" "$(( $(jq '.items | length' "$DECL") + 1 ))" "$(jq '.items | length' "$T3/canonical/claude/settings.harness.json")"
eq_matrix "$T3" m3
ck  "M3: fixture をすべて走らせた" "${#FIX_NAMES[@]}" "$EQ_RAN"
ck  "M3: sync はどれも 0 を返す" "" "$EQ_L_SYNC"
ck  "M3: 書ける相手で check はどれも 0 を返す" "" "$EQ_L_CHECK"
ck  "M3: 書ける相手で宣言の外のキーが変わらない" "" "$EQ_L_INV"
ck  "M3: 書けない相手は期待どおり" "" "$EQ_L_UNW"
# 足した項目が実際に当たっていることを見る（緑が空回りでないこと）。
eq_probe_miss=""; eq_probe_unseen=""
for n in "${FIX_NAMES[@]}"; do
  eq_unwritable_reason "$n" >/dev/null && continue
  [[ "$(jq -c '.hub401Probe' "$_TMP_DIR/eq/m3/$n/home/.claude/settings.json" 2>/dev/null)" == '{"nested":{"k":[1,"two",null,false]}}' ]] \
    || eq_probe_miss="${eq_probe_miss:+$eq_probe_miss }$n"
  grep -qF '一致 /hub401Probe' "$_TMP_DIR/eq/m3/$n/check.out" 2>/dev/null || eq_probe_unseen="${eq_probe_unseen:+$eq_probe_unseen }$n"
done
ck  "M3: 書ける相手の結果すべてに、足した項目が正本の値で入る" "" "$eq_probe_miss"
ck  "M3: 書ける相手の check すべてが、足した項目を一致と判定する" "" "$eq_probe_unseen"
ck  "M3: stale_replace の初期値にも足した項目が入る" "true" "$(jq -r 'has("hub401Probe")' "$_TMP_DIR/eq/m3/stale_replace/before.json" 2>/dev/null)"

# --- M4: apply が失敗したら、sync も 0 でない値で終わる（終了コードの 0 でない組） ---
T4="$_TMP_DIR/tree-m4"; eq_tree_or_fail "$T4"
eq_first_src="$(jq -r '.items[0].source.file // empty' "$DECL")"
if [[ -n "$eq_first_src" && "$eq_first_src" != /* ]]; then rm -f "$T4/$eq_first_src"; fi
ck  "M4: 写しの木から最初の項目の正本を消した" "true" "$([[ -n "$eq_first_src" && ! -e "$T4/$eq_first_src" ]] && echo true || echo false)"
eq_run "$T4" m4 personal_keys "$(eq_init_of personal_keys)"
ck  "M4: sync が 0 でない値を返す" "nonzero" "$([[ "$EQ_SYNC_RC" != skip && "$EQ_SYNC_RC" -ne 0 ]] && echo nonzero || echo "rc=$EQ_SYNC_RC")"
ckc "M4: 失敗の理由が apply から届く" "$(cat "$EQ_DIR/sync.out" 2>/dev/null)" "設定の適用に失敗しました（rc=2）"
ck  "M4: settings.json はバイト単位で前のまま" "yes" "$EQ_KEPT"

# --- M5: sync と apply が、それぞれ自分の shebang の interpreter で動く ---
T5="$_TMP_DIR/tree-m5"; eq_tree_or_fail "$T5"
# shellcheck disable=SC2016  # sed の置き換えなのでシェルに展開させない
sed 's|^set -euo pipefail$|&\nprintf "%s" "${BASH_VERSINFO[0]}" > "${HOME}/.sync-bash-major"|' \
    "$REPO_ROOT/scripts/sync/sync-claude.sh" > "$T5/scripts/sync/sync-claude.sh"
# shellcheck disable=SC2016  # sed の置き換えなのでシェルに展開させない
sed 's|^set -uo pipefail$|&\nprintf "%s" "${BASH_VERSINFO[0]}" > "${HOME}/.apply-bash-major"|' \
    "$APPLY" > "$T5/scripts/sync/apply-claude-settings.sh"
chmod +x "$T5/scripts/sync/sync-claude.sh" "$T5/scripts/sync/apply-claude-settings.sh"
ck  "M5: sync に記録の行を挿せた" "1" "$(grep -cF '.sync-bash-major' "$T5/scripts/sync/sync-claude.sh" | tr -d ' ')"
ck  "M5: apply に記録の行を挿せた" "1" "$(grep -cF '.apply-bash-major' "$T5/scripts/sync/apply-claude-settings.sh" | tr -d ' ')"
eq_run "$T5" m5 missing NONE
# shebang の interpreter が名乗る主版番号。"/usr/bin/env bash" は語に分けて起動する。
eq_major_of() {
  local interp
  interp="$(head -1 "$1" | sed 's|^#![[:space:]]*||')"
  # shellcheck disable=SC2086,SC2016  # interp は語に分ける。-c の中身はシェルに展開させない
  env -u BASH_ENV -u ENV $interp -c 'printf "%s" "${BASH_VERSINFO[0]}"'
}
eq_sync_want="$(eq_major_of "$REPO_ROOT/scripts/sync/sync-claude.sh")"
eq_apply_want="$(eq_major_of "$APPLY")"
ck  "M5: sync は shebang の interpreter（主版 ${eq_sync_want}）で動く" "$eq_sync_want" "$(cat "$EQ_DIR/home/.sync-bash-major" 2>/dev/null)"
ck  "M5: apply は shebang の interpreter（主版 ${eq_apply_want}）で動く" "$eq_apply_want" "$(cat "$EQ_DIR/home/.apply-bash-major" 2>/dev/null)"
if [[ "$eq_sync_want" == "$eq_apply_want" ]]; then
  echo "  NOTE: sync と apply の interpreter の主版番号が同じ（${eq_sync_want}）なので、この環境では組み合わせの違いを区別できない"
fi
if [[ "$eq_sync_want" == "${BASH_VERSINFO[0]}" ]]; then
  echo "  NOTE: テストを走らせた bash と sync の interpreter の主版番号が同じ（${eq_sync_want}）なので、この実行では \"\$BASH\" での起動と区別できない"
fi

# --- M6: check は期待値を apply から作っていない（成立条件の守り） ---
# どんな入力にも誤った値を書く apply にする。check が「空の settings に apply を当てて
# 期待値を作る」形に変わると、誤った値が期待値にも入って緑になり、ここが落ちる。
T6="$_TMP_DIR/tree-m6"; eq_tree_or_fail "$T6"
# shellcheck disable=SC2016  # sed のパターンなのでシェルに展開させない
sed 's|if \$item.op == "replace" then setpath(\$path; \$item.expected)|if $item.op == "replace" then setpath($path; {"__wrong401__": true})|' \
    "$APPLY" > "$T6/scripts/sync/apply-claude-settings.sh"
chmod +x "$T6/scripts/sync/apply-claude-settings.sh"
ck  "M6: 差し替えを挿せた" "1" "$(grep -cF '__wrong401__' "$T6/scripts/sync/apply-claude-settings.sh" | tr -d ' ')"
eq_run "$T6" m6 missing NONE
ck  "M6: check が 1 を返す" "1" "$EQ_CHECK_RC"
while IFS= read -r p; do
  ckc "M6: $p の誤りを見つける" "$(cat "$EQ_DIR/check.out" 2>/dev/null)" "差分 $p (replace)"
done < <(eq_replace_ptrs "$T6")

echo "[23] 中身が同じ symlink へ直前に差し替えられても置き換えない（実装SO 指摘の回帰）"
fresh c23
printf '%s' '{"theme":"dark"}' > "$ST"
# リンク先は「その時点の settings と同じ内容」にする。内容比較では見抜けない。
# 差し替えは「直前の再確認」より前に起こす。再確認と置き換えの間に起きる
# 差し替えは rename の原子性の外なので、どう並べても捕まえられない。ここで
# 確かめるのは、再確認が同内容の symlink を見抜けるかどうかである。
sed "s|^    # (d) 置き換える直前にもう一度だけ種別を見る。|    if [[ ! -L '$ST' ]]; then cp '$ST' '$CASE/twin.json'; rm -f '$ST'; ln -s '$CASE/twin.json' '$ST'; fi\n    # (d) 置き換える直前にもう一度だけ種別を見る。|" \
    "$APPLY" > "$CASE/apply_twin.sh"
chmod +x "$CASE/apply_twin.sh"
ck  "割り込みを挿せた" "1" "$(grep -c 'twin.json' "$CASE/apply_twin.sh" | tr -d ' ')"
OUT="$("$BASH" "$CASE/apply_twin.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ck  "symlink のまま残る" "true" "$([[ -L "$ST" ]] && echo true || echo false)"
ck  "リンク先に宣言を書いていない" "false" "$(jq -r '(.hooks != null)' "$CASE/twin.json")"
ckc "差し替わったと言う" "$OUT" "直前に symlink かディレクトリへ差し替わった"
ck  "exit 0（止めない）" "0" "$RC"

echo "[24] union-array は正本側の重複も取り除く（実装SO 指摘の回帰）"
fresh c24
printf '%s' '{"listy":["a"]}' > "$ST"
printf '%s' '{"listy":["x","x","a","y"]}' > "$CASE/src.json"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/listy","op":"union-array","scope_behavior":"merge",
           "source":{"file":"$CASE/src.json","pointer":"/listy"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 0" "0" "$RC"
ck  "重複が畳まれて3件" "3" "$(jq -r '.listy | length' "$ST")"
ck  "x は1つだけ" "1" "$(jq -r '[.listy[] | select(. == "x")] | length' "$ST")"
ck  "手元の a は先頭のまま" "a" "$(jq -r '.listy[0]' "$ST")"

echo "[25] 変更の有無を比べられないときは成功を名乗らない（実装SO 指摘の回帰）"
fresh c25
printf '%s' '{"theme":"dark"}' > "$ST"
# 比較用の正規化を必ず失敗させる複製を作る。
# shellcheck disable=SC2016  # sed のパターンなのでシェルに展開させない
sed 's|^        jq -S . "${out}" > "${out}.cmp2" 2>/dev/null .. cmp_ok=0$|        cmp_ok=0|' \
    "$APPLY" > "$CASE/apply_cmpfail.sh"
chmod +x "$CASE/apply_cmpfail.sh"
ck  "割り込みを挿せた" "1" "$(grep -cE '^        cmp_ok=0$' "$CASE/apply_cmpfail.sh" | tr -d ' ')"
OUT="$("$BASH" "$CASE/apply_cmpfail.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ck  "exit 1" "1" "$RC"
ckc "比べられないと言う" "$OUT" "比べられませんでした"
ck  "個人層は無傷" "dark" "$(jq -r '.theme' "$ST")"
ck  "宣言は書かれていない" "false" "$(jq -r '(.hooks != null)' "$ST")"

echo "[26] 直前にディレクトリへ差し替えられても置き換えない（実装SO 指摘の回帰）"
fresh c26
printf '%s' '{"theme":"dark"}' > "$ST"
sed "s|^    # (b) 置き換えに関わる相手の種別をもう一度見る。|    if [[ ! -d '$ST' ]]; then rm -f '$ST'; mkdir -p '$ST'; fi\n    # (b) 置き換えに関わる相手の種別をもう一度見る。|" \
    "$APPLY" > "$CASE/apply_dir.sh"
chmod +x "$CASE/apply_dir.sh"
ck  "割り込みを挿せた" "1" "$(grep -c "mkdir -p '$ST'" "$CASE/apply_dir.sh" | tr -d ' ')"
OUT="$("$BASH" "$CASE/apply_dir.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ck  "ディレクトリのまま" "true" "$([[ -d "$ST" ]] && echo true || echo false)"
ck  "中に一時ファイルを残していない" "0" "$(find "$ST" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
ck  "exit 0（止めない）" "0" "$RC"

echo "[27] union-array は手元の配列の重複も畳む（実装SO 指摘の回帰）"
fresh c27
printf '%s' '{"listy":["mine","mine"]}' > "$ST"
printf '%s' '{"listy":["canon"]}' > "$CASE/src.json"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/listy","op":"union-array","scope_behavior":"merge",
           "source":{"file":"$CASE/src.json","pointer":"/listy"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 0" "0" "$RC"
ck  "2件に畳まれる" "2" "$(jq -r '.listy | length' "$ST")"
ck  "mine は1つ" "1" "$(jq -r '[.listy[] | select(. == "mine")] | length' "$ST")"

echo "[28] statusLine がオブジェクトでなければ触らない（実装SO 指摘の回帰）"
fresh c28
printf '%s' '{"statusLine":"nonsense","theme":"dark"}' > "$ST"
run
ck  "exit 0" "0" "$RC"
ck  "statusLine はそのまま" "nonsense" "$(jq -r '.statusLine' "$ST")"
ck  "hooks は入る" "true" "$(jq -r '(.hooks != null)' "$ST")"
ck  "個人層も残る" "dark" "$(jq -r '.theme' "$ST")"

echo "[29] source.pointer の配列添字も拒む（実装SO 指摘の回帰）"
fresh c29
printf '%s' '{"theme":"dark"}' > "$ST"
printf '%s' '{"arr":[{"k":1}]}' > "$CASE/src.json"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/target","op":"replace","scope_behavior":"override",
           "source":{"file":"$CASE/src.json","pointer":"/arr/0"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 2" "2" "$RC"
ckc "添字は扱えないと言う" "$OUT" "配列の添字は宣言で扱えません"
ck  "何も書かない" "false" "$(jq -r '(.target != null)' "$ST")"

echo "[30] 参照するスクリプトを配ってから設定を書く（順序の回帰）"
# shellcheck disable=SC2016  # grep のパターンなのでシェルに展開させない
apply_line="$(grep -n 'apply_declared_settings "\${TARGET_BASE}/settings.json"' "$REPO_ROOT/scripts/sync/sync-claude.sh" | head -1 | cut -d: -f1)"
# shellcheck disable=SC2016  # grep のパターンなのでシェルに展開させない
sl_line="$(grep -n 'sync_hook_scripts "\${CANONICAL_DIR}/claude/statusline"' "$REPO_ROOT/scripts/sync/sync-claude.sh" | head -1 | cut -d: -f1)"
# shellcheck disable=SC2016  # grep のパターンなのでシェルに展開させない
hook_line="$(grep -n 'sync_hook_scripts "\${CANONICAL_DIR}/hooks/scripts"' "$REPO_ROOT/scripts/sync/sync-claude.sh" | head -1 | cut -d: -f1)"
ck  "statusLine の producer 配備より後に設定を書く" "true" "$([[ -n "$apply_line" && -n "$sl_line" && "$apply_line" -gt "$sl_line" ]] && echo true || echo false)"
ck  "hook スクリプト配備より後に設定を書く" "true" "$([[ -n "$apply_line" && -n "$hook_line" && "$apply_line" -gt "$hook_line" ]] && echo true || echo false)"

echo "[31] 破壊的な横取り: 確認の直前にファイルを消される（実装SO 指摘の回帰）"
fresh c31
printf '%s' '{"theme":"dark","model":"opus"}' > "$ST"
sed "s|^    # (c) 最後の確認。|    rm -f '$ST'\n    # (c) 最後の確認。|" "$APPLY" > "$CASE/a.sh"
chmod +x "$CASE/a.sh"
OUT="$("$BASH" "$CASE/a.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ck  "宣言だけのファイルを作らない" "1" "$RC"
ckc "消えたと言う" "$OUT" "settings.json が消えました"
bk="$(find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | sort | head -1)"
ck  "写しが残っている" "true" "$([[ -n "$bk" ]] && echo true || echo false)"
ck  "写しに個人層がある" "dark" "$(jq -r '.theme' "$bk" 2>/dev/null)"
ck  "写しに model もある" "opus" "$(jq -r '.model' "$bk" 2>/dev/null)"

echo "[32] 破壊的な横取り: 確認の直前に空にされる（実装SO 指摘の回帰）"
fresh c32
printf '%s' '{"theme":"dark","model":"opus"}' > "$ST"
sed "s|^    # (c) 最後の確認。|    : > '$ST'\n    # (c) 最後の確認。|" "$APPLY" > "$CASE/a.sh"
chmod +x "$CASE/a.sh"
OUT="$("$BASH" "$CASE/a.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ck  "空のまま何も書かない" "0" "$RC"
ckc "読めないと言う" "$OUT" "JSON として読めないので触りません"
ckc "写しの在処を伝える" "$OUT" "読んだ時点の内容"
bk="$(find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | sort | head -1)"
ck  "写しから個人層を戻せる" "dark" "$(jq -r '.theme' "$bk" 2>/dev/null)"

echo "[33] 破壊的な横取り: 確認の直前に空オブジェクトへ置換される（実装SO 指摘の回帰）"
fresh c33
printf '%s' '{"theme":"dark","model":"opus"}' > "$ST"
sed "s|^    # (c) 最後の確認。|    printf '%s' '{}' > '$ST'\n    # (c) 最後の確認。|" "$APPLY" > "$CASE/a.sh"
chmod +x "$CASE/a.sh"
OUT="$("$BASH" "$CASE/a.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
# 横取り側が個人層を消したので、手元の結果に個人層は戻らない。写しから戻せることを見る。
bk="$(find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | sort | head -1)"
ck  "写しが残っている" "true" "$([[ -n "$bk" ]] && echo true || echo false)"
ck  "写しに個人層がある" "dark" "$(jq -r '.theme' "$bk" 2>/dev/null)"
ck  "終了コードは 0 か 1" "true" "$([[ "$RC" -eq 0 || "$RC" -eq 1 ]] && echo true || echo false)"

echo "[34] 最初から無いファイルを別プロセスが空で作っても上書きしない（実装SO 指摘の回帰）"
fresh c34
sed "s|^    # (c) 最後の確認。|    : > '$ST'\n    # (c) 最後の確認。|" "$APPLY" > "$CASE/a.sh"
chmod +x "$CASE/a.sh"
OUT="$("$BASH" "$CASE/a.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ckc "変化を見つけて読み直す" "$OUT" "読み直します"
ck  "空のまま残る（宣言で上書きしない）" "0" "$(wc -c < "$ST" | tr -d ' ')"

echo "[35] 計算の途中で実体が空にされても、写しは読んだ時点のまま（実装SO 指摘の回帰）"
fresh c35
printf '%s' '{"theme":"dark","model":"opus"}' > "$ST"
# 読み取りの直後・写しを取る前に実体を空にする。
sed "s|^    # statusline-wrap が退避に使う元コマンドを、いまの内容から取り出す。|    : > '$ST'\n    # statusline-wrap が退避に使う元コマンドを、いまの内容から取り出す。|" \
    "$APPLY" > "$CASE/a.sh"
chmod +x "$CASE/a.sh"
ck  "割り込みを挿せた" "1" "$(grep -c ": > '$ST'" "$CASE/a.sh" | tr -d ' ')"
OUT="$("$BASH" "$CASE/a.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
bk="$(find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | sort | head -1)"
ck  "写しが残っている" "true" "$([[ -n "$bk" ]] && echo true || echo false)"
ck  "写しは空になっていない" "dark" "$(jq -r '.theme' "$bk" 2>/dev/null)"
ck  "写しに model もある" "opus" "$(jq -r '.model' "$bk" 2>/dev/null)"

echo "[36] 末尾の改行だけの違いも横取りとして拾う（バイト比較の回帰）"
fresh c36
printf '%s' '{"theme":"dark"}' > "$ST"
sed "s|^    # (c) 最後の確認。|    printf '%s\\\\n' '{\"theme\":\"dark\"}' > '$ST'\n    # (c) 最後の確認。|" \
    "$APPLY" > "$CASE/a.sh"
chmod +x "$CASE/a.sh"
OUT="$("$BASH" "$CASE/a.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ckc "変化として読み直す" "$OUT" "読み直します"

echo "[37] 読み取り用の一時ファイルを残さない"
fresh c37
printf '%s' '{"theme":"dark"}' > "$ST"
run
ck  "exit 0" "0" "$RC"
ck  "read の一時ファイルが残っていない" "0" "$(find "$CASE" -maxdepth 1 -name 'settings.json.read.*' | wc -l | tr -d ' ')"
run
ck  "変更なしの経路でも残さない" "0" "$(find "$CASE" -maxdepth 1 -name 'settings.json.read.*' | wc -l | tr -d ' ')"

echo "[38] 作業ファイルを残さない（trap の上書きの回帰）"
fresh c38
printf '%s' '{"theme":"dark"}' > "$ST"
before_tmp="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l | tr -d ' ')"
run
ck  "exit 0" "0" "$RC"
after_tmp="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l | tr -d ' ')"
ck  "一時ファイルが増えていない" "$before_tmp" "$after_tmp"
ck  "settings の隣にも残骸なし" "0" "$(find "$CASE" -maxdepth 1 \( -name 'settings.json.read.*' -o -name 'settings.json.tmp.*' \) | wc -l | tr -d ' ')"

echo "[39] やり直して成功したとき、最後の写しが置き換え直前の版になる（実装SO 指摘の回帰）"
fresh c39
printf '%s' '{"theme":"dark"}' > "$ST"
marker2="$CASE/raced2"
sed "s|^    # (c) 最後の確認。|    if [[ ! -e '$marker2' ]]; then touch '$marker2'; jq -c '. + {mid: 1}' '$ST' > '$ST.r' \&\& mv '$ST.r' '$ST'; fi\n    # (c) 最後の確認。|" \
    "$APPLY" > "$CASE/a.sh"
chmod +x "$CASE/a.sh"
OUT="$("$BASH" "$CASE/a.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ck  "成功する" "0" "$RC"
oldest="$(find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | sort | head -1)"
newest="$(find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | sort | tail -1)"
ck  "最古の写しは元の内容（割り込み前）" "null" "$(jq -r '.mid' "$oldest" 2>/dev/null)"
ck  "最後の写しは置き換え直前の版（割り込み後）" "1" "$(jq -r '.mid' "$newest" 2>/dev/null)"
ck  "結果にも割り込みの追記が残る" "1" "$(jq -r '.mid' "$ST")"

echo "[40] 値の出どころが無い操作を拒む（実装SO 指摘の回帰）"
fresh c40
printf '%s' '{"theme":"dark"}' > "$ST"
cat > "$CASE/decl.json" <<'DECLEOF'
{"version":1,
 "items":[{"pointer":"/target","op":"replace","scope_behavior":"override"}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 2" "2" "$RC"
ckc "出どころが要ると言う" "$OUT" "値の出どころが要ります"
ck  "null を書いていない" "false" "$(jq -r 'has("target")' "$ST")"
ck  "個人層は無傷" "dark" "$(jq -r '.theme' "$ST")"

echo "[41] スラッシュ1文字のポインタを拒む（実装SO 指摘の回帰・個人層の全消し）"
fresh c41
printf '%s' '{"theme":"dark","model":"opus","tui":"fullscreen"}' > "$ST"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/","op":"replace","scope_behavior":"override",
           "source":{"file":"$REPO_ROOT/canonical/hooks/claude.hooks.json","pointer":"/hooks"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 2" "2" "$RC"
ckc "文書全体は使えないと言う" "$OUT" "文書全体を指すポインタは使えません"
ck  "theme が残る" "dark" "$(jq -r '.theme' "$ST")"
ck  "model が残る" "opus" "$(jq -r '.model' "$ST")"
ck  "tui が残る" "fullscreen" "$(jq -r '.tui' "$ST")"
ck  "キーの数が変わらない" "3" "$(jq -r 'keys | length' "$ST")"

echo "[42] union-array は手元の値が配列でなければ触らない（実装SO 指摘の回帰）"
fresh c42
printf '%s' '{"listy":"not-an-array","theme":"dark"}' > "$ST"
printf '%s' '{"listy":["canon"]}' > "$CASE/src.json"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/listy","op":"union-array","scope_behavior":"merge",
           "source":{"file":"$CASE/src.json","pointer":"/listy"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "落ちない" "0" "$RC"
ck  "手元の値をそのまま残す" "not-an-array" "$(jq -r '.listy' "$ST")"
ck  "個人層も無傷" "dark" "$(jq -r '.theme' "$ST")"

echo "[43] 一時ファイルとバックアップの名前が予測できない（実装SO 指摘の回帰）"
fresh c43
printf '%s' '{"theme":"dark"}' > "$ST"
run
bk="$(find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | head -1)"
ck  "写しができている" "true" "$([[ -n "$bk" ]] && echo true || echo false)"
# 名前がプロセス番号だけで決まるなら、この形に一致するはず。ランダム部分があれば一致しない。
ck  "プロセス番号だけの名前ではない" "false" "$([[ "$bk" == *".bak."*".$$" ]] && echo true || echo false)"
ck  "read の一時ファイルが残っていない" "0" "$(find "$CASE" -maxdepth 1 -name 'settings.json.read.*' | wc -l | tr -d ' ')"

echo "[44] merge-object は手元がオブジェクトでなければ触らない（実装SO 指摘の回帰）"
fresh c44
printf '%s' '{"autoMode":"not-an-object","theme":"dark"}' > "$ST"
printf '%s' '{"autoMode":{"a":1}}' > "$CASE/src.json"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[
   {"pointer":"/autoMode","op":"merge-object","scope_behavior":"override",
    "source":{"file":"$CASE/src.json","pointer":"/autoMode"}},
   {"pointer":"/hooks","op":"replace","scope_behavior":"merge",
    "source":{"file":"$REPO_ROOT/canonical/hooks/claude.hooks.json","pointer":"/hooks"}}
 ],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "落ちない" "0" "$RC"
ck  "手元の値をそのまま残す" "not-an-object" "$(jq -r '.autoMode' "$ST")"
ck  "他の項目は適用される" "true" "$(jq -r '(.hooks != null)' "$ST")"
ck  "個人層も無傷" "dark" "$(jq -r '.theme' "$ST")"

echo "[45] 値が null や false だけの settings を壊れていると誤判定しない（実装SO 指摘の回帰）"
for v in 'null' 'false' '0' '"str"' '[]'; do
  fresh "c45$(printf '%s' "$v" | tr -cd 'a-z0-9')"
  printf '%s' "$v" > "$ST"
  run
  # トップが object でない settings には触らないのが正しい（宣言はキーを指すため）。
  ncc "[$v] 壊れているとは言わない" "$OUT" "JSON として読めないので触りません"
  ckc "[$v] オブジェクトでないので触らないと言う" "$OUT" "いちばん外側がオブジェクトではないので触りません"
  ck  "[$v] 中身は変わらない" "$v" "$(cat "$ST")"
  ck  "[$v] 止めない" "0" "$RC"
done

echo "[46] 空ファイルは読めないものとして扱う"
fresh c46
: > "$ST"
run
ck  "exit 0（止めない）" "0" "$RC"
ckc "読めないと言う" "$OUT" "JSON として読めないので触りません"
ck  "空のまま" "0" "$(wc -c < "$ST" | tr -d ' ')"

echo "[47] statusline-wrap は /statusLine 以外に宣言できない（実装SO 指摘の回帰）"
fresh c47
printf '%s' '{"theme":"dark"}' > "$ST"
cat > "$CASE/decl.json" <<DECLEOF
{"version":1,
 "items":[{"pointer":"/somewhereElse","op":"handler","handler":"statusline-wrap","scope_behavior":"override",
           "source":{"file":"$REPO_ROOT/canonical/claude/statusline/claude.statusline.json","pointer":"/statusLine"}}],
 "unchecked_scopes":["x"]}
DECLEOF
run_d "$CASE/decl.json"
ck  "exit 2" "2" "$RC"
ckc "置き場が違うと言う" "$OUT" "statusline-wrap は /statusLine にしか宣言できません"
ck  "何も書かない" "false" "$(jq -r 'has("somewhereElse")' "$ST")"
ck  "個人層は無傷" "dark" "$(jq -r '.theme' "$ST")"

echo "[48] 包んだ元コマンドのチルダ展開が壊れない（実装SO 指摘の回帰・bash 版差）"
fresh c48
printf '%s' '{"statusLine":{"type":"command","command":"~/mybar.sh --fancy","padding":2}}' > "$ST"
run
wrapped="$(jq -r '.statusLine.command' "$ST")"
ck  "1回だけ包む" "1" "$(printf '%s' "$wrapped" | grep -c 'OE_HEARTBEAT_WRAP_CMD' | tr -d ' ')"
ncc "先頭のチルダを escape しない" "$wrapped" '\~'
ckc "元コマンドが残っている" "$wrapped" 'mybar.sh'
# 退避した値を取り出して評価し、チルダが展開されることを見る。
saved="$(printf '%s' "$wrapped" | sed -n 's|^OE_HEARTBEAT_WRAP_CMD=\(.*\) /.*|\1|p')"
[[ -z "$saved" ]] && saved="$(printf '%s' "$wrapped" | sed -n 's|^OE_HEARTBEAT_WRAP_CMD=\(.*\) ".*|\1|p')"
expanded="$("$BASH" -c "eval printf '%s' $saved" 2>/dev/null)"
# shellcheck disable=SC2088  # 展開されないことを確かめる側なので literal でよい
ncc "評価してもチルダのままにならない" "$expanded" '~/'
ckc "ホームに展開される" "$expanded" "$HOME"

echo "[49] items が配列でない宣言を拒む（Copilot 指摘の回帰）"
fresh c49
printf '%s' '{"theme":"dark"}' > "$ST"
for bad in '"abc"' '5' '{"a":1}'; do
  printf '%s' "{\"version\":1,\"items\":$bad,\"unchecked_scopes\":[\"x\"]}" > "$CASE/decl.json"
  run_d "$CASE/decl.json"
  ck  "items=$bad を拒む" "2" "$RC"
  ckc "配列でないと言う" "$OUT" "items が配列ではありません"
done
ck  "個人層は無傷" "dark" "$(jq -r '.theme' "$ST")"

echo "[50] agent view を切る値そのものを固定する（#338・owner 裁定）"
# 値の一致だけでなく true であることを見る。build_green と同じく正本から読む形だと、
# 正本を false に書き換えても緑のままになる（実測）。ここで true を止めておくと、
# 方針を変えるときにテストも一緒に直す必要が出る。それが狙いである。
ck  "正本の値は true" "true" "$(jq -r '.disableAgentView' "$REPO_ROOT/canonical/claude/settings.values.json")"
fresh c50
printf '%s' '{"disableAgentView":false,"theme":"dark"}' > "$ST"
run
ck  "exit 0" "0" "$RC"
ck  "適用後は true に直る" "true" "$(jq -r '.disableAgentView' "$ST")"
ck  "個人層は無傷" "dark" "$(jq -r '.theme' "$ST")"

echo "[51] アイドル時の圧縮を止める値そのものを固定する（#415・owner 裁定）"
# [50] と同じ理由で、正本から読まず false を直に見る。値が false なので、
# キーが無い（null）こととも区別する。
ck  "正本の値は false" "false" "$(jq -r '.idleCompaction' "$REPO_ROOT/canonical/claude/settings.values.json")"
fresh c51a
printf '%s' '{"idleCompaction":true,"theme":"dark"}' > "$ST"
run
ck  "exit 0" "0" "$RC"
ck  "適用後は false に直る" "false" "$(jq -r '.idleCompaction' "$ST")"
ck  "個人層は無傷" "dark" "$(jq -r '.theme' "$ST")"
fresh c51b
printf '%s' '{"theme":"dark"}' > "$ST"
run
ck  "キーが無ければ作る" "true" "$(jq -r 'has("idleCompaction")' "$ST")"
ck  "作った値は false（null ではない）" "false" "$(jq -r '.idleCompaction' "$ST")"

echo ""
echo "=== PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
