#!/usr/bin/env bash
set -uo pipefail

# test_prompt_receipt.sh — #299 P1/P3 の検証。
#   1) canonical/hooks/scripts/oe-prompt-receipt.sh（受け手側の取り込み印）
#   2) bin/oe-selfcheck（版に固定された前提の点検・3値判定）
#
# 実 tmux 不要。hook は stdin の payload と env（TMUX_PANE / TMUX）だけで動くので、
# 隔離した OE_EVENT_DIR に対して直接叩く。selfcheck は env で各置き場を差し替えて
# 「陽性対照が無いときに ok を名乗らない」ことを見る。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
HOOK="$REPO_DIR/canonical/hooks/scripts/oe-prompt-receipt.sh"
SELFCHECK="$PROJECT_DIR/bin/oe-selfcheck"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }
[[ -f "$HOOK" ]] || { echo "FAIL: hook not found: $HOOK"; exit 1; }

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

PASS=0; FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then echo "  PASS: $label"; PASS=$((PASS+1));
  else echo "  FAIL: $label (want=[$expected] got=[$actual])"; FAIL=$((FAIL+1)); fi
}

NONCE="01KZ1VQA1979K4S2MMH5YY24ZJ"
NONCE2="01KZ1VQA1979K4S2MMH5YY24ZK"

new_env() {   # 隔離した state を作り、送信 1 件（nonce 付き）を仕込む
  EVDIR="$_TMP_DIR/ev$RANDOM"; mkdir -p "$EVDIR"
  EVFILE="$EVDIR/oe-events.jsonl"
  DIAG="$EVDIR/oe-receipt-diag.jsonl"
  jq -cn --arg n "$NONCE" \
    '{ts:"2026-08-03T00:00:00+00:00",type:"message_sent",
      from:{pane:"%59",role:"parent",label:"boss"},to:{pane:"%66",role:"child",label:"kid"},
      preview:"hi",delivery_signal:"unknown",delivery_receipt:{nonce:$n}}' > "$EVFILE"
}
run_hook() { # run_hook <prompt-json-string> [env assignments...]
  printf '%s' "$1" | OE_EVENT_DIR="$EVDIR" TMUX_PANE="${HP_PANE-%66}" TMUX="${HP_TMUX-oe,9999,0}" \
    bash "$HOOK" 2>"$_TMP_DIR/err.txt"
}
last_ev() { tail -n 1 "$EVFILE"; }
nlines()  { [[ -s "$EVFILE" ]] && wc -l < "$EVFILE" | tr -d '[:space:]' || echo 0; }

echo "[1] タグ付き prompt: ペインに束縛された取り込み印が出る / stdout は汚さない"
new_env
out="$(run_hook "$(jq -cn --arg n "$NONCE" '{prompt:("やって [oe:" + $n + "]")}')")"
ck "stdout は空（モデル文脈を汚さない）" ""                 "$out"
ck "stderr は空"                        ""                 "$(cat "$_TMP_DIR/err.txt")"
ck "type"                               "prompt_received"  "$(last_ev | jq -r .type)"
ck "from=取り込んだ側のペイン"           "%66"              "$(last_ev | jq -r .from.pane)"
# 送信元は emit 時点で引けない（送信側は finalize 後に message_sent を書くので受領印が先）。
# read 側が nonce で突き合わせる。空 = 不明を honest に空で表す。
ck "to は空（送信元は read 時に nonce で解決する）" ""      "$(last_ev | jq -r .to.pane)"
ck "nonce"                              "$NONCE"           "$(last_ev | jq -r .nonce)"
ck "covers_count を持たない（report_received の意味を継がない）" "null" "$(last_ev | jq -r '.covers_count // "null"')"

echo "[2] タグ無し prompt: 何も書かない・無音（データ不在は環境エラーではない）"
new_env
before="$(nlines)"
out="$(run_hook '{"prompt":"ふつうの手打ちプロンプト"}')"
ck "追記しない"   "$before" "$(nlines)"
ck "stdout 空"    ""        "$out"
ck "stderr 空"    ""        "$(cat "$_TMP_DIR/err.txt")"
ck "診断も書かない" "0"       "$([[ -f "$DIAG" ]] && wc -l < "$DIAG" | tr -d '[:space:]' || echo 0)"

