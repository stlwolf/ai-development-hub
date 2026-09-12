#!/usr/bin/env bash
set -euo pipefail

# test_handoff_take.sh — oe-handoff take / start と lib/seat.sh の検証（#390 PR-2）
#
# **実物には一切触れない。** board も登記も拍動も、すべて一時ディレクトリの fixture で、
# 外部 verb（oe-register / oe-selfcheck / oe-send / tmux / claude）は PATH でなく
# OE_HANDOFF_* のノブで stub に差し替える。稼働中の統括の席を動かさないための境界である。
#
# 見るもの:
#   (1) 席の張替が DJ-8 の不変条件を満たす（最後の marker より後ろで後継の pane が前任より先）
#   (2) 前提を満たさないときは **board を1バイトも書き換えない**（fail-closed）
#   (3) 何度実行しても同じ結果になる
#   (4) 途中で落ちたとき、何が済んで何が済んでいないかが出る
#   (5) start が起こすペインが登記の子にならず、PARENT_TMUX_PANE も渡らない
#   (6) kickoff が起動より後に出る

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

# --- 置き場（すべて一時） ---
HB="$_TMP_DIR/heartbeat"; REG="$_TMP_DIR/registry"; TR="$_TMP_DIR/transcripts"
EV="$_TMP_DIR/events";    WS="$_TMP_DIR/ws";        STUB="$_TMP_DIR/stub"
mkdir -p "$HB" "$REG" "$TR" "$EV" "$WS/.oe" "$STUB"
export OE_HEARTBEAT_DIR="$HB" OE_DELEGATE_STATE_DIR="$REG" OE_TRANSCRIPT_DIR="$TR"
export OE_EVENT_DIR="$EV" OE_HS_SERVER_PID="900"
NOW_EPOCH="$(date +%s)"; export OE_HS_NOW_EPOCH="$NOW_EPOCH"

