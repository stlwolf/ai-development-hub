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
#   - #327: model は .model が object のときだけ {id, display_name} を投影する（object 以外は {}）。
#   - #327: server_pid は $TMUX の pid 部（非数値・不在は空）。テストは TMUX を常に明示制御して
#     決定化する（ホストが tmux 内で回すと ambient な $TMUX を拾って結果が変わるため）。
#   - #570: effort は .effort が object で .level が low / medium / high / xhigh / max の文字列のときだけ
#     足す。欠落・object でない・未知の値・文字列でないときは項目ごと出さない（それ以外の記録は不変）。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PRODUCER="$REPO_ROOT/canonical/claude/statusline/statusline-oe-heartbeat.sh"

[[ -f "$PRODUCER" ]] || { echo "FAIL: producer not found: $PRODUCER"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
# #577: lease の環境（OE_LEASE_ID・OE_GENERATION）を持つセッションの中で回すと、producer が sidecar に2項目を
# 足すので、従来の出力を確かめる場面が崩れる。テストの冒頭で外す（Copilot の指摘・PR #581）。
unset OE_LEASE_ID OE_GENERATION 2>/dev/null || true
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
    printf '%s' "$input" | env -u TMUX OE_HEARTBEAT_DIR="$HBDIR" TMUX_PANE="$2" bash "$PRODUCER"
  else
    printf '%s' "$input" | env -u TMUX -u TMUX_PANE OE_HEARTBEAT_DIR="$HBDIR" bash "$PRODUCER"
  fi
}
# run_tmux <input-json> <TMUX_PANE> <TMUX> — $TMUX を明示指定して回す（server_pid の検証用・#327）
run_tmux() {
  printf '%s' "$1" | env OE_HEARTBEAT_DIR="$HBDIR" TMUX_PANE="$2" TMUX="$3" bash "$PRODUCER"
}
# sidecar のフィールドを読む
field()  { jq -r "$2" "$HBDIR/$1.json" 2>/dev/null; }
# sidecar のフィールドを JSON として読む（object 比較用・#327）
fieldc() { jq -c "$2" "$HBDIR/$1.json" 2>/dev/null; }

# ============================================================================
echo "[1] 基本: sidecar に {ts, context_pct, pane} が書かれる + 最小 statusLine 出力"
mkhb f1
OUT="$(run '{"session_id":"01ABC","model":{"display_name":"Opus"},"context_window":{"used_percentage":42}}' '%99')"
ck  "sidecar ファイルが session_id 名で存在" "yes" "$([[ -f "$HBDIR/01ABC.json" ]] && echo yes || echo no)"
ck  "context_pct=42" "42" "$(field 01ABC '.context_pct')"
ck  "pane=%99（TMUX_PANE 伝播）" "%99" "$(field 01ABC '.pane')"
ck  "ts が正の整数" "yes" "$([[ "$(field 01ABC '.ts')" =~ ^[0-9]+$ ]] && echo yes || echo no)"
# キー集合は契約そのものなので固定する（#327 で model / server_pid を additive に追加した）。
ck  "JSON キーは ts/context_pct/pane/server_pid/model の5つ" "context_pct model pane server_pid ts" "$(field 01ABC 'keys_unsorted | sort | join(" ")')"
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
ck  "sidecar キーは表示機能の追加で増えない" "context_pct model pane server_pid ts" "$(field 01R2 'keys_unsorted | sort | join(" ")')"
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
echo "[13] #327: model は object のときだけ投影する"
# ============================================================================
mkhb m13
run '{"session_id":"01M13A","model":{"id":"claude-opus-5","display_name":"Opus 5 (1M context)"},"context_window":{"used_percentage":42}}' '%9' >/dev/null
ck  "model.id が載る"                     "claude-opus-5"        "$(field 01M13A '.model.id')"
ck  "display_name が末尾まで載る"          "Opus 5 (1M context)"  "$(field 01M13A '.model.display_name')"
run '{"session_id":"01M13B","model":"opus","context_window":{"used_percentage":5}}' '%9' >/dev/null
ck  "model が文字列 → {}（jq を落とさない）" "{}" "$(fieldc 01M13B '.model')"
ck  "  既存キーも生き残る（context_pct）"    "5"  "$(field 01M13B '.context_pct')"
run '{"session_id":"01M13C","context_window":{"used_percentage":7}}' '%9' >/dev/null
ck  "model 欠落 → {}"                      "{}" "$(fieldc 01M13C '.model')"
run '{"session_id":"01M13D","model":null,"context_window":{"used_percentage":7}}' '%9' >/dev/null
ck  "model が null → {}"                   "{}" "$(fieldc 01M13D '.model')"
run '{"session_id":"01M13E","model":{"display_name":"Sonnet 5"},"context_window":{"used_percentage":7}}' '%9' >/dev/null
ck  "id 欠落 → 空文字（キーは残す）"         ""           "$(field 01M13E '.model.id')"
ck  "  display_name は載る"                "Sonnet 5"   "$(field 01M13E '.model.display_name')"

