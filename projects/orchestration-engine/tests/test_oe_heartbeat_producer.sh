#!/usr/bin/env bash
set -euo pipefail

# test_oe_heartbeat_producer.sh — canonical/claude/statusline/statusline-oe-heartbeat.sh
#   （#239 段階1 PR-A・statusLine 拍動 producer）の検証。
#
# 観点（plan §2 PR-A の test 方針）:
#   - サンプル stdin JSON を食わせ、sidecar が {ts, context_pct, pane} で書かれる。
#   - used_percentage が null / 欠落のとき context_pct=0 に fallback する。
#   - write 先を OE_HEARTBEAT_DIR で隔離しテスト決定化。
#   - 通常の statusLine 文字列が出力される（非破壊・exit 0）。
#   - pane は ${TMUX_PANE:-}（伝播すれば載る・無ければ空）。
#   - 既存 statusLine の wrap（OE_HEARTBEAT_WRAP_CMD）で表示を保ちつつ beat も書く。
#   - atomic write の temp（.hb.*）を残さない。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PRODUCER="$REPO_ROOT/canonical/claude/statusline/statusline-oe-heartbeat.sh"

[[ -f "$PRODUCER" ]] || { echo "FAIL: producer not found: $PRODUCER"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

PASS=0; FAIL=0
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3] in [$2])"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }
ckr() { if printf '%s' "$2" | grep -qE -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (no match /$3/ in [$2])"; FAIL=$((FAIL+1)); fi; }

# 隔離した sidecar dir を都度用意
HBDIR=""
mkhb() { HBDIR="$_TMP_DIR/$1"; mkdir -p "$HBDIR"; }
# run <input-json> [TMUX_PANE] — 固定 OE_HEARTBEAT_DIR で producer を回す。第2引数省略で TMUX_PANE 無し。
run() {
  local input="$1"
  if [[ $# -ge 2 ]]; then
    printf '%s' "$input" | env OE_HEARTBEAT_DIR="$HBDIR" TMUX_PANE="$2" bash "$PRODUCER"
  else
    printf '%s' "$input" | env -u TMUX_PANE OE_HEARTBEAT_DIR="$HBDIR" bash "$PRODUCER"
  fi
}
# sidecar のフィールドを読む
field() { jq -r "$2" "$HBDIR/$1.json" 2>/dev/null; }

# ============================================================================
echo "[1] 基本: sidecar に {ts, context_pct, pane} が書かれる + 最小 statusLine 出力"
mkhb f1
OUT="$(run '{"session_id":"01ABC","model":{"display_name":"Opus"},"context_window":{"used_percentage":42}}' '%99')"
ck  "sidecar ファイルが session_id 名で存在" "yes" "$([[ -f "$HBDIR/01ABC.json" ]] && echo yes || echo no)"
ck  "context_pct=42" "42" "$(field 01ABC '.context_pct')"
ck  "pane=%99（TMUX_PANE 伝播）" "%99" "$(field 01ABC '.pane')"
ck  "ts が正の整数" "yes" "$([[ "$(field 01ABC '.ts')" =~ ^[0-9]+$ ]] && echo yes || echo no)"
ck  "JSON キーは ts/context_pct/pane の3つ" "context_pct pane ts" "$(field 01ABC 'keys_unsorted | sort | join(" ")')"
ckc "表示に model" "$OUT" "Opus"
ckc "表示に context%" "$OUT" "42% ctx"

echo "[2] used_percentage=null → context_pct=0 fallback"
mkhb f2
run '{"session_id":"01NUL","model":{"display_name":"Opus"},"context_window":{"used_percentage":null}}' '%1' >/dev/null
ck  "null → context_pct=0" "0" "$(field 01NUL '.context_pct')"

echo "[3] context_window 欠落（session 早期）→ context_pct=0 fallback"
mkhb f3
run '{"session_id":"01EARLY","model":{"display_name":"Opus"}}' '%1' >/dev/null
ck  "欠落 → context_pct=0" "0" "$(field 01EARLY '.context_pct')"

echo "[4] TMUX_PANE 無し（cron/未伝播）→ pane 空・契約は保たれる"
mkhb f4
run '{"session_id":"01NOPANE","model":{"display_name":"Opus"},"context_window":{"used_percentage":10}}' >/dev/null
ck  "pane 空" "" "$(field 01NOPANE '.pane')"
ck  "sidecar は書かれる" "yes" "$([[ -f "$HBDIR/01NOPANE.json" ]] && echo yes || echo no)"

echo "[5] 非破壊: session_id 無しでも表示は出て exit 0（write は skip）"
mkhb f5
rc=0; OUT="$(run '{"model":{"display_name":"Sonnet"},"context_window":{"used_percentage":7}}' '%1')" || rc=$?
ck  "exit 0" "0" "$rc"
ckc "表示は出る（model）" "$OUT" "Sonnet"
ckc "表示に context%" "$OUT" "7% ctx"
ck  "session_id 無し → sidecar 書かない" "0" "$(find "$HBDIR" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')"

echo "[6] wrap: OE_HEARTBEAT_WRAP_CMD で既存表示を保ちつつ beat も書く"
mkhb f6
rc=0
OUT="$(printf '%s' '{"session_id":"01WRAP","model":{"display_name":"Opus"},"context_window":{"used_percentage":55}}' \
  | env OE_HEARTBEAT_DIR="$HBDIR" TMUX_PANE='%7' OE_HEARTBEAT_WRAP_CMD='jq -r "\"WRAP:\(.model.display_name)\""' bash "$PRODUCER")" || rc=$?
ck  "wrap exit 0" "0" "$rc"
ckc "表示は wrap 出力（call-through）" "$OUT" "WRAP:Opus"
ncc "最小行は出さない（表示は wrap 側）" "$OUT" "% ctx"
ck  "wrap でも beat は side-effect で書かれる" "55" "$(field 01WRAP '.context_pct')"

echo "[7] session_id が不正（区切り混入）→ write skip・表示は出る"
mkhb f7
rc=0; OUT="$(run '{"session_id":"a/b","model":{"display_name":"X"},"context_window":{"used_percentage":5}}' '%1')" || rc=$?
ck  "不正 id exit 0" "0" "$rc"
ck  "不正 id → sidecar 書かない" "0" "$(find "$HBDIR" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')"
ckc "表示は出る" "$OUT" "5% ctx"

echo "[8] float の context_pct を保持（used_percentage=23.5）"
mkhb f8
run '{"session_id":"01FLOAT","model":{"display_name":"Opus"},"context_window":{"used_percentage":23.5}}' '%1' >/dev/null
ck  "float 保持" "23.5" "$(field 01FLOAT '.context_pct')"

echo "[9] atomic write の temp（.hb.*）を残さない"
mkhb f9
run '{"session_id":"01TMP","model":{"display_name":"Opus"},"context_window":{"used_percentage":1}}' '%1' >/dev/null
ck  "temp 残骸なし" "0" "$(find "$HBDIR" -maxdepth 1 -name '.hb.*' | wc -l | tr -d ' ')"

echo "[10] 再 invocation で sidecar を上書き（最新 beat）"
mkhb f10
run '{"session_id":"01UPD","model":{"display_name":"Opus"},"context_window":{"used_percentage":10}}' '%1' >/dev/null
run '{"session_id":"01UPD","model":{"display_name":"Opus"},"context_window":{"used_percentage":80}}' '%1' >/dev/null
ck  "最新値へ上書き" "80" "$(field 01UPD '.context_pct')"
ck  "ファイルは1つ（session 単位）" "1" "$(find "$HBDIR" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')"

echo "[11] 非破壊: HOME も OE_HEARTBEAT_DIR も未設定でも set -u で abort しない（表示・exit 0）"
rc=0
OUT="$(printf '%s' '{"session_id":"01NOHOME","model":{"display_name":"Opus"},"context_window":{"used_percentage":9}}' \
  | env -u HOME -u OE_HEARTBEAT_DIR -u TMUX_PANE bash "$PRODUCER")" || rc=$?
ck  "HOME 未設定でも exit 0" "0" "$rc"
ckc "HOME 未設定でも表示は出る" "$OUT" "9% ctx"

echo "[12] wrap コマンドが失敗しても最小行へフォールバック（非破壊）+ beat は書く"
mkhb f12
rc=0
OUT="$(printf '%s' '{"session_id":"01WFAIL","model":{"display_name":"Opus"},"context_window":{"used_percentage":3}}' \
  | env OE_HEARTBEAT_DIR="$HBDIR" TMUX_PANE='%1' OE_HEARTBEAT_WRAP_CMD='oe-nonexistent-cmd-zzz' bash "$PRODUCER")" || rc=$?
ck  "wrap 失敗でも exit 0" "0" "$rc"
ckc "最小行へフォールバック" "$OUT" "3% ctx"
ck  "wrap 失敗でも beat は書く" "3" "$(field 01WFAIL '.context_pct')"

echo "[13] プラン消費%（#276）: 7d 常時・5h は閾値超え時のみ・7d の右（最右）・リセット残り時間つき"
mkhb f13
_now=$(date +%s); _reset=$((_now + 6420))  # +1h47m

# rate_limits 無し → セグメント無し（従来どおり）
OUT="$(run '{"session_id":"01R0","model":{"display_name":"Opus 4.8"},"context_window":{"used_percentage":34}}' '%1')"
ckc "base: context% は出る" "$OUT" "34% ctx"
ncc "rate_limits 無し → 7d 出さない" "$OUT" "7d"
ncc "rate_limits 無し → 5h 出さない" "$OUT" "5h"

# 7d あり・5h < 80 → 7d のみ（5h 非表示）
OUT="$(run '{"session_id":"01R1","model":{"display_name":"Opus 4.8"},"context_window":{"used_percentage":34},"rate_limits":{"seven_day":{"used_percentage":41},"five_hour":{"used_percentage":50}}}' '%1')"
ckc "7d は常時表示" "$OUT" "· 7d 41%"
ncc "5h < 80 → 非表示" "$OUT" "5h"

# 5h >= 80 + resets_at → 7d の右に 5h・残り時間つき・最右
OUT="$(run "{\"session_id\":\"01R2\",\"model\":{\"display_name\":\"Opus 4.8\"},\"context_window\":{\"used_percentage\":34},\"rate_limits\":{\"seven_day\":{\"used_percentage\":41},\"five_hour\":{\"used_percentage\":83,\"resets_at\":$_reset}}}" '%1')"
ckc "5h >= 80 で表示" "$OUT" "· 5h 83%"
ckc "順序: 7d の右に 5h（最右）" "$OUT" "· 7d 41% · 5h 83%"
ckr "5h にリセット残り時間 (XhYm)" "$OUT" '· 5h 83% \([0-9hm]+\)'

# 5h >= 80 だが resets_at 欠落 → % のみ・時間なし（graceful）
OUT="$(run '{"session_id":"01R3","model":{"display_name":"Opus 4.8"},"context_window":{"used_percentage":34},"rate_limits":{"five_hour":{"used_percentage":83}}}' '%1')"
ckc "resets_at 欠落でも 5h% は出す" "$OUT" "· 5h 83%"
ncc "resets_at 欠落 → 括弧の時間は出さない" "$OUT" "5h 83% ("

# float % は round（41.6→42・82.4→82）context% は従来どおり保持
OUT="$(run "{\"session_id\":\"01R4\",\"model\":{\"display_name\":\"Opus 4.8\"},\"context_window\":{\"used_percentage\":23.5},\"rate_limits\":{\"seven_day\":{\"used_percentage\":41.6},\"five_hour\":{\"used_percentage\":82.4,\"resets_at\":$_reset}}}" '%1')"
ckc "context% は保持（23.5）" "$OUT" "23.5% ctx"
ckc "7d 41.6 → 42（round）" "$OUT" "· 7d 42%"
ckc "5h 82.4 → 82（round）" "$OUT" "· 5h 82%"

# 閾値 env 上書き（OE_STATUSLINE_5H_THRESHOLD=40 で 5h 50% を出す）
OUT="$(printf '%s' "{\"session_id\":\"01R5\",\"model\":{\"display_name\":\"Opus 4.8\"},\"context_window\":{\"used_percentage\":34},\"rate_limits\":{\"five_hour\":{\"used_percentage\":50,\"resets_at\":$_reset}}}" \
  | env OE_HEARTBEAT_DIR="$HBDIR" TMUX_PANE='%1' OE_STATUSLINE_5H_THRESHOLD=40 bash "$PRODUCER")"
ckc "閾値 env 上書きで 5h 表示" "$OUT" "· 5h 50%"

# rate_limits があっても sidecar 契約は不変（{ts,context_pct,pane}・context_pct のみ）
ck  "sidecar キーは従来どおり" "context_pct pane ts" "$(field 01R2 'keys_unsorted | sort | join(" ")')"
ck  "sidecar context_pct=34（rate_limits 混入なし）" "34" "$(field 01R2 '.context_pct')"

echo "[14] now 取得不可（date 失敗）→ 5h% は出すが残り時間は抑止（Copilot 指摘・誤値回避）"
mkhb f14
# date が失敗する stub を PATH 先頭に置く（jq/mktemp 等は元 PATH で解決される）。
STUB="$_TMP_DIR/stub-bin"; mkdir -p "$STUB"
printf '#!/usr/bin/env bash\nexit 1\n' > "$STUB/date"; chmod +x "$STUB/date"
OUT="$(printf '%s' "{\"session_id\":\"01R6\",\"model\":{\"display_name\":\"Opus 4.8\"},\"context_window\":{\"used_percentage\":34},\"rate_limits\":{\"five_hour\":{\"used_percentage\":83,\"resets_at\":9999999999}}}" \
  | env OE_HEARTBEAT_DIR="$HBDIR" TMUX_PANE='%1' PATH="$STUB:$PATH" bash "$PRODUCER")"
ckc "date 失敗でも 5h% は出す" "$OUT" "· 5h 83%"
ncc "now 欠落 → 残り時間の括弧は出さない" "$OUT" "5h 83% ("

# ============================================================================
echo ""
echo "=== RESULT: PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]] || exit 1
