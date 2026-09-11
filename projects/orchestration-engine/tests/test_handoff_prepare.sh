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

mk_beat() { # mk_beat <sid> <pane> <server_pid> <ctx>
  jq -cn --arg p "$2" --arg s "$3" --argjson c "$4" \
    '{ts:1, context_pct:$c, pane:$p, server_pid:$s}' > "$HB/$1.json"
}
mk_child() { # mk_child <pane> <parent_pane> <label>
  jq -cn --arg p "$1" --arg par "$2" --arg l "$3" \
    '{pane:$p, label:$l, workspace:"", parent_pane:$par, role:"child"}' > "$REG/900_${1#%}.json"
}

source "$PROJECT_DIR/lib/handoff-state.sh"

echo "[1] session_id 逆引き: server_pid が一致する sidecar がちょうど1件 → その値"
mk_beat "sid-aaa" "%10" "900" 42
ck "一致1件で session_id を返す" "sid-aaa" "$(oe_hs_session_for_pane '%10')"
ck "その session の context% を返す" "42" "$(oe_hs_context_for_session 'sid-aaa')"

echo "[2] pane 再利用: 同じ pane・同じ server_pid の sidecar が2件 → unknown"
mk_beat "sid-bbb" "%10" "900" 77
ck "曖昧なら値を書かない" "unknown" "$(oe_hs_session_for_pane '%10')"
rm -f "$HB/sid-bbb.json"

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
rm -f "$REG/900_77.json"

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
r_before="$(stat -f %m "$REG/900_11.json" 2>/dev/null || stat -c %Y "$REG/900_11.json")"
OE_BOARD_FILE="$BOARD" OE_EVENT_DIR="$_TMP_DIR" \
  "$OE_HANDOFF" prepare -w "$WS" --out "$OUT" --predecessor '%10' >/dev/null 2>&1 || true
ck "board の mtime が動かない"   "$b_before" "$(stat -f %m "$BOARD" 2>/dev/null || stat -c %Y "$BOARD")"
ck "イベントログの mtime が動かない" "$e_before" "$(stat -f %m "$EVENTS" 2>/dev/null || stat -c %Y "$EVENTS")"
ck "登記の mtime が動かない"     "$r_before" "$(stat -f %m "$REG/900_11.json" 2>/dev/null || stat -c %Y "$REG/900_11.json")"

echo "[10] session_id が引けないときは、停止できないと書く"
OUT2="$WS/.oe/handoff2.md"
out2="$("$OE_HANDOFF" prepare -w "$WS" --out "$OUT2" --predecessor '%99' 2>&1)" || true
ckc "画面で注意する" "$out2" "retire が停止を止めます"
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

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
