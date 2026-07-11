#!/usr/bin/env bash
set -euo pipefail

# test_oe_vitals.sh — bin/oe-vitals（#239 段階1 PR-B・統括 vital 監視 consumer）の検証。
#
# read-only 前提: fixture の sidecar 群（<sid>.json = {ts, context_pct, pane}）を直に置き、board
# （OE_BOARD_FILE）の現統括 pane と突合して統括 session だけを対象化し、真理値表
# （alive×fresh×high / alive×fresh×low / gone×stale / absent / alive×stale）を検証する。
# 鮮度は決定論化のため OE_VITALS_NOW_EPOCH で now を固定する（date +%s は使わない）。
# liveness は PATH-stub tmux で固定（%158 alive・他は gone）。wez は stub で呼出記録。
# sidecar / board は jq / printf で runtime 生成し、生制御文字をソースに置かない（#239 の Write 化け罠）。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_VITALS="$PROJECT_DIR/bin/oe-vitals"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

# --- stub tmux (%158 alive・他は gone) + wez (呼出記録) ---
STUB_BIN="$_TMP_DIR/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "list-panes" ]]; then printf '%%158\n'; exit 0; fi
exit 0
EOF
chmod +x "$STUB_BIN/tmux"
WEZ_LOG="$_TMP_DIR/wez.log"; : > "$WEZ_LOG"
cat > "$STUB_BIN/wez" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$WEZ_LOG"
exit 0
EOF
chmod +x "$STUB_BIN/wez"

