#!/usr/bin/env bash
#
# oe-prompt-receipt.sh — Claude Code UserPromptSubmit hook (#299 P1).
#
# 受け手のセッションが、注入された 1 行を自分のターンとして取り込んだ瞬間に、
# 取り込み印（prompt_received）を活動ログへ追記する。送信側 oe_send_line が payload 末尾へ
# 載せた相関 ID（`[oe:<26 桁>]`）を鍵に、送信と受領を突き合わせる。
#
# 突き合わせの強さ（言い切らない）: 鍵は送信ごとに一意なので原理的には 1 対 1 だが、
# 印が複数行来ることは妨げない（read 側が nonce で畳む）。**「1 対 1 で突き合う」と言えるのは
# read 側が nonce と宛先ペインの両方を見る場合に限る** — nonce だけを見ると、別のペインが
# 同じタグを submit しただけで受領扱いになる。
#
# なぜ受け手側で撃つのか:
#   送信側の画面 scrape では配送を判別できない（実測で信号が逆を指していた・#299）。
#   受け手が自分で撃つ印は $TMUX_PANE に束縛される。ただし**取り違えが起きないのは、read 側が
#   その束縛を実際に照合する場合だけ**である（`oe-undelivered` は nonce と宛先ペインの両方を見る）。
#
# 言えることの範囲（強めない）:
#   この印が言うのは「そのセッションが 1 ターンとして取り込んだ」までである。
#   読んだ・実行した・作業に反映した、ではない。report_received（#206A・「読んだ」）とは
#   別イベントであり、意味を継がない。
#
# 版依存であることを認める:
#   これは Claude Code の hook 契約（イベント名 UserPromptSubmit・stdin の .prompt・
#   $TMUX_PANE が hook の env に伝播すること）に依存する。契約が変われば印は出なくなる。
#   **免疫があるとは言わない。壊れ方がましだと言っている** — 失効した画面の目印（#144 の
#   `esc to interrupt`）は「静かに嘘の値を出し続けた」のに対し、契約が壊れた場合は
#   「印が出なくなる」という観測可能な形で現れる。壊れたことを拾う検査は `oe-selfcheck`。
#
#   **「ましだ」の成立条件を書く。** (a) `oe-selfcheck` が実行されること — 定期実行は未配線で、
#   人が打つまで動かない。(b) read 側が nonce だけでなく宛先ペインまで照合すること。
#   (c) `.prompt` が取れない契約変更が診断へ残ること。(b)(c) は実装したが (a) は残っている。
#   **(a) が埋まるまで「marker よりまし」は条件付きの主張である。**
#
# 自己完結（リポジトリに依存しない）:
#   配備先 ~/.claude/hooks/ から engine の lib は見えないため、他の配備物（notify.sh /
#   statusline-oe-heartbeat.sh）と同じく自前で 1 行 JSON を組む。role と送信元ペインは空にする
#   （不明を honest に空で表す）。識別子と関係は突き合わせ先の message_sent が焼き込んでいるので、
#   ここで再導出しない。
#
# stdout を汚さない:
#   UserPromptSubmit の stdout はモデルの文脈へ注入される。本 hook は stdout へ一切出さない。
#   異常は stderr と診断ファイルへ出す。exit は常に 0（非 0 はプロンプトを止めうるため）。
#
# 失敗を握り潰さない:
#   「環境エラー（jq 不在・ログが書けない・pane が取れない）」と「データ不在（タグの無い
#   通常のプロンプト）」を別に扱う。前者は診断ファイルへ記録する。後者は無音で抜ける
#   （人が手で打つたびに鳴らさない）。
#
set -uo pipefail

payload="$(cat 2>/dev/null || true)"
home="${HOME:-}"
[ -n "$home" ] || exit 0

event_dir="${OE_EVENT_DIR:-${home}/.claude/state}"
event_file="${event_dir}/oe-events.jsonl"
diag_file="${event_dir}/oe-receipt-diag.jsonl"

# JSON 文字列として安全な形へ escape する。この経路は jq が無いときにも通るので素の shell で行う。
# 診断ファイルは後段の集計対象なので、1 行でも壊れた JSONL を書くと以後読めなくなる（Copilot 指摘）。
# **バックスラッシュを最初に処理する** — 後にすると自分が入れた `\` を二重に escape してしまう。
_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# 環境エラーを診断ファイルへ記録する。ここが no-op になると「印が無い理由」が読めなくなるので、
# jq が無い場合でも素の printf で 1 行残す（診断だけは最後まで落とさない）。
note_env_error() {
  local reason="$1" detail="${2:-}"
  mkdir -p "$event_dir" 2>/dev/null || return 0
  printf '{"ts":"%s","hook":"oe-prompt-receipt","kind":"env-error","reason":"%s","detail":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)" "$(_json_escape "$reason")" "$(_json_escape "$detail")" \
    >> "$diag_file" 2>/dev/null || true
  echo "oe-prompt-receipt: ${reason}${detail:+ (${detail})}" >&2
}