# ============================================================================
echo ""
echo "[14] #327: server_pid は \$TMUX の pid 部（非数値・不在は空）"
# ============================================================================
mkhb m14
run_tmux '{"session_id":"01M14A","model":{"id":"m","display_name":"M"},"context_window":{"used_percentage":3}}' '%9' '/private/tmp/tmux-501/default,739,0' >/dev/null
ck  "pid 部を取る"                 "739" "$(field 01M14A '.server_pid')"
run_tmux '{"session_id":"01M14B","model":{"id":"m","display_name":"M"},"context_window":{"used_percentage":3}}' '%9' 'socket,notanumber,0' >/dev/null
ck  "pid が非数値 → 空"            ""    "$(field 01M14B '.server_pid')"
run '{"session_id":"01M14C","model":{"id":"m","display_name":"M"},"context_window":{"used_percentage":3}}' '%9' >/dev/null
ck  "\$TMUX 不在 → 空"             ""    "$(field 01M14C '.server_pid')"
ck  "  pane は env から載る"        "%9"  "$(field 01M14C '.pane')"

# ============================================================================
echo ""
echo "[15] #327: display_name の制御文字と区切り文字は JSON に保持され write は成功する"
# ============================================================================
mkhb m15
# 制御文字は実行時に jq の implode で作る（テストの入力にも生バイトを置かない）
_in15="$(jq -nc '{session_id:"01M15", model:{id:"x|y", display_name:("A|B" + ([10]|implode) + "C" + ([27]|implode) + "2J")}, context_window:{used_percentage:1}}')"
run "$_in15" '%9' >/dev/null
ck  "write は成功する（sidecar が在る）"   "yes" "$([[ -f "$HBDIR/01M15.json" ]] && echo yes || echo no)"
ck  "id の | が保持される"                "x|y" "$(field 01M15 '.model.id')"
ck  "display_name の改行が保持される"      "$(printf 'A|B\nC\033'"2J")" "$(field 01M15 '.model.display_name')"
ck  "  temp を残さない"                   "0"   "$(find "$HBDIR" -maxdepth 1 -name '.hb.*' | wc -l | tr -d ' ')"

# ============================================================================
echo ""
echo "[16] #327: 既存キーの契約は不変（追加は additive）"
# ============================================================================
mkhb m16
run '{"session_id":"01M16","model":{"id":"m","display_name":"M"},"context_window":{"used_percentage":42}}' '%9' >/dev/null
ckr "ts は epoch 秒"        "$(field 01M16 '.ts')" '^[0-9]+$'
ck  "context_pct は不変"     "42"  "$(field 01M16 '.context_pct')"
ck  "pane は不変"            "%9"  "$(field 01M16 '.pane')"
ck  "既存 consumer の投影が通る（ts|ctx|pane）" "42|%9" "$(jq -r '"\(.context_pct)|\(.pane)"' "$HBDIR/01M16.json")"

# ============================================================================
echo ""
echo "[17] #570: effort は .effort.level が既知の5語のときだけ足す（それ以外は項目ごと出さない）"
# ============================================================================
mkhb m17
for _lv in low medium high xhigh max; do
  run "{\"session_id\":\"01E17_${_lv}\",\"model\":{\"id\":\"m\",\"display_name\":\"M\"},\"effort\":{\"level\":\"${_lv}\"},\"context_window\":{\"used_percentage\":37}}" '%9' >/dev/null
  ck "level=${_lv} → effort=${_lv}" "$_lv" "$(field "01E17_${_lv}" '.effort')"
done
ck  "effort ありのキー集合（既存5つ + effort）" "context_pct effort model pane server_pid ts" \
    "$(field 01E17_xhigh 'keys_unsorted | sort | join(" ")')"
ck  "  既存キーは不変（ctx / model / pane）" "37|M|%9" \
    "$(jq -r '"\(.context_pct)|\(.model.display_name)|\(.pane)"' "$HBDIR/01E17_xhigh.json")"
