#!/usr/bin/env bash
# test_oe_threads.sh — oe-threads（#327・生存ペインごとのモデル名とコンテキスト%）の検証
#
# 隔離は4点セット（どれかを落とすとホスト依存になる）:
#   - OE_HEARTBEAT_DIR   sidecar の置き場（実ホームの 200 件超を読ませない）
#   - OE_PANE_ISSUE_DIR  ラベル解決の置き場
#   - PATH 先頭の tmux stub（実 tmux のペイン一覧・pane_title を使わない）
#   - NOW_EPOCH          時計固定（AGE と鮮度判定を決定化）
#   - OE_THREADS_FRESH_SEC  帰属窓の固定（ホストに設定されていると G1 / G3 の期待が壊れる・実装SO 指摘）
#
# 回帰テストとして固定する事象（すべて #327 の gate で実測・または実装中に発見）:
#   - G1: 生存ペインは古い sidecar を溜めるので、鮮度を帰属に使わないと墓地が既定出力に出る
#   - G3: sidecar は server 内でのみ一意な pane を持つので、別 server の同番ペインを誤帰属しうる
#   - G4: pane が空の sidecar は交差では落ちるので unbound 行として出す
#   - 実装中に発見: 区切りに TAB を使うと空フィールドで列がずれる（TAB は IFS の空白文字）
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERB="$SCRIPT_DIR/../bin/oe-threads"
[[ -x "$VERB" ]] || { echo "FAIL: verb not found: $VERB"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$_TMP"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

# --- 固定した時計と server pid ---
NOW=1700000000
SPID=99999
export TMUX="/tmp/mock-tmux-socket,${SPID},0"
export NOW_EPOCH="$NOW"
# 帰属窓もホストから切り離す（既定値と同じ値を明示的に固定する）
export OE_THREADS_FRESH_SEC=900

# --- 隔離した置き場 ---
export OE_HEARTBEAT_DIR="$_TMP/oe-heartbeat"
export OE_PANE_ISSUE_DIR="$_TMP/pane-issue"
export OE_DELEGATE_STATE_DIR="$_TMP/oe-delegate"
mkdir -p "$OE_HEARTBEAT_DIR" "$OE_PANE_ISSUE_DIR" "$OE_DELEGATE_STATE_DIR"

# --- tmux stub（PATH 先頭・list-panes と display-message だけ意味を持つ）---
STUB="$_TMP/bin"; mkdir -p "$STUB"
cat > "$STUB/tmux" <<'TMUXEOF'
#!/usr/bin/env bash
# mock tmux: MOCK_LIVE_PANES（空白区切り）を list-panes が返す。display-message は title を返す。
case "${1:-}" in
  list-panes)
    if [[ -n "${MOCK_TMUX_FAIL:-}" ]]; then echo "no server running" >&2; exit 1; fi
    for p in ${MOCK_LIVE_PANES:-}; do printf '%s\n' "$p"; done ;;
  display-message)
    # 実 tmux と同じく要求書式で分岐する。#{pid} は observer 自身の server pid。
    # MOCK_SERVER_PID は - 既定（:- ではない）。空を明示代入して「pid が取れない server」を再現する。
    if [[ "$*" == *'#{pid}'* ]]; then printf '%s\n' "${MOCK_SERVER_PID-99999}"; exit 0; fi
    t=""; prev=""
    for a in "$@"; do [[ "$prev" == "-t" ]] && t="$a"; prev="$a"; done
    printf 'title of %s\n' "$t" ;;
  *) exit 0 ;;
esac
TMUXEOF
chmod +x "$STUB/tmux"
export PATH="$STUB:$PATH"
# tmux を PATH から外した状態を作るための空ディレクトリ（[13-6] で使う）
mkdir -p "$_TMP/no-tmux"

