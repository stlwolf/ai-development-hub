#!/usr/bin/env bash
set -euo pipefail

# test_oe_confirm.sh — bin/oe-confirm（#336・送信 1 件ごとの到達照合 + 常駐の見張り）の検証。
#
# read-only 前提: fixture の oe-events.jsonl と oe-receipt-diag.jsonl を直に置き、送信と受領印を
# nonce ＋宛先ペインで突き合わせた分類を検証する。now は OE_CONFIRM_NOW_EPOCH で固定して決定論化する
# （jq の now builtin は使わない）。liveness は PATH-stub tmux で固定。通知は stub wez で呼出記録。
#
# 参照 epoch（すべて +00:00）:
#   11:00:00=1789124400 11:30:00=1789126200 12:00:00=1789128000 12:05:00=1789128300
#   12:09:00=1789128540 12:10:00=1789128600 12:20:00=1789129200 12:30:00=1789129800
#
# 窓は既定 600 秒。12:00 の送信は now=12:20 で age=1200s（窓超え）、now=12:05 で age=300s（窓の内）。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OE_CONFIRM="$PROJECT_DIR/bin/oe-confirm"
OE_SELFCHECK="$PROJECT_DIR/bin/oe-selfcheck"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

# --- stub tmux（%53 %61 alive・他は gone）+ stub wez（呼出記録）---
STUB_BIN="$_TMP_DIR/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "list-panes" ]]; then printf '%%53\n%%61\n'; exit 0; fi
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
ck()  { if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (want=[$2] got=[$3])"; FAIL=$((FAIL+1)); fi; }
ckc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1 (missing [$3])"; FAIL=$((FAIL+1)); fi; }
ncc() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "  FAIL: $1 (unexpected [$3])"; FAIL=$((FAIL+1)); else echo "  PASS: $1"; PASS=$((PASS+1)); fi; }

mkfix() { local d="$_TMP_DIR/$1"; mkdir -p "$d"; EVDIR="$d"; EVFILE="$d/oe-events.jsonl"; DIAGFILE="$d/oe-receipt-diag.jsonl"; : > "$EVFILE"; : > "$DIAGFILE"; }
run() { local now="$1"; shift; env PATH="$STUB_BIN:$PATH" OE_EVENT_DIR="$EVDIR" OE_CONFIRM_NOW_EPOCH="$now" bash "$OE_CONFIRM" "$@"; }

# 送信 1 行（nonce つき）
sent() { # sent <ts> <from> <to> <nonce> [preview] [tolabel]
  printf '{"ts":"%s","type":"message_sent","from":{"pane":"%s","role":"child","label":""},"to":{"pane":"%s","role":"parent","label":"%s"},"preview":"%s","delivery_signal":"none","delivery_receipt":{"nonce":"%s"}}\n' \
    "$1" "$2" "$3" "${6:-}" "${5:-p}" "$4" >> "$EVFILE"
}
# 受領印 1 行（受け手が撃つ・from=受け手）
recv() { # recv <ts> <receiver_pane> <nonce>
  printf '{"ts":"%s","type":"prompt_received","from":{"pane":"%s","role":"","label":""},"to":{"pane":"","role":"","label":""},"nonce":"%s"}\n' \
    "$1" "$2" "$3" >> "$EVFILE"
}
# 受け手診断 1 行（印を書けなかった）
diag() { # diag <ts> <nonce> <pane>
  printf '{"ts":"%s","hook":"oe-prompt-receipt","kind":"env-error","reason":"no-tmux-pane","detail":"d","nonce":"%s","pane":"%s"}\n' \
    "$1" "$2" "${3:-}" >> "$DIAGFILE"
}

N1=01M00000000000000000000001
N2=01M00000000000000000000002
N3=01M00000000000000000000003
N4=01M00000000000000000000004

# ============================================================================
echo "[1] received — 宛先ペイン自身の印が nonce 一致で在れば received（既定では出さない）"
mkfix f1
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "HELLO-RECV"
recv "2026-09-11T12:00:02+00:00" "%53" "$N1"
OUT="$(run 1789129200)"                       # now=12:20
ncc "既定では received を出さない" "$OUT" "HELLO-RECV"
ck  "内訳で received=1"  "1" "$(run 1789129200 --json | jq -r '.delivery.received')"
ckc "--all なら出る" "$(run 1789129200 --all)" "HELLO-RECV"

