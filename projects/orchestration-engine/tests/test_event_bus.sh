#!/usr/bin/env bash
set -euo pipefail

# test_event_bus.sh — lib/event-bus.sh（#206 増分1 活動ログ emit）の検証。
#
# 実 tmux 不要（emit は file 読みのみ・liveness は viewer 側）。registry/pane-issue は mock し、
# 固定 server pid（TMUX 経由）でキー名前空間を固定する（test_oe_ident と同イディオム）。jq は実体。
# 末尾に oe-delegate を PATH-stub tmux で 1 回起動し、child_spawned が実 bin から emit される
# 結線も検証する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
export OE_EVENT_DIR="$_TMP_DIR/events"
export OE_DELEGATE_STATE_DIR="$_TMP_DIR/oe-delegate"
export OE_PANE_ISSUE_DIR="$_TMP_DIR/pane-issue"
mkdir -p "$OE_EVENT_DIR" "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"
EVENTS="$OE_EVENT_DIR/oe-events.jsonl"

# shellcheck source=../lib/delegate-registry.sh
source "$PROJECT_DIR/lib/delegate-registry.sh"
# shellcheck source=../lib/event-bus.sh
source "$PROJECT_DIR/lib/event-bus.sh"

PID=9999
export TMUX="oe,${PID},0"
keyfor() { TMUX="oe,${PID},0" _oe_reg_key "$1"; }

PASS=0; FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then echo "  PASS: $label"; PASS=$((PASS+1));
  else echo "  FAIL: $label (want=[$expected] got=[$actual])"; FAIL=$((FAIL+1)); fi
}
reset_events() { : > "$EVENTS"; }
last() { tail -n 1 "$EVENTS"; }
nlines() { [[ -s "$EVENTS" ]] && wc -l < "$EVENTS" | tr -d '[:space:]' || echo 0; }

# --- mock 状態: parent %59（pane-issue ラベル）、child %66（spawn entry・parent=%59）---
printf '{"name":"#206 inbox"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %59)"
jq -cn '{pane:"%66",label:"#206 impl",workspace:"/w",parent_pane:"%59",role:"child"}' \
  > "$OE_DELEGATE_STATE_DIR/$(keyfor %66).json"

echo "[1] child_spawned: from=parent(label 解決) / to=child(label 引数) / role 固定"
reset_events
oe_event_child_spawned "%59" "%66" "#206 impl"
ck "type"        "child_spawned"  "$(last | jq -r .type)"
ck "from.pane"   "%59"            "$(last | jq -r .from.pane)"
ck "from.role"   "parent"         "$(last | jq -r .from.role)"
ck "from.label"  "#206 inbox"     "$(last | jq -r .from.label)"
ck "to.pane"     "%66"            "$(last | jq -r .to.pane)"
ck "to.role"     "child"          "$(last | jq -r .to.role)"
ck "to.label"    "#206 impl"      "$(last | jq -r .to.label)"
ck "ts present"  "true"           "$(last | jq -r '(.ts|type=="string") and (.ts|length>0)')"

echo "[1b] child_spawned: permission_mode / elevated を extra に焼き込む・省略時は無し（#262）"
reset_events
oe_event_child_spawned "%59" "%66" "#206 impl" "auto" "true"
ck "permission_mode=auto"          "auto"  "$(last | jq -r '.permission_mode // "MISSING"')"
ck "elevated=true"                 "true"  "$(last | jq -r '.elevated')"
reset_events
oe_event_child_spawned "%59" "%66" "#206 impl" "auto"
ck "elevated 省略時は false"        "false" "$(last | jq -r '.elevated')"
reset_events
oe_event_child_spawned "%59" "%66" "#206 impl"
ck "pmode/elevated 両省略で pmode 無し" "null" "$(last | jq -r '.permission_mode')"
ck "両省略で elevated も無し"           "null" "$(last | jq -r '.elevated')"

echo "[2] message_sent report（子→親）: 直接 parent リンクで from=child/to=parent に確定"
reset_events
oe_event_message_sent "%66" "%59" "実装完了しました" "none"
ck "type"           "message_sent" "$(last | jq -r .type)"
ck "from.role=child" "child"       "$(last | jq -r .from.role)"
ck "to.role=parent"  "parent"      "$(last | jq -r .to.role)"
ck "preview"         "実装完了しました" "$(last | jq -r .preview)"
ck "delivery none"   "none"        "$(last | jq -r .delivery_signal)"