# --- sidecar を書く helper ---
# mkbeat <name> <age_sec> <ctx-json> <pane> <server_pid> <display_name|-none->
mkbeat() {
  local name="$1" age="$2" ctx="$3" pane="$4" spid="$5" dn="$6"
  jq -nc --argjson ts "$((NOW - age))" --argjson ctx "$ctx" --arg pane "$pane" --arg spid "$spid" --arg dn "$dn" \
    '{ts:$ts, context_pct:$ctx, pane:$pane, server_pid:$spid,
      model:(if $dn == "-none-" then {} else {id:"id-x", display_name:$dn} end)}' \
    > "$OE_HEARTBEAT_DIR/${name}.json"
}
mkissue() { printf '%s' "{\"name\":\"$2\"}" > "$OE_PANE_ISSUE_DIR/${SPID}_${1}"; }
reset_beats() { rm -rf "$OE_HEARTBEAT_DIR"; mkdir -p "$OE_HEARTBEAT_DIR"; }
run() { MOCK_LIVE_PANES="$1" bash "$VERB" "${@:2}" 2>/dev/null; }
rows() { printf '%s' "$1" | tail -n +2 | grep -c .; }

# ============================================================================
echo "[1] 母集団: 生存ペイン起点で、行数はペイン数と一致する"
# ============================================================================
reset_beats
mkbeat live0 5 61 '%0' "$SPID" 'Opus 5'
OUT="$(run '%0 %1 %2')"
ck  "行数はペイン数（3）"        "3"    "$(rows "$OUT")"
ckc "sidecar の無いペインも出る"  "$OUT" "%1"
ckc "  値は - になる"            "$OUT" "%1           -      -  -"

# ============================================================================
echo ""
echo "[2] G1 回帰: 同じ pane の古い sidecar（墓地）を既定出力に出さない"
# ============================================================================
reset_beats
mkbeat ghost1 345600 97 '%0' "$SPID" 'Opus 4.8'   # 4日前
mkbeat ghost2 345601 13 '%0' "$SPID" 'Opus 4.8'
mkbeat ghost3 345602 20 '%0' "$SPID" 'Opus 4.8'
mkbeat live0  5      61 '%0' "$SPID" 'Opus 5'
OUT="$(run '%0')"
ck  "%0 の行は1行だけ"           "1"    "$(rows "$OUT")"
ckc "現役の ctx が出る"           "$OUT" "61"
ncc "墓地の ctx は出ない（97）"    "$OUT" "97"
ncc "曖昧マークは付かない"         "$OUT" "%0?"

# ============================================================================
echo ""
echo "[3] DJ-C: fresh な候補が2件なら曖昧マークを付けて値を出さない"
# ============================================================================
reset_beats
mkbeat dupa 10 33 '%4' "$SPID" 'Fable 5'
mkbeat dupb 20 44 '%4' "$SPID" 'Opus 5'
OUT="$(run '%4')"
ckc "PANE に曖昧マーク"           "$OUT" "%4?"
ckc "件数を出す"                  "$OUT" "ambiguous(2)"
ncc "値は出さない（33）"           "$OUT" "33"
ncc "値は出さない（44）"           "$OUT" "44"

# ============================================================================
echo ""
echo "[4] G3 回帰: 別 server の同番ペインを誤帰属しない"
# ============================================================================
reset_beats
mkbeat other 15 22 '%1' '99998' 'Haiku 4.5'
OUT="$(run '%1')"
ncc "別 server の ctx を出さない"       "$OUT" "22"
ncc "別 server の model を出さない"     "$OUT" "Haiku"
ckc "値は - になる"                     "$OUT" "%1           -      -  -"
# server_pid が空の記録（producer 更新前 / TMUX 不在）は pane だけで突合する劣化動作
reset_beats
mkbeat legacy 15 22 '%1' '' 'Haiku 4.5'
OUT="$(run '%1')"
ckc "server_pid 空は pane だけで突合する" "$OUT" "Haiku 4.5"
ckc "  ctx も出る"                        "$OUT" "22"

# ============================================================================
echo ""
echo "[5] G4 回帰: pane を持たない fresh スレッドを unbound 行で出す"
# ============================================================================
reset_beats
mkbeat unb 25 8 '' "$SPID" 'Opus 5'
mkbeat old 999999 8 '' "$SPID" 'Opus 4.8'   # 古い unbound は出さない
OUT="$(run '%0')"
ckc "unbound 行が出る"              "$OUT" "unbound session"
ckc "  model が出る"                "$OUT" "Opus 5"
ncc "古い unbound は出さない"        "$OUT" "Opus 4.8"
ck  "行数はペイン1 + unbound1 = 2"  "2"    "$(rows "$OUT")"

