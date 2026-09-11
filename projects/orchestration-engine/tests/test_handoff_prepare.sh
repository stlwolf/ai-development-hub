#!/usr/bin/env bash
set -euo pipefail

# test_handoff_prepare.sh — bin/oe-handoff prepare と lib/handoff-state.sh の検証（#390 PR-1）
#
# 見るもの:
#   (1) 機械の節だけが毎回上書きされ、人が書いた内容は保たれる（目印も重複しない）
#   (2) pane から session_id を引く逆引きが、曖昧なときに unknown へ倒れる
#       （sidecar は掃除されないので同じ pane 番号の別世代が貯まる。誤った値を書くくらいなら書かない）
#   (3) 生きた委譲子の数え方の錨が「引数の pane」であり「自ペイン」ではない
#       （自ペインで数えると後継のセッションでは常に0件になり、fail-closed が反転する）
#   (4) prepare が引き継ぎ文書以外を書き換えない（board・登記・イベントログの mtime が動かない）
#
# fixture は runtime に printf / jq で作る（生の制御文字をソースへ置かない）。
# liveness は PATH-stub の tmux で固定する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_HANDOFF="$PROJECT_DIR/bin/oe-handoff"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

# --- stub: tmux（%10 と %11 だけ alive）/ gh（open PR なし）---
STUB_BIN="$_TMP_DIR/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "list-panes" ]; then printf '%%10\n%%11\n'; exit 0; fi
exit 0
EOF
chmod +x "$STUB_BIN/tmux"
cat > "$STUB_BIN/gh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$STUB_BIN/gh"
export PATH="$STUB_BIN:$PATH"

PASS=0; FAIL=0
ck()  { if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }

# --- 置き場 ---
HB="$_TMP_DIR/heartbeat"; mkdir -p "$HB"
REG="$_TMP_DIR/registry";  mkdir -p "$REG"
WS="$_TMP_DIR/ws";         mkdir -p "$WS/.oe"
export OE_HEARTBEAT_DIR="$HB"
export OE_DELEGATE_STATE_DIR="$REG"
export OE_HS_SERVER_PID="900"
TR="$_TMP_DIR/transcripts"; mkdir -p "$TR"
export OE_TRANSCRIPT_DIR="$TR"
NOW_EPOCH="$(date +%s)"
export OE_HS_NOW_EPOCH="$NOW_EPOCH"

mk_beat() { # mk_beat <sid> <pane> <server_pid> <ctx> [age_sec]
  # ts は「いまから <age_sec> 秒前」。古い固定値を使うと、鮮度の欠陥をテストが固定してしまう。
  local ts=$(( NOW_EPOCH - ${5:-0} ))
  jq -cn --arg p "$2" --arg s "$3" --argjson c "$4" --argjson t "$ts" \
    '{ts:$t, context_pct:$c, pane:$p, server_pid:$s}' > "$HB/$1.json"
}
reg_key() { # reg_key <pane> — 実物と同じキー（"<server_pid>_<pane>" の非英数を _ に）
  printf '%s' "900_$1" | tr -c 'A-Za-z0-9' '_'
}
mk_child() { # mk_child <pane> <parent_pane> <label> [server_pid]
  local key
  if [ -n "${4:-}" ]; then key="$(printf '%s' "$4_$1" | tr -c 'A-Za-z0-9' '_')"; else key="$(reg_key "$1")"; fi
  jq -cn --arg p "$1" --arg par "$2" --arg l "$3" \
    '{pane:$p, label:$l, workspace:"", parent_pane:$par, role:"child"}' > "$REG/${key}.json"
}
mk_transcript() { # mk_transcript <sid> [age_sec]
  # mtime の設定は perl の utime で行う。`date -r <epoch>` は BSD 専用（GNU では
  # 第1引数がファイル名）なので、GNU 環境では黙って現在時刻へ落ちて鮮度テストが
  # 何も検証しなくなる。
  local t=$(( NOW_EPOCH - ${2:-0} ))
  printf '{"type":"x"}\n' > "$TR/$1.jsonl"
  perl -e 'utime $ARGV[0], $ARGV[0], $ARGV[1] or die' "$t" "$TR/$1.jsonl"
}

source "$PROJECT_DIR/lib/handoff-state.sh"

