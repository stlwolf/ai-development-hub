#!/usr/bin/env bash
set -euo pipefail

# test_handoff_retire.sh — oe-handoff retire の検証（#390）
#
# **実物には一切触れない。** board・登記・拍動・引き継ぎ文書はすべて一時ディレクトリの
# fixture で、tmux は OE_HANDOFF_TMUX のノブで stub に差し替える。**本物のペインを閉じない。**
#
# 見るもの:
#   (1) 停止の必須条件3つ（session_id が記録にある / 生きた委譲子0体 / 申告の全項目に処分）
#   (2) 申告と機械の検査の食い違いを列挙し、食い違ったら閉じない
#   (3) 引数なしは下見で、**kill-pane を1度も呼ばない**
#   (4) --execute は検査をやり直してから閉じる（呼び出し順で見る）
#   (5) --execute が前任のペイン以外を変更しない（board・登記・イベントログの mtime 不変）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_HANDOFF="$PROJECT_DIR/bin/oe-handoff"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }
command -v perl >/dev/null 2>&1 || { echo "SKIP: perl required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

PASS=0; FAIL=0
ck()  { if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
nck() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

HB="$_TMP_DIR/heartbeat"; REG="$_TMP_DIR/registry"; TR="$_TMP_DIR/transcripts"
EV="$_TMP_DIR/events";    WS="$_TMP_DIR/ws";        STUB="$_TMP_DIR/stub"
mkdir -p "$HB" "$REG" "$TR" "$EV" "$WS/.oe" "$STUB"
export OE_HEARTBEAT_DIR="$HB" OE_DELEGATE_STATE_DIR="$REG" OE_TRANSCRIPT_DIR="$TR"
export OE_EVENT_DIR="$EV" OE_HS_SERVER_PID="900"
NOW_EPOCH="$(date +%s)"; export OE_HS_NOW_EPOCH="$NOW_EPOCH"

CALL_LOG="$_TMP_DIR/calls.log"; : > "$CALL_LOG"
ALIVE="$_TMP_DIR/alive.txt"; printf '%%10\n%%11\n' > "$ALIVE"
cat > "$STUB/tmux" <<EOF
#!/usr/bin/env bash
printf 'tmux %s\n' "\$*" >> "$CALL_LOG"
case "\${1:-}" in
  list-panes) cat "$ALIVE"; exit 0 ;;
  kill-pane)  grep -vxF -- "\${3:-}" "$ALIVE" > "$ALIVE.new" && mv "$ALIVE.new" "$ALIVE"; exit 0 ;;