# ============================================================================
echo ""
echo "[6] 空フィールドで列がずれない（実装中に発見・TAB 区切りの罠の回帰）"
# ============================================================================
reset_beats
mkbeat e1 5 61 '%0' '' 'Opus 5'          # server_pid だけ空
OUT="$(run '%0')"
ckc "server_pid 空でも model が MODEL 列に出る" "$OUT" "Opus 5"
ncc "  SESSION 値が PANE 列に来ていない"        "$OUT" "e1  "
reset_beats
mkbeat e2 5 61 '' '' 'Opus 5'            # pane と server_pid の両方が空
OUT="$(run '%0')"
ckc "両方空でも unbound 行として出る"           "$OUT" "unbound session e2"
ckc "  model が出る"                            "$OUT" "Opus 5"

# ============================================================================
echo ""
echo "[7] DJ-D/DJ-E: MODEL は幅で切らない（1M 版の区別が末尾に残る）"
# ============================================================================
reset_beats
mkbeat m1 5 47 '%6' "$SPID" 'Opus 5 (1M context)'
OUT="$(run '%6')"
ckc "display_name が末尾まで出る" "$OUT" "Opus 5 (1M context)"

# ============================================================================
echo ""
echo "[8] LABEL: pane-issue を優先し、無ければ pane_title へ落ちる"
# ============================================================================
reset_beats
mkbeat l1 5 47 '%6' "$SPID" 'Opus 5'
mkissue '_6' '#327 label-from-issue'
OUT="$(run '%6 %7')"
ckc "pane-issue のラベルが出る"   "$OUT" "#327 label-from-issue"
ckc "無いペインは pane_title"     "$OUT" "title of %7"

# ============================================================================
echo ""
echo "[9] DJ-H: 異常入力の期待値"
# ============================================================================
reset_beats
printf '%s' 'not json at all'    > "$OE_HEARTBEAT_DIR/broken.json"
printf '%s' '["array","not","object"]' > "$OE_HEARTBEAT_DIR/arr.json"
mkbeat future 0 50 '%2' "$SPID" 'Future 9'
jq -nc --argjson ts "$((NOW + 600))" '{ts:$ts, context_pct:50, pane:"%2", server_pid:"99999", model:{display_name:"Future 9"}}' > "$OE_HEARTBEAT_DIR/future.json"
jq -nc --argjson ts "$((NOW - 5))"   '{ts:$ts, context_pct:"NaN", pane:"%3", server_pid:"99999", model:{display_name:"Ctx Bad"}}' > "$OE_HEARTBEAT_DIR/ctxbad.json"
jq -nc                               '{ts:"nope", context_pct:5, pane:"%5", server_pid:"99999", model:{display_name:"Ts Bad"}}'  > "$OE_HEARTBEAT_DIR/tsbad.json"
jq -nc --argjson ts "$((NOW - 5))"   '{ts:$ts, context_pct:9, pane:"%7", server_pid:"99999", model:"a string"}'                  > "$OE_HEARTBEAT_DIR/modelstr.json"
OUT="$(run '%2 %3 %5 %7')"
ck  "壊れた JSON / 配列でも落ちない（4行出る）" "4" "$(rows "$OUT")"
ncc "未来 ts は候補にしない（Future 9）"        "$OUT" "Future 9"
ckc "ctx 非数値は - にして model は出す"        "$OUT" "Ctx Bad"
ncc "  ctx に NaN を出さない"                   "$OUT" "NaN"
ncc "ts 非数値は候補にしない（Ts Bad）"          "$OUT" "Ts Bad"
ckc "model が文字列なら MODEL は -"             "$OUT" "%7           9"