echo "[3] message_sent kick（親→子）: from=parent/to=child・delivery=suspected_miss"
reset_events
oe_event_message_sent "%59" "%66" "増分1を進めて" "suspected_miss"
ck "from.role=parent" "parent"        "$(last | jq -r .from.role)"
ck "to.role=child"    "child"         "$(last | jq -r .to.role)"
ck "delivery miss"    "suspected_miss" "$(last | jq -r .delivery_signal)"

echo "[4] preview 切り詰め: >100 codepoint → 100 + … (length 101)・末尾 …"
reset_events
LONG="$(printf 'あ%.0s' {1..150})"
oe_event_message_sent "%66" "%59" "$LONG" "none"
ck "preview length 101" "101" "$(last | jq -r '.preview|length')"
ck "preview ends …"     "true" "$(last | jq -r '.preview|endswith("…")')"

echo "[5] preview ≤100 はそのまま（… を付けない）"
reset_events
oe_event_message_sent "%66" "%59" "短い報告" "none"
ck "short unchanged" "短い報告" "$(last | jq -r .preview)"

echo "[6] delivery_signal 未知値は none に正規化"
reset_events
oe_event_message_sent "%66" "%59" "x" "garbage-value"
ck "unknown→none" "none" "$(last | jq -r .delivery_signal)"

echo "[7] OE_EVENT_LOG=0 で kill-switch（書き込まない）"
reset_events
OE_EVENT_LOG=0 oe_event_child_spawned "%59" "%66" "#206 impl"
OE_EVENT_LOG=0 oe_event_message_sent "%59" "%66" "x" "none"
ck "no write when off" "0" "$(nlines)"

echo "[8] label 内の改行（JSON 文字列内エスケープ）は焼く前に畳む（行境界の偽造防止）"
reset_events
printf '%s' '{"name":"#206\ninbox"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %59)"  # JSON 内 escape \n
oe_event_child_spawned "%59" "%66" "#206 impl"
ck "1 physical line" "1" "$(nlines)"
ck "label folded"    "#206 inbox" "$(last | jq -r .from.label)"

echo "[8b] label 内 TAB/US も畳む（_oe_event_ident の US 区切り内部プロトコルを守る・実装SO cursor 指摘）"
printf '%s' '{"name":"foo\tbar"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %59)"  # JSON 文字列内の TAB
IFS=$'\037' read -r _ _l _p < <(_oe_event_ident "%59") || true
ck "tab folded in label"       "foo bar" "$_l"
ck "parent not shifted by tab" ""        "$_p"   # %59 は own entry 無し ＝ parent 空のはず
printf '%s' '{"name":"foo\u001fbar"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %59)"  # JSON escape の US
IFS=$'\037' read -r _ _l _p < <(_oe_event_ident "%59") || true
ck "US folded in label"        "foo bar" "$_l"
ck "parent not shifted by US"  ""        "$_p"
printf '%s' '{"name":"foo\tbar"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %59)"  # TAB へ戻す（下の burn 検証は TAB fixture）
reset_events
oe_event_message_sent "%66" "%59" "x" "none"      # %66→%59（report）。to=%59 の label が焼かれる
ck "burned label tab-folded"   "foo bar" "$(last | jq -r .to.label)"
printf '%s' '{"name":"#206 inbox"}' > "$OE_PANE_ISSUE_DIR/$(keyfor %59)"  # 復元

echo "[9] 関係不明（spawn 関係の無い 2 ペイン）: role は空・fallback で type は出る"
reset_events
oe_event_message_sent "%80" "%81" "side chat" "none"
ck "from.role empty" "" "$(last | jq -r .from.role)"
ck "to.role empty"   "" "$(last | jq -r .to.role)"
ck "type"            "message_sent" "$(last | jq -r .type)"

echo "[9b] 自己 root entry（parent 空）: _oe_event_ident の role は中立（child でない）・#259 述語締め"
# 子を持つ前に評価する（is_parent 判定より先）。parent 空 → is_child=0 → role 空。
jq -cn '{pane:"%90",label:"#259 sup",workspace:"/w",parent_pane:"",role:"child"}' \
  > "$OE_DELEGATE_STATE_DIR/$(keyfor %90).json"
IFS=$'\037' read -r _r90 _l90 _p90 < <(_oe_event_ident "%90") || true
ck "self-root role neutral"  ""         "$_r90"
ck "self-root label kept"    "#259 sup" "$_l90"
ck "self-root parent empty"  ""         "$_p90"

echo "[9c] 既存形（parent 非空）は child のまま（既存データに bit-identical）"
jq -cn '{pane:"%91",label:"#c",workspace:"/w",parent_pane:"%90",role:"child"}' \
  > "$OE_DELEGATE_STATE_DIR/$(keyfor %91).json"
