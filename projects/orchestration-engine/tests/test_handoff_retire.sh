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

HB="$_TMP_DIR/heartbeat"; REG="$_TMP_DIR/registry"; TR="$_TMP_DIR/transcripts"; PIDMAP="$_TMP_DIR/pidmap"
EV="$_TMP_DIR/events";    WS="$_TMP_DIR/ws";        STUB="$_TMP_DIR/stub"
mkdir -p "$HB" "$REG" "$TR" "$EV" "$WS/.oe" "$STUB" "$PIDMAP"
export OE_HEARTBEAT_DIR="$HB" OE_DELEGATE_STATE_DIR="$REG" OE_TRANSCRIPT_DIR="$TR"
export OE_EVENT_DIR="$EV" OE_HS_SERVER_PID="900"
NOW_EPOCH="$(date +%s)"; export OE_HS_NOW_EPOCH="$NOW_EPOCH"

CALL_LOG="$_TMP_DIR/calls.log"; : > "$CALL_LOG"
ALIVE="$_TMP_DIR/alive.txt"; printf '%%10\n%%11\n' > "$ALIVE"

# **stub は要求された format を尊重する。** 実物の tmux は `-F '#{pane_id} #{pane_pid}'` で
# 2列返すので、pane id だけを返す stub は「pid が引けない」を作ってしまい、**主張と違う条件で
# test が通る**（この単位で何度も踏んだ型）。pid は PIDMAP に在ればそれを、無ければ `9<番号>`。
cat > "$STUB/_panes.sh" <<EOF
emit_panes() { # \$1=全引数, \$2..=追加で生きているペイン
  local args="\$1"; shift
  { cat "$ALIVE"; for x in "\$@"; do printf '%s\n' "\$x"; done; } | while read -r p; do
    [ -n "\$p" ] || continue
    if printf '%s' "\$args" | grep -q pane_pid; then
      printf '%s %s\n' "\$p" "\$(cat "$PIDMAP/\${p#%}" 2>/dev/null || printf '9%s' "\${p#%}")"
    else
      printf '%s\n' "\$p"
    fi
  done
}
EOF

cat > "$STUB/tmux" <<EOF
#!/usr/bin/env bash
printf 'tmux %s\n' "\$*" >> "$CALL_LOG"
case "\${1:-}" in
  list-panes) . "$STUB/_panes.sh"; emit_panes "\$*"; exit 0 ;;
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
    # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
    printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
    # shellcheck disable=SC2016
    # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
    printf -- '- 前任の session_id: `%s`\n' "${sid:-unknown}"
    # shellcheck disable=SC2016
    # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
    printf -- '- 前任のペインの pid: `%s`\n' "${5:-910}"
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
ckc "食い違いを挙げる"    "$out8" "open PR #399 に処分が付いていない"
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
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
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
ckc "理由を言う"        "$out18" "機械の節が挙げた PR #501 に処分が付いていない"
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
  list-panes) . "$STUB/_panes.sh"; if [ -f "$LATE" ]; then emit_panes "\$*" '%13'; else emit_panes "\$*"; fi; exit 0 ;;
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
  list-panes) [ -f "$FAILAFTER" ] && exit 1; . "$STUB/_panes.sh"; emit_panes "\$*"; exit 0 ;;
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
  list-panes) . "$STUB/_panes.sh"; emit_panes "\$*"; exit 0 ;;
  kill-pane)  grep -vxF -- "\${3:-}" "$ALIVE" > "$ALIVE.new" && mv "$ALIVE.new" "$ALIVE"; exit 0 ;;
esac
exit 0
EOF
chmod +x "$STUB/tmux"
SUB="$WS/.oe/substr.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
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
ckc "欠落を見逃さない"  "$out21" "機械の節が挙げた PR #501 に処分が付いていない"
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