# ============================================================================
echo ""
echo "[10] 前提が満たせないときは exit 2（空表を 0 件と偽らない）"
# ============================================================================
reset_beats
MOCK_TMUX_FAIL=1 MOCK_LIVE_PANES='%0' bash "$VERB" >/dev/null 2>&1; rc=$?
ck  "tmux 不在 / list-panes 失敗 → exit 2" "2" "$rc"
env -u HOME -u OE_HEARTBEAT_DIR MOCK_LIVE_PANES='%0' bash "$VERB" >/dev/null 2>&1; rc=$?
ck  "HOME 未設定で置き場が決まらない → exit 2" "2" "$rc"
# shellcheck disable=SC2012  # / 直下の名前一覧を比べるだけなので ls で足りる（test_home_unset.sh と同じ判断）
_root_before="$(ls -a / 2>/dev/null | sort)"
env -u HOME -u OE_HEARTBEAT_DIR MOCK_LIVE_PANES='%0' bash "$VERB" >/dev/null 2>&1 || true
# shellcheck disable=SC2012
ck  "  / を汚さない" "$_root_before" "$(ls -a / 2>/dev/null | sort)"
MOCK_LIVE_PANES='%0' bash "$VERB" --fresh 0 >/dev/null 2>&1; rc=$?
ck  "--fresh 0 は不正 → exit 2" "2" "$rc"
MOCK_LIVE_PANES='%0' bash "$VERB" --bogus >/dev/null 2>&1; rc=$?
ck  "未知のオプション → exit 2" "2" "$rc"
MOCK_LIVE_PANES='%0' bash "$VERB" -h >/dev/null 2>&1; rc=$?
ck  "--help は exit 0" "0" "$rc"

# ============================================================================
echo ""
echo "[11] --all: 鮮度で絞らず全件を出す"
# ============================================================================
reset_beats
mkbeat g1 345600 97 '%0' "$SPID" 'Opus 4.8'
mkbeat l1 5      61 '%0' "$SPID" 'Opus 5'
OUT="$(run '%0' --all)"
ck  "全件出る（2行）"        "2"    "$(rows "$OUT")"
ckc "墓地も出る"             "$OUT" "97"
ckc "AGE が日で出る"         "$OUT" "4d"
ckc "SRVPID 列が出る"        "$OUT" "99999"

# ============================================================================
echo ""
echo "[12] 実装SO 指摘の回帰: observer の \$TMUX が空でも server identity を落とさない"
# ============================================================================
# tmux 外の端末（Cursor の統合ターミナル等）から叩くと $TMUX は空だが list-panes は既定 server の
# ペインを返す。ここで observer の pid を諦めると、別 server の sidecar が同番 pane に載る（G3 復活）。
reset_beats
mkbeat other 15 22 '%1' '99998' 'Haiku 4.5'
OUT="$(env -u TMUX MOCK_LIVE_PANES='%1' bash "$VERB" 2>/dev/null)"
ncc "TMUX 空でも別 server の ctx を出さない"    "$OUT" "22"
ncc "TMUX 空でも別 server の model を出さない"  "$OUT" "Haiku"
reset_beats
mkbeat mine 15 22 '%1' '99999' 'Opus 5'
OUT="$(env -u TMUX MOCK_LIVE_PANES='%1' bash "$VERB" 2>/dev/null)"
ckc "TMUX 空でも自 server の記録は出る"         "$OUT" "Opus 5"
ckc "  ctx も出る"                              "$OUT" "22"
# server pid がどうしても確定できないなら帰属を推測せず中断する
env -u TMUX MOCK_SERVER_PID='' MOCK_LIVE_PANES='%1' bash "$VERB" >/dev/null 2>&1; rc=$?
ck  "身元が確定できないと exit 2"                "2" "$rc"
# ラベルの key も <server_pid>_<pane> なので、TMUX 空でも pane-issue が引けること
reset_beats
mkbeat mine2 15 22 '%6' '99999' 'Opus 5'
mkissue '_6' '#327 label-from-issue'
OUT="$(env -u TMUX MOCK_LIVE_PANES='%6' bash "$VERB" 2>/dev/null)"
ckc "TMUX 空でも pane-issue のラベルが出る"      "$OUT" "#327 label-from-issue"
ncc "  pane_title へ落ちていない"                "$OUT" "title of %6"

# ============================================================================
echo ""
echo "[13] 実装SO 再依頼の回帰: 読取失敗を「記録なし」に化かさない / --all の前提はモード別"
# ============================================================================
# 13-1: 置き場が読めない（権限）→ exit 2。dir 未作成（正当な 0 件）とは区別する。
reset_beats
_unreadable="$_TMP/unreadable"; rm -rf "$_unreadable"; mkdir -p "$_unreadable"; chmod 000 "$_unreadable"
OE_HEARTBEAT_DIR="$_unreadable" MOCK_LIVE_PANES='%0' bash "$VERB" >/dev/null 2>&1; rc=$?
chmod 755 "$_unreadable"
ck  "置き場が読めない → exit 2"                    "2" "$rc"
_missing="$_TMP/never-created"
OE_HEARTBEAT_DIR="$_missing" MOCK_LIVE_PANES='%0' bash "$VERB" >/dev/null 2>&1; rc=$?
ck  "置き場が未作成（正当な 0 件）→ exit 0"        "0" "$rc"