IFS=$'\037' read -r _r91 _ _ < <(_oe_event_ident "%91") || true
ck "existing-shape still child" "child" "$_r91"

echo "[10] 結線: oe-delegate を PATH-stub tmux で起動 → child_spawned が実 bin から emit"
reset_events
STUB_BIN="$_TMP_DIR/bin"; mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  split-window) printf '%%9\n' ;;
  list-panes)   printf '%%1\n%%9\n' ;;
  send-keys)    : ;;
  display-message) printf '0\n' ;;
  *) : ;;
esac
exit 0
EOF
chmod +x "$STUB_BIN/tmux"
# claude を no-op に（子コマンドは split-window が無視するので不要だが PATH は隔離）。
env PATH="$STUB_BIN:$PATH" TMUX="oe,${PID},0" TMUX_PANE="%1" \
    OE_DELEGATE_WAIT_SEC=0 OE_SEND_FINALIZE=0 OE_SEND_ENTER_DELAY=0 \
    OE_EVENT_DIR="$OE_EVENT_DIR" OE_DELEGATE_STATE_DIR="$OE_DELEGATE_STATE_DIR" OE_PANE_ISSUE_DIR="$OE_PANE_ISSUE_DIR" \
    bash "$PROJECT_DIR/bin/oe-delegate" --label "#child" -- "やること" >/dev/null 2>&1 || true
ck "child_spawned emitted" "1" "$(jq -rs '[.[]|select(.type=="child_spawned" and .to.pane=="%9")]|length' "$EVENTS" 2>/dev/null || echo 0)"
ck "child label burned-in" "#child" "$(jq -rs 'map(select(.type=="child_spawned"))[-1].to.label' "$EVENTS" 2>/dev/null || echo MISSING)"

echo "[11] 非数値 OE_EVENT_PREVIEW_MAX でも emit は no-op にならない（100 fallback・Copilot 指摘）"
reset_events
OE_EVENT_PREVIEW_MAX="abc" oe_event_message_sent "%66" "%59" "$(printf 'A%.0s' {1..150})" "none" 2>/dev/null
ck "still emitted (not silent no-op)" "1" "$(nlines)"
ck "preview fell back to 100+…"       "101" "$(last | jq -r '.preview|length')"
warn="$(OE_EVENT_PREVIEW_MAX="abc" oe_event_message_sent "%66" "%59" "x" "none" 2>&1 >/dev/null)"
case "$warn" in *非数値*) ck "warn emitted" "1" "1" ;; *) ck "warn emitted" "1" "0" ;; esac

echo "[12] state dir 未設定でも event-bus.sh が既定を入れる（root glob 防止・Copilot 指摘）"
# _oe_reg_key を他所が定義済 ＝ delegate-registry.sh は source されない経路を再現し、
# event-bus.sh 自身の fallback 既定が効くことを確認する。PROJECT_DIR は env で渡し inner bash で展開する。
# shellcheck disable=SC2016  # bash -c 本文の $ は inner shell で展開させる意図
defs="$(env -u OE_DELEGATE_STATE_DIR -u OE_PANE_ISSUE_DIR PROJECT_DIR="$PROJECT_DIR" bash -c '
  _oe_reg_key() { printf "k_%s" "$1"; }
  _oe_reg_server_pid() { printf "9999"; }
  source "$PROJECT_DIR/lib/event-bus.sh"
  printf "%s|%s" "${OE_DELEGATE_STATE_DIR:-EMPTY}" "${OE_PANE_ISSUE_DIR:-EMPTY}"')"