echo "[25] 拍動がまだ旧世代を指しているあいだも、pid が変わっていれば閉じない"
# **これが session_id の突合だけでは塞げない窓である。** `oe_hs_session_for_pane` は
# 「ペインが再利用され、新しいセッションがまだ一度も拍動を書いていない」あいだ**旧世代の
# session_id を返す**（lib の注記）。つまり sid の突合は通る。**pid は tmux が握っているので
# その窓でも変わる。** [23] は新しい拍動が既に在る場合しか作っていなかった（実装SO の指摘）。
printf '9999\n' > "$PIDMAP/10"        # %10 の pid が変わった（ペインが作り直された）
: > "$CALL_LOG"
set +e
out25="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute 2>&1)"; rc25=$?
set -e
ck  "非0 で終わる"                "1" "$rc25"
ckc "sid の突合は通っている"      "$out25" "前任の session_id が引き継ぎ記録にある（sid-pred）"
ckc "pid が変わったと言う"        "$out25" "で走っているプロセスが変わっています"
ckc "記録といまの両方を出す"      "$out25" "記録 pid 910 / いま 9999"
ck  "kill-pane を呼ばない"        "0" "$(grep -c 'kill-pane' "$CALL_LOG" | tr -d ' ')"
ck  "前任は生きたまま"            "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"
rm -f "$PIDMAP/10"

echo "[26] 引き継ぎ記録に pid が無い（古い形式）なら閉じない"
# pid の行が無い引き継ぎ文書を作る。**「無い」を「一致した」に畳まない。**
OLDFMT="$WS/.oe/handoff-oldfmt.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->'
  printf '%s\n' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任の session_id: `sid-pred`\n'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |'
  printf '%s\n' '| --- | --- | --- |'
  printf '%s\n' '| PR #392 | 済んだ | マージ済み |'
  printf '\n%s\n' '## owner が下した裁定'
} > "$OLDFMT"
: > "$CALL_LOG"
set +e
out26="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$OLDFMT" --execute 2>&1)"; rc26=$?
set -e
ck  "非0 で終わる"              "1" "$rc26"
ckc "古い形式だと言う"          "$out26" "古い形式の引き継ぎ文書です"
ckc "prepare を走らせ直せと言う" "$out26" "oe-handoff prepare を走らせ直して"
ck  "kill-pane を呼ばない"      "0" "$(grep -c 'kill-pane' "$CALL_LOG" | tr -d ' ')"