# 13-2: 在るファイルを1件も読めない → exit 2（「観測不能」を空表にしない）
reset_beats
mkbeat u1 5 61 '%0' "$SPID" 'Opus 5'
chmod 000 "$OE_HEARTBEAT_DIR/u1.json"
MOCK_LIVE_PANES='%0' bash "$VERB" >/dev/null 2>&1; rc=$?
chmod 644 "$OE_HEARTBEAT_DIR/u1.json"
ck  "在るのに全件読めない → exit 2"                "2" "$rc"

# 13-3: 一部が読めないときは警告を出しつつ、読めた分は出す
reset_beats
mkbeat ok1 5 61 '%0' "$SPID" 'Opus 5'
mkbeat ng1 5 22 '%1' "$SPID" 'Sonnet 5'
chmod 000 "$OE_HEARTBEAT_DIR/ng1.json"
OUT="$(MOCK_LIVE_PANES='%0 %1' bash "$VERB" 2>"$_TMP/err13.txt")"; rc=$?
chmod 644 "$OE_HEARTBEAT_DIR/ng1.json"
ck  "一部読めない → exit 0"                        "0" "$rc"
ckc "読めた分は出る"                                "$OUT" "Opus 5"
ckc "読めなかった件数を stderr に出す"              "$(cat "$_TMP/err13.txt")" "読めませんでした"
ncc "読めなかった分の値は出さない"                  "$OUT" "Sonnet 5"

# 13-4: 壊れた JSON は「読取失敗」とは別枠で、警告つきで候補から外す（DJ-H どおり行は出る）
reset_beats
mkbeat ok2 5 61 '%0' "$SPID" 'Opus 5'
printf '%s' 'not json at all' > "$OE_HEARTBEAT_DIR/broken2.json"
OUT="$(MOCK_LIVE_PANES='%0' bash "$VERB" 2>"$_TMP/err14.txt")"; rc=$?
ck  "壊れた JSON が在っても exit 0"                "0" "$rc"
ckc "壊れている件数を stderr に出す"                "$(cat "$_TMP/err14.txt")" "中身が壊れている"
ncc "  読取失敗として数えない"                      "$(cat "$_TMP/err14.txt")" "読めませんでした"
ckc "健全な記録は出る"                              "$OUT" "Opus 5"

# 13-5: display_name が string でない sidecar でも、有効な ts / ctx / pane が脱落しない
reset_beats
jq -nc --argjson ts "$((NOW - 5))" '{ts:$ts, context_pct:61, pane:"%0", server_pid:"99999", model:{id:"x", display_name:["arr"]}}' \
  > "$OE_HEARTBEAT_DIR/typed.json"
OUT="$(run '%0')"
ckc "ctx は生き残る"                                "$OUT" "61"
ckc "MODEL は - になる"                             "$OUT" "-"
ncc "行が脱落していない"                            "$OUT" "%0           -      -  -"

# 13-6: --all は tmux を必要としない（既定モードは必要）
reset_beats
mkbeat a1 5 61 '%0' "$SPID" 'Opus 5'
OUT="$(PATH="$_TMP/no-tmux:$(dirname "$(command -v jq)"):/usr/bin:/bin" bash "$VERB" --all 2>/dev/null)"; rc=$?
ck  "--all は tmux 不在でも exit 0"                "0" "$rc"
ckc "  内容が出る"                                  "$OUT" "Opus 5"
PATH="$_TMP/no-tmux:$(dirname "$(command -v jq)"):/usr/bin:/bin" bash "$VERB" >/dev/null 2>&1; rc=$?
ck  "既定モードは tmux 不在で exit 2"              "2" "$rc"

# ============================================================================
echo ""
echo "=== RESULT: pass=$PASS fail=$FAIL ==="
[[ "$FAIL" -eq 0 ]] || exit 1