# ============================================================================
echo "[2] 陽性対照 — 送信あり・印なし・宛先は鮮度窓内で計装済み・窓超え → unconfirmed"
mkfix f2
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "LOST-ONE"
# 宛先 %53 が別の送信で印を出している＝鮮度窓内で計装済みの証拠
sent "2026-09-11T11:59:00+00:00" "%61" "%53" "$N2" "OTHER"
recv "2026-09-11T11:59:01+00:00" "%53" "$N2"
OUT="$(run 1789129200)"                       # now=12:20 → age=1200s > 600s
ckc "unconfirmed として出る" "$OUT" "unconfirmed"
ckc "対象の preview が出る"   "$OUT" "LOST-ONE"
ckc "文言は断定しない"        "$OUT" "10 分経っても受領を確認できていない"
ncc "「届かなかった」と書かない" "$OUT" "届かなかった"
ck  "内訳 unconfirmed=1" "1" "$(run 1789129200 --json | jq -r '.delivery.unconfirmed')"

# ============================================================================
echo "[3] cannot-confirm — 印は無いが同じ nonce の診断が在る（未着ではない）"
mkfix f3
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "DIAGGED"
diag "2026-09-11T12:00:01+00:00" "$N1" ""
OUT="$(run 1789129200)"
ckc "cannot-confirm として出る" "$OUT" "cannot-confirm"
ckc "未着ではないと明記"        "$OUT" "未着ではありません"
ck  "unconfirmed には数えない" "0" "$(run 1789129200 --json | jq -r '.delivery.unconfirmed')"
ck  "cannot_confirm=1"         "1" "$(run 1789129200 --json | jq -r '.delivery.cannot_confirm')"

# ============================================================================
echo "[4] instrumentation-unknown — 印も診断も無く宛先の計装を確認できない（未着と断定しない）"
mkfix f4
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "NOEVIDENCE"
OUT="$(run 1789129200)"
ckc "instrumentation-unknown として出る" "$OUT" "instrumentation-unknown"
ck  "unconfirmed には数えない" "0" "$(run 1789129200 --json | jq -r '.delivery.unconfirmed')"

# ============================================================================
echo "[5] pending — まだ窓の内なら unconfirmed にしない"
mkfix f5
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "YOUNG"
sent "2026-09-11T11:59:00+00:00" "%61" "%53" "$N2" "OTHER"
recv "2026-09-11T11:59:01+00:00" "%53" "$N2"
ck "now=12:05（age=300s）は pending" "1" "$(run 1789128300 --json | jq -r '.delivery.pending')"
ck "そのとき unconfirmed=0"          "0" "$(run 1789128300 --json | jq -r '.delivery.unconfirmed')"

# ============================================================================
echo "[6] **遅延受領の遷移** — 窓を過ぎてから印が来たら unconfirmed でなく received-delayed（終状態でない）"
mkfix f6
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "LATE-ONE"
recv "2026-09-11T12:15:00+00:00" "%53" "$N1"     # 900 秒後（窓 600 を明確に超えてから）に着いた
OUT="$(run 1789129200)"                          # now=12:20
ckc "received-delayed として出る" "$OUT" "received-delayed"
ckc "遅延秒数を出す"              "$OUT" "900秒後"
ck  "unconfirmed=0（終状態でない）" "0" "$(run 1789129200 --json | jq -r '.delivery.unconfirmed')"
ck  "received_delayed=1"            "1" "$(run 1789129200 --json | jq -r '.delivery.received_delayed')"
# 境界: ちょうど窓ぴったりで着いたものは「遅延」と呼ばない（age > window で unconfirmed に
# なる規則と同じ向きに揃える。片側だけ >= にすると、一度も unconfirmed に出ていない送信が
# 遅延扱いになって数が合わなくなる）。
mkfix f6b
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "EXACT"
recv "2026-09-11T12:10:00+00:00" "%53" "$N1"     # ちょうど 600 秒後
ck  "ちょうど窓なら received（遅延ではない）" "1" "$(run 1789129200 --json | jq -r '.delivery.received')"
ck  "received_delayed=0"                      "0" "$(run 1789129200 --json | jq -r '.delivery.received_delayed')"

# ============================================================================
echo "[7] 宛先ペインの一致を見る — nonce だけ合う別ペインの印では received にしない"
mkfix f7
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "WRONGPANE"
recv "2026-09-11T12:00:02+00:00" "%99" "$N1"      # 別ペインが同じタグを submit した
sent "2026-09-11T11:59:00+00:00" "%61" "%53" "$N2" "OTHER"
recv "2026-09-11T11:59:01+00:00" "%53" "$N2"
OUT="$(run 1789129200)"
ckc "unconfirmed のまま" "$OUT" "unconfirmed"
ck  "received=1（OTHER の分だけ）" "1" "$(run 1789129200 --json | jq -r '.delivery.received')"

