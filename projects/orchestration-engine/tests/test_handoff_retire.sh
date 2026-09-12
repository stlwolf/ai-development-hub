#!/usr/bin/env bash
set -euo pipefail

# test_handoff_retire.sh — oe-handoff retire の検証（#390）
#
# **実物には一切触れない。** board・登記・拍動・引き継ぎ文書はすべて一時ディレクトリの
# fixture で、tmux は OE_HANDOFF_TMUX のノブで stub に差し替える。**本物のペインを閉じない。**
#
# 見るもの:
#   (1) 停止の必須条件2つ（session_id が記録にある / 申告の全項目に処分）
#       生きた委譲子は**閉じない理由にしない**（owner 裁定 2026-09-13）。数えて出すだけである。
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

echo "[3] 生きた委譲子が居ても閉じる（owner 裁定 2026-09-13）"
# 以前はここが必須条件2で、子が居ると閉じなかった。**子が生きたままの交代が正常系**であり、
# 止めているほうが不具合だという裁定で要求をやめた。数えて出し、穴の在り処を明示して閉じる。
mk_child "%12" "%10"; printf '%%12\n' >> "$ALIVE"
set +e
out3="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc3=$?
set -e
ck  "0 で終わる"            "0" "$rc3"
ckc "件数を言う"            "$out3" "生きた委譲子が 1 件ある"
ckc "閉じない理由にしない"  "$out3" "閉じない理由にはしない"
ckc "引き受けるものとして出す" "$out3" "後継が引き受けるもの"
ckc "穴の在り処を出す"      "$out3" "残る穴: 生きた委譲子が自分から出す報告"
ckc "塞ぎ方を出す"          "$out3" "報告の宛先は後継の pane である"
ckc "挨拶では塞がらないと出す" "$out3" "挨拶では塞がりません"
ck  "前任は閉じた"          "0" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"
printf '%%10\n' >> "$ALIVE"
rm -f "$REG"/*.json; grep -vxF -- '%12' "$ALIVE" > "$ALIVE.n" && mv "$ALIVE.n" "$ALIVE"

echo "[4] 委譲子を数えられなくても閉じる。ただし「居ない」とは書かない"
set +e
out4="$(OE_DELEGATE_STATE_DIR="" "$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc4=$?
set -e
ck  "0 で終わる"          "0" "$rc4"
ckc "数えられないと言う"  "$out4" "数えられない"
nck "居ないとは言わない"  "$out4" "前任に生きた委譲子は居ない"
ck  "前任は閉じた"        "0" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"
printf '%%10\n' >> "$ALIVE"

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

echo "[19] 閉じる直前に現れた委譲子を数え直して出す（閉じるのは止めない）"
# **最初の検査では子を見せない。** 目印を「retire の途中で必ず走る別のコマンド」に作らせる。
# 前のやり方（テストが始まる前に目印を置く）だと**最初の list-panes で既に子が見えてしまい**、
# 閉じる直前の数え直しを1度も通らないまま test が通っていた。
# retire は 子の検査 → open PR の再検査（gh を呼ぶ）→ 閉じる直前の数え直し、の順で進むので、
# gh の stub に目印を作らせれば「あとから現れた子」を作れる。
#
# **見るものが owner 裁定（2026-09-13）で変わった。** 以前は「あとから現れたら閉じない」だったが、
# 子は交代を止めないので**閉じる**。見るのは「数え直しが実際に走り、あとから現れた子を出すこと」
# である（後継が声をかける相手が変わるため）。**数え直し自体を落とすと、誰を引き受けたかが
# 出なくなる**ので、数え直しは残す。
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
ck  "0 で終わる"                    "0" "$rc19"
ckc "閉じる直前の件数を出す"        "$out19" "閉じる直前の生きた委譲子: 1 件"
ckc "あとから現れた子を一覧で出す"  "$out19" "%13"
ckc "後継が引き受けると出す"        "$out19" "この子は後継が引き受ける"
ck  "kill-pane を呼ぶ"              "1" "$(grep -c 'kill-pane' "$CALL_LOG" | tr -d ' ')"
ck  "前任は閉じた"                  "0" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"
printf '%%10\n' >> "$ALIVE"
# **最初の検査では子が見えていなかったこと**を確かめる。見えていたなら、あとから現れた子を
# 数え直しで拾ったことの証拠にならない（この test は数え直しが走ることを見るためのものである）。
nck "早い方の検査には出ていない"    "$out19" "前任に生きた委譲子が 1 件ある"
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

echo "[23] 閉じるペインが別の session のものになっていたら閉じない（pane 番号の再利用）"
# **transcript が使えることは「記録の session が生きている」ことしか言わない。**
# ペイン番号が再利用されていれば、そのペインに座っているのは別の session である。
# 確かめずに閉じると、関係のないセッションを閉じたうえで「前任は resume で開き直せる」と
# 報告することになる（実装SO の指摘・2026-09-13）。
# **同じ時刻の拍動を2つ置くと「同じ新しさ」になり unknown へ落ちる**（[24] がその枝である）。
# ここで作りたいのは「新しい別の session がそのペインに座っている」状態なので、**厳密に新しい**
# 拍動を置く。最初にこれを間違え、tie になって [24] と同じ枝を通っていた。
NEWER=$((NOW_EPOCH + 60))
jq -cn --arg p '%10' --argjson t "$NEWER" '{ts:$t, context_pct:50, pane:$p, server_pid:"900"}' > "$HB/sid-other.json"
printf '{"type":"user"}\n' > "$TR/sid-other.jsonl"
perl -e 'utime $ARGV[0], $ARGV[0], $ARGV[1] or die' "$NEWER" "$TR/sid-other.jsonl"
: > "$CALL_LOG"
set +e
out23="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc23=$?
set -e
ck  "非0 で終わる"            "1" "$rc23"
ckc "別の session だと言う"   "$out23" "に座っているのは別の session です"
ckc "記録といまの両方を出す"  "$out23" "記録 sid-pred / いま sid-other"
ckc "再利用だと言う"          "$out23" "ペイン番号が再利用されています"
ck  "前任は生きたまま"        "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"
ck  "kill-pane を呼ばない"    "0" "$(grep -c 'kill-pane' "$CALL_LOG" | tr -d ' ')"
rm -f "$HB/sid-other.json" "$TR/sid-other.jsonl"

echo "[24] 閉じる直前に session_id を引けなければ閉じない（unknown を一致に数えない）"
# 同じ pane に**同じ新しさ**の拍動が2つあると oe_hs_session_for_pane は unknown を返す。
# **unknown を「記録と一致した」に畳まない。**
mk_beat "sid-tie-a" "%10"; mk_beat "sid-tie-b" "%10"
printf '{"type":"user"}\n' > "$TR/sid-tie-a.jsonl"
printf '{"type":"user"}\n' > "$TR/sid-tie-b.jsonl"
: > "$CALL_LOG"
set +e
out24="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc24=$?
set -e
ck  "非0 で終わる"                  "1" "$rc24"
ckc "引けなかったと言う"            "$out24" "session_id を引けませんでした"
ckc "確かめられないから閉じないと言う" "$out24" "前任のものだと確かめられないので閉じません"
ck  "前任は生きたまま"              "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"
ck  "kill-pane を呼ばない"          "0" "$(grep -c 'kill-pane' "$CALL_LOG" | tr -d ' ')"
rm -f "$HB/sid-tie-a.json" "$HB/sid-tie-b.json" "$TR/sid-tie-a.jsonl" "$TR/sid-tie-b.jsonl"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
