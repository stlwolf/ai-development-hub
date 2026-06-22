#!/usr/bin/env bash
set -euo pipefail

# test_oe_activity.sh — bin/oe-activity（#206 増分1 read-only 投影ビュー）の検証。
#
# liveness は PATH-stub tmux で固定（%59/%66 を alive・%77 は出さない＝gone）。jq は実体。
# fixture の oe-events.jsonl を直に置いて投影（往復カウント / liveness / report/kick 向き /
# inbox フィルタ / degrade / 空）を検証する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_ACTIVITY="$PROJECT_DIR/bin/oe-activity"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
export OE_EVENT_DIR="$_TMP_DIR/events"; mkdir -p "$OE_EVENT_DIR"
EVENTS="$OE_EVENT_DIR/oe-events.jsonl"

# --- stub tmux: list-panes は %59 %66 を返す（%77 は不在＝gone）---
STUB_BIN="$_TMP_DIR/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "list-panes" ]]; then printf '%%59\n%%66\n'; exit 0; fi
exit 0
EOF
chmod +x "$STUB_BIN/tmux"

# fixture: %66 = 生存子（kick + report の 2 往復）、%77 = departed 子（report 1・suspected_miss）
cat > "$EVENTS" <<'EOF'
{"ts":"2026-06-22T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"#206 inbox"},"to":{"pane":"%66","role":"child","label":"#206 impl"}}
{"ts":"2026-06-22T12:01:00+00:00","type":"message_sent","from":{"pane":"%59","role":"parent","label":"#206 inbox"},"to":{"pane":"%66","role":"child","label":"#206 impl"},"preview":"increment1 を進めて","delivery_signal":"none"}
{"ts":"2026-06-22T12:02:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206 impl"},"to":{"pane":"%59","role":"parent","label":"#206 inbox"},"preview":"DONE-IMPL-REPORT","delivery_signal":"none"}
{"ts":"2026-06-22T12:03:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"#206 inbox"},"to":{"pane":"%77","role":"child","label":"#199 old"}}
{"ts":"2026-06-22T12:04:00+00:00","type":"message_sent","from":{"pane":"%77","role":"child","label":"#199 old"},"to":{"pane":"%59","role":"parent","label":"#206 inbox"},"preview":"PARTIAL-OLD-REPORT","delivery_signal":"suspected_miss"}
EOF

PASS=0; FAIL=0
ck() { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { # contains: <desc> <haystack> <needle>
  if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
run() { env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" bash "$OE_ACTIVITY" "$@"; }
# %66 row / %77 row を取り出す（preview マーカで一意特定）
row_of() { printf '%s\n' "$1" | grep -F "$2"; }

echo "[1] overview: 2 関係・新しい順（%77 の最終 12:04 が先頭）"
OUT="$(run)"
ckc "has %66 child label" "$OUT" "#206 impl"
ckc "has %77 child label" "$OUT" "#199 old"
first_data="$(printf '%s\n' "$OUT" | sed -n '3p')"   # 1=title 2=header 3=first row
ckc "newest first = %77 row" "$first_data" "#199 old"

echo "[2] liveness: 生存子=alive / departed 子=gone"
ckc "%66 alive" "$(row_of "$OUT" "DONE-IMPL-REPORT")" "alive"
ckc "%77 gone"  "$(row_of "$OUT" "PARTIAL-OLD-REPORT")" "gone"

echo "[3] 往復回数: %66=2（kick+report）/ %77=1"
r66="$(row_of "$OUT" "DONE-IMPL-REPORT")"; r77="$(row_of "$OUT" "PARTIAL-OLD-REPORT")"
ck "%66 trips=2" "2" "$(printf '%s' "$r66" | awk '{print $2}')"
ck "%77 trips=1" "1" "$(printf '%s' "$r77" | awk '{print $2}')"

echo "[4] delivery: %77 は suspected_miss（miss 表示）/ %66 は none"
ckc "%77 suspected_miss" "$r77" "suspected_miss"
ckc "%66 none"           "$r66" "none"

echo "[5] preview: 直近 message が出る"
ckc "%66 latest preview" "$r66" "DONE-IMPL-REPORT"

echo "[6] inbox: 自分(%59)宛の報告を送信元ごとに（kick は出ない）"
IN="$(run --inbox)"
ckc "inbox header" "$IN" "report inbox (to %59"
ckc "inbox has %66 report" "$IN" "DONE-IMPL-REPORT"
ckc "inbox has %77 report" "$IN" "PARTIAL-OLD-REPORT"
in66="$(row_of "$IN" "DONE-IMPL-REPORT")"
ck "inbox %66 trips=1 (report のみ)" "1" "$(printf '%s' "$in66" | awk '{print $2}')"
ckc "inbox %66 alive" "$in66" "alive"

echo "[7] liveness ?: tmux 失敗時は ? に degrade"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$STUB_BIN/tmux"
OUT2="$(run)"
ckc "live=? on tmux fail" "$(row_of "$OUT2" "DONE-IMPL-REPORT")" "?"
# stub 復元
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "list-panes" ]]; then printf '%%59\n%%66\n'; exit 0; fi
exit 0
EOF
chmod +x "$STUB_BIN/tmux"

echo "[8] 空ログ: メッセージ + exit 0"
rc=0; OUT3="$(OE_EVENT_DIR="$_TMP_DIR/empty" bash "$OE_ACTIVITY" 2>&1)" || rc=$?
ck "empty exit 0" "0" "$rc"
ckc "empty message" "$OUT3" "no activity recorded yet"

echo "[9] jq 不在: degrade（件数のみ・exit 0）"
NOJQ="$_TMP_DIR/nojq"; mkdir -p "$NOJQ"
# 「jq だけ不在」の PATH を作る: 現 PATH の全実行可能ファイルを jq 以外 symlink する
# （bash や profile 依存も残るので startup を壊さない）。
IFS=':' read -ra _pdirs <<< "$PATH"
for d in "${_pdirs[@]}"; do
  [[ -d "$d" ]] || continue
  for f in "$d"/*; do
    [[ -x "$f" && ! -d "$f" ]] || continue
    b="$(basename "$f")"
    [[ "$b" == "jq" ]] && continue
    [[ -e "$NOJQ/$b" ]] || ln -s "$f" "$NOJQ/$b" 2>/dev/null || true
  done
done
rc=0; OUT4="$(PATH="$NOJQ" TMUX_PANE="%59" bash "$OE_ACTIVITY" 2>&1)" || rc=$?
ck "nojq exit 0" "0" "$rc"
ckc "nojq notice" "$OUT4" "jq not found"
ckc "nojq count" "$OUT4" "events: 5"

echo "[10] 不正オプション → usage・exit 2"
rc=0; env PATH="$STUB_BIN:$PATH" TMUX_PANE="%59" bash "$OE_ACTIVITY" --bogus >/dev/null 2>&1 || rc=$?
ck "bad opt exit 2" "2" "$rc"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