# ============================================================================
echo "[8] 通知フィルタ — unconfirmed では撃つが cannot-confirm / instrumentation-unknown では撃たない"
mkfix f8
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "UNCONF"
sent "2026-09-11T11:59:00+00:00" "%61" "%53" "$N2" "OTHER"
recv "2026-09-11T11:59:01+00:00" "%53" "$N2"
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N3" "CANNOT"
diag "2026-09-11T12:00:01+00:00" "$N3" ""
sent "2026-09-11T12:00:00+00:00" "%61" "%77" "$N4" "UNKNOWNINSTR"
: > "$WEZ_LOG"
run 1789129200 --notify >/dev/null
NOTIFIED="$(cat "$WEZ_LOG")"
ckc "unconfirmed は通知する"            "$NOTIFIED" "$N1"
ncc "cannot-confirm は通知しない"        "$NOTIFIED" "$N3"
ncc "instrumentation-unknown は通知しない" "$NOTIFIED" "$N4"
ckc "文言は断定しない"                   "$NOTIFIED" "受領を確認できていません"
# 二重通知抑止（送信 1 件ごとのキー）
: > "$WEZ_LOG"
run 1789129200 --notify >/dev/null
ck "同じ送信は二度通知しない" "0" "$(grep -c "$N1" "$WEZ_LOG" || true)"

# ============================================================================
echo "[9] 子ペインの消滅 — child_spawned で登記された子が居なくなったら出す"
mkfix f9
printf '{"ts":"2026-09-11T12:00:00+00:00","type":"child_spawned","from":{"pane":"%%53","role":"parent","label":"cockpit"},"to":{"pane":"%%61","role":"child","label":"alive-child"}}\n' >> "$EVFILE"
printf '{"ts":"2026-09-11T12:00:00+00:00","type":"child_spawned","from":{"pane":"%%53","role":"parent","label":"cockpit"},"to":{"pane":"%%88","role":"child","label":"dead-child"}}\n' >> "$EVFILE"
OUT="$(run 1789129200)"
ckc "消えた子を出す"       "$OUT" "dead-child"
ncc "生きている子は出さない" "$OUT" "alive-child"
ck  "panes_gone=1" "1" "$(run 1789129200 --json | jq -r '.panes_gone')"

# ============================================================================
echo "[10] report 新規 — 初回は watermark で鳴らさない・新しい file は 2 回安定して初めて出す"
mkfix f10
RD="$_TMP_DIR/reports"; mkdir -p "$RD"
printf 'old\n' > "$RD/report-000-old.md"
OUT="$(run 1789129200 --reports "$RD")"
ncc "初回は既存を鳴らさない（watermark）" "$OUT" "report-000-old.md"
printf 'new\n' > "$RD/report-111-new.md"
OUT="$(run 1789129200 --reports "$RD")"
ncc "現れた直後は出さない（まだ書いている途中かもしれない）" "$OUT" "report-111-new.md"
OUT="$(run 1789129200 --reports "$RD")"
ckc "2 回目に size と mtime が変わらなければ出す" "$OUT" "report-111-new.md"
OUT="$(run 1789129200 --reports "$RD")"
ncc "一度出したら繰り返さない" "$OUT" "report-111-new.md"

# ============================================================================
echo "[11] 書込途中 — 走査の間に size が変われば完成扱いにしない"
mkfix f11
RD2="$_TMP_DIR/reports2"; mkdir -p "$RD2"
run 1789129200 --reports "$RD2" >/dev/null            # 初回 watermark
printf 'partial' > "$RD2/report-222-wip.md"
run 1789129200 --reports "$RD2" >/dev/null            # 1 回目の観測
printf 'partial-more-bytes' > "$RD2/report-222-wip.md" # まだ書いている
OUT="$(run 1789129200 --reports "$RD2")"
ncc "size が変わった回は出さない" "$OUT" "report-222-wip.md"
OUT="$(run 1789129200 --reports "$RD2")"
ckc "安定した次の回で出す" "$OUT" "report-222-wip.md"

