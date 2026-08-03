#!/usr/bin/env bash
set -euo pipefail

# test_oe_undelivered.sh — bin/oe-undelivered（#239 段階0・報告未達検知 watchdog）の検証。
#
# read-only 前提: fixture の oe-events.jsonl を直に置き、#220 frontier（未ack）＋時間窓 W で
# 「報告未達（pending>0 かつ age>W）」を FLAG するかを検証する。
# age は決定論化のため OE_UNDELIVERED_NOW_EPOCH で now を固定する（jq now builtin は使わない）。
# liveness は PATH-stub tmux で固定（%59/%66 alive・他は gone）。wez は stub で呼出記録。
#
# 参照 epoch（すべて +00:00）:
#   12:00:00=1782993600 12:01:00=1782993660 12:02:00=1782993720 12:04:00=1782993840
#   12:05:00=1782993900 12:06:00=1782993960 12:10:00=1782994200 12:40:00=1782996000

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_UNDELIVERED="$PROJECT_DIR/bin/oe-undelivered"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

# --- stub tmux (%59 %66 alive・他は gone) + wez (呼出記録) ---
STUB_BIN="$_TMP_DIR/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "list-panes" ]]; then printf '%%59\n%%66\n'; exit 0; fi
exit 0
EOF
chmod +x "$STUB_BIN/tmux"
WEZ_LOG="$_TMP_DIR/wez.log"
: > "$WEZ_LOG"
cat > "$STUB_BIN/wez" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$WEZ_LOG"
exit 0
EOF
chmod +x "$STUB_BIN/wez"

PASS=0; FAIL=0
ck() { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }
row_of() { printf '%s\n' "$1" | grep -F "$2"; }

# mkfix <dir> — fixture ディレクトリを作り $EVFILE / $EVDIR を設定
mkfix() { local d="$_TMP_DIR/$1"; mkdir -p "$d"; EVFILE="$d/oe-events.jsonl"; EVDIR="$d"; }
# run <now_epoch> [args...] — 固定 now で watchdog を回す（stub PATH・$TMUX_PANE 無し＝cron 相当）
run() { local now="$1"; shift; env PATH="$STUB_BIN:$PATH" OE_EVENT_DIR="$EVDIR" OE_UNDELIVERED_NOW_EPOCH="$now" bash "$OE_UNDELIVERED" "$@"; }

# ============================================================================
echo "[1] pending>0 かつ age>W → FLAG（ペア + age を出す）"
mkfix f1
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"R2-UNACKED","delivery_signal":"none"}
EOF
OUT="$(run 1782996000)"   # now=12:40 → age=35m>30m
ckc "header 出る" "$OUT" "受領印の無い報告"
ckc "FLAG 行に子ラベル" "$OUT" "#206A"
ckc "FLAG 行に親" "$OUT" "boss (%59)"
ckc "AGE 表示(35m)" "$(row_of "$OUT" "R2-UNACKED")" "35m"
# #299 P4: 列は PLIVE($1) AGE($2) TS($3) RECEIPT($4)。PENDING（関係単位の残数）は廃止した。
ck  "RECEIPT=判定不可（nonce 無しの送信は未着と呼ばない）" "判定不可" "$(printf '%s' "$(row_of "$OUT" "R2-UNACKED")" | awk '{print $4}')"

echo "[2] pending>0 だが age<W → FLAG 無し（no-op メッセージ・exit 0）"
rc=0; OUT="$(run 1782994200)" || rc=$?   # now=12:10 → age=5m<30m
ck  "age<W exit 0" "0" "$rc"
ckc "no undelivered メッセージ" "$OUT" "表示対象なし"
ncc "FLAG ヘッダ出ない" "$OUT" "受領印の無い報告 (read-only"