esac
exit 0
EOF
cat > "$STUB/gh" <<'EOF'
#!/usr/bin/env bash
[ -n "${GH_PRS:-}" ] && printf '%s\n' "$GH_PRS"
exit 0
EOF
chmod +x "$STUB"/*
export OE_HANDOFF_TMUX="$STUB/tmux"
export PATH="$STUB:$PATH"
export TMUX_PANE="%11"

mk_beat() { jq -cn --arg p "$2" --argjson t "$NOW_EPOCH" '{ts:$t, context_pct:50, pane:$p, server_pid:"900"}' > "$HB/$1.json"
  printf '{"x":1}\n' > "$TR/$1.jsonl"; perl -e 'utime $ARGV[0], $ARGV[0], $ARGV[1] or die' "$NOW_EPOCH" "$TR/$1.jsonl"; }
mk_child() { local key; key="$(printf '%s' "900_$1" | tr -c 'A-Za-z0-9' '_')"
  jq -cn --arg p "$1" --arg par "$2" '{pane:$p, label:"child", workspace:"", parent_pane:$par, role:"child"}' > "$REG/${key}.json"; }
mk_board() {
  # shellcheck disable=SC2016  # backtick は board の Markdown 記法
  printf '# START HERE\n\n鮮度: 2026-09-12 / 現統括: pane `%%11`（統括15代目・2026-09-12 着任。前任 `%%10` は退任申告済み・停止待ち）/ succession: **完了**\n' > "$1"
}
# mk_handoff <path> <session_id|""> <処分> [表を空にするか]
mk_handoff() {
  # `${3:-...}` は**空文字も既定値に置き換える**ので、空の処分を作れない（fixture が主張どおりの
  # 条件を作っていないことになる）。`${3-...}` は未指定のときだけ既定値を使う。
  local sid="${2:-}" disp="${3-済んだ}" empty="${4:-0}"
  {
    printf '%s\n' '<!-- oe-handoff:machine:begin -->'
    printf '%s\n' '## 観測できる状態'
    # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
    printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
    # shellcheck disable=SC2016
    printf -- '- 前任の session_id: `%s`\n' "${sid:-unknown}"
    printf '%s\n' '<!-- oe-handoff:machine:end -->'
    printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
    printf '%s\n' '| 項目 | 処分 | 補足 |'
    printf '%s\n' '| --- | --- | --- |'
    if [ "$empty" != "1" ]; then
      printf '| PR #392 | %s | マージ済み |\n' "$disp"
    fi
    printf '\n%s\n' '**機械に見えない残余**:'
    printf '%s\n' '- 返信待ち: なし'
    printf '\n%s\n' '## owner が下した裁定'
    printf '%s\n' '-'
  } > "$1"
}

# workspace は実際の git repo にする。非 git のままだと repo の検査が常に「分からない」に
# 倒れ、**テストが本番と違う前提を見ることになる**（#347 の教訓）。
git -C "$WS" init -q 2>/dev/null || true
git -C "$WS" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null || true

BOARD="$WS/.oe/board.md"; HANDOFF="$WS/.oe/handoff.md"
mk_board "$BOARD"; mk_handoff "$HANDOFF" "sid-pred" "済んだ"
mk_beat "sid-pred" "%10"

echo "[1] 下見（引数なし）: 条件がそろえば「閉じてよい」と言い、何も停止しない"
: > "$CALL_LOG"
set +e
out1="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1)"; rc1=$?
set -e
ck  "0 で終わる"            "0" "$rc1"
ckc "閉じてよいと言う"      "$out1" "判定: 閉じてよい"
ckc "下見だと言う"          "$out1" "下見なので何もしていません"
ckc "次の一手を出す"        "$out1" "oe-handoff retire --execute"
ck  "kill-pane を呼ばない"  "0" "$(grep -c 'kill-pane' "$CALL_LOG" | tr -d ' ')"
ck  "前任はまだ生きている"  "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[2] session_id が引き継ぎ記録に無ければ閉じない"
mk_handoff "$HANDOFF" "" "済んだ"
set +e
out2="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc2=$?
set -e
ck  "非0 で終わる"          "1" "$rc2"
ckc "理由を言う"            "$out2" "session_id が引き継ぎ記録に無い"
ck  "前任は生きたまま"      "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"
mk_handoff "$HANDOFF" "sid-pred" "済んだ"

echo "[3] 生きた委譲子が居れば閉じない"
mk_child "%12" "%10"; printf '%%12\n' >> "$ALIVE"
set +e
out3="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc3=$?
set -e
ck  "非0 で終わる"      "1" "$rc3"
ckc "件数を言う"        "$out3" "生きた委譲子が 1 件ある"
ck  "前任は生きたまま"  "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"
rm -f "$REG"/*.json; grep -vxF -- '%12' "$ALIVE" > "$ALIVE.n" && mv "$ALIVE.n" "$ALIVE"

echo "[4] 委譲子を数えられないときも閉じない"
set +e
out4="$(OE_DELEGATE_STATE_DIR="" "$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc4=$?
set -e
ck  "非0 で終わる"      "1" "$rc4"
ckc "数えられないと言う" "$out4" "数えられない"
ck  "前任は生きたまま"  "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[5] 申告の項目に処分が無ければ閉じない"
mk_handoff "$HANDOFF" "sid-pred" ""
set +e
out5="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc5=$?
set -e
ck  "非0 で終わる"    "1" "$rc5"
ckc "理由を言う"      "$out5" "処分が付いていない"
ck  "前任は生きたまま" "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[6] 語彙の外の処分も通さない"
mk_handoff "$HANDOFF" "sid-pred" "たぶん済んだ"
set +e
"$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute >/dev/null 2>&1; rc6=$?
set -e
ck "非0 で終わる" "1" "$rc6"

echo "[7] 「保留ゼロ」だけ（表が空）も通さない"
mk_handoff "$HANDOFF" "sid-pred" "済んだ" 1
set +e
out7="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc7=$?
set -e
ck  "非0 で終わる" "1" "$rc7"
ckc "理由を言う"   "$out7" "項目が1つも書かれていない"
mk_handoff "$HANDOFF" "sid-pred" "済んだ"

echo "[8] 申告に出てこない open PR があれば食い違いとして閉じない"
set +e
out8="$(GH_PRS='399 draft=false 別の作業' "$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc8=$?
set -e
ck  "非0 で終わる"        "1" "$rc8"
ckc "食い違いを挙げる"    "$out8" "open PR #399 が申告に出てこない"
ckc "閉じないと言う"      "$out8" "食い違っています"
ck  "前任は生きたまま"    "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[9] 引き継ぎ記録と board の註が食い違えば閉じない"
BAD="$WS/.oe/badboard.md"
# shellcheck disable=SC2016  # backtick は board の Markdown 記法
printf '鮮度: 2026-09-12 / 現統括: pane `%%11`（前任 `%%77` は退任申告済み・停止待ち）\n' > "$BAD"
set +e
out9="$("$OE_HANDOFF" retire -w "$WS" --board "$BAD" --handoff "$HANDOFF" --execute 2>&1)"; rc9=$?
set -e
ck  "非0 で終わる"      "1" "$rc9"
ckc "食い違いを言う"    "$out9" "board の註（%77）が食い違っています"
ck  "前任は生きたまま"  "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[10] board の席が自分でなければ閉じない（先に take を通す）"
OTHER="$WS/.oe/otherseat.md"
# shellcheck disable=SC2016  # backtick は board の Markdown 記法
printf '鮮度: 2026-09-12 / 現統括: pane `%%99`（前任 `%%10` は退任申告済み・停止待ち）\n' > "$OTHER"
set +e
out10="$("$OE_HANDOFF" retire -w "$WS" --board "$OTHER" --handoff "$HANDOFF" --execute 2>&1)"; rc10=$?
set -e
ck  "非0 で終わる"    "1" "$rc10"
ckc "take を促す"     "$out10" "先に take を通す"
ck  "前任は生きたまま" "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[11] 前任と自分が同じペインなら呼び方の誤り"
set +e
TMUX_PANE='%10' "$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" >/dev/null 2>&1; rc11=$?
set -e
ck "2 で終わる" "2" "$rc11"

# mtime は `date -r <file> +%s` で取る。`stat -f %m` は GNU では filesystem の情報を返して
# **成功してしまう**ので、before/after が同じ誤った値になり、書き換えを検出できない
# （lib/handoff-state.sh で同じ罠を直したのに、テストで再導入していた）。
echo "[12] --execute は検査をやり直してから閉じる（呼び出し順で見る）"
: > "$CALL_LOG"
BOARD_M_BEFORE="$(date -r "$BOARD" +%s)"
REG_FILE="$REG/$(printf '%s' '900_%11' | tr -c 'A-Za-z0-9' '_').json"
jq -cn '{pane:"%11", label:"cockpit", workspace:"", parent_pane:"", role:"child"}' > "$REG_FILE"
REG_M_BEFORE="$(date -r "$REG_FILE" +%s)"
printf '{"type":"x"}\n' > "$EV/oe-events.jsonl"
EV_M_BEFORE="$(date -r "$EV/oe-events.jsonl" +%s)"
set +e
out12="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc12=$?
set -e
ck  "0 で終わる"                "0" "$rc12"
ckc "閉じたと言う"              "$out12" "閉じました"
ckc "不在を確認したと言う"      "$out12" "不在を確認しました"
ckc "resume の案内を出す"       "$out12" "claude --resume sid-pred"
ck  "前任は不在になった"        "0" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"
ck  "list-panes が kill-pane より先" "list-panes" "$(awk '/^tmux (list-panes|kill-pane)/{print $2; exit}' "$CALL_LOG")"
ck  "kill-pane は1回だけ"       "1" "$(grep -c 'kill-pane' "$CALL_LOG" | tr -d ' ')"
ckc "閉じた相手は前任だけ"      "$(grep 'kill-pane' "$CALL_LOG")" "kill-pane -t %10"

echo "[13] --execute は前任のペイン以外を変更しない"
ck "board の mtime が動かない"       "$BOARD_M_BEFORE"  "$(date -r "$BOARD" +%s)"
ck "登記の mtime が動かない"         "$REG_M_BEFORE"    "$(date -r "$REG_FILE" +%s)"
ck "イベントログの mtime が動かない" "$EV_M_BEFORE"     "$(date -r "$EV/oe-events.jsonl" +%s)"
ckc "後始末はしないと言う"           "$out12" "後始末（登記の掃除・worktree の掃除・issue の close）はしていません"

echo "[14] 引き継ぎ文書が無ければ呼び方の誤り"
set +e
"$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$WS/.oe/nope.md" >/dev/null 2>&1; rc14=$?
set -e
ck "2 で終わる" "2" "$rc14"

# [12] が前任を閉じたので、ここから先のために生存状態を作り直す
printf '%%10\n%%11\n' > "$ALIVE"
mk_handoff "$HANDOFF" "sid-pred" "済んだ"

echo "[15] board が渡されなければ閉じない（観測できないまま判断しない）"
set +e
"$OE_HANDOFF" retire -w "$WS" --handoff "$HANDOFF" --execute >/dev/null 2>&1; rc15=$?
set -e
ck  "2 で終わる"       "2" "$rc15"
ck  "前任は生きたまま" "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[16] 自ペインが分からなければ閉じない（後継本人かを確かめられない）"
set +e
( unset TMUX_PANE; "$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute ) >/dev/null 2>&1; rc16=$?
set -e
ck  "2 で終わる"       "2" "$rc16"
ck  "前任は生きたまま" "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[17] board の註から前任を読めなければ閉じない"
NONOTE="$WS/.oe/nonote.md"
# shellcheck disable=SC2016  # backtick は board の Markdown 記法
printf '鮮度: 2026-09-12 / 現統括: pane `%%11`（註に前任が書かれていない）\n' > "$NONOTE"
set +e
out17="$("$OE_HANDOFF" retire -w "$WS" --board "$NONOTE" --handoff "$HANDOFF" --execute 2>&1)"; rc17=$?
set -e
ck  "非0 で終わる"      "1" "$rc17"
ckc "理由を言う"        "$out17" "board の註から前任を読めない"
ck  "前任は生きたまま"  "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[18] 機械の節が挙げた PR が申告に出てこなければ閉じない"
MACH="$WS/.oe/mach.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016
  printf -- '- 前任の session_id: `sid-pred`\n'
  printf -- '- 501 draft=false 機械が挙げた別の PR\n'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |' '| --- | --- | --- |' '| PR #392 | 済んだ | マージ済み |'
  printf '\n%s\n' '## owner が下した裁定' '-'
} > "$MACH"
set +e
out18="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$MACH" --execute 2>&1)"; rc18=$?
set -e
ck  "非0 で終わる"      "1" "$rc18"
ckc "理由を言う"        "$out18" "機械の節が挙げた PR #501 が申告に出てこない"
ck  "前任は生きたまま"  "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[19] 閉じる直前に委譲子が現れたら閉じない（最初の検査では居ない）"
# **最初の検査では子を見せない。** 目印を「retire の途中で必ず走る別のコマンド」に作らせる。
# 前のやり方（テストが始まる前に目印を置く）だと**最初の list-panes で既に子が見えてしまい**、
# 早い方の検査で落ちるので、**閉じる直前の数え直しを1度も通らないまま test が通っていた**。
# retire は 子の検査 → open PR の再検査（gh を呼ぶ）→ 閉じる直前の数え直し、の順で進むので、
# gh の stub に目印を作らせれば「あとから現れた子」を作れる。
LATE="$_TMP_DIR/late_child"
cat > "$STUB/gh" <<EOF
#!/usr/bin/env bash
touch "$LATE"
[ -n "\${GH_PRS:-}" ] && printf '%s\n' "\$GH_PRS"
exit 0
EOF
cat > "$STUB/tmux" <<EOF
#!/usr/bin/env bash
printf 'tmux %s\n' "\$*" >> "$CALL_LOG"
case "\${1:-}" in
  list-panes) cat "$ALIVE"; [ -f "$LATE" ] && printf '%%13\n'; exit 0 ;;
  kill-pane)  grep -vxF -- "\${3:-}" "$ALIVE" > "$ALIVE.new" && mv "$ALIVE.new" "$ALIVE"; exit 0 ;;
esac
exit 0
EOF
chmod +x "$STUB/tmux" "$STUB/gh"
rm -f "$LATE"; mk_child "%13" "%10"
: > "$CALL_LOG"
set +e
out19="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc19=$?
set -e
ck  "非0 で終わる"                  "1" "$rc19"
ckc "閉じる直前に現れたと言う"      "$out19" "閉じる直前に生きた委譲子が 1 件現れました"
ck  "kill-pane を呼ばない"          "0" "$(grep -c 'kill-pane' "$CALL_LOG" | tr -d ' ')"
ck  "前任は生きたまま"              "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"
# **最初の検査では子が見えていなかったこと**（＝早い方の検査で落ちていないこと）を確かめる
nck "早い方の検査では落ちていない"  "$out19" "前任に生きた委譲子が 1 件あります"
rm -f "$LATE" "$REG"/*.json
cat > "$STUB/gh" <<'EOF'
#!/usr/bin/env bash
[ -n "${GH_PRS:-}" ] && printf '%s\n' "$GH_PRS"
exit 0
EOF
chmod +x "$STUB/gh"

echo "[20] 停止後の一覧が引けなければ「不在を確認した」と言わない"
FAILAFTER="$_TMP_DIR/fail_after_kill"
cat > "$STUB/tmux" <<EOF
#!/usr/bin/env bash
printf 'tmux %s\n' "\$*" >> "$CALL_LOG"
case "\${1:-}" in
  list-panes) [ -f "$FAILAFTER" ] && exit 1; cat "$ALIVE"; exit 0 ;;
  kill-pane)  touch "$FAILAFTER"; exit 0 ;;
esac
exit 0
EOF
chmod +x "$STUB/tmux"
rm -f "$FAILAFTER"; : > "$CALL_LOG"
set +e
out20="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc20=$?
set -e
ck  "非0 で終わる"           "1" "$rc20"
ckc "確認できていないと言う" "$out20" "不在を確認できていません"
nck "確認したとは言わない"   "$out20" "不在を確認しました"

echo "[21] PR 番号の照合が部分一致で通らない"
printf '%%10\n%%11\n' > "$ALIVE"
cat > "$STUB/tmux" <<EOF
#!/usr/bin/env bash
printf 'tmux %s\n' "\$*" >> "$CALL_LOG"
case "\${1:-}" in
  list-panes) cat "$ALIVE"; exit 0 ;;
  kill-pane)  grep -vxF -- "\${3:-}" "$ALIVE" > "$ALIVE.new" && mv "$ALIVE.new" "$ALIVE"; exit 0 ;;
esac
exit 0
EOF
chmod +x "$STUB/tmux"
SUB="$WS/.oe/substr.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016
  printf -- '- 前任の session_id: `sid-pred`\n'
  printf -- '- 501 draft=false 機械が挙げた PR\n'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  # 申告は #3501 という**別の PR** を書いている。部分一致だと 501 に当たってしまう
  printf '%s\n' '| 項目 | 処分 | 補足 |' '| --- | --- | --- |' '| PR #3501 | 済んだ | 別の PR |'
  printf '\n%s\n' '## owner が下した裁定' '-'
} > "$SUB"
set +e
out21="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$SUB" --execute 2>&1)"; rc21=$?
set -e
ck  "非0 で終わる"      "1" "$rc21"
ckc "欠落を見逃さない"  "$out21" "機械の節が挙げた PR #501 が申告に出てこない"
ck  "前任は生きたまま"  "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[22] 閉じる直前に transcript が使えなくなっていたら閉じない"
mk_handoff "$HANDOFF" "sid-pred" "済んだ"
mv "$TR/sid-pred.jsonl" "$TR/sid-pred.jsonl.away"
set +e
out22="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc22=$?
set -e
mv "$TR/sid-pred.jsonl.away" "$TR/sid-pred.jsonl"
ck  "非0 で終わる"      "1" "$rc22"
ckc "理由を言う"        "$out22" "transcript が見つからないか古すぎます"
ck  "前任は生きたまま"  "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
