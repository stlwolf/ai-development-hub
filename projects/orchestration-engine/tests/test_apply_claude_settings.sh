#!/usr/bin/env bash
set -uo pipefail

# test_apply_claude_settings.sh — 宣言駆動の適用を検証（#359 PR-3）。
#
# 一時ディレクトリの settings.json だけを触る（実 ~/.claude は読まない・書かない）。
# 検証する軸:
#   - 宣言に無い項目（個人層）を一切変えない
#   - 書き込みは1回。バックアップも1回
#   - 変更が無いときは書かない（バックアップも作らない）
#   - 書けない相手（symlink / 通常ファイル以外 / 壊れた JSON）には触らず、止めない
#   - 読んでから書くまでに他が書き換えたら読み直す
#   - 1項目でも正本が解けなければ何も書かない（部分適用を作らない）
#   - replace / merge-object / union-array / absent / statusline-wrap の各動作

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
APPLY="$REPO_ROOT/scripts/sync/apply-claude-settings.sh"
DECL="$REPO_ROOT/canonical/claude/settings.harness.json"
HOOKS_SRC="$REPO_ROOT/canonical/hooks/claude.hooks.json"

[[ -x "$APPLY" ]] || { echo "FAIL: apply script not found: $APPLY"; exit 1; }
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
ck  "宣言の2項目だけ" "hooks statusLine" "$(jq -r 'keys | join(" ")' "$ST")"

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
ck  "捨てたバックアップが残っていない" "1" "$(find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | wc -l | tr -d ' ')"

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
ck  "使わなかったバックアップを残さない" "0" "$(find "$CASE" -maxdepth 1 -name 'settings.json.bak.*' | wc -l | tr -d ' ')"

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
ck  "宣言の2項目が入る" "hooks statusLine" "$(jq -r 'keys | join(" ")' "$ST")"

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

echo "[22] 現行実装との等価性（fixture 比較・終了コードも含める）"
# 枝の名前に頼らない。履歴を遡って、旧実装をまだ含んでいる最後の版を探す。
old_sync="$_TMP_DIR/old-sync-claude.sh"
old_rev=""
while IFS= read -r c; do
  if git -C "$REPO_ROOT" show "$c:scripts/sync/sync-claude.sh" 2>/dev/null | grep -q 'sync_claude_hooks'; then
    old_rev="$c"; break
  fi
done < <(git -C "$REPO_ROOT" rev-list HEAD -- scripts/sync/sync-claude.sh 2>/dev/null)
if [[ -z "$old_rev" ]]; then
  # 見つからないときは緑にしない。等価性は受け入れ条件そのものなので、
  # 確かめられなかったことを失敗として出す。
  echo "  FAIL: 旧実装を含む版を履歴から見つけられない（等価性を確認できない）"
  FAIL=$((FAIL+1))
else
  git -C "$REPO_ROOT" show "$old_rev:scripts/sync/sync-claude.sh" > "$old_sync"
  old_in_repo="$REPO_ROOT/scripts/sync/.old-sync-claude-for-test.sh"
  cp "$old_sync" "$old_in_repo"; chmod +x "$old_in_repo"
  run_fixture() {  # run_fixture <script> <name> <init> <outdir>
    local script="$1" name="$2" init="$3" outdir="$4"
    local home="$outdir/$name/home"; mkdir -p "$home/.claude"
    local st="$home/.claude/settings.json"
    case "$init" in
      NONE) ;;
      SYMLINK) printf '%s' '{"hooks":{}}' > "$home/.claude/real.json"; ln -s "$home/.claude/real.json" "$st" ;;
      DIR) mkdir -p "$st" ;;
      *) printf '%s' "$init" > "$st" ;;
    esac
    env HOME="$home" bash "$script" >/dev/null 2>&1
    local rc=$?
    # 終了コードも比べる。片方が適用前に落ちて入力が残っただけでも
    # 内容だけ見ると一致に見えるため（実装SO 指摘）。
    printf 'rc_class=%s\n' "$( [[ "$rc" -eq 0 ]] && echo ok || echo nonzero )"
    if [[ -f "$st" && ! -L "$st" ]]; then jq -S . "$st" 2>/dev/null || cat "$st"
    elif [[ -L "$st" ]]; then echo "SYMLINK"
    elif [[ -d "$st" ]]; then echo "DIR"
    else echo "MISSING"; fi
  }
  declare -a FIX_NAMES=(missing hooks_only own_statusline wrapped broken_json symlink personal_keys dir)
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
  )
  echo "  （比較元: $(git -C "$REPO_ROOT" rev-parse --short "$old_rev")）"
  for i in "${!FIX_NAMES[@]}"; do
    n="${FIX_NAMES[$i]}"; init="${FIX_INITS[$i]}"
    o="$(run_fixture "$old_in_repo" "$n" "$init" "$_TMP_DIR/eq_old")"
    w="$(run_fixture "$REPO_ROOT/scripts/sync/sync-claude.sh" "$n" "$init" "$_TMP_DIR/eq_new")"
    # 壊れた JSON のときだけ終了コードが変わるのは意図した変更なので、内容だけ比べる。
    if [[ "$n" == "broken_json" ]]; then
      o="$(printf '%s' "$o" | grep -v '^rc_class=')"
      w="$(printf '%s' "$w" | grep -v '^rc_class=')"
    fi
    ck "fixture $n の結果が一致" "$o" "$w"
  done
  rm -f "$old_in_repo"
fi

echo "[23] 中身が同じ symlink へ直前に差し替えられても置き換えない（実装SO 指摘の回帰）"
fresh c23
printf '%s' '{"theme":"dark"}' > "$ST"
# リンク先は「その時点の settings と同じ内容」にする。内容比較では見抜けない。
# 差し替えは「直前の再確認」より前に起こす。再確認と置き換えの間に起きる
# 差し替えは rename の原子性の外なので、どう並べても捕まえられない。ここで
# 確かめるのは、再確認が同内容の symlink を見抜けるかどうかである。
sed "s|^    # 置き換える直前にもう一度 symlink を見る。|    if [[ ! -L '$ST' ]]; then cp '$ST' '$CASE/twin.json'; rm -f '$ST'; ln -s '$CASE/twin.json' '$ST'; fi\n    # 置き換える直前にもう一度 symlink を見る。|" \
    "$APPLY" > "$CASE/apply_twin.sh"
chmod +x "$CASE/apply_twin.sh"
ck  "割り込みを挿せた" "1" "$(grep -c 'twin.json' "$CASE/apply_twin.sh" | tr -d ' ')"
OUT="$("$BASH" "$CASE/apply_twin.sh" --settings "$ST" --declaration "$DECL" --repo-root "$REPO_ROOT" 2>&1)"; RC=$?
ck  "symlink のまま残る" "true" "$([[ -L "$ST" ]] && echo true || echo false)"
ck  "リンク先に宣言を書いていない" "false" "$(jq -r '(.hooks != null)' "$CASE/twin.json")"
ckc "差し替わったと言う" "$OUT" "直前に symlink へ差し替わった"
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

echo ""
echo "=== PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