echo "[27] 申告の表: escaped pipe で処分が付いたように見せられない"
# `| command \| 済んだ |  | … |` は Markdown 上では**処分欄が空**である。素朴に `-F'|'` で
# 割ると3番目の欄が `済んだ` に見えて未処分の項目が通る（実装SO の指摘・実測で再現した）。
ESCP="$WS/.oe/handoff-escpipe.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->'
  printf '%s\n' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任の session_id: `sid-pred`\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペインの pid: `910`\n'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |'
  printf '%s\n' '| --- | --- | --- |'
  printf '%s\n' '| command \| 済んだ |  | 処分が空である |'
  printf '\n%s\n' '## owner が下した裁定'
} > "$ESCP"
set +e
out27="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$ESCP" --execute 2>&1)"; rc27=$?
set -e
ck  "非0 で終わる"          "1" "$rc27"
ckc "処分が無いと言う"      "$out27" "処分が付いていない（または語彙の外の）項目がある"
ckc "空の処分を出して見せる" "$out27" "処分[]"
ck  "前任は生きたまま"      "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[28] 申告の表: 項目名に「項目」を含む行を見出しとして捨てない"
HDR="$WS/.oe/handoff-hdrword.md"
sed 's/| command \\| 済んだ |  | 処分が空である |/| この項目 |  | 処分が空である |/' "$ESCP" > "$HDR"
set +e
out28="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HDR" --execute 2>&1)"; rc28=$?
set -e
ck  "非0 で終わる"            "1" "$rc28"
nck "「項目が1つも無い」にしない" "$out28" "自己申告の表に項目が1つも書かれていない"
ckc "処分が無いと言う"        "$out28" "処分が付いていない（または語彙の外の）項目がある"
ck  "前任は生きたまま"        "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[29] 申告の表: 字下げされた行を黙って落とさない"
# `/^\|/` で錨を打つと、字下げされた行（Markdown では有効な表の行）が数から消える。
# **一部だけ字下げされていると、その行の未処分を見逃す**（自分で試して見つけた・2026-09-13）。
IND="$WS/.oe/handoff-indent.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->'
  printf '%s\n' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任の session_id: `sid-pred`\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペインの pid: `910`\n'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |'
  printf '%s\n' '| --- | --- | --- |'
  printf '%s\n' '| PR #392 | 済んだ | 字下げなし |'
  printf '%s\n' '  | PR #393 |  | 字下げあり・処分が空 |'
  printf '\n%s\n' '## owner が下した裁定'
} > "$IND"
set +e
out29="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$IND" --execute 2>&1)"; rc29=$?
set -e
ck  "非0 で終わる"            "1" "$rc29"
ckc "字下げされた行を拾う"    "$out29" "PR #393"
ckc "処分が無いと言う"        "$out29" "処分が付いていない（または語彙の外の）項目がある"
ck  "前任は生きたまま"        "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[30] 申告の表: 項目名の literal TAB で処分が付いたように見せられない"
# 以前は「項目<TAB>処分」に直してから `awk -F'\t'` で読み直していたので、**項目名に TAB が
# あると列がずれ**、処分欄が空でも `済んだ` と読めた（実装SO の指摘・2026-09-13）。
TABP="$WS/.oe/handoff-tab.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->'
  printf '%s\n' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任の session_id: `sid-pred`\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペインの pid: `910`\n'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |'
  printf '%s\n' '| --- | --- | --- |'
  # **本物の TAB を1つ入れる。** `printf '%b'` で作る（`\t` を文字列のまま置くと試験にならない）。
  printf '| foo%b済んだ |  | 処分が空である |\n' '\t'
  printf '\n%s\n' '## owner が下した裁定'
} > "$TABP"
ck "fixture に本物の TAB が在る" "1" "$(grep -c "$(printf '\t')" "$TABP" | tr -d ' ')"
set +e
out30="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$TABP" --execute 2>&1)"; rc30=$?
set -e
ck  "非0 で終わる"        "1" "$rc30"
ckc "処分が無いと言う"    "$out30" "処分が付いていない（または語彙の外の）項目がある"
ck  "前任は生きたまま"    "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[31] 機械の節の PR は、散文に番号を書いただけでは通らない"
# 申告の節全体を部分一致で見ていたので、**表に別の適法な行を1つ置き、散文に番号を書くだけで**
# 未処分の PR を通せた（実装SO の2レーンが独立に再現・2026-09-13）。
PROSE="$WS/.oe/handoff-prose.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->'
  printf '%s\n' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任の session_id: `sid-pred`\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペインの pid: `910`\n'
  printf '%s\n' '### open PR'
  printf '%s\n' '- 501 draft=false 未処分にしたい PR'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |'
  printf '%s\n' '| --- | --- | --- |'
  printf '%s\n' '| PR #392 | 済んだ | これは適法な行 |'
  printf '\n%s\n' '- 返信待ち: PR #501'
  printf '\n%s\n' '## owner が下した裁定'
} > "$PROSE"
set +e
out31="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$PROSE" --execute 2>&1)"; rc31=$?
set -e
ck  "非0 で終わる"                "1" "$rc31"
ckc "処分が無いと言う"            "$out31" "機械の節が挙げた PR #501 に処分が付いていない"
ckc "表の語彙の検査は通っている"  "$out31" "申告の全項目に処分が付いている（1 件）"
ck  "前任は生きたまま"            "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[32] 表の行に処分付きで書いてあれば通る（[31] の対になる確認）"
OKP="$WS/.oe/handoff-okprose.md"
sed 's/^| PR #392 | 済んだ | これは適法な行 |$/| PR #501 | 引き継ぐ | 表の行に処分付きで書いた |/' "$PROSE" > "$OKP"
set +e
out32="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$OKP" 2>&1)"; rc32=$?
set -e
ck  "下見は 0 で終わる"       "0" "$rc32"
nck "PR の処分を落とさない"   "$out32" "PR #501 に処分が付いていない"

echo "[33] 同一性の検査と kill のあいだに何も挟まない"
# 以前は pid の突合が子の数え直しより前にあり、**確かめてから閉じるまでに別の処理が入っていた**。
# そのあいだにペイン番号が再利用されると、確かめた相手と閉じる相手がずれる（実装SO の指摘）。
# **窓を0にはできないが、あいだに何も挟まないことは機械で見られる。**
# CALL_LOG の `kill-pane` の直前の tmux 呼び出しが、pid を要求する list-panes であることを見る。
mk_board "$BOARD"; mk_handoff "$HANDOFF" "sid-pred" "済んだ"
: > "$CALL_LOG"
set +e
"$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --execute >/dev/null 2>&1
set -e
prev_call="$(awk '/^tmux kill-pane/{print prev; exit} {prev=$0}' "$CALL_LOG")"
ckc "kill の直前は pid を引く呼び出し" "$prev_call" "pane_pid"
ck  "kill-pane は1回だけ"              "1" "$(grep -c '^tmux kill-pane' "$CALL_LOG" | tr -d ' ')"
printf '%%10\n' >> "$ALIVE"