# ============================================================================
echo "[12] 検知器自身の沈黙 — latest.json の陳腐化を別の主体（oe-selfcheck）が拾う"
mkfix f12
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "X"
run 1789129200 --write-latest >/dev/null
LATEST="$EVDIR/oe-confirm/latest.json"
ck "latest.json を書く" "1" "$( [[ -r "$LATEST" ]] && echo 1 || echo 0 )"
ck "最終走査時刻が入る" "1789129200" "$(jq -r '.scanned_at_epoch' "$LATEST")"
SC_FRESH="$(env PATH="$STUB_BIN:$PATH" OE_EVENT_DIR="$EVDIR" OE_SELFCHECK_NOW_EPOCH=1789129260 bash "$OE_SELFCHECK" 2>/dev/null || true)"
ckc "走査が新しければ ok" "$SC_FRESH" "watchdog-freshness      ok"
# 陽性対照: job が止まったことにして時刻を進める
SC_STALE="$(env PATH="$STUB_BIN:$PATH" OE_EVENT_DIR="$EVDIR" OE_SELFCHECK_NOW_EPOCH=1789133000 bash "$OE_SELFCHECK" 2>/dev/null || true)"
ckc "走査が古ければ broken（見張りが黙っている）" "$SC_STALE" "watchdog-freshness      broken"
# latest.json が無い＝未配線は ok ではない
mkfix f12b
SC_NONE="$(env PATH="$STUB_BIN:$PATH" OE_EVENT_DIR="$EVDIR" OE_SELFCHECK_NOW_EPOCH=1789129260 bash "$OE_SELFCHECK" 2>/dev/null || true)"
ckc "記録が無ければ indeterminate（ok にしない）" "$SC_NONE" "watchdog-freshness      indeterminate"

# ============================================================================
echo "[13] 観測の起点 — start-after より前の送信は出さない"
mkfix f13
sent "2026-09-11T11:00:00+00:00" "%61" "%53" "$N1" "ANCIENT"
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N2" "RECENT"
sent "2026-09-11T11:59:00+00:00" "%61" "%53" "$N3" "OTHER"
recv "2026-09-11T11:59:01+00:00" "%53" "$N3"
OUT="$(run 1789129200 --start-after 1789126200)"   # 11:30 以降
ncc "起点より前は出さない" "$OUT" "ANCIENT"
ckc "起点より後は出す"     "$OUT" "RECENT"

# ============================================================================
echo "[14] 契約 — observer なので常に exit 0 / usage の誤りだけ 2"
mkfix f14
run 1789129200 >/dev/null; ck "検知なしでも exit 0" "0" "$?"
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "X"
run 1789129200 >/dev/null; ck "検知ありでも exit 0" "0" "$?"
rc=0; run 1789129200 --window abc >/dev/null 2>&1 || rc=$?; ck "不正な窓は exit 2" "2" "$rc"
rc=0; run 1789129200 --bogus >/dev/null 2>&1 || rc=$?; ck "未知のオプションは exit 2" "2" "$rc"
rc=0; run 1789129200 -h >/dev/null 2>&1 || rc=$?; ck "--help は exit 0" "0" "$rc"

# ============================================================================
echo "[15] read-only — イベントログと診断を書き換えない"
mkfix f15
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "X"
diag "2026-09-11T12:00:01+00:00" "$N2" ""
SUM_BEFORE="$(cat "$EVFILE" "$DIAGFILE" | shasum | cut -d' ' -f1)"
run 1789129200 --notify --write-latest >/dev/null
SUM_AFTER="$(cat "$EVFILE" "$DIAGFILE" | shasum | cut -d' ' -f1)"
ck "入力を変更しない" "$SUM_BEFORE" "$SUM_AFTER"

# ============================================================================
echo "[16] 診断は宛先ペインまで見る — 別ペインが出した診断で cannot-confirm にしない"
mkfix f16
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "WRONGPANE-DIAG"
diag "2026-09-11T12:00:01+00:00" "$N1" "%99"      # 宛先ではないペインが出した診断
sent "2026-09-11T11:59:00+00:00" "%61" "%53" "$N2" "OTHER"
recv "2026-09-11T11:59:01+00:00" "%53" "$N2"
ck "別ペインの診断では cannot-confirm にしない" "0" "$(run 1789129200 --json | jq -r '.delivery.cannot_confirm')"
ck "unconfirmed のまま"                          "1" "$(run 1789129200 --json | jq -r '.delivery.unconfirmed')"
# 宛先が出した診断なら数える
mkfix f16b
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "RIGHTPANE-DIAG"
diag "2026-09-11T12:00:01+00:00" "$N1" "%53"
ck "宛先が出した診断は cannot-confirm" "1" "$(run 1789129200 --json | jq -r '.delivery.cannot_confirm')"
# pane を束縛できなかった診断（no-tmux-pane）は空のまま突き合わせを許す
mkfix f16c
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "EMPTYPANE-DIAG"
diag "2026-09-11T12:00:01+00:00" "$N1" ""
ck "pane が空の診断は cannot-confirm" "1" "$(run 1789129200 --json | jq -r '.delivery.cannot_confirm')"