echo "[1] session_id 逆引き: server_pid が一致する sidecar 1件 + transcript が在る → その値"
mk_beat "sid-aaa" "%10" "900" 42
mk_transcript "sid-aaa" 0
ck "一致1件で session_id を返す" "sid-aaa" "$(oe_hs_session_for_pane '%10')"
ck "その session の context% を返す" "42" "$(oe_hs_context_for_session 'sid-aaa')"

echo "[2] pane 再利用: 同じ pane に複数の世代が貯まっていても、いちばん新しい拍動を採る"
mk_beat "sid-bbb" "%10" "900" 77 7200
mk_transcript "sid-bbb" 7200
ck "古いほうは採らない" "sid-aaa" "$(oe_hs_session_for_pane '%10')"
# 実測で最も多い pane には7件貯まっていた。件数で unknown にすると、その pane では
# 交代が永久に始められない（実装SO の指摘）。件数ではなく新しさで決める。
mk_beat "sid-c1" "%10" "900" 10 9000
mk_beat "sid-c2" "%10" "900" 11 9100
mk_beat "sid-c3" "%10" "900" 12 9200
mk_beat "sid-c4" "%10" "900" 13 9300
mk_beat "sid-c5" "%10" "900" 14 9400
ck "7件貯まっても unknown にしない" "sid-aaa" "$(oe_hs_session_for_pane '%10')"
rm -f "$HB/sid-bbb.json" "$TR/sid-bbb.jsonl" "$HB"/sid-c?.json

echo "[3] server_pid が違う sidecar しか無い → unknown（別世代を掴まない）"
mk_beat "sid-old" "%11" "111" 90
ck "server_pid 不一致は採らない" "unknown" "$(oe_hs_session_for_pane '%11')"

echo "[4] sidecar が1件も無い pane → unknown"
ck "0 件は unknown" "unknown" "$(oe_hs_session_for_pane '%99')"

echo "[5] 委譲子の数え方の錨は引数の pane（自ペインではない）"
mk_child "%11" "%10" "#123 child-of-10"
ck "%10 の子を数える" "1" "$(oe_hs_children_of '%10' | grep -c '^')"
ck "%11 を親にすると0件" "0" "$(oe_hs_children_of '%11' | grep -c '^' || true)"
ckc "子の pane と label を返す" "$(oe_hs_children_of '%10')" "%11 #123 child-of-10"

echo "[6] 死んだ子は数えない（tmux に居ない pane）"
mk_child "%77" "%10" "#124 dead-child"
ck "生存する子だけ数える" "1" "$(oe_hs_children_of '%10' | grep -c '^')"
rm -f "$REG/$(reg_key '%77').json"

echo "[7] prepare: 文書を作り、機械の節を埋める"
OUT="$WS/.oe/handoff.md"
out1="$("$OE_HANDOFF" prepare -w "$WS" --out "$OUT" --predecessor '%10' 2>&1)" || true
ckc "作成を報告する" "$out1" "引き継ぎ文書を作りました"
ckc "生きた委譲子の件数を出す" "$out1" "生きた委譲子 1 件"
ckc "子が居るあいだは交代できないと言う" "$out1" "まだ交代できません"
ckc "機械の節に見張りの節がある" "$(cat "$OUT")" "### 常駐の見張り"

echo "[8] prepare: 人が書いた内容は保たれ、目印は重複しない"
printf '\n人の節の目印 XYZ789\n' >> "$OUT"
"$OE_HANDOFF" prepare -w "$WS" --out "$OUT" --predecessor '%10' >/dev/null 2>&1 || true
ck "machine:begin は1つ" "1" "$(grep -c 'oe-handoff:machine:begin' "$OUT" | tr -d ' ')"
ck "machine:end は1つ" "1" "$(grep -c 'oe-handoff:machine:end' "$OUT" | tr -d ' ')"
ck "人が書いた行が残る" "1" "$(grep -c '人の節の目印 XYZ789' "$OUT" | tr -d ' ')"
ck "人の節の見出しが残る" "1" "$(grep -c '^## 渡らないもの' "$OUT" | tr -d ' ')"