echo "[34] 未 push の照合も散文では通らない"
# 5箇所目。**1つ取り残すと、そこだけ散文で通る**（自分で grep して見つけた・2026-09-13）。
# 未 push が在る repo 状態を作り、申告は「表に適法な行1つ + 散文に『未 push』」にする。
UP="$_TMP_DIR/ws-unpushed"; mkdir -p "$UP/.oe"
git -C "$UP" init -q 2>/dev/null || true
git -C "$UP" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null || true
git -C "$UP" branch -q -M topic 2>/dev/null || true
# 上流を持たない枝だと「比べる相手が無い」枝へ行くので、上流のある枝を作る
REMOTE="$_TMP_DIR/remote.git"; git init -q --bare "$REMOTE" 2>/dev/null || true
git -C "$UP" remote add origin "$REMOTE" 2>/dev/null || true
git -C "$UP" push -q -u origin topic 2>/dev/null || true
git -C "$UP" -c user.email=t@t -c user.name=t commit -q --allow-empty -m unpushed 2>/dev/null || true
UPH="$UP/.oe/handoff.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->'
  printf '%s\n' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任の session_id: `sid-pred`\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペインの pid: `910`\n'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |'
  printf '%s\n' '| --- | --- | --- |'
  printf '%s\n' '| PR #392 | 済んだ | 適法な行 |'
  printf '\n%s\n' '- 未 push のことは散文にだけ書いた'
  printf '\n%s\n' '## owner が下した裁定'
} > "$UPH"
# lib は source していないので、未 push の有無は git で直に数える（fixture が主張どおりの
# 条件を作れていることを確かめるため。ここを飛ばすと、別の理由で落ちても test が通る）。
up_ahead="$(git -C "$UP" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)"
ck "fixture に未 push が1件在る" "1" "$up_ahead"
set +e
out34="$("$OE_HANDOFF" retire -w "$UP" --board "$BOARD" --handoff "$UPH" --execute 2>&1)"; rc34=$?
set -e
ck  "非0 で終わる"          "1" "$rc34"
ckc "散文では通らない"      "$out34" "未 push が残っているのに、処分の付いた申告の行に出てこない"
ck  "前任は生きたまま"      "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[35] PR の照合が種別をまたいで誤一致しない"
# `worktree topic-501` という処分済みの行が **PR #501 の処分としても一致**していた
# （番号だけの境界付き一致だったため・実装SO の指摘・2026-09-13）。`#<番号>` を要求する。
XK="$WS/.oe/handoff-crosskind.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->'
  printf '%s\n' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任の session_id: `sid-pred`\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペインの pid: `910`\n'
  printf '%s\n' '### open PR'
  printf '%s\n' '- 501 draft=false 未処分にしたい PR'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |'
  printf '%s\n' '| --- | --- | --- |'
  printf '%s\n' '| worktree topic-501 | 引き継ぐ | PR の処分ではない |'
  printf '\n%s\n' '## owner が下した裁定'
} > "$XK"
set +e
out35="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$XK" --execute 2>&1)"; rc35=$?
set -e
ck  "非0 で終わる"                "1" "$rc35"
ckc "PR の処分が無いと言う"       "$out35" "機械の節が挙げた PR #501 に処分が付いていない"
# shellcheck disable=SC2016  # backtick は出力に含まれる Markdown 記法で、展開させない
ckc "求める形を言う"              "$out35" '`#501` の形で出てこない'
ck  "前任は生きたまま"            "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[36] GFM の alignment delimiter を未処分のデータ行として数えない"
# `| :--- | :---: | ---: |` は区切り行である。以前は `^-{2,}$` だけを区切りとしていたので、
# **正当に全項目へ処分を付けた申告が恒常的に通らなかった**（fail-closed だが誤判定）。
ALGN="$WS/.oe/handoff-align.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->'
  printf '%s\n' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任の session_id: `sid-pred`\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペインの pid: `910`\n'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |'
  printf '%s\n' '| :--- | :---: | ---: |'
  printf '%s\n' '| PR #392 | 済んだ | 適法な行 |'
  printf '\n%s\n' '## owner が下した裁定'
} > "$ALGN"
set +e
out36="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$ALGN" 2>&1)"; rc36=$?
set -e
ck  "下見は 0 で終わる"           "0" "$rc36"
ckc "件数は1件"                   "$out36" "申告の全項目に処分が付いている（1 件）"
nck "区切り行を落とさない"        "$out36" ":---"