# 項目が出ない場合: 欠落・未知の文字列・非文字列（数・配列・null・object）・effort が object でない
_n17=0
for _ef in '' ',"effort":{"level":"turbo"}' ',"effort":{"level":"XHIGH"}' ',"effort":{"level":"high "}' \
           ',"effort":{"level":5}' ',"effort":{"level":["max"]}' ',"effort":{"level":null}' \
           ',"effort":{"level":{"v":"max"}}' ',"effort":{}' ',"effort":"high"' ',"effort":null' \
           ',"effort":["high"]' ',"effort":3'; do
  _n17=$((_n17 + 1))
  rc=0
  run "{\"session_id\":\"01E17N${_n17}\",\"model\":{\"id\":\"m\",\"display_name\":\"M\"}${_ef},\"context_window\":{\"used_percentage\":12}}" '%9' >/dev/null || rc=$?
  ck "[${_ef:-欠落}] → exit 0" "0" "$rc"
  ck "[${_ef:-欠落}] → effort の項目を出さない（キーは既存5つ）" "context_pct model pane server_pid ts" \
     "$(field "01E17N${_n17}" 'keys_unsorted | sort | join(" ")')"
  ck "[${_ef:-欠落}]   既存キーは書かれる（jq を落とさない）" "12|M" \
     "$(jq -r '"\(.context_pct)|\(.model.display_name)"' "$HBDIR/01E17N${_n17}.json" 2>/dev/null)"
done
# model が object でなくても effort は独立に判定する
run '{"session_id":"01E17M","model":"opus","effort":{"level":"max"},"context_window":{"used_percentage":5}}' '%9' >/dev/null
ck  "model が文字列でも effort は載る"   "max" "$(field 01E17M '.effort')"
ck  "  model は {}"                     "{}"  "$(fieldc 01E17M '.model')"

# ============================================================================
echo ""
echo "[18] #350: 書きかけで SIGTERM を受けても temp（.hb.*）を残さない"
# ============================================================================
# Claude Code は実行中の statusLine を SIGTERM で打ち切り、process group に届く（2.1.322 で実測）。
# 本体を書く jq を、pid を残して眠る stub に替えて書きかけの状態で止め、producer と stub の両方に
# SIGTERM を送る（process group へ届くのを写す）。stub は本体を書く呼び出し（--argjson を含む）だけ眠り、
# session_id を読む呼び出しは本物の jq へ渡す。
mkhb m18
STUB18="$_TMP_DIR/stub18-bin"; mkdir -p "$STUB18"
_realjq="$(command -v jq)"
cat > "$STUB18/jq" <<EOF18
#!/bin/sh
for a in "\$@"; do
  if [ "\$a" = "--argjson" ]; then echo \$\$ > "$STUB18/jq.pid"; exec sleep 30; fi
done
exec "$_realjq" "\$@"
EOF18
chmod +x "$STUB18/jq"
for _sh in "${BASH:-bash}" /bin/bash; do
  [[ -x "$_sh" ]] || continue
  rm -f "$STUB18/jq.pid"; rm -f "$HBDIR"/.hb.* "$HBDIR"/*.json 2>/dev/null || true
  printf '%s' '{"session_id":"01T18","model":{"display_name":"Opus"},"context_window":{"used_percentage":4}}' \
    | env -u TMUX -u TMUX_PANE OE_HEARTBEAT_DIR="$HBDIR" PATH="$STUB18:$PATH" "$_sh" "$PRODUCER" >/dev/null 2>&1 &
  _pid18=$!
  _seen=no
  for _i in $(seq 1 50); do
    if [[ -s "$STUB18/jq.pid" ]] && [[ -n "$(find "$HBDIR" -maxdepth 1 -name '.hb.*' 2>/dev/null)" ]]; then _seen=yes; break; fi
    sleep 0.1
  done
  ck "[$_sh] 書きかけの temp ができた（前提）" "yes" "$_seen"
  kill -TERM "$_pid18" 2>/dev/null || true
  kill -TERM "$(cat "$STUB18/jq.pid" 2>/dev/null)" 2>/dev/null || true
  rc=0; wait "$_pid18" 2>/dev/null || rc=$?
  ck "[$_sh] SIGTERM で終わる（exit 143）" "143" "$rc"
  ck "[$_sh] temp（.hb.*）を残さない" "0" "$(find "$HBDIR" -maxdepth 1 -name '.hb.*' | wc -l | tr -d ' ')"
  ck "[$_sh] sidecar は書かない（書きかけを置き換えない）" "0" "$(find "$HBDIR" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')"
done

# ============================================================================
echo ""
echo "=== RESULT: PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]] || exit 1