# --- stub（外部 verb は実物を呼ばない） ---
CALL_LOG="$_TMP_DIR/calls.log"; : > "$CALL_LOG"
cat > "$STUB/register" <<EOF
#!/usr/bin/env bash
printf 'register %s\n' "\$*" >> "$CALL_LOG"
[ -f "$_TMP_DIR/register_fails" ] && exit 1
exit 0
EOF
cat > "$STUB/selfcheck" <<'EOF'
#!/usr/bin/env bash
printf '{"checks":[{"check":"watchdog-freshness","verdict":"ok","detail":"最終走査は 100 秒前"}]}\n'
exit 1
EOF
cat > "$STUB/send" <<EOF
#!/usr/bin/env bash
printf 'send %s\n' "\$*" >> "$CALL_LOG"
exit 0
EOF
cat > "$STUB/tmux" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "split-window" ]; then printf 'split %s\n' "\$*" >> "$CALL_LOG"; printf '%%77\n'; exit 0; fi
if [ "\${1:-}" = "list-panes" ]; then printf '%%10\n%%11\n%%12\n%%77\n'; exit 0; fi
exit 0
EOF
chmod +x "$STUB"/*
export OE_HANDOFF_REGISTER="$STUB/register" OE_HANDOFF_SELFCHECK="$STUB/selfcheck"
export OE_HANDOFF_SEND="$STUB/send" OE_HANDOFF_TMUX="$STUB/tmux" OE_HANDOFF_CLAUDE="claude"
export OE_HANDOFF_START_WAIT=1 OE_HANDOFF_START_SETTLE=0
export PATH="$STUB:$PATH"

mk_beat() { # <sid> <pane> <ctx> [age]
  jq -cn --arg p "$2" --argjson c "$3" --argjson t "$(( NOW_EPOCH - ${4:-0} ))" \
    '{ts:$t, context_pct:$c, pane:$p, server_pid:"900"}' > "$HB/$1.json"
  printf '{"x":1}\n' > "$TR/$1.jsonl"
  perl -e 'utime $ARGV[0], $ARGV[0], $ARGV[1] or die' "$NOW_EPOCH" "$TR/$1.jsonl"
}
mk_child() { # <pane> <parent>
  local key; key="$(printf '%s' "900_$1" | tr -c 'A-Za-z0-9' '_')"
  jq -cn --arg p "$1" --arg par "$2" '{pane:$p, label:"child", workspace:"", parent_pane:$par, role:"child"}' \
    > "$REG/${key}.json"
}
mk_board() { # <path> — 実 board と同じ freeform 形（1行に長い散文・pane が複数）
  # shellcheck disable=SC2016  # backtick は board の Markdown 記法で、展開させない
  printf '# START HERE\n\n' > "$1"
  # shellcheck disable=SC2016  # backtick は board の Markdown 記法で、展開させない
  printf '鮮度: 2026-01-01 / 現統括: pane `%%10`（統括**14代目**・2026-01-01 着任。前任 13代目 `%%9` は交代済み）/ succession: **完了**（以前の系譜: 12代目 `%%8` / 11代目 `%%7`）\n' >> "$1"
  # shellcheck disable=SC2016  # backtick は board の Markdown 記法で、展開させない
  printf '\n## in-flight（統括は 14代目 `%%10`）\n\n本文は触られてはならない。\n' >> "$1"
}
mk_handoff() { printf '%s\n' '<!-- oe-handoff:machine:begin -->' '## 観測できる状態' '<!-- oe-handoff:machine:end -->' '人の節' > "$1"; }

# fixture の初期状態
BOARD="$WS/.oe/board.md"; HANDOFF="$WS/.oe/handoff.md"
mk_board "$BOARD"; mk_handoff "$HANDOFF"
mk_beat "sid-pred" "%10" 90 60
export TMUX_PANE="%11"

echo "[1] 席の張替と検算（正常系）"
out="$("$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --reason context_exhaustion 2>&1)" || true
ckc "張り替えたと言う"     "$out" "board の宣言を自分（%11）へ張り替えた"
ckc "検算したと言う"       "$out" "読み直して自分が返る"
ckc "委譲子0件を確かめた"  "$out" "生きた委譲子が居ないことを確かめた"
ckc "session_id を確かめた" "$out" "前任の session_id を確かめた"
ckc "自己登記した"         "$out" "root として登記した"
ckc "登記の呼び出しに --force がある" "$(cat "$CALL_LOG")" "register root --label cockpit --force"

echo "[2] DJ-8 の不変条件（後継の pane が前任より先に来る）"
source "$PROJECT_DIR/lib/seat.sh"
ck "宣言は後継を指す" "%11" "$(oe_seat_resolve "$BOARD")"
line="$(grep -m1 -- '現統括:' "$BOARD")"
ck "最後の marker の後ろで後継が先頭" "%11" "$(printf '%s' "${line##*現統括}" | grep -oE '%[0-9]+' | head -1)"
# shellcheck disable=SC2016  # backtick は board の Markdown 記法で、展開させない
ckc "前任が併記されている" "$line" '前任 `%10` は退任申告済み・停止待ち'
ckc "鮮度が更新されている" "$line" "鮮度: $(date '+%Y-%m-%d')"

echo "[3] 系譜の散文と他の行を壊さない"
ckc "系譜が残る"       "$(cat "$BOARD")" "以前の系譜: 12代目"
ckc "別の行が残る"     "$(cat "$BOARD")" "本文は触られてはならない"
ck  "行数が変わらない" "7" "$(grep -c '' "$BOARD" | tr -d ' ')"

echo "[4] 交代イベントが記録され、読み直して確かめている"
ckc "イベントを記録したと言う" "$out" "交代イベントを記録した"
ck  "ログに1行ある" "1" "$(grep -c 'supervisor_succession' "$EV/oe-events.jsonl" | tr -d ' ')"
ev="$(grep 'supervisor_succession' "$EV/oe-events.jsonl" | tail -1)"
ck "from は前任"     "%10" "$(printf '%s' "$ev" | jq -r '.from.pane')"
ck "to は後継"       "%11" "$(printf '%s' "$ev" | jq -r '.to.pane')"
ck "世代が入る"      "15"  "$(printf '%s' "$ev" | jq -r '.generation')"
ck "理由が入る"      "context_exhaustion" "$(printf '%s' "$ev" | jq -r '.reason')"
ck "server pid が入る" "900" "$(printf '%s' "$ev" | jq -r '.server_pid')"
ck "role は空（親子にしない）" "" "$(printf '%s' "$ev" | jq -r '.from.role + .to.role')"

echo "[5] 何度実行しても同じ結果になる（2回目は成功で終わる）"
before="$(cat "$BOARD")"
set +e
out2="$("$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1)"; rc2=$?
set -e
ck  "2回目は 0 で終わる"          "0" "$rc2"
ckc "既に自分を指していると言う"  "$out2" "席は既に自分"
ck  "board を書き換えない"        "$before" "$(cat "$BOARD")"
ck  "イベントを二重に書かない"    "1" "$(grep -c 'supervisor_succession' "$EV/oe-events.jsonl" | tr -d ' ')"

echo "[6] 生きた委譲子が居るときは席を動かさない"
mk_board "$BOARD"; before="$(cat "$BOARD")"
mk_child "%12" "%10"
set +e
out3="$("$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1)"; rc3=$?
set -e
ck  "非0 で終わる"        "1" "$rc3"
ckc "理由を言う"          "$out3" "生きた委譲子が 1 件"
ckc "済んでいないと言う"  "$out3" "生きた委譲子が居るので席を動かしていない"
ck  "board を書き換えない" "$before" "$(cat "$BOARD")"
rm -f "$REG"/*.json

echo "[7] 委譲子を数えられないときも席を動かさない"
mk_board "$BOARD"; before="$(cat "$BOARD")"
set +e
out4="$(OE_DELEGATE_STATE_DIR="" "$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1)"; rc4=$?
set -e
ck  "非0 で終わる"         "1" "$rc4"
ckc "数えられないと言う"   "$out4" "数えられませんでした"
ck  "board を書き換えない"  "$before" "$(cat "$BOARD")"

echo "[8] session_id が引けないときは席を動かさない"
mk_board "$BOARD"; before="$(cat "$BOARD")"
set +e
out5="$(OE_HEARTBEAT_DIR="$_TMP_DIR/empty-hb" "$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1)"; rc5=$?
set -e
ck  "非0 で終わる"         "1" "$rc5"
ckc "理由を言う"           "$out5" "session_id が引けません"
ck  "board を書き換えない"  "$before" "$(cat "$BOARD")"

echo "[9] 引き継ぎ文書が無いときは席を動かさない"
mk_board "$BOARD"; before="$(cat "$BOARD")"
set +e
out6="$("$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$WS/.oe/nope.md" 2>&1)"; rc6=$?
set -e
ck  "非0 で終わる"         "1" "$rc6"
ckc "理由を言う"           "$out6" "引き継ぎ文書がありません"
ck  "board を書き換えない"  "$before" "$(cat "$BOARD")"

echo "[10] 自己登記に失敗したら、そこで止めて board を触らない"
mk_board "$BOARD"; before="$(cat "$BOARD")"
touch "$_TMP_DIR/register_fails"
set +e
out7="$("$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1)"; rc7=$?
set -e
rm -f "$_TMP_DIR/register_fails"
ck  "非0 で終わる"          "1" "$rc7"
ckc "済んでいないことを出す" "$out7" "自己登記に失敗した"
ck  "board を書き換えない"   "$before" "$(cat "$BOARD")"

echo "[11] oe-selfcheck の終了コードで判定しない（stub は常に 1 を返す）"
mk_board "$BOARD"
out8="$("$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1)" || true
ckc "見張りの行を読めている" "$out8" "watchdog-freshness）: ok"

echo "[12] 世代が分からないときはイベントを書かない（0 を書かない）"
mk_board "$BOARD"
perl -i -pe 's/統括\*\*14代目\*\*/統括/' "$BOARD"
rm -f "$EV/oe-events.jsonl"
out9="$("$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1)" || true
ckc "席は取れている"           "$out9" "張り替えた"
ckc "イベントは書いていないと言う" "$out9" "世代が分からない"
ck  "ログに交代イベントが無い"   "0" "$(grep -c 'supervisor_succession' "$EV/oe-events.jsonl" 2>/dev/null | tr -d ' ' || echo 0)"