echo "[37] worktree を数えられなければ、無いことにしない"
# `git worktree list` の失敗を `wt_now=""` に畳んでいたので、**観測できていないのに未処分の
# worktree が無いことにして閉じた**（実装SO の指摘・2026-09-13）。git でない場所を渡して作る。
NOGIT="$_TMP_DIR/not-a-repo"; mkdir -p "$NOGIT/.oe"
cp "$HANDOFF" "$NOGIT/.oe/handoff.md"
set +e
out37="$("$OE_HANDOFF" retire -w "$NOGIT" --board "$BOARD" --handoff "$NOGIT/.oe/handoff.md" --execute 2>&1)"; rc37=$?
set -e
ck  "非0 で終わる"                "1" "$rc37"
ckc "数えられないと言う"          "$out37" "worktree を数えられなかった"
ckc "無いとは言わないと明示する"  "$out37" "未処分の worktree が無いとは言えない"
ck  "前任は生きたまま"            "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[38] 機械の節の目印が壊れていたら、文書の散文から値を拾わない"
# 以前は `grep -m1 '^- 前任のペイン: '` を文書全体に当てていたので、**機械の節が無くても
# 同じ形の行が散文にあれば値を信用した**（実装SO の指摘・2026-09-13）。
FAKE="$WS/.oe/handoff-nomarker.md"
{
  printf '%s\n' '## 観測できる状態（目印が無い・人が手で書いた）'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任の session_id: `sid-pred`\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペインの pid: `910`\n'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |'
  printf '%s\n' '| --- | --- | --- |'
  printf '%s\n' '| PR #392 | 済んだ | x |'
  printf '\n%s\n' '## owner が下した裁定'
} > "$FAKE"
: > "$CALL_LOG"
set +e
out38="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$FAKE" --execute 2>&1)"; rc38=$?
set -e
ck  "2 で終わる"                  "2" "$rc38"
ckc "目印が1組でないと言う"       "$out38" "機械の節の目印が1組になっていません"
ckc "機械が書いた記録と言えないと言う" "$out38" "機械が書いた記録だと言えないので閉じません"
ck  "kill-pane を呼ばない"        "0" "$(grep -c 'kill-pane' "$CALL_LOG" | tr -d ' ')"
ck  "前任は生きたまま"            "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo '[39] 機械の節が # 付きで書いていても読む（表示と要求する形を揃えた分）'
# `prepare` は 2026-09-13 から open PR を `- #501 draft=...` と出す（人に要求する形と揃えるため）。
# **読む側は `#` の有無どちらも受ける**（それ以前の文書も検査が走るように）。
for form in '- 501 draft=false 古い形式' '- #501 draft=false 新しい形式'; do
  FRM="$WS/.oe/handoff-form.md"
  {
    printf '%s\n' '<!-- oe-handoff:machine:begin -->'
    printf '%s\n' '## 観測できる状態'
    # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
    printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
    # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
    printf -- '- 前任の session_id: `sid-pred`\n'
    # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
    printf -- '- 前任のペインの pid: `910`\n'
    printf '%s\n' '### open PR'
    printf '%s\n' "$form"
    printf '%s\n' '<!-- oe-handoff:machine:end -->'
    printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
    printf '%s\n' '| 項目 | 処分 | 補足 |'
    printf '%s\n' '| --- | --- | --- |'
    printf '%s\n' '| PR #392 | 済んだ | 501 の処分は書いていない |'
    printf '\n%s\n' '## owner が下した裁定'
  } > "$FRM"
  set +e
  out39="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$FRM" 2>&1)"; rc39=$?
  set -e
  ck  "[$form] 非0 で終わる"     "1" "$rc39"
  ckc "[$form] 欠落を見つける"   "$out39" "機械の節が挙げた PR #501 に処分が付いていない"