echo "[3] TMUX_PANE が無い: 束縛できないので環境エラーとして診断に残す（黙って捨てない）"
new_env
before="$(nlines)"
out="$(printf '%s' "$(jq -cn --arg n "$NONCE" '{prompt:("x [oe:" + $n + "]")}')" \
  | OE_EVENT_DIR="$EVDIR" env -u TMUX_PANE bash "$HOOK" 2>"$_TMP_DIR/err.txt")"
ck "受領印は書かない"     "$before" "$(nlines)"
ck "stdout 空"           ""        "$out"
ck "stderr に出す"        "1"       "$(grep -c 'no-tmux-pane' "$_TMP_DIR/err.txt")"
ck "診断ファイルへ残す"    "1"       "$(jq -rs '[ .[] | select(.reason=="no-tmux-pane") ] | length' "$DIAG" 2>/dev/null)"
ck "診断は env-error 種別" "env-error" "$(jq -rs '.[0].kind' "$DIAG" 2>/dev/null)"

echo "[4] 送信ログに無い nonce でも印は出す（突き合わせは read 側の責務）"
new_env
out="$(run_hook "$(jq -cn --arg n "$NONCE2" '{prompt:("y [oe:" + $n + "]")}')")"
ck "印は出る"           "prompt_received" "$(last_ev | jq -r .type)"
ck "送信元は空"          ""                "$(last_ev | jq -r .to.pane)"
ck "nonce は保つ"        "$NONCE2"         "$(last_ev | jq -r .nonce)"
ck "環境エラーにはしない" "0"               "$([[ -f "$DIAG" ]] && wc -l < "$DIAG" | tr -d '[:space:]' || echo 0)"

echo "[5] 本文に複数タグ: 末尾側を採る（引用された古いタグに引っ張られない）"
new_env
out="$(run_hook "$(jq -cn --arg a "$NONCE2" --arg b "$NONCE" \
  '{prompt:("引用 [oe:" + $a + "] のあと本物 [oe:" + $b + "]")}')")"
ck "末尾のタグを採る" "$NONCE" "$(last_ev | jq -r .nonce)"

echo "[6] 同じ nonce の重複: write は追記のみ・read で畳むと 1 件"
new_env
run_hook "$(jq -cn --arg n "$NONCE" '{prompt:("z [oe:" + $n + "]")}')" >/dev/null
run_hook "$(jq -cn --arg n "$NONCE" '{prompt:("z [oe:" + $n + "]")}')" >/dev/null
ck "2 行とも追記" "2" "$(jq -rs '[ .[] | select(.type=="prompt_received") ] | length' "$EVFILE")"
ck "read で畳めば 1 件" "1" "$(jq -rs '[ .[] | select(.type=="prompt_received") | .nonce ] | unique | length' "$EVFILE")"

echo "[7] 壊れたタグ（ULID でない）は拾わない"
new_env
before="$(nlines)"
out="$(run_hook '{"prompt":"w [oe:not-a-ulid]"}')"
ck "追記しない" "$before" "$(nlines)"
ck "stdout 空"  ""        "$out"