echo "[13] start: 後継を登記の子にせず、PARENT_TMUX_PANE も渡さない"
: > "$CALL_LOG"; rm -f "$REG"/*.json
out10="$("$OE_HANDOFF" start -w "$WS" --handoff "$HANDOFF" 2>&1)" || true
ckc "ペインを起こしたと言う"       "$out10" "後継のペインを起こしました"
ckc "split に claude がある"       "$(cat "$CALL_LOG")" "claude"
nck "PARENT_TMUX_PANE を渡さない"  "$(cat "$CALL_LOG")" "PARENT_TMUX_PANE"
nck "oe-delegate を使わない"       "$(cat "$CALL_LOG")" "delegate"
ck  "登記を作らない"               "0" "$(find "$REG" -name '*.json' | grep -c '^' | tr -d ' ')"

echo "[14] start: kickoff は起動より後に出る"
ck "split が先" "split" "$(awk 'NR==1{print $1}' "$CALL_LOG")"
ck "send が後"  "send"  "$(awk '/^send /{print $1; exit}' "$CALL_LOG")"
ckc "送ったのは引き継ぎ文書のパス" "$(cat "$CALL_LOG")" "$HANDOFF を読んで進めて。"

echo "[15] start: 引き継ぎ文書が無ければ起こさない"
: > "$CALL_LOG"
set +e
"$OE_HANDOFF" start -w "$WS" --handoff "$WS/.oe/nope.md" >/dev/null 2>&1; rc11=$?
set -e
ck "非0 で終わる" "1" "$rc11"
ck "ペインを起こしていない" "0" "$(grep -c '^split' "$CALL_LOG" | tr -d ' ')"

echo "[16] seat: pane が無い board は張り替えない"
NOPANE="$_TMP_DIR/nopane.md"; printf '鮮度: 2026-01-01 / 現統括: まだ居ない\n' > "$NOPANE"
set +e
oe_seat_rewrite "$NOPANE" "%11" 2 "2026-01-01" ""; rc12=$?
set -e
ck "2 を返す" "2" "$rc12"
ck "中身が変わらない" "鮮度: 2026-01-01 / 現統括: まだ居ない" "$(cat "$NOPANE")"

echo "[17] 既に root として登記されているなら登記し直さない"
mk_board "$BOARD"
SELF_KEY="$(printf '%s' "900_%11" | tr -c 'A-Za-z0-9' '_')"
jq -cn '{pane:"%11", label:"cockpit", workspace:"", parent_pane:"", role:"child"}' > "$REG/${SELF_KEY}.json"
: > "$CALL_LOG"
out12="$("$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1)" || true
ckc "既に登記されていると言う" "$out12" "既に root として登記されている"
ck  "登記を呼んでいない"       "0" "$(grep -c '^register' "$CALL_LOG" | tr -d ' ')"
rm -f "$REG/${SELF_KEY}.json"

echo "[18] 見出しの printf が落ちない（format が - で始まらない）"
mk_board "$BOARD"
out13="$("$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" 2>&1)" || true
ckc "済んだことの見出しが出る"     "$out13" "--- 済んだこと ---"
ckc "済んでいないことの見出しが出る" "$out13" "--- 済んでいないこと ---"
nck "printf のエラーが出ない"      "$out13" "無効なオプション"

echo "[19] board の宣言と違う前任を渡されたら席を動かさない"
mk_board "$BOARD"; before="$(cat "$BOARD")"
set +e
out14="$("$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --predecessor '%99' 2>&1)"; rc14=$?
set -e
ck  "非0 で終わる"        "1" "$rc14"
ckc "食い違いを言う"      "$out14" "board の宣言（%10）と違います"
ck  "board を書き換えない" "$before" "$(cat "$BOARD")"

echo "[20] 検査から書き換えの間に席が動いていたら上書きしない（compare-and-swap）"
CAS="$_TMP_DIR/cas.md"; mk_board "$CAS"
set +e
oe_seat_rewrite "$CAS" "%11" 15 "2026-09-12" "%10" "%98"; rc15=$?
set -e
ck "期待と違えば 3 を返す" "3" "$rc15"
ck "board を書き換えない"  "$(cat "$CAS")" "$(cat "$CAS")"
ck "宣言は動いていない"    "%10" "$(oe_seat_resolve "$CAS")"

echo "[21] 交代イベントの読み直しが「過去の同じ行」で素通りしない"
mk_board "$BOARD"
: > "$EV/oe-events.jsonl"
jq -cn '{ts:"2026-01-01T00:00:00+00:00", type:"supervisor_succession", from:{pane:"%10",role:"",label:""}, to:{pane:"%11",role:"",label:""}, generation:15, reason:"planned", server_pid:"900"}' >> "$EV/oe-events.jsonl"
n_before="$(grep -c '' "$EV/oe-events.jsonl" | tr -d ' ')"
set +e
( OE_EVENT_LOG=0 "$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" > "$_TMP_DIR/out16.txt" 2>&1 )
set -e
ckc "書けていないと言う" "$(cat "$_TMP_DIR/out16.txt")" "交代イベントが記録されていない"
ck  "ログは増えていない"  "$n_before" "$(grep -c '' "$EV/oe-events.jsonl" | tr -d ' ')"

echo "[22] 別イベントの文字列に型名が入っていても拾わない"
: > "$EV/oe-events.jsonl"
jq -cn '{ts:"2026-01-01T00:00:00+00:00", type:"message_sent", from:{pane:"%10",role:"",label:""}, to:{pane:"%11",role:"",label:""}, preview:"supervisor_succession の話", delivery_signal:"none"}' >> "$EV/oe-events.jsonl"
set +e
( source "$PROJECT_DIR/lib/event-bus.sh"; oe_event_succession_recorded "%10" "%11" ) >/dev/null 2>&1; rc17=$?
set -e
ck "型で選ぶので拾わない" "1" "$rc17"

echo "[23] start: ペインが現れなければ送らない"
cat > "$STUB/tmux" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "split-window" ]; then printf 'split %s\n' "\$*" >> "$CALL_LOG"; printf '%%88\n'; exit 0; fi
if [ "\${1:-}" = "list-panes" ]; then printf '%%10\n'; exit 0; fi
exit 0
EOF
chmod +x "$STUB/tmux"
: > "$CALL_LOG"
set +e
out18="$("$OE_HANDOFF" start -w "$WS" --handoff "$HANDOFF" 2>&1)"; rc18=$?
set -e
ck  "非0 で終わる"      "1" "$rc18"
ckc "送っていないと言う" "$out18" "送っていません"
ck  "send を呼んでいない" "0" "$(grep -c '^send' "$CALL_LOG" | tr -d ' ')"

echo "[24] board の散文の backslash を壊さない"
ESC="$_TMP_DIR/esc.md"
# 中身は format でなく引数で渡す。format に置くと printf 自身が \t を TAB に変えてしまい、
# 「literal な backslash が残るか」を試したつもりで別のものを試すことになる。
# shellcheck disable=SC2016  # backtick と backslash は board の中身で、展開させない
printf '%s\n' '鮮度: 2026-01-01 / 現統括: pane `%10`（a\tb と c\\d が入っている）' > "$ESC"
oe_seat_rewrite "$ESC" "%11" 2 "2026-09-12" "%10" "%10" >/dev/null 2>&1 || true
ckc "backslash-t が残る" "$(cat "$ESC")" 'a\tb'
ckc "backslash 2つが残る" "$(cat "$ESC")" 'c\\d'

echo "[25] 席の書き換えは他のプロセスと同時に走らない（ロック）"
LK="$_TMP_DIR/lock.md"; mk_board "$LK"
mkdir -p "${LK}.lock"          # 別プロセスが握っている状態を作る
set +e
OE_SEAT_LOCK_RETRY=2 oe_seat_rewrite "$LK" "%11" 2 "2026-09-12" "%10" "%10"; rc19=$?
set -e
rmdir "${LK}.lock"
ck "握られていれば 4 を返す" "4" "$rc19"
ck "board を書き換えない"    "%10" "$(oe_seat_resolve "$LK")"
ck "ロックを解放する"        "0" "$(find "$_TMP_DIR" -maxdepth 1 -name 'lock.md.lock' | grep -c '^' | tr -d ' ')"
oe_seat_rewrite "$LK" "%11" 2 "2026-09-12" "%10" "%10" >/dev/null 2>&1 || true
ck "解放後は書き換えられる" "%11" "$(oe_seat_resolve "$LK")"

echo "[26] 別 server の時代の同じ pane 宛てイベントを「今回の記録」と誤認しない"
: > "$EV/oe-events.jsonl"
jq -cn '{ts:"2026-01-01T00:00:00+00:00", type:"supervisor_succession", from:{pane:"%9",role:"",label:""}, to:{pane:"%11",role:"",label:""}, generation:9, reason:"planned", server_pid:"111"}' >> "$EV/oe-events.jsonl"
set +e
( source "$PROJECT_DIR/lib/event-bus.sh"; oe_event_succession_recorded "" "%11" 0 "" "900" ) >/dev/null 2>&1; rc20=$?
( source "$PROJECT_DIR/lib/event-bus.sh"; oe_event_succession_recorded "" "%11" 0 "" "111" ) >/dev/null 2>&1; rc21=$?
set -e
ck "server_pid が違えば拾わない" "1" "$rc20"
ck "server_pid が合えば拾う"     "0" "$rc21"

echo "[27] 世代と理由の値を検証してから書き換える（board の部分更新を作らない）"
mk_board "$BOARD"; before="$(cat "$BOARD")"
set +e
"$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --generation abc >/dev/null 2>&1; rc22=$?
"$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --generation 0 >/dev/null 2>&1; rc23=$?
"$OE_HANDOFF" take -w "$WS" --board "$BOARD" --handoff "$HANDOFF" --reason nope >/dev/null 2>&1; rc24=$?
set -e
ck "整数でない世代は 2"     "2" "$rc22"
ck "0 の世代は 2"           "2" "$rc23"
ck "未知の理由は 2"         "2" "$rc24"
ck "board を書き換えない"    "$before" "$(cat "$BOARD")"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