echo "[3] pending==0（全 ack 済）→ FLAG 無し"
mkfix f3
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"R2-ACKED","delivery_signal":"none"}
{"ts":"2026-07-02T12:06:00+00:00","type":"report_received","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"},"covers_count":1,"covers_last_ts":"2026-07-02T12:05:00+00:00"}
EOF
OUT="$(run 1782996000)"   # now=12:40（十分古いが全 ack 済）
ckc "全 ack → no undelivered" "$OUT" "表示対象なし"

echo "[4] 部分 ack: 2 報告中 1 ack → 未ack 1・最古未ack が age 基準"
mkfix f4
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:01:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"R1-ACKED","delivery_signal":"none"}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"R2-UNACKED","delivery_signal":"none"}
{"ts":"2026-07-02T12:04:00+00:00","type":"report_received","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"},"covers_count":1,"covers_last_ts":"2026-07-02T12:01:00+00:00"}
EOF
OUT="$(run 1782996000)"
ck  "R1 は ack 済みなので R2 だけが出る" "1" "$(printf '%s\n' "$OUT" | grep -c 'R[12]-')"
ckc "最古未ack=R2 の ts(12:05)" "$(row_of "$OUT" "R2-UNACKED")" "2026-07-02T12:05:00"
ncc "R1(ack 済)は出ない" "$OUT" "R1-ACKED"

echo "[5] kick（parent→child）は報告未達に数えない（child→parent のみ）"
mkfix f5
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:06:00+00:00","type":"message_sent","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"},"preview":"KICK-ONLY","delivery_signal":"none"}
EOF
OUT="$(run 1782996000)"
ckc "kick のみ → no undelivered" "$OUT" "表示対象なし"
ncc "kick は FLAG されない" "$OUT" "KICK-ONLY"

echo "[6] mode3: departed / role 空の子（child_spawned 無し）も既知親宛なら検知"
mkfix f6
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:02:00+00:00","type":"message_sent","from":{"pane":"%77","role":"","label":""},"to":{"pane":"%59","role":"","label":""},"preview":"DEPARTED-REPORT","delivery_signal":"suspected_miss"}
EOF
OUT="$(run 1782996000)"
ckc "departed 子の報告未達を検知（%77 が既知親 %59 宛）" "$OUT" "DEPARTED-REPORT"
r77="$(row_of "$OUT" "DEPARTED-REPORT")"
ck  "departed も 1 行出る" "1" "$(printf '%s\n' "$OUT" | grep -c DEPARTED-REPORT)"
# #299 P0/P4: MISS 列は廃止した。suspected_miss は実測で配送失敗と逆を指していたので、
# 判定にも表示にも使わない。代わりに受領印の状態を出す。
ck  "MISS 列は廃止（suspected_miss を miss として数えない）" "判定不可" "$(printf '%s' "$r77" | awk '{print $4}')"
ncc "旧 MISS ヘッダが残っていない" "$OUT" "MISS"

echo "[7] liveness 付記: 親 gone / alive"
mkfix f7
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:00:30+00:00","type":"child_spawned","from":{"pane":"%88","role":"parent","label":"deadboss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"TO-ALIVE-PARENT","delivery_signal":"none"}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%88","role":"parent","label":"deadboss"},"preview":"TO-GONE-PARENT","delivery_signal":"none"}
EOF
OUT="$(run 1782996000)"
# %59 は stub tmux で alive・%88 は list に無い＝gone。列: PLIVE($1) ...
ck "親 %59 alive" "alive" "$(printf '%s' "$(row_of "$OUT" "TO-ALIVE-PARENT")" | awk '{print $1}')"
# #299 P4-5（再判断）: gone は既定で出す。この verb の主目的（統括死亡で報告が消える経路）は
# まさに親ペインが gone のときに起きるので、既定で伏せると主目的が見えなくなる。
ck "gone の相手も既定で出る（統括死亡の検出）" "gone" "$(printf '%s' "$(row_of "$OUT" "TO-GONE-PARENT")" | awk '{print $1}')"
OUTA="$(run 1782996000 --alive-only)"
ncc "--alive-only なら伏せる"     "$OUTA" "TO-GONE-PARENT"
ckc "伏せたことを告げる"           "$OUTA" "統括死亡の検出はこの中に居ます"
ckc "生存側は --alive-only でも残る" "$OUTA" "TO-ALIVE-PARENT"