echo "[9] prepare: 引き継ぎ文書以外を書き換えない"
BOARD="$WS/.oe/board.md"
# shellcheck disable=SC2016  # backtick は board の Markdown 記法で、展開させない
printf '# board\n\n鮮度: 2026-09-11 / 現統括: pane `%%10`\n' > "$BOARD"
EVENTS="$_TMP_DIR/oe-events.jsonl"; printf '{"type":"child_spawned"}\n' > "$EVENTS"
b_before="$(stat -f %m "$BOARD" 2>/dev/null || stat -c %Y "$BOARD")"
e_before="$(stat -f %m "$EVENTS" 2>/dev/null || stat -c %Y "$EVENTS")"
REG_FILE="$REG/$(reg_key '%11').json"
r_before="$(stat -f %m "$REG_FILE" 2>/dev/null || stat -c %Y "$REG_FILE")"
OE_BOARD_FILE="$BOARD" OE_EVENT_DIR="$_TMP_DIR" \
  "$OE_HANDOFF" prepare -w "$WS" --out "$OUT" --predecessor '%10' >/dev/null 2>&1 || true
ck "board の mtime が動かない"   "$b_before" "$(stat -f %m "$BOARD" 2>/dev/null || stat -c %Y "$BOARD")"
ck "イベントログの mtime が動かない" "$e_before" "$(stat -f %m "$EVENTS" 2>/dev/null || stat -c %Y "$EVENTS")"
ck "登記の mtime が動かない"     "$r_before" "$(stat -f %m "$REG_FILE" 2>/dev/null || stat -c %Y "$REG_FILE")"

echo "[10] session_id が引けないときは、停止できないと書く"
OUT2="$WS/.oe/handoff2.md"
out2="$("$OE_HANDOFF" prepare -w "$WS" --out "$OUT2" --predecessor '%99' 2>&1)" || true
ckc "画面で注意する" "$out2" "停止が取り消せません"
ckc "文書にも書く" "$(cat "$OUT2")" "この状態では前任を"

echo "[11] 呼び方の誤りと目印の欠落"
set +e
"$OE_HANDOFF" bogus >/dev/null 2>&1; rc_bogus=$?
"$OE_HANDOFF" >/dev/null 2>&1; rc_none=$?
"$OE_HANDOFF" -h >/dev/null 2>&1; rc_help=$?
printf '# 目印を消した文書\n' > "$WS/.oe/broken.md"
"$OE_HANDOFF" prepare -w "$WS" --out "$WS/.oe/broken.md" --predecessor '%10' >/dev/null 2>&1; rc_broken=$?
set -e
ck "未知の subcommand は 2" "2" "$rc_bogus"
ck "subcommand 無しは 2"    "2" "$rc_none"
ck "-h は 0"                "0" "$rc_help"
ck "目印の無い文書は 2"      "2" "$rc_broken"

echo "[12] 子を数えられないときは 0 件に化かさない（fail-closed のまま）"
OUT3="$WS/.oe/handoff3.md"
out3="$(OE_DELEGATE_STATE_DIR="" "$OE_HANDOFF" prepare -w "$WS" --out "$OUT3" --predecessor '%10' 2>&1)" || true
ckc "件数を unknown と言う" "$out3" "生きた委譲子 unknown 件"
ckc "数えられないうちは交代させない" "$out3" "まだ交代できません"
ckc "文書にも数えられなかったと書く" "$(cat "$OUT3")" "数えられませんでした"

echo "[13] upstream の無い枝で「未 push 0 件」と言わない"
NOUP="$_TMP_DIR/noup"; mkdir -p "$NOUP"
git -C "$NOUP" init -q 2>/dev/null || true
git -C "$NOUP" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init 2>/dev/null || true
ckc "unknown と言う" "$(oe_hs_repo_state "$NOUP")" "unpushed=unknown(no-upstream)"

echo "[14] 拍動だけでは足りない: transcript が無ければ unknown"
mk_beat "sid-nots" "%11" "900" 30
ck "transcript 不在は unknown" "unknown" "$(oe_hs_session_for_pane '%11')"

echo "[15] transcript が古ければ unknown（pane 再利用で残った旧世代を掴まない）"
mk_transcript "sid-nots" 999999
ck "古い transcript は採らない" "unknown" "$(OE_HS_RESUME_MAX_AGE_SEC=3600 oe_hs_session_for_pane '%11')"
ck "窓を広げれば採る" "sid-nots" "$(OE_HS_RESUME_MAX_AGE_SEC=99999999 OE_HS_BEAT_MAX_AGE_SEC=99999999 oe_hs_session_for_pane '%11')"
rm -f "$HB/sid-nots.json" "$TR/sid-nots.jsonl"