ck "state dir defaulted (not empty)"  "1" "$([[ -n "${defs%|*}" && "${defs%|*}" != "EMPTY" ]] && echo 1 || echo 0)"
ck "pane-issue dir defaulted (not empty)" "1" "$([[ -n "${defs#*|}" && "${defs#*|}" != "EMPTY" ]] && echo 1 || echo 0)"

echo "[13] report_received（#206A）: 純 emit・covers 焼込・関係 role 上書き（親が子の報告に受領印）"
# [10] の oe-delegate 実行が registry を GC する（stub list-panes に %66 が居ない）ため、
# 関係 role の検証用に %66 entry を再作成する。
jq -cn '{pane:"%66",label:"#206 impl",workspace:"/w",parent_pane:"%59",role:"child"}' \
  > "$OE_DELEGATE_STATE_DIR/$(keyfor %66).json"
reset_events
oe_event_report_received "%59" "%66" 3 "2026-07-02T10:06:00+00:00"
ck "type"              "report_received" "$(last | jq -r .type)"
ck "from.pane=受領者"   "%59"             "$(last | jq -r .from.pane)"
ck "from.role=parent"  "parent"          "$(last | jq -r .from.role)"
ck "to.pane=報告元"     "%66"             "$(last | jq -r .to.pane)"
ck "to.role=child"     "child"           "$(last | jq -r .to.role)"
ck "covers_count"      "3"               "$(last | jq -r .covers_count)"
ck "covers_count is number" "number"     "$(last | jq -r '.covers_count|type')"
ck "covers_last_ts"    "2026-07-02T10:06:00+00:00" "$(last | jq -r .covers_last_ts)"

echo "[14] report_received: 不正 covers は emit しない（schema 違反行を作らない・常に rc=0）"
reset_events
rc=0; oe_event_report_received "%59" "%66" 0 "2026-07-02T10:06:00+00:00" || rc=$?
ck "covers=0 rc=0"      "0" "$rc"
rc=0; oe_event_report_received "%59" "%66" "abc" "2026-07-02T10:06:00+00:00" || rc=$?
ck "covers=abc rc=0"    "0" "$rc"
rc=0; oe_event_report_received "%59" "%66" 3 "" || rc=$?
ck "frontier空 rc=0"    "0" "$rc"
rc=0; OE_EVENT_LOG=0 oe_event_report_received "%59" "%66" 3 "2026-07-02T10:06:00+00:00" || rc=$?
ck "kill-switch rc=0"   "0" "$rc"
ck "no write (0/abc/空/off)" "0" "$(nlines)"

echo "[15] report_received: spawn 関係の無い 2 ペインでも emit（role は空・honest）"
reset_events
oe_event_report_received "%80" "%81" 1 "2026-07-02T10:00:00+00:00"
ck "emitted"         "1"  "$(nlines)"
ck "from.role empty" ""   "$(last | jq -r .from.role)"
ck "to.role empty"   ""   "$(last | jq -r .to.role)"

echo "[16] 回帰: registry GC 後（entry 消滅・pane-issue label のみ）でも label が role 位置へシフトしない"
# TAB 区切り内部プロトコル時代の潜在バグ: role 空 + label あり だと read が先頭 TAB を剥ぎ
# label を role に焼いていた（schema の role enum 違反）。departed children の ack で直撃する。
rm -f "$OE_DELEGATE_STATE_DIR"/*.json
reset_events
oe_event_message_sent "%66" "%59" "after-gc report" "none"
ck "msg from.role empty (not label)" ""           "$(last | jq -r .from.role)"
ck "msg to.role empty (not label)"   ""           "$(last | jq -r .to.role)"
ck "msg to.label = pane-issue label" "#206 inbox" "$(last | jq -r .to.label)"
oe_event_report_received "%59" "%66" 1 "2026-07-02T10:30:00+00:00"
ck "ack from.role empty (not label)" ""           "$(last | jq -r .from.role)"
ck "ack from.label = pane-issue label" "#206 inbox" "$(last | jq -r .from.label)"

echo "[17] #224: preview を write-time で無害化して保存（tool-call タグ/box-drawing/制御文字）"
# 制御文字/box はソースにリテラル直書きせず printf 8進で生成（#224 NEGATIVE KNOWLEDGE）:
#   \342\224\200 = U+2500 '─'（box-drawing） / \037 = US（制御文字）
reset_events
PL="$(printf '<invoke name="Bash">\342\224\200\037end')"
oe_event_message_sent "%66" "%59" "$PL" "none"
ck "stored preview sanitized" '< invoke name="Bash"> end' "$(last | jq -r .preview)"

echo "[18] #224: 誤爆しない — 正当な court を含む送信の preview は壊れない"
reset_events
oe_event_message_sent "%66" "%59" "The court ruled today" "none"
ck "legit court prose intact" "The court ruled today" "$(last | jq -r .preview)"

echo "[19] #224: 100cp truncate（preview 長の責務）は helper 無害化後も従来どおり効く"
reset_events
oe_event_message_sent "%66" "%59" "$(printf 'あ%.0s' {1..150})" "none"
ck "still 100+… after sanitize" "101" "$(last | jq -r '.preview|length')"

echo "[20] #299 P0: delivery_signal の enum に unknown を additive 追加（none は上書きしない）"
reset_events
oe_event_message_sent "%66" "%59" "u" "unknown"
ck "unknown を受理して書く"        "unknown"        "$(last | jq -r .delivery_signal)"
oe_event_message_sent "%66" "%59" "n" "none"
ck "none は従来どおり"             "none"           "$(last | jq -r .delivery_signal)"
# suspected_miss は #299 P0 で書き込みを止めたが、正規化の受理値としては残す（呼び出し側が渡した
# 事実を黙って none へ潰さない）。書き込みを止めたのは delegate-send 側であり、ここではない。
oe_event_message_sent "%66" "%59" "s" "suspected_miss"
ck "suspected_miss は受理値に残す" "suspected_miss" "$(last | jq -r .delivery_signal)"
oe_event_message_sent "%66" "%59" "b" "bogus"
ck "未知値は none へ正規化"        "none"           "$(last | jq -r .delivery_signal)"

echo "[21] #299: delivery_receipt.nonce（送信側の相関 ID・任意）"
reset_events
NONCE_OK="01KZ1VQA1979K4S2MMH5YY24ZJ"
oe_event_message_sent "%66" "%59" "with-nonce" "unknown" "$NONCE_OK"
ck "nonce を焼く"           "$NONCE_OK" "$(last | jq -r '.delivery_receipt.nonce')"
oe_event_message_sent "%66" "%59" "no-nonce" "unknown"
ck "nonce 省略時は付けない" "null"      "$(last | jq -r '.delivery_receipt // "null"')"
# 壊れた nonce は「黙って捨てる」のでなく warn を出してから落とす（環境エラーとデータ不在を分ける）。
_err="$(oe_event_message_sent "%66" "%59" "bad-nonce" "unknown" "not-a-ulid" 2>&1 >/dev/null)"
ck "壊れた nonce は warn を出す"          "1"    "$(printf '%s' "$_err" | grep -c 'ULID の形ではない')"
ck "壊れた nonce では receipt を付けない" "null" "$(last | jq -r '.delivery_receipt // "null"')"
ck "壊れた nonce でも message_sent は残る" "message_sent" "$(last | jq -r .type)"

echo "[22] #299 P1: prompt_received は report_received と別イベント（意味を継がない）"
# [16] が registry GC を模擬して spawn entry を消しているので、role 解決を見る本ブロックでは
# fixture を張り直す（緩めるのでなく前提を戻す）。
jq -cn '{pane:"%66",label:"#206 impl",workspace:"/w",parent_pane:"%59",role:"child"}' \
  > "$OE_DELEGATE_STATE_DIR/$(keyfor %66).json"
reset_events
# from=取り込んだ側（子 %66）/ to=送信元（親 %59）。関係で role を確定する。
oe_event_prompt_received "%66" "%59" "$NONCE_OK"
ck "type"                      "prompt_received" "$(last | jq -r .type)"
ck "nonce"                     "$NONCE_OK"       "$(last | jq -r .nonce)"
ck "from=取り込んだ側"          "%66"             "$(last | jq -r .from.pane)"
ck "from.role"                 "child"           "$(last | jq -r .from.role)"
ck "to=送信元"                  "%59"             "$(last | jq -r .to.pane)"
ck "to.role"                   "parent"          "$(last | jq -r .to.role)"
# covers_* を持たない = report_received（読んだ）の意味を継がない。
ck "covers_count を持たない"    "null" "$(last | jq -r '.covers_count // "null"')"
ck "covers_last_ts を持たない"  "null" "$(last | jq -r '.covers_last_ts // "null"')"
ck "1 行だけ"                   "1"    "$(nlines)"

echo "[23] #299 P1: nonce 無し/壊れは emit しない（無しは無音・壊れは warn）"
reset_events
_err="$(oe_event_prompt_received "%66" "%59" "" 2>&1 >/dev/null)"
ck "nonce 無しは emit しない" "0" "$(nlines)"
ck "nonce 無しは無音（人の手打ちで stderr を鳴らさない）" "" "$_err"
_err="$(oe_event_prompt_received "%66" "%59" "not-a-ulid" 2>&1 >/dev/null)"
ck "壊れた nonce は emit しない" "0" "$(nlines)"
ck "壊れた nonce は warn を出す" "1" "$(printf '%s' "$_err" | grep -c 'ULID の形ではない')"

echo "[24] #299 P1: 同じ nonce の重複は write 側で潰さない（append-only を保つ・畳むのは read 側）"
reset_events
oe_event_prompt_received "%66" "%59" "$NONCE_OK"
oe_event_prompt_received "%66" "%59" "$NONCE_OK"
ck "2 行とも追記される" "2" "$(nlines)"
ck "read 側で畳めば受領は 1 件" "1" \
  "$(jq -rs '[.[] | select(.type=="prompt_received") | .nonce] | unique | length' "$EVENTS")"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