echo "[8] 複数ペア混在は age 降順（最も滞留したものが先頭）"
mkfix f8
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"NEWER-1205","delivery_signal":"none"}
{"ts":"2026-07-02T12:02:00+00:00","type":"message_sent","from":{"pane":"%77","role":"","label":""},"to":{"pane":"%59","role":"","label":""},"preview":"OLDER-1202","delivery_signal":"none"}
EOF
OUT="$(run 1782996000)"
first_row="$(printf '%s\n' "$OUT" | sed -n '3p')"   # 1=title 2=header 3=first data
ckc "age 降順: 先頭=最古(12:02)" "$first_row" "OLDER-1202"

# #299: fixture に nonce を持たせて「受領印なし」経路を通す。nonce 無しは判定不可となり
# 通知対象にならないので、それでは dedup / 通知本文 / 再飽和の試験が成立しない
# （初版はそこを見落として、通知経路のテストが1つも無かった・実装SO claude レーン指摘）。
echo "[9] dedup(D-b): 2 回目は notify 抑止・stdout は継続表示"
mkfix f9
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"DEDUP-R","delivery_signal":"unknown","delivery_receipt":{"nonce":"01KZ1VQA1979K4S2MMH5YY24ZR"}}
EOF
: > "$WEZ_LOG"
# #299 P4-2: 既定は shadow。--notify を明示したときだけ owner へ ping する。
run 1782996000 >/dev/null
ck  "既定(shadow): wez notify 0 回" "0" "$(awk 'END{print NR}' "$WEZ_LOG")"
: > "$WEZ_LOG"
run 1782996000 --notify >/dev/null   # run1: notify + seen cache 追記（stdout は不要）
n1="$(awk 'END{print NR}' "$WEZ_LOG")"
ck  "run1(--notify): wez notify 1 回" "1" "$n1"
# #299 P4-4: 抑止キーはメッセージ単位（ts + ログ内 index）。関係単位だと ack が来ない限り
# 同じ関係の新しい未達が永久に抑止されるため。
ckc "run1: seen cache に key（メッセージ単位）" "$(cat "$EVDIR/oe-undelivered/seen")" "%66|%59|2026-07-02T12:05:00+00:00|"
: > "$WEZ_LOG"
OUT2="$(run 1782996000 --notify)"     # run2: 同一 state
n2="$(awk 'END{print NR}' "$WEZ_LOG")"
ck  "run2: 新規キー無し → wez notify 0 回（二重通知抑止）" "0" "$n2"
ckc "run2: stdout は継続表示（durable）" "$OUT2" "DEDUP-R"

echo "[10] wez notify 本文にペア要約（best-effort）"
mkfix f10
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"NOTIFY-BODY","delivery_signal":"unknown","delivery_receipt":{"nonce":"01KZ1VQA1979K4S2MMH5YY24ZS"}}
EOF
: > "$WEZ_LOG"
run 1782996000 --notify >/dev/null
ckc "notify title" "$(cat "$WEZ_LOG")" "undelivered report"

echo "[11] 空 / 不在ログ → クリーンな no-op（exit 0）"
mkfix f11empty   # ディレクトリだけ・ファイル無し
rc=0; OUT="$(run 1782996000)" || rc=$?
ck  "空ログ exit 0" "0" "$rc"
ckc "no activity メッセージ" "$OUT" "no activity recorded yet"

echo "[12] 壊れた JSONL 行は read 時にスキップ（degrade・exit 0・有効行は残る）"
mkfix f12
{
  printf '%s\n' 'not json at all {{{'
  printf '%s\n' '{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}'
  printf '%s\n' '{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"VALID-AFTER-CORRUPT","delivery_signal":"none"}'
} > "$EVFILE"
rc=0; OUT="$(run 1782996000)" || rc=$?
ck  "corrupt exit 0" "0" "$rc"
ckc "有効行は残る" "$OUT" "VALID-AFTER-CORRUPT"