echo "[8] oe-selfcheck: 陽性対照が無いときに ok を名乗らない（0 件を不在の証拠にしない）"
[[ -x "$SELFCHECK" ]] || { echo "  SKIP: oe-selfcheck 不在"; }
if [[ -x "$SELFCHECK" ]]; then
  EMPTY="$_TMP_DIR/empty"; mkdir -p "$EMPTY/projects" "$EMPTY/beat" "$EMPTY/state"
  echo '{}' > "$EMPTY/settings.json"
  out="$(OE_EVENT_DIR="$EMPTY/state" OE_HEARTBEAT_DIR="$EMPTY/beat" \
         OE_TRANSCRIPT_DIR="$EMPTY/projects" OE_CLAUDE_SETTINGS="$EMPTY/settings.json" \
         "$SELFCHECK" --json 2>/dev/null)"
  ck "transcript 0 件 → indeterminate（ok ではない）" "indeterminate" \
     "$(printf '%s' "$out" | jq -r '.[] | select(.check=="transcript-format") | .verdict')"
  ck "sidecar 0 件 → indeterminate"                   "indeterminate" \
     "$(printf '%s' "$out" | jq -r '.[] | select(.check=="pane-session-bridge") | .verdict')"
  ck "保持期間 0 件 → indeterminate"                   "indeterminate" \
     "$(printf '%s' "$out" | jq -r '.[] | select(.check=="retention-horizon") | .verdict')"
  ck "hook 未配線 → broken（配線の不在は判定できる）"   "broken" \
     "$(printf '%s' "$out" | jq -r '.[] | select(.check=="hook-contract") | .verdict')"
  ck "ok を名乗った検査は 0 件" "0" \
     "$(printf '%s' "$out" | jq -r '[ .[] | select(.verdict=="ok") ] | length')"

  echo "[9] oe-selfcheck: 送信が在るのに受領印が 0 件なら broken（陽性対照が在るときは断定する）"
  # 配備先は $HOME/.claude/hooks/ である。ここを間違えると「配線はあるが実行可能でない」で
  # broken になり、**別の理由で期待どおりの verdict が出てしまう**（初版のテストがこれで
  # 前段だけ通っていた）。理由まで検証して取り違えを防ぐ。
  WIRED="$_TMP_DIR/wired"; mkdir -p "$WIRED/state" "$WIRED/.claude/hooks"
  cp "$HOOK" "$WIRED/.claude/hooks/oe-prompt-receipt.sh"
  chmod +x "$WIRED/.claude/hooks/oe-prompt-receipt.sh"
  jq -cn '{hooks:{UserPromptSubmit:[{hooks:[{type:"command",command:"$HOME/.claude/hooks/oe-prompt-receipt.sh"}]}]}}' \
    > "$WIRED/settings.json"
  # 時刻は過去の固定 epoch を使う。未来の ts だと猶予判定で母集団から外れ indeterminate になる
  # （初版のテストがこれで落ちた。実装ではなく fixture の誤り）。
  # 2026-07-02T00:00:00+00:00 = 1782950400 / now は +1h の 1782954000。
  jq -cn --arg n "$NONCE" \
    '{ts:"2026-07-02T00:00:00+00:00",type:"message_sent",
      from:{pane:"%59",role:"parent",label:"b"},to:{pane:"%66",role:"child",label:"k"},
      preview:"hi",delivery_signal:"unknown",delivery_receipt:{nonce:$n}}' > "$WIRED/state/oe-events.jsonl"
  SC_NOW=1782954000
  out="$(HOME="$WIRED" OE_EVENT_DIR="$WIRED/state" OE_HEARTBEAT_DIR="$_TMP_DIR/none" \
         OE_TRANSCRIPT_DIR="$_TMP_DIR/none" OE_CLAUDE_SETTINGS="$WIRED/settings.json" \
         OE_SELFCHECK_NOW_EPOCH="$SC_NOW" "$SELFCHECK" --json 2>/dev/null)"
  ck "送信あり受領印 0 → broken" "broken" \
     "$(printf '%s' "$out" | jq -r '.[] | select(.check=="hook-contract") | .verdict')"
  ck "broken の理由が「直近に受領印が無い」であること（配線不備で通っていないこと）" "1" \
     "$(printf '%s' "$out" | jq -r '[ .[] | select(.check=="hook-contract") | select(.detail | test("宛先ペインからの受領印が無い")) ] | length')"
  # 受領印を足すと ok へ変わる（同じ経路で陽性を示せる＝検査自体が生きている証明）
  jq -cn --arg n "$NONCE" \
    '{ts:"2026-07-02T00:00:01+00:00",type:"prompt_received",
      from:{pane:"%66",role:"",label:""},to:{pane:"%59",role:"",label:""},nonce:$n}' \
    >> "$WIRED/state/oe-events.jsonl"
  out="$(HOME="$WIRED" OE_EVENT_DIR="$WIRED/state" OE_HEARTBEAT_DIR="$_TMP_DIR/none" \
         OE_TRANSCRIPT_DIR="$_TMP_DIR/none" OE_CLAUDE_SETTINGS="$WIRED/settings.json" \
         OE_SELFCHECK_NOW_EPOCH="$SC_NOW" "$SELFCHECK" --json 2>/dev/null)"
  ck "受領印を足すと ok（検査が生きている陽性対照）" "ok" \
     "$(printf '%s' "$out" | jq -r '.[] | select(.check=="hook-contract") | .verdict')"