# --- 特定ツールを欠いた PATH を作る（tmux/wez 不在・jq 不在の degrade 検証用）---
IFS=':' read -ra _pdirs <<< "$PATH"
build_path_without() {  # build_path_without <dir> <tool>...
  local dest="$1"; shift; mkdir -p "$dest"; local d f b skip t
  for d in "${_pdirs[@]}"; do
    [[ -d "$d" ]] || continue
    for f in "$d"/*; do
      [[ -x "$f" && ! -d "$f" ]] || continue
      b="$(basename "$f")"; skip=0
      for t in "$@"; do [[ "$b" == "$t" ]] && skip=1; done
      [[ "$skip" -eq 1 ]] && continue
      [[ -e "$dest/$b" ]] || ln -s "$f" "$dest/$b" 2>/dev/null || true
    done
  done
}
NOTOOLS="$_TMP_DIR/notools"; build_path_without "$NOTOOLS" tmux wez
NOJQ="$_TMP_DIR/nojq"; build_path_without "$NOJQ" jq

PASS=0; FAIL=0
ck() { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }
row_of() { printf '%s\n' "$1" | grep -F "$2"; }

# mkfix <name> — sidecar dir + state dir + board を作り $SIDEDIR / $STATEDIR / $BOARD を設定
mkfix() {
  local d="$_TMP_DIR/$1"
  SIDEDIR="$d/heartbeat"; STATEDIR="$d/state"; BOARD="$d/board.md"
  mkdir -p "$SIDEDIR" "$STATEDIR"; : > "$BOARD"
}
# write_sidecar <sid> <ts> <ctx-json> <pane> — sidecar を jq で安全に書く（生制御文字を置かない）
write_sidecar() {
  jq -cn --argjson ts "$2" --argjson ctx "$3" --arg pane "$4" \
    '{ts:$ts, context_pct:$ctx, pane:$pane}' > "$SIDEDIR/$1.json"
}
# board_frontmatter <pane> <succ> — PR-C schema 形（YAML frontmatter）
board_frontmatter() { printf '%s\n' "---" "鮮度: 2026-07-10" "現統括: \"$1\"" "succession: $2" "---" "" "# board" > "$BOARD"; }
# board_freeform <pane> <succ> — 現行 board 形（frontmatter 無し・1 行に併記・前任 pane %157 も後方併記）
# backtick は board markup の literal（command 展開ではない）ゆえ single-quote 維持。
# shellcheck disable=SC2016
board_freeform() { printf '# START HERE\n\n鮮度: 2026-07-10 / 現統括: pane `%s`（統括5代目・前 seat `%%157`）/ succession: **%s**（...）\n' "$1" "$2" > "$BOARD"; }

# run <now> [args...] — 固定 now で consumer を回す（stub PATH・cron 相当・board/dir を env で隔離）
run() { local now="$1"; shift; env PATH="$STUB_BIN:$PATH" OE_HEARTBEAT_DIR="$SIDEDIR" OE_BOARD_FILE="$BOARD" OE_EVENT_DIR="$STATEDIR" OE_VITALS_NOW_EPOCH="$now" bash "$OE_VITALS" "$@"; }

NOW=1000000     # 基準 now（epoch）。fresh=age≤W / stale=age>W を offset で作る。
FRESH=$((NOW-60))       # age 60s（≤1800）
STALE=$((NOW-3600))     # age 3600s（>1800）

# ============================================================================
echo "[1] board 突合 + alive×fresh×high → FLAG context + owner ping"
mkfix f1; board_frontmatter "%158" "完了"; write_sidecar sup "$FRESH" 91 "%158"
: > "$WEZ_LOG"
rc=0; OUT="$(run "$NOW")" || rc=$?
ck  "exit 0（observer）" "0" "$rc"
ckc "header 出る" "$OUT" "supervisor vitals"
ckc "KIND=context の note" "$OUT" "context 肥大接近"
ckc "handoff 促し" "$OUT" "handoff"
ckc "現統括 pane %158 が行に出る" "$(row_of "$OUT" "context 肥大接近")" "%158"
ck  "wez notify 1 回" "1" "$(awk 'END{print NR}' "$WEZ_LOG")"

echo "[2] alive×fresh×low（ctx≤T）→ FLAG 無し（健全・exit 0）"
mkfix f2; board_frontmatter "%158" "完了"; write_sidecar sup "$FRESH" 50 "%158"
rc=0; OUT="$(run "$NOW")" || rc=$?
ck  "exit 0" "0" "$rc"
ckc "健全メッセージ" "$OUT" "は健全"
ncc "context FLAG 出ない" "$OUT" "context 肥大接近"

echo "[3] gone×stale → FLAG death + ping（board が現統括のまま pane 消滅＝crash 疑い）"
mkfix f3; board_frontmatter "%157" "進行中"; write_sidecar sup "$STALE" 40 "%157"   # %157 は stub で gone
: > "$WEZ_LOG"
OUT="$(run "$NOW")"
ckc "death FLAG" "$OUT" "プロセス死"
ckc "PLIVE=gone" "$(row_of "$OUT" "プロセス死")" "gone"
ckc "board succession 併記（進行中）" "$OUT" "board succession=進行中"
ck  "wez notify 1 回" "1" "$(awk 'END{print NR}' "$WEZ_LOG")"

echo "[4] absent: board は現統括を declare するが該当 pane の sidecar 無し → 検知なし（死に化かさない）"
mkfix f4; board_frontmatter "%158" "完了"; write_sidecar other "$FRESH" 99 "%199"   # 別 pane のみ
OUT="$(run "$NOW")"
ckc "heartbeat 見つからない" "$OUT" "heartbeat が見つかりません"
ncc "context FLAG は出ない" "$OUT" "context 肥大接近"
ncc "death FLAG も出ない" "$OUT" "プロセス死"

echo "[5] alive×stale → FLAG 無し（hang 誤検知を実装しない）"
mkfix f5; board_frontmatter "%158" "完了"; write_sidecar sup "$STALE" 40 "%158"   # %158 alive だが beat stale
OUT="$(run "$NOW")"
ckc "健全扱い（検知なし）" "$OUT" "検知なし"
ncc "death FLAG 出ない（alive なので）" "$OUT" "プロセス死"
ncc "context FLAG 出ない（stale なので）" "$OUT" "context 肥大接近"

echo "[6] 非統括 sidecar は無視（scope 化）: 統括 %158 は健全・別 session %199 が高 ctx でも FLAG しない"
mkfix f6; board_frontmatter "%158" "完了"
write_sidecar sup "$FRESH" 40 "%158"     # 統括: 健全
write_sidecar noise "$FRESH" 99 "%199"   # 非統括: 高 ctx（無視されるべき）
OUT="$(run "$NOW")"
ckc "統括は健全" "$OUT" "は健全"
ncc "非統括の高 ctx で context FLAG しない" "$OUT" "context 肥大接近"

echo "[7] board 未設定（OE_BOARD_FILE 空）→ scope できず検知なし"
mkfix f7; write_sidecar sup "$FRESH" 91 "%158"   # board は空
OUT="$(env PATH="$STUB_BIN:$PATH" OE_HEARTBEAT_DIR="$SIDEDIR" OE_BOARD_FILE="" OE_EVENT_DIR="$STATEDIR" OE_VITALS_NOW_EPOCH="$NOW" bash "$OE_VITALS")"
ckc "統括を特定できない旨" "$OUT" "統括を特定できません"
ncc "FLAG しない" "$OUT" "context 肥大接近"

echo "[8] sidecar dir 空 → no heartbeat（exit 0）"
mkfix f8; board_frontmatter "%158" "完了"   # sidecar 無し
rc=0; OUT="$(run "$NOW")" || rc=$?
ck  "exit 0" "0" "$rc"
ckc "no heartbeat メッセージ" "$OUT" "no heartbeat recorded yet"

echo "[9] dedup: 2 回目は notify 抑止・stdout は継続表示（durable）"
mkfix f9; board_frontmatter "%158" "完了"; write_sidecar sup "$FRESH" 91 "%158"
: > "$WEZ_LOG"
run "$NOW" >/dev/null   # run1: notify + seen 追記
ck  "run1: wez notify 1 回" "1" "$(awk 'END{print NR}' "$WEZ_LOG")"
ckc "run1: seen cache に key" "$(cat "$STATEDIR/oe-vitals/seen")" "context|sup"
: > "$WEZ_LOG"
OUT2="$(run "$NOW")"
ck  "run2: 新規キー無し → wez notify 0 回（二重通知抑止）" "0" "$(awk 'END{print NR}' "$WEZ_LOG")"
ckc "run2: stdout は継続表示" "$OUT2" "context 肥大接近"

echo "[10] context_pct null → 0 扱い（閾値以下・健全）・crash しない"
mkfix f10; board_frontmatter "%158" "完了"
jq -cn --argjson ts "$FRESH" --arg pane "%158" '{ts:$ts, context_pct:null, pane:$pane}' > "$SIDEDIR/sup.json"
rc=0; OUT="$(run "$NOW")" || rc=$?
ck  "exit 0" "0" "$rc"
ckc "null ctx → 健全（0 扱い）" "$OUT" "は健全"

echo "[11] --window / --threshold + env + 優先順位 + 不正値"
mkfix f11; board_frontmatter "%158" "完了"; write_sidecar sup "$FRESH" 80 "%158"   # ctx=80
ckc "既定 T=85 → ctx80 は健全" "$(run "$NOW")" "は健全"
ckc "--threshold 70 → ctx80 で FLAG" "$(run "$NOW" --threshold 70)" "context 肥大接近"
ckc "--threshold=70（=形式）→ FLAG" "$(run "$NOW" --threshold=70)" "context 肥大接近"
ckc "env THRESHOLD=70 → FLAG" "$(env PATH="$STUB_BIN:$PATH" OE_HEARTBEAT_DIR="$SIDEDIR" OE_BOARD_FILE="$BOARD" OE_EVENT_DIR="$STATEDIR" OE_VITALS_NOW_EPOCH="$NOW" OE_VITALS_CONTEXT_THRESHOLD=70 bash "$OE_VITALS")" "context 肥大接近"
ckc "--threshold 90 が env 70 を上書き → 健全" "$(env PATH="$STUB_BIN:$PATH" OE_HEARTBEAT_DIR="$SIDEDIR" OE_BOARD_FILE="$BOARD" OE_EVENT_DIR="$STATEDIR" OE_VITALS_NOW_EPOCH="$NOW" OE_VITALS_CONTEXT_THRESHOLD=70 bash "$OE_VITALS" --threshold 90)" "は健全"
# --window: STALE(age3600) を window で fresh/stale 切替（%158 alive なので stale でも death は出ない=健全/検知なし）
mkfix f11b; board_frontmatter "%158" "完了"; write_sidecar sup "$STALE" 91 "%158"
ckc "--window 4000 → beat fresh 扱い → 高 ctx で context FLAG" "$(run "$NOW" --window 4000)" "context 肥大接近"
ckc "既定 window 1800 → stale 扱い（alive×stale）→ 検知なし" "$(run "$NOW")" "検知なし"
# 不正値
rc=0; run "$NOW" --threshold abc >/dev/null 2>&1 || rc=$?; ck "threshold 非整数 → exit 2" "2" "$rc"
rc=0; run "$NOW" --threshold 101 >/dev/null 2>&1 || rc=$?; ck "threshold 101 → exit 2" "2" "$rc"
rc=0; run "$NOW" --window abc >/dev/null 2>&1 || rc=$?; ck "window 非整数 → exit 2" "2" "$rc"
rc=0; run "$NOW" --window 0 >/dev/null 2>&1 || rc=$?; ck "window 0 → exit 2" "2" "$rc"

echo "[12] 不正オプション / 余分引数 → usage・exit 2"
mkfix f12; board_frontmatter "%158" "完了"; write_sidecar sup "$FRESH" 91 "%158"
rc=0; run "$NOW" --bogus >/dev/null 2>&1 || rc=$?; ck "bad opt exit 2" "2" "$rc"
rc=0; run "$NOW" extra-arg >/dev/null 2>&1 || rc=$?; ck "余分引数 exit 2" "2" "$rc"

echo "[13] -h/--help → exit 0・usage"
mkfix f13; board_frontmatter "%158" "完了"
rc=0; H="$(run "$NOW" --help 2>&1)" || rc=$?
ck  "--help exit 0" "0" "$rc"
ckc "usage 表示" "$H" "統括の拍動鮮度"

echo "[14] jq 不在 → exit 2"
mkfix f14; board_frontmatter "%158" "完了"; write_sidecar sup "$FRESH" 91 "%158"
rc=0; ERRO="$(PATH="$NOJQ" OE_HEARTBEAT_DIR="$SIDEDIR" OE_BOARD_FILE="$BOARD" OE_EVENT_DIR="$STATEDIR" OE_VITALS_NOW_EPOCH="$NOW" bash "$OE_VITALS" 2>&1)" || rc=$?
ck  "nojq exit 2" "2" "$rc"
ckc "nojq err メッセージ" "$ERRO" "jq"

echo "[15] tmux 不在 → liveness ? に degrade・検知は継続（fresh×high は context FLAG）"
mkfix f15; board_frontmatter "%158" "完了"; write_sidecar sup "$FRESH" 91 "%158"
rc=0; OUT="$(PATH="$NOTOOLS" OE_HEARTBEAT_DIR="$SIDEDIR" OE_BOARD_FILE="$BOARD" OE_EVENT_DIR="$STATEDIR" OE_VITALS_NOW_EPOCH="$NOW" bash "$OE_VITALS" 2>&1)" || rc=$?
ck  "no-tmux exit 0" "0" "$rc"
ckc "検知は継続（context FLAG）" "$OUT" "context 肥大接近"
ckc "PLIVE=?（tmux 不在 degrade）" "$(row_of "$OUT" "context 肥大接近")" "?"

echo "[16] wez 不在: 通知経路なし → seen へ記録せず永続抑止しない（stdout は durable）"
mkfix f16; board_frontmatter "%158" "完了"; write_sidecar sup "$FRESH" 91 "%158"
r16() { PATH="$NOTOOLS" OE_HEARTBEAT_DIR="$SIDEDIR" OE_BOARD_FILE="$BOARD" OE_EVENT_DIR="$STATEDIR" OE_VITALS_NOW_EPOCH="$NOW" bash "$OE_VITALS"; }
OUT_A="$(r16)"
ckc "wez 不在でも FLAG は stdout に出る" "$OUT_A" "context 肥大接近"
ck  "通知していないので seen cache を作らない" "1" "$([[ ! -e "$STATEDIR/oe-vitals/seen" ]] && echo 1 || echo 0)"
OUT_B="$(r16)"
ckc "2 回目も抑止されず表示" "$OUT_B" "context 肥大接近"

echo "[17] board freeform 形（frontmatter 無し・前任 %157 併記）でも現統括 %158 を解決"
mkfix f17; board_freeform "%158" "完了"; write_sidecar sup "$FRESH" 91 "%158"
OUT="$(run "$NOW")"
ckc "freeform 現統括を解決し FLAG" "$OUT" "context 肥大接近"
ckc "現統括 %158（前任 %157 でない）" "$(row_of "$OUT" "context 肥大接近")" "%158"
ncc "前任 %157 を統括と誤認しない" "$(row_of "$OUT" "context 肥大接近")" "%157"

echo "[18] pane 再利用: 現統括 pane を持つ sidecar 複数 → 最新 ts を採用"
mkfix f18; board_frontmatter "%158" "完了"
write_sidecar old "$STALE" 99 "%158"   # 古い・高 ctx（採用されない）
write_sidecar new "$FRESH" 40 "%158"   # 新しい・低 ctx（採用される）
OUT="$(run "$NOW")"
ckc "最新 ts の sidecar（低 ctx）→ 健全" "$OUT" "は健全"
ncc "古い高 ctx を採用しない" "$OUT" "context 肥大接近"

echo "[19] board succession の制御文字は無害化（death FLAG の会話到達面・#224/#233）"
mkfix f19; write_sidecar sup "$STALE" 40 "%157"   # %157 gone×stale → death
_esc="$(printf '\033')"
# succession 値に ESC を仕込む（（ の前・抽出範囲内）。生 ESC は printf runtime 生成でソースに置かない。
# backtick は board markup の literal ゆえ single-quote 維持。
# shellcheck disable=SC2016
printf '# board\n\n鮮度: 2026-07-10 / 現統括: pane `%%157` / succession: DONE%sEVIL（x）\n' "$_esc" > "$BOARD"
OUT="$(run "$NOW")"
if printf '%s' "$OUT" | LC_ALL=C grep -q "$_esc"; then echo "  FAIL: succession の ESC 未無害化"; FAIL=$((FAIL+1)); else echo "  PASS: succession ESC neutralized"; PASS=$((PASS+1)); fi
ckc "death FLAG は出る" "$OUT" "プロセス死"
ckc "succession 周辺テキスト残存" "$OUT" "EVIL"

echo "[20] ?×stale → death を出さない（設計SO 反証の回帰: tmux 不在で偽 crash ping しない）"
mkfix f20; board_frontmatter "%157" "完了"; write_sidecar sup "$STALE" 40 "%157"
rc=0; OUT="$(PATH="$NOTOOLS" OE_HEARTBEAT_DIR="$SIDEDIR" OE_BOARD_FILE="$BOARD" OE_EVENT_DIR="$STATEDIR" OE_VITALS_NOW_EPOCH="$NOW" bash "$OE_VITALS" 2>&1)" || rc=$?
ck  "exit 0" "0" "$rc"
ncc "?×stale で death を出さない（確定 gone のみ death）" "$OUT" "プロセス死"
ckc "no-op（検知なし）" "$OUT" "検知なし"

echo "[21] gone×fresh → 即 death（旧設計の W 遅延を解消・確定 gone は鮮度非依存）"
mkfix f21; board_frontmatter "%157" "完了"; write_sidecar sup "$FRESH" 40 "%157"   # %157 は stub で gone・beat fresh
OUT="$(run "$NOW")"
ckc "gone×fresh でも death" "$OUT" "プロセス死"
ckc "beat は fresh 表示" "$(row_of "$OUT" "プロセス死")" "fresh"

echo "[22] board 見出しの（現統括 %OLD の担当）を誤 match しない（colon 宣言のみ拾う）"
mkfix f22; write_sidecar sup "$FRESH" 91 "%158"
printf '%s\n' "# board" "" "## in-flight（現統括 %144 の担当）" "" '現統括: "%158"' "succession: 完了" > "$BOARD"
OUT="$(run "$NOW")"
ckc "declaration の %158 を解決し context FLAG" "$OUT" "context 肥大接近"
ckc "現統括=%158" "$(row_of "$OUT" "context 肥大接近")" "%158"
ncc "見出しの stale %144 を誤採用しない" "$(row_of "$OUT" "context 肥大接近")" "%144"

echo "[23] pane 未伝播（sidecar 全て pane 空）→ 明示 warn・死に化かさない"
mkfix f23; board_frontmatter "%158" "完了"
write_sidecar a "$FRESH" 91 ""   # pane 空
write_sidecar b "$FRESH" 50 ""   # pane 空
OUT="$(run "$NOW")"
ckc "heartbeat 見つからない" "$OUT" "heartbeat が見つかりません"
ckc "pane 空を明示（未伝播の疑い）" "$OUT" "pane 空"
ncc "死に化かさない" "$OUT" "プロセス死"

echo "[24] board に 現統括: 宣言はあるが %NNN 無し → graceful no-op（pipefail 落ちの回帰・実装SO 指摘）"
mkfix f24; write_sidecar sup "$FRESH" 91 "%158"
printf '%s\n' "# board" "" "現統括: （未定・pane 未記載）" "succession: 進行中" > "$BOARD"
rc=0; OUT="$(run "$NOW")" || rc=$?
ck  "exit 0（set -e で落ちない）" "0" "$rc"
ckc "統括を特定できない no-op" "$OUT" "統括を特定できません"

echo "[25] HOME 未設定 + OE_EVENT_DIR 未設定 → unbound で落ちない（exit 0・実装SO codex 指摘）"
mkfix f25; board_frontmatter "%158" "完了"; write_sidecar sup "$FRESH" 40 "%158"
rc=0; OUT="$(env -u HOME -u OE_EVENT_DIR PATH="$STUB_BIN:$PATH" OE_HEARTBEAT_DIR="$SIDEDIR" OE_BOARD_FILE="$BOARD" OE_VITALS_NOW_EPOCH="$NOW" bash "$OE_VITALS" 2>&1)" || rc=$?
ck  "HOME/OE_EVENT_DIR 未設定でも exit 0" "0" "$rc"
ckc "健全（正常に判定まで到達）" "$OUT" "は健全"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