# ============================================================================
echo "[17] 同時起動 — ロックを取れなければ表示だけ行い、通知と状態保存は見送る"
mkfix f17
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "LOCKED"
sent "2026-09-11T11:59:00+00:00" "%61" "%53" "$N2" "OTHER"
recv "2026-09-11T11:59:01+00:00" "%53" "$N2"
mkdir -p "$EVDIR/oe-confirm/.lock"          # 別プロセスがロックを持っている状態
: > "$WEZ_LOG"
# now を未来に固定しているので、既定の stale 秒（1800）だと作りたてのロックが「古い」と判定
# されて回収されてしまう。ここでは回収されない側を見たいので十分大きくする。
OUT="$(env PATH="$STUB_BIN:$PATH" OE_EVENT_DIR="$EVDIR" OE_CONFIRM_NOW_EPOCH=1789129200 \
  OE_CONFIRM_LOCK_STALE_SEC=999999999 bash "$OE_CONFIRM" --notify --write-latest 2>&1)"
ckc "検知の表示は出る"       "$OUT" "unconfirmed"
ckc "見送ったことを告げる"   "$OUT" "通知は見送りました"
ck  "通知は撃たない"         "0" "$(grep -c "$N1" "$WEZ_LOG" || true)"
ck  "latest.json を書かない" "0" "$( [[ -r "$EVDIR/oe-confirm/latest.json" ]] && echo 1 || echo 0 )"
rmdir "$EVDIR/oe-confirm/.lock" 2>/dev/null || true
OUT="$(run 1789129200 --notify --write-latest 2>&1)"
ck  "ロックが空けば書ける" "1" "$( [[ -r "$EVDIR/oe-confirm/latest.json" ]] && echo 1 || echo 0 )"

echo "[17b] 古いロックは回収する（プロセス死の残骸で永久に黙らない）"
mkfix f17b
sent "2026-09-11T12:00:00+00:00" "%61" "%53" "$N1" "STALELOCK"
mkdir -p "$EVDIR/oe-confirm/.lock"
OUT="$(env PATH="$STUB_BIN:$PATH" OE_EVENT_DIR="$EVDIR" OE_CONFIRM_NOW_EPOCH=1789129200 \
  OE_CONFIRM_LOCK_STALE_SEC=0 bash "$OE_CONFIRM" --write-latest 2>&1)"
ckc "古いロックを回収したと告げる" "$OUT" "古いロックを回収しました"
ck  "回収後は書ける" "1" "$( [[ -r "$EVDIR/oe-confirm/latest.json" ]] && echo 1 || echo 0 )"

# ============================================================================
echo "[18] 走査状態の破損 — 壊れていたら watermark を引き直す（一斉に鳴らさない）"
mkfix f18
RD3="$_TMP_DIR/reports3"; mkdir -p "$RD3"
printf 'a
' > "$RD3/report-a.md"; printf 'b
' > "$RD3/report-b.md"
run 1789129200 --reports "$RD3" >/dev/null                 # 初回 watermark
: > "$EVDIR/oe-confirm/reports-state"                       # truncate されたことにする
OUT="$(run 1789129200 --reports "$RD3" 2>&1)"
ckc "破損を告げる"           "$OUT" "走査状態が壊れています"
ncc "既存を一斉に鳴らさない" "$OUT" "report-a.md"
OUT="$(run 1789129200 --reports "$RD3" 2>&1)"
ncc "引き直した後も鳴らさない" "$OUT" "report-a.md"
# 壊れた行が混じっていても、有効な行が在れば通常どおり動く
mkfix f18b
RD4="$_TMP_DIR/reports4"; mkdir -p "$RD4"
printf 'a
' > "$RD4/report-a.md"
run 1789129200 --reports "$RD4" >/dev/null
printf 'これは壊れた行\n' >> "$EVDIR/oe-confirm/reports-state"
printf 'c
' > "$RD4/report-c.md"
run 1789129200 --reports "$RD4" >/dev/null                  # c は pending
OUT="$(run 1789129200 --reports "$RD4" 2>&1)"
ncc "壊れた行が在っても破損扱いにしない" "$OUT" "走査状態が壊れています"
ckc "新しい file は通常どおり出る"       "$OUT" "report-c.md"

echo ""
echo "=== test_oe_confirm: PASS=$PASS FAIL=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