fi


echo "[10] hook 契約が変わった疑い（.prompt からタグを取り出せない）は環境エラーにする"
new_env
before="$(nlines)"
# 生の payload にはタグが在るが .prompt には無い（キー改名を模擬）
out="$(run_hook "$(jq -cn --arg n "$NONCE" '{prompt:"", user_text:("x [oe:" + $n + "]")}')")"
ck "受領印は書かない"       "$before"              "$(nlines)"
ck "stdout 空"             ""                     "$out"
ck "契約変更として診断へ残す" "prompt-field-missing" "$(jq -rs '.[-1].reason' "$DIAG" 2>/dev/null)"
# 一方、.prompt にタグが在るが ULID でない場合は「データの問題」なので無音のまま
new_env
out="$(run_hook '{"prompt":"y [oe:not-a-ulid]"}')"
ck "壊れたタグは無音（契約変更と区別する）" "0" \
   "$([[ -f "$DIAG" ]] && wc -l < "$DIAG" | tr -d '[:space:]' || echo 0)"

echo "[11] oe-selfcheck: 一度成功しても、直近が無印なら broken になる（緑のまま腐らない）"
if [[ -x "$SELFCHECK" ]]; then
  DEC="$_TMP_DIR/decay"; mkdir -p "$DEC/state" "$DEC/.claude/hooks"
  cp "$HOOK" "$DEC/.claude/hooks/oe-prompt-receipt.sh"; chmod +x "$DEC/.claude/hooks/oe-prompt-receipt.sh"
  jq -cn '{hooks:{UserPromptSubmit:[{hooks:[{type:"command",command:"$HOME/.claude/hooks/oe-prompt-receipt.sh"}]}]}}' \
    > "$DEC/settings.json"
  OLD=01KZ1VQA1979K4S2MMH5YY24ZN; NEW1=01KZ1VQA1979K4S2MMH5YY24ZP
  {
    # 過去: 送信 + 受領印あり（初版はこれだけで永久に ok になっていた）
    jq -cn --arg n "$OLD" '{ts:"2026-07-01T00:00:00+00:00",type:"message_sent",from:{pane:"%59",role:"",label:""},to:{pane:"%66",role:"",label:""},preview:"old",delivery_signal:"unknown",delivery_receipt:{nonce:$n}}'
    jq -cn --arg n "$OLD" '{ts:"2026-07-01T00:00:05+00:00",type:"prompt_received",from:{pane:"%66",role:"",label:""},to:{pane:"",role:"",label:""},nonce:$n}'
    # 直近: 送信のみ（hook が死んだ状態）
    jq -cn --arg n "$NEW1" '{ts:"2026-07-02T10:00:00+00:00",type:"message_sent",from:{pane:"%59",role:"",label:""},to:{pane:"%66",role:"",label:""},preview:"new",delivery_signal:"unknown",delivery_receipt:{nonce:$n}}'
  } > "$DEC/state/oe-events.jsonl"
  # now = 直近送信の十分あと（猶予 60 秒を超える）
  # 2026-07-02T10:00:00+00:00 = 1782986400。猶予（60秒）を超える now と、超えない now を用意する。
  NOWE=1782990000    # +1h
  out="$(HOME="$DEC" OE_EVENT_DIR="$DEC/state" OE_HEARTBEAT_DIR="$_TMP_DIR/none" \
         OE_TRANSCRIPT_DIR="$_TMP_DIR/none" OE_CLAUDE_SETTINGS="$DEC/settings.json" \
         OE_SELFCHECK_RECENT_SENDS=1 OE_SELFCHECK_NOW_EPOCH="$NOWE" \
         "$SELFCHECK" --json 2>/dev/null)"
  ck "直近が無印なら broken（過去の成功で緑にしない）" "broken" \
     "$(printf '%s' "$out" | jq -r '.[] | select(.check=="hook-contract") | .verdict')"

  echo "[12] oe-selfcheck: 送った直後（猶予内）は broken と読まない"
  NOWE2=1782986405   # +5s（猶予内）
  out="$(HOME="$DEC" OE_EVENT_DIR="$DEC/state" OE_HEARTBEAT_DIR="$_TMP_DIR/none" \
         OE_TRANSCRIPT_DIR="$_TMP_DIR/none" OE_CLAUDE_SETTINGS="$DEC/settings.json" \
         OE_SELFCHECK_RECENT_SENDS=1 OE_SELFCHECK_NOW_EPOCH="$NOWE2" \
         "$SELFCHECK" --json 2>/dev/null)"
  ck "猶予内は indeterminate" "indeterminate" \
     "$(printf '%s' "$out" | jq -r '.[] | select(.check=="hook-contract") | .verdict')"

  echo "[13] oe-selfcheck: 受領印が別ペインからでは ok にしない"
  jq -cn --arg n "$NEW1" '{ts:"2026-07-02T10:00:01+00:00",type:"prompt_received",from:{pane:"%98",role:"",label:""},to:{pane:"",role:"",label:""},nonce:$n}' \
    >> "$DEC/state/oe-events.jsonl"
  out="$(HOME="$DEC" OE_EVENT_DIR="$DEC/state" OE_HEARTBEAT_DIR="$_TMP_DIR/none" \
         OE_TRANSCRIPT_DIR="$_TMP_DIR/none" OE_CLAUDE_SETTINGS="$DEC/settings.json" \
         OE_SELFCHECK_RECENT_SENDS=1 OE_SELFCHECK_NOW_EPOCH="$NOWE" \
         "$SELFCHECK" --json 2>/dev/null)"
  ck "別ペインの印では broken のまま" "broken" \
     "$(printf '%s' "$out" | jq -r '.[] | select(.check=="hook-contract") | .verdict')"
  # 陽性対照は **hook を実際に通して**作る（fixture を直接 append すると hook 契約の
  # 陽性対照にならない＝「別の理由で通る」テストになる・実装SO codex 指摘）。
  printf '%s' "$(jq -cn --arg n "$NEW1" '{prompt:("ok [oe:" + $n + "]")}')" \
    | OE_EVENT_DIR="$DEC/state" TMUX_PANE=%66 TMUX="oe,9999,0" bash "$HOOK" >/dev/null 2>&1
  ck "hook を通すと受領印が 1 行増える" "1" \
     "$(jq -rs '[ .[] | select(.type=="prompt_received") | select(.nonce==$n) | select(.from.pane=="%66") ] | length' \
        --arg n "$NEW1" < <(jq -R 'fromjson? // empty' "$DEC/state/oe-events.jsonl") 2>/dev/null)"
  out="$(HOME="$DEC" OE_EVENT_DIR="$DEC/state" OE_HEARTBEAT_DIR="$_TMP_DIR/none" \
         OE_TRANSCRIPT_DIR="$_TMP_DIR/none" OE_CLAUDE_SETTINGS="$DEC/settings.json" \
         OE_SELFCHECK_RECENT_SENDS=1 OE_SELFCHECK_NOW_EPOCH="$NOWE" \
         "$SELFCHECK" --json 2>/dev/null)"
  ck "宛先ペイン自身の印なら ok" "ok" \
     "$(printf '%s' "$out" | jq -r '.[] | select(.check=="hook-contract") | .verdict')"
fi

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