if ! command -v jq >/dev/null 2>&1; then
  note_env_error "jq-missing" "受領印を出せない"
  exit 0
fi

# --- タグの有無を先に安く判定する（タグ無し = データ不在 = 無音で抜ける）---
# 大きな prompt を argv へ載せない（ARG_MAX。payload は変数のまま jq の stdin へ流す）。
case "$payload" in
  *'[oe:'*) ;;
  *) exit 0 ;;
esac

# 末尾側の一致を採る。oe_send_line はタグを payload の末尾へ付けるので、本文中に引用された
# 古いタグより後ろに本物が来る。引用の取り違えが起きても read 側が nonce で畳むので害は小さい。
nonce="$(printf '%s' "$payload" \
  | jq -r '[ (.prompt // "") | scan("\\[oe:([0-9A-HJKMNP-TV-Z]{26})\\]") ] | last | if type=="array" then .[0] else (. // empty) end' \
  2>/dev/null)" || nonce=""
if [ -z "$nonce" ] || [ "$nonce" = "null" ]; then
  # ここへ来たのは「生の payload にはタグが在るのに `.prompt` から取り出せなかった」ときである。
  # 原因は2つに分かれ、扱いも別である（黙って同じ無音にしない）。
  #   (a) `.prompt` にタグが在るが ULID の形でない  → データの問題。無音で抜ける。
  #   (b) `.prompt` にタグが無い                     → **hook 契約が変わった疑い**（キー改名 /
  #       本文が別フィールドへ移った 等）。これを「タグ無し」と同じ無音にすると、marker と
  #       同じ「静かに何も起きない」故障になるので環境エラーとして記録する。
  if printf '%s' "$payload" | jq -e '((.prompt // "") | test("\\[oe:"))' >/dev/null 2>&1; then
    exit 0
  fi
  note_env_error "prompt-field-missing" "生の payload にタグが在るのに .prompt から取り出せない（hook 契約の変更を疑う）"
  exit 0
fi

# --- 受け手ペイン。取れなければ束縛できない = 環境エラーとして記録する ---
pane="${TMUX_PANE:-}"
if [ -z "$pane" ]; then
  note_env_error "no-tmux-pane" "タグ付きの prompt を受け取ったがペインに束縛できない"
  exit 0
fi

# --- 送信元ペインは emit 時点では引けない（空のままにする）---
# 初版はここで nonce をログ末尾から引いて送信元を焼こうとしたが、実機ではまず成功しない。
# 送信側 oe_send_line は finalize の観測窓（既定 3 秒）が閉じてから message_sent を書くのに対し、
# 本 hook は submit の瞬間に走るので、受領印のほうが先に書かれるためである（実機 2 件で確認）。
# **「常に」とまでは言わない** — `OE_SEND_FINALIZE=0` の経路やスケジューリング次第では順序が入れ替わりうる。
# ただし成功率が低い lookup を残すと「黙って空へ縮退する」経路になるので消した。
#
# 送信元は read 側が nonce で message_sent と突き合わせて解決する。to.pane は空 = 不明を
# honest に空で表す（endpoint の空文字規約に従う）。
sender=""

# --- 受け手のラベル（pane-issue state・session-name.sh と同じキー規約）---
label=""
server="${TMUX:-}"; server="${server#*,}"; server="${server%%,*}"
if [ -n "$server" ]; then
  key="${server}_${pane}"; key="${key//[^A-Za-z0-9]/_}"
  pane_issue="${home}/.claude/state/pane-issue/${key}"
  if [ -f "$pane_issue" ]; then
    label="$(jq -r '.name // empty' "$pane_issue" 2>/dev/null)" || label=""
  fi
fi

# --- 追記（1 行 JSON・O_APPEND で atomic）---
# role は空にする。関係は突き合わせ先の message_sent が焼き込んでいるので再導出しない。
if ! mkdir -p "$event_dir" 2>/dev/null; then
  note_env_error "event-dir-unwritable" "$event_dir"
  exit 0
fi
line="$(jq -cn \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)" \
  --arg fp "$pane" --arg fl "$label" --arg tp "$sender" --arg nc "$nonce" \
  '{ts:$ts, type:"prompt_received",
    from:{pane:$fp, role:"", label:$fl},
    to:{pane:$tp, role:"", label:""},
    nonce:$nc}' 2>/dev/null)" || {
  note_env_error "encode-failed" "nonce=${nonce}"
  exit 0
}
[ -n "$line" ] || { note_env_error "encode-empty" "nonce=${nonce}"; exit 0; }
printf '%s\n' "$line" >> "$event_file" 2>/dev/null || note_env_error "append-failed" "$event_file"

exit 0