echo "[16] 旧 server の登記は子に数えない（pane 番号が再利用されている）"
mk_child "%11" "%10" "#999 old-server-child" "111"
ck "現 server の分だけ数える" "1" "$(oe_hs_children_of '%10' | grep -c '^')"
rm -f "$REG/$(printf '%s' '111_%11' | tr -c 'A-Za-z0-9' '_').json"

echo "[17] tmux が引けないときは「子0件」に化かさない"
NOTMUX="$_TMP_DIR/notmux"; mkdir -p "$NOTMUX"
set +e
( PATH="$NOTMUX:/usr/bin:/bin" ; export PATH ; oe_hs_children_of '%10' >/dev/null 2>&1 ) ; rc_notmux=$?
set -e
ck "tmux 不在では失敗を返す（0 件としない）" "2" "$rc_notmux"

echo "[18] 目印が壊れている文書は、書き換える前に落とす"
OUT4="$WS/.oe/handoff4.md"
{ printf '%s\n' '<!-- oe-handoff:machine:end -->'; printf '%s\n' '人の節 KEEPME'; printf '%s\n' '<!-- oe-handoff:machine:begin -->'; } > "$OUT4"
before4="$(cat "$OUT4")"
set +e
"$OE_HANDOFF" prepare -w "$WS" --out "$OUT4" --predecessor '%10' >/dev/null 2>&1; rc_order=$?
set -e
ck "順序が逆なら 2 で落ちる" "2" "$rc_order"
ck "文書を壊さない" "$before4" "$(cat "$OUT4")"
OUT5="$WS/.oe/handoff5.md"
{ printf '%s\n' '<!-- oe-handoff:machine:begin -->'; printf '%s\n' '<!-- oe-handoff:machine:begin -->'; printf '%s\n' '<!-- oe-handoff:machine:end -->'; } > "$OUT5"
before5="$(cat "$OUT5")"
set +e
"$OE_HANDOFF" prepare -w "$WS" --out "$OUT5" --predecessor '%10' >/dev/null 2>&1; rc_dup=$?
set -e
ck "目印が重複していたら 2 で落ちる" "2" "$rc_dup"
ck "重複でも文書を壊さない" "$before5" "$(cat "$OUT5")"

echo "[19] repo 節は枝の名前を名乗り、open PR は workspace の中で引く"
ckc "branch= を出す" "$(oe_hs_repo_state "$NOUP")" "branch="
ckc "workspace が無ければ unknown" "$(oe_hs_open_prs "$_TMP_DIR/nonexistent")" "unknown workspace-not-found"

echo "[20] 拍動が古ければ unknown（pane がすぐ再利用され、新セッションがまだ拍動を書いていない場合）"
mk_beat "sid-oldbeat" "%11" "900" 55 999999
mk_transcript "sid-oldbeat" 0
ck "古い拍動は採らない" "unknown" "$(oe_hs_session_for_pane '%11')"
ck "窓を広げれば採る" "sid-oldbeat" "$(OE_HS_BEAT_MAX_AGE_SEC=99999999 oe_hs_session_for_pane '%11')"
rm -f "$HB/sid-oldbeat.json" "$TR/sid-oldbeat.jsonl"

echo "[21] 壊れた登記を「子が居ない」に畳まない"
printf 'not json at all\n' > "$REG/$(reg_key '%12').json"
set +e
oe_hs_children_of '%10' >/dev/null 2>&1; rc_broken_reg=$?
set -e
ck "読めない登記があれば失敗を返す" "2" "$rc_broken_reg"
rm -f "$REG/$(reg_key '%12').json"

echo "[22] session_id が引けないときは「次は start」と言わない（子のゲートと対称）"
OUT6="$WS/.oe/handoff6.md"
out6="$("$OE_HANDOFF" prepare -w "$WS" --out "$OUT6" --predecessor '%11' 2>&1)" || true
ckc "まだ交代できないと言う" "$out6" "まだ交代できません"
if printf '%s' "$out6" | grep -qF 'oe-handoff start で後継'; then
  echo "  FAIL: start を勧めない"; FAIL=$((FAIL+1))