echo "[13] preview の制御文字は空白へ畳む（会話到達面・#224/#233・端末注入防止）"
# 制御文字(ESC)は runtime に printf で生成し jq に JSON エスケープさせて jsonl へ書く（\uXXXX 形）。
# ソースに raw 制御文字を置かない（raw 制御文字は JSON 不正で fromjson が行ごと落とすため）。
mkfix f13
_esc="$(printf '\033')"
printf '%s\n' '{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"c"}}' > "$EVFILE"
jq -cn --arg p "CTRL${_esc}INJECT" \
  '{ts:"2026-07-02T12:05:00+00:00",type:"message_sent",from:{pane:"%66",role:"child",label:"c"},to:{pane:"%59",role:"parent",label:"boss"},preview:$p,delivery_signal:"none"}' >> "$EVFILE"
OUT="$(run 1782996000)"
if printf '%s' "$OUT" | LC_ALL=C grep -q "$_esc"; then echo "  FAIL: ESC 未畳み込み"; FAIL=$((FAIL+1)); else echo "  PASS: ESC folded to space"; PASS=$((PASS+1)); fi
ckc "周辺テキスト CTRL 残存" "$OUT" "CTRL"
ckc "周辺テキスト INJECT 残存" "$OUT" "INJECT"

echo "[14] --window 引数・環境変数・優先順位・不正値"
mkfix f14
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"WIN-R","delivery_signal":"none"}
EOF
# now=12:40 → age=2100s。window=3000 なら FLAG 無し / 1800 なら FLAG。
ckc "--window 3000 → 無し" "$(run 1782996000 --window 3000)" "表示対象なし"
ckc "--window 1800 → FLAG" "$(run 1782996000 --window 1800)" "WIN-R"
ckc "--window=1800（=形式）→ FLAG" "$(run 1782996000 --window=1800)" "WIN-R"
# 環境変数
ckc "env WINDOW=3000 → 無し" "$(env PATH="$STUB_BIN:$PATH" OE_EVENT_DIR="$EVDIR" OE_UNDELIVERED_NOW_EPOCH=1782996000 OE_UNDELIVERED_WINDOW_SEC=3000 bash "$OE_UNDELIVERED")" "表示対象なし"
# --window は env より優先
ckc "--window 1800 が env 3000 を上書き→ FLAG" "$(env PATH="$STUB_BIN:$PATH" OE_EVENT_DIR="$EVDIR" OE_UNDELIVERED_NOW_EPOCH=1782996000 OE_UNDELIVERED_WINDOW_SEC=3000 bash "$OE_UNDELIVERED" --window 1800)" "WIN-R"
# 不正 window → exit 2
rc=0; run 1782996000 --window abc >/dev/null 2>&1 || rc=$?
ck "window 非整数 → exit 2" "2" "$rc"
rc=0; run 1782996000 --window 0 >/dev/null 2>&1 || rc=$?
ck "window 0 → exit 2" "2" "$rc"

echo "[15] 不正オプション / 余分引数 → usage・exit 2"
rc=0; run 1782996000 --bogus >/dev/null 2>&1 || rc=$?
ck "bad opt exit 2" "2" "$rc"
rc=0; run 1782996000 extra-arg >/dev/null 2>&1 || rc=$?
ck "余分引数 exit 2" "2" "$rc"

echo "[16] -h/--help → exit 0・usage"
rc=0; H="$(run 1782996000 --help 2>&1)" || rc=$?
ck  "--help exit 0" "0" "$rc"
ckc "usage 表示" "$H" "受け取られた形跡の無い報告"

echo "[17] jq 不在 → exit 2（frontier 計算に必須）"
NOJQ="$_TMP_DIR/nojq"; mkdir -p "$NOJQ"
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
rc=0; ERRO="$(PATH="$NOJQ" OE_EVENT_DIR="$_TMP_DIR/f1" OE_UNDELIVERED_NOW_EPOCH=1782996000 bash "$OE_UNDELIVERED" 2>&1)" || rc=$?
ck  "nojq exit 2" "2" "$rc"
ckc "nojq err メッセージ" "$ERRO" "jq"