done

echo "[40] 申告の表: 先頭パイプを省略した行も読む（未処分を黙って落とさない）"
# GFM は先頭のパイプ省略を許す。`^[ \t]*\|` で行を判定していたので、**省略した行が数から
# 消え、未処分の項目を見逃した**（実装SO の指摘・2026-09-13）。
NOLEAD="$WS/.oe/handoff-nolead.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->'
  printf '%s\n' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任の session_id: `sid-pred`\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペインの pid: `910`\n'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |'
  printf '%s\n' '| --- | --- | --- |'
  printf '%s\n' '| PR #392 | 済んだ | 通常の行 |'
  printf '%s\n' 'PR #501 |  | 先頭パイプ省略・処分が空'
  printf '\n%s\n' '## owner が下した裁定'
} > "$NOLEAD"
set +e
out40="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$NOLEAD" --execute 2>&1)"; rc40=$?
set -e
ck  "非0 で終わる"              "1" "$rc40"
ckc "省略形の行を拾う"          "$out40" "PR #501 → 処分[]"
ckc "処分が無いと言う"          "$out40" "処分が付いていない（または語彙の外の）項目がある"
ck  "前任は生きたまま"          "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo "[41] 申告の表: コードブロック内の疑似行を実データとして受理しない"
# 4空白以上の字下げはコードブロックである。表の行として受理すると、**説明のために書いた
# 見本が申告として数えられる**（誤受理）。
CBLK="$WS/.oe/handoff-codeblock.md"
sed 's/^PR #501 |  | 先頭パイプ省略・処分が空$/    | にせの行 | 済んだ | コードブロックの中 |/' "$NOLEAD" > "$CBLK"
set +e
out41="$("$OE_HANDOFF" retire -w "$WS" --board "$BOARD" --handoff "$CBLK" 2>&1)"; rc41=$?
set -e
ck  "下見は 0 で終わる"         "0" "$rc41"
ckc "件数は1件（にせの行を数えない）" "$out41" "申告の全項目に処分が付いている（1 件）"
nck "にせの行を拾わない"        "$out41" "にせの行"

echo "[42] worktree の照合が部分一致で通らない"
# `grep -F` だったので、basename が別の項目の部分文字列であるだけで一致した
# （例: basename `501` が `PR #501` の行に当たる・実装SO の指摘・2026-09-13）。
# worktree を1つ足した repo を作り、申告にはその basename を含む**別の項目**だけを書く。
WTR="$_TMP_DIR/ws-wt"; mkdir -p "$WTR/.oe"
git -C "$WTR" init -q 2>/dev/null || true
git -C "$WTR" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null || true
git -C "$WTR" worktree add -q -b side "$_TMP_DIR/501" 2>/dev/null || true
wt_base="$(git -C "$WTR" worktree list | awk 'NR>1 {print $1}' | head -1 | xargs basename 2>/dev/null)"
ck "fixture の worktree の basename" "501" "$wt_base"
WTH="$WTR/.oe/handoff.md"
{
  printf '%s\n' '<!-- oe-handoff:machine:begin -->'
  printf '%s\n' '## 観測できる状態'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペイン: `%%10`（tmux server pid `900`）\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任の session_id: `sid-pred`\n'
  # shellcheck disable=SC2016  # backtick は引き継ぎ文書の Markdown 記法
  printf -- '- 前任のペインの pid: `910`\n'
  printf '%s\n' '<!-- oe-handoff:machine:end -->'
  printf '\n%s\n\n' '## 前任の自己申告（人が書く）'
  printf '%s\n' '| 項目 | 処分 | 補足 |'
  printf '%s\n' '| --- | --- | --- |'
  printf '%s\n' '| PR #501 | 済んだ | worktree の処分ではない |'
  printf '\n%s\n' '## owner が下した裁定'
} > "$WTH"
set +e
out42="$("$OE_HANDOFF" retire -w "$WTR" --board "$BOARD" --handoff "$WTH" --execute 2>&1)"; rc42=$?
set -e
ck  "非0 で終わる"              "1" "$rc42"
ckc "worktree の処分が無いと言う" "$out42" "main 以外の worktree に処分が付いていない（501）"
ck  "前任は生きたまま"          "1" "$(grep -cxF -- '%10' "$ALIVE" | tr -d ' ')"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