else
  echo "  PASS: start を勧めない"; PASS=$((PASS+1))
fi

echo "[23] 一時ファイルを残さない"
ck "tmp が残らない"     "0" "$(find "$WS/.oe" -name '*.tmp.*' 2>/dev/null | grep -c '^' | tr -d ' ')"
ck "staging が残らない" "0" "$(find "$WS/.oe" -name '*.machine.*' 2>/dev/null | grep -c '^' | tr -d ' ')"

echo "[24] 目印の判定は検査と置換で同じ規則（空白が付いた目印を受理しない）"
OUT7="$WS/.oe/handoff7.md"
{ printf '%s\n' '<!-- oe-handoff:machine:begin -->'; printf '%s\n' '人の節 KEEP7'; printf ' %s\n' '<!-- oe-handoff:machine:end -->'; } > "$OUT7"
before7="$(cat "$OUT7")"
set +e
"$OE_HANDOFF" prepare -w "$WS" --out "$OUT7" --predecessor '%10' >/dev/null 2>&1; rc_sp=$?
set -e
ck "空白付きの目印は通さない" "2" "$rc_sp"
ck "人の節を消さない" "$before7" "$(cat "$OUT7")"

echo "[25] 引き継ぎ文書の権限を umask 任せにしない"
OUT8="$WS/.oe/handoff8.md"
( umask 022; "$OE_HANDOFF" prepare -w "$WS" --out "$OUT8" --predecessor '%10' >/dev/null 2>&1 ) || true
ck "新規作成は 600" "600" "$(stat -f %Lp "$OUT8" 2>/dev/null || stat -c %a "$OUT8")"

echo "[26] 拍動の古さを文書に出す（人が判断できるように）"
ckc "古さの行がある" "$(cat "$OUT")" "前任の拍動の古さ"

echo "[27] 拍動の ts が同率なら「決められない」として unknown"
mk_beat "sid-t1" "%13" "900" 10 100
mk_beat "sid-t2" "%13" "900" 11 100
mk_transcript "sid-t1" 0; mk_transcript "sid-t2" 0
ck "同率は曖昧扱い" "unknown" "$(oe_hs_session_for_pane '%13')"
rm -f "$HB/sid-t1.json" "$HB/sid-t2.json" "$TR/sid-t1.jsonl" "$TR/sid-t2.jsonl"

echo "[28] 登記の置き場が読めないときは「子0件」にしない"
UNREAD="$_TMP_DIR/unreadable"; mkdir -p "$UNREAD"; chmod 000 "$UNREAD"
set +e
( OE_DELEGATE_STATE_DIR="$UNREAD" oe_hs_children_of '%10' >/dev/null 2>&1 ); rc_unread=$?
set -e
chmod 755 "$UNREAD"
ck "読めない置き場は失敗を返す" "2" "$rc_unread"

echo "[29] 必須の項目が欠けた登記も「数えられない」扱い"
printf '{"label":"no-pane","parent_pane":"%%10"}\n' > "$REG/$(reg_key '%14').json"
set +e
oe_hs_children_of '%10' >/dev/null 2>&1; rc_missing=$?
set -e
ck "pane が無い登記は失敗を返す" "2" "$rc_missing"
rm -f "$REG/$(reg_key '%14').json"

echo "[30] transcript の置き場は既存のノブ（OE_TRANSCRIPT_DIR）で動く"
ALT_TR="$_TMP_DIR/alt-transcripts"; mkdir -p "$ALT_TR"
mk_beat "sid-alt" "%15" "900" 20 10
printf '{"type":"x"}\n' > "$ALT_TR/sid-alt.jsonl"
perl -e 'utime $ARGV[0], $ARGV[0], $ARGV[1] or die' "$NOW_EPOCH" "$ALT_TR/sid-alt.jsonl"
ck "別の置き場を指せば引ける" "sid-alt" "$(OE_TRANSCRIPT_DIR="$ALT_TR" oe_hs_session_for_pane '%15')"
ck "既定の置き場には無いので unknown" "unknown" "$(oe_hs_session_for_pane '%15')"
rm -f "$HB/sid-alt.json"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