echo "[18] tmux 不在時は liveness ? に degrade（検知は継続）"
mkfix f18
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"NOTMUX-R","delivery_signal":"none"}
EOF
# tmux/wez を持たない PATH（jq/date/grep 等は残す）
NOTOOLS="$_TMP_DIR/notools"; mkdir -p "$NOTOOLS"
for d in "${_pdirs[@]}"; do
  [[ -d "$d" ]] || continue
  for f in "$d"/*; do
    [[ -x "$f" && ! -d "$f" ]] || continue
    b="$(basename "$f")"
    [[ "$b" == "tmux" || "$b" == "wez" ]] && continue
    [[ -e "$NOTOOLS/$b" ]] || ln -s "$f" "$NOTOOLS/$b" 2>/dev/null || true
  done
done
rc=0; OUT="$(PATH="$NOTOOLS" OE_EVENT_DIR="$EVDIR" OE_UNDELIVERED_NOW_EPOCH=1782996000 bash "$OE_UNDELIVERED" 2>&1)" || rc=$?
ck  "no-tmux exit 0" "0" "$rc"
ckc "検知は継続（FLAG 行あり）" "$OUT" "NOTMUX-R"
ck  "PLIVE=?（tmux 不在 degrade）" "?" "$(printf '%s' "$(row_of "$OUT" "NOTMUX-R")" | awk '{print $1}')"

echo "[19] wez 不在: 通知経路が無い → seen へ記録せず永続抑止しない（実装SO cursor 指摘の回帰）"
mkfix f19
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"#206A"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"WEZLESS-R","delivery_signal":"none"}
EOF
# NOTOOLS（[18] で構築・wez/tmux を持たない PATH）で実行＝wez 不在の cron を模す。
r19() { PATH="$NOTOOLS" OE_EVENT_DIR="$EVDIR" OE_UNDELIVERED_NOW_EPOCH=1782996000 bash "$OE_UNDELIVERED"; }
OUT_A="$(r19)"
ckc "wez 不在でも FLAG は stdout に出る（durable）" "$OUT_A" "WEZLESS-R"
ck  "通知していないので seen cache を作らない" "1" "$([[ ! -e "$EVDIR/oe-undelivered/seen" ]] && echo 1 || echo 0)"
OUT_B="$(r19)"
ckc "2 回目も抑止されず表示（wez 復帰時に通知可能）" "$OUT_B" "WEZLESS-R"

echo "[20] label の制御文字も無害化（stdout / notify 到達面・実装SO codex 指摘の回帰）"
mkfix f20
_esc="$(printf '\033')"
# 子 label に ESC を仕込む（jq が JSON エスケープして書き、fromjson で実 ESC へ復号）。
jq -cn --arg cl "EVIL${_esc}LABEL" \
  '{ts:"2026-07-02T12:00:00+00:00",type:"child_spawned",from:{pane:"%59",role:"parent",label:"boss"},to:{pane:"%66",role:"child",label:$cl}}' > "$EVFILE"
printf '%s\n' '{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"c"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"LABELSAN-R","delivery_signal":"none"}' >> "$EVFILE"
OUT="$(run 1782996000)"
if printf '%s' "$OUT" | LC_ALL=C grep -q "$_esc"; then echo "  FAIL: label の ESC 未無害化"; FAIL=$((FAIL+1)); else echo "  PASS: label ESC neutralized"; PASS=$((PASS+1)); fi
ckc "FLAG 行は残る" "$OUT" "LABELSAN-R"
ckc "label 周辺テキスト EVIL 残存" "$OUT" "EVIL"


echo "[21] #299 P4-3: 受領印（prompt_received）が在る送信は出さない"
mkfix f16
N1=01KZ1VQA1979K4S2MMH5YY24ZJ
N2=01KZ1VQA1979K4S2MMH5YY24ZK
{
  printf '%s\n' '{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}'
  printf '{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%%66","role":"child","label":"c"},"to":{"pane":"%%59","role":"parent","label":"boss"},"preview":"WITH-RECEIPT","delivery_signal":"unknown","delivery_receipt":{"nonce":"%s"}}\n' "$N1"
  printf '{"ts":"2026-07-02T12:05:01+00:00","type":"message_sent","from":{"pane":"%%66","role":"child","label":"c"},"to":{"pane":"%%59","role":"parent","label":"boss"},"preview":"NO-RECEIPT","delivery_signal":"unknown","delivery_receipt":{"nonce":"%s"}}\n' "$N2"
  printf '{"ts":"2026-07-02T12:05:02+00:00","type":"prompt_received","from":{"pane":"%%59","role":"","label":""},"to":{"pane":"%%66","role":"","label":""},"nonce":"%s"}\n' "$N1"
} > "$EVFILE"
OUT="$(run 1782996000)"
ncc "受領印のある送信は出さない" "$OUT" "WITH-RECEIPT"
ckc "受領印の無い送信は出す"     "$OUT" "NO-RECEIPT"
ck  "RECEIPT=受領印なし（nonce が在って印が無い）" "受領印なし" \
    "$(printf '%s' "$(row_of "$OUT" "NO-RECEIPT")" | awk '{print $4}')"

echo "[21b] #299: 受領印はペインまで一致を要求する（別ペインの印では消えない）"
mkfix f21b
N3=01KZ1VQA1979K4S2MMH5YY24ZM
{
  printf '%s\n' '{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}'
  printf '{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%%66","role":"child","label":"c"},"to":{"pane":"%%59","role":"parent","label":"boss"},"preview":"WRONG-PANE-RECEIPT","delivery_signal":"unknown","delivery_receipt":{"nonce":"%s"}}\n' "$N3"
  # 印を打ったのが宛先(%59)ではなく無関係な %99 → 未達は消えてはならない
  printf '{"ts":"2026-07-02T12:05:02+00:00","type":"prompt_received","from":{"pane":"%%99","role":"","label":""},"to":{"pane":"","role":"","label":""},"nonce":"%s"}\n' "$N3"
} > "$EVFILE"
OUT="$(run 1782996000)"
ckc "別ペインの受領印では未達が消えない" "$OUT" "WRONG-PANE-RECEIPT"
# 宛先自身の印を足すと消える
printf '{"ts":"2026-07-02T12:05:03+00:00","type":"prompt_received","from":{"pane":"%%59","role":"","label":""},"to":{"pane":"","role":"","label":""},"nonce":"%s"}\n' "$N3" >> "$EVFILE"
OUT="$(run 1782996000)"
ncc "宛先自身の受領印なら消える" "$OUT" "WRONG-PANE-RECEIPT"

echo "[22] #299 P4-1: 観測の起点（watermark）— 過去を消さずに起点だけ動かす"
mkfix f17
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:01:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"c"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"OLD-BEFORE-MARK","delivery_signal":"none"}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"c"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"NEW-AFTER-MARK","delivery_signal":"none"}
EOF
OUT="$(run 1782996000)"
ckc "起点なし: 古いほうも出る" "$OUT" "OLD-BEFORE-MARK"
# 12:03 (=1782993780) を起点に置く（12:01 の前・12:05 の後ろ）
OUT="$(run 1782996000 --start-after 1782993780)"
ncc "起点より前は出さない" "$OUT" "OLD-BEFORE-MARK"
ckc "起点より後は出す"     "$OUT" "NEW-AFTER-MARK"
# 保存した起点は次回以降も効く（消すのでなく起点を置く）
run 1782996000 --set-start-after 1782993780 >/dev/null
ck  "起点が保存される" "1782993780" "$(cat "$EVDIR/oe-undelivered/start-after")"
OUT="$(run 1782996000)"
ncc "保存された起点が効く" "$OUT" "OLD-BEFORE-MARK"
ckc "起点より後は残る"     "$OUT" "NEW-AFTER-MARK"
# 起点を 0 に戻せば過去も見える（消していないことの確認）
OUT="$(run 1782996000 --start-after 0)"
ckc "起点を戻せば過去も見える（消していない）" "$OUT" "OLD-BEFORE-MARK"

echo "[23] #299 P4-4: 同じ関係で新しい未達が起きたら再び通知する（seen 再飽和しない）"
mkfix f18
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:01:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"c"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"FIRST-R","delivery_signal":"unknown","delivery_receipt":{"nonce":"01KZ1VQA1979K4S2MMH5YY24ZS"}}
EOF
: > "$WEZ_LOG"
run 1782996000 --notify >/dev/null
ck "1件目で通知" "1" "$(awk 'END{print NR}' "$WEZ_LOG")"
# 同じ関係へ 2 件目の未達を足す（ack は来ない＝最古未ack の ts は動かない）
printf '%s\n' '{"ts":"2026-07-02T12:02:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"c"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"SECOND-R","delivery_signal":"unknown","delivery_receipt":{"nonce":"01KZ1VQA1979K4S2MMH5YY24ZT"}}' >> "$EVFILE"
: > "$WEZ_LOG"
run 1782996000 --notify >/dev/null
ck "2件目も通知される（関係単位キーなら抑止されていた）" "1" "$(awk 'END{print NR}' "$WEZ_LOG")"


echo "[24] #299: 全行が 判定不可 のとき、空 body の通知を飛ばさず seen も焼かない"
mkfix f24
cat > "$EVFILE" <<'EOF'
{"ts":"2026-07-02T12:00:00+00:00","type":"child_spawned","from":{"pane":"%59","role":"parent","label":"boss"},"to":{"pane":"%66","role":"child","label":"#206A"}}
{"ts":"2026-07-02T12:05:00+00:00","type":"message_sent","from":{"pane":"%66","role":"child","label":"c"},"to":{"pane":"%59","role":"parent","label":"boss"},"preview":"NO-NONCE-ONLY","delivery_signal":"none"}
EOF
: > "$WEZ_LOG"
OUT="$(run 1782996000 --notify)"
ckc "stdout には出る（durable signal）" "$OUT" "NO-NONCE-ONLY"
ck  "判定不可だけなら通知 0 回（空 body を飛ばさない）" "0" "$(awk 'END{print NR}' "$WEZ_LOG")"
ck  "判定不可だけなら seen へ焼かない" "0" \
    "$([[ -f "$EVDIR/oe-undelivered/seen" ]] && wc -l < "$EVDIR/oe-undelivered/seen" | tr -d '[:space:]' || echo 0)"

echo "[25] #299: 受領印なしの行があるときだけ通知し、seen はその行のキーだけ焼く"
N4=01KZ1VQA1979K4S2MMH5YY24ZQ
printf '{"ts":"2026-07-02T12:06:00+00:00","type":"message_sent","from":{"pane":"%%66","role":"child","label":"c"},"to":{"pane":"%%59","role":"parent","label":"boss"},"preview":"NEEDS-RECEIPT","delivery_signal":"unknown","delivery_receipt":{"nonce":"%s"}}\n' "$N4" >> "$EVFILE"
: > "$WEZ_LOG"
OUT="$(run 1782996000 --notify)"
ck  "通知は 1 回" "1" "$(awk 'END{print NR}' "$WEZ_LOG")"
ckc "body は空でない（受領印なしの行が載る）" "$(cat "$WEZ_LOG")" "受領印なし"
ck  "seen は通知した 1 件だけ（判定不可の行を焼かない）" "1" \
    "$(wc -l < "$EVDIR/oe-undelivered/seen" | tr -d '[:space:]')"
ckc "seen に焼かれたのは 12:06 の行" "$(cat "$EVDIR/oe-undelivered/seen")" "2026-07-02T12:06:00+00:00"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
