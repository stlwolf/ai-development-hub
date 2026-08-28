#!/usr/bin/env bash
# statusline-oe-heartbeat.sh — #239 段階1 PR-A: statusLine 拍動 producer（sidecar write）
#
# Claude Code の statusLine コマンドとして invocation 毎（event 駆動 + refreshInterval の idle timer）に
# 走り、session の「拍動（heartbeat）」を sidecar ファイルへ best-effort で書く producer。
# out-of-session の consumer（#239 PR-B）が拍動鮮度と context% 閾値を read して owner に ping する。
#
# 契約（PR-A が正本として定義・PR-B が read する前提）:
#   - sidecar パス : ${OE_HEARTBEAT_DIR:-${HOME}/.claude/state/oe-heartbeat}/<session_id>.json
#                    <session_id> は stdin JSON の .session_id（session 安定。実体は UUIDv4 で、
#                    以前この行が ULID と書いていたのは誤り＝#327 で実データと照合して訂正）。
#   - sidecar 内容 : {"ts":<epoch秒>, "context_pct":<0-100>, "pane":"<tmux pane|空>",
#                     "server_pid":"<tmux server pid|空>",
#                     "model":{"id":"<model id>","display_name":"<表示名>"}|{}}
#       ts          = date +%s（BSD/GNU 両可搬・bin/oe-undelivered:100 と同型）
#       context_pct = stdin .context_window.used_percentage（null/早期は // 0 fallback）
#       pane        = ${TMUX_PANE:-}（statusLine 実行 env に伝播すれば載る。stdin には tmux pane 情報が
#                     無いため env から取得する。伝播しない環境では空になり、consumer は session_id
#                     主キー + board 突合で pane を解決する＝空でも契約は保たれる）
#       server_pid  = $TMUX の pid 部（lib/delegate-registry.sh の _oe_reg_server_pid と同一の導出）。
#                     pane 番号は tmux server 内でのみ一意なので、pane だけでは別 server の同番ペインと
#                     衝突する。registry が <server_pid>_<pane> でキーを名前空間化しているのと同じ理由で
#                     持たせる（#327）。$TMUX 不在・pid が数値でない場合は空。
#       model       = stdin .model の id と display_name。**.model が object でないとき（文字列 / null /
#                     欠落）は {} を書く**。素朴に .model.id を引くと jq が "Cannot index string with
#                     string" で落ち、書き込み全体が失敗して既存キーの契約まで死ぬ（#327 で実測）。
#                     display_name は 1M 版の区別（"Opus 5 (1M context)"）を末尾に持つので、消費者側で
#                     頭から切らないこと。**id / display_name は string 以外なら空にする** — 配列や
#                     object をそのまま保存すると、消費者側の @tsv が rc=5 で落ちて sidecar のレコード
#                     全体（有効な ts / context_pct / pane を含む）が脱落する（#327 の実装SO 指摘）。
#   - write は atomic（同一 dir 内 temp + rename）。毎秒級 write × 別プロセス read の競合で
#     consumer が半端な JSON を読まないようにする。
#
# 非破壊（status bar を壊さない）:
#   - sidecar write は side-effect。write が失敗してもスクリプトは通常どおり statusLine 文字列を出力し、
#     exit 0 で終える（best-effort。だから set -e は使わない）。
#   - 既存 statusLine があれば wrap（call-through）して表示を保つ: 環境変数 OE_HEARTBEAT_WRAP_CMD に
#     元コマンドが入っていれば、stdin をそれへ渡してその出力を表示する（sync 側が非破壊 merge で設定）。
#     無ければ beat producer が最小 statusLine（model + context%）を担う。
#
# 既定パスは verb/lib 内でインライン宣言し env で上書き可（lib/event-bus.sh:44-46 idiom）。
# lib/constants.sh には足さない（あそこは engine/project-relative 専用）。テストは OE_HEARTBEAT_DIR で隔離。

set -u

# stdin（statusLine session JSON）を1度だけ読む。
input="$(cat 2>/dev/null || true)"

# 既定 sidecar dir（env で上書き可・テスト隔離）。
# HOME 未設定でも set -u で abort しないよう ${HOME:-} で守る（非破壊契約: 表示を出して exit 0）。
# HOME 空なら既定 dir は /.claude/... となり write は best-effort で失敗し、表示だけ出る。
OE_HEARTBEAT_DIR="${OE_HEARTBEAT_DIR:-${HOME:-}/.claude/state/oe-heartbeat}"

# --- 拍動 write（best-effort side-effect・全失敗を飲み込み status bar を壊さない）---
_oe_heartbeat_write() {
  command -v jq >/dev/null 2>&1 || return 0

  local sid ts pane server_pid dir tmp
  sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)" || return 0
  [[ -n "$sid" ]] || return 0
  # session_id をファイル名として安全な文字集合に限定（区切り混入 / path traversal 防止）。
  [[ "$sid" =~ ^[A-Za-z0-9._-]+$ ]] || return 0

  ts="$(date +%s 2>/dev/null)" || return 0
  [[ "$ts" =~ ^[0-9]+$ ]] || return 0
  pane="${TMUX_PANE:-}"
  # server_pid: $TMUX = "socket,pid,session" の pid 部（_oe_reg_server_pid と同一の導出）。
  # 数値でなければ空にする（偽の名前空間を作らない）。
  server_pid="${TMUX:-}"
  server_pid="${server_pid#*,}"
  server_pid="${server_pid%%,*}"
  [[ "$server_pid" =~ ^[0-9]+$ ]] || server_pid=""
  dir="$OE_HEARTBEAT_DIR"

  mkdir -p "$dir" 2>/dev/null || return 0
  tmp="$(mktemp "${dir}/.hb.XXXXXX" 2>/dev/null)" || return 0
  # 本体は input を主入力に取り、ts/pane/server_pid を注入。context_pct は null/欠落を // 0 で吸収。
  # model は object のときだけ投影する（object 以外を素朴に index すると jq 全体が落ちる＝上の契約参照）。
  if printf '%s' "$input" \
    | jq -c --argjson ts "$ts" --arg pane "$pane" --arg spid "$server_pid" \
        '{ts:$ts,
          context_pct:((.context_window.used_percentage // 0) | tonumber? // 0),
          pane:$pane,
          server_pid:$spid,
          model:(if (.model|type) == "object"
                 then {id:(.model.id | if type == "string" then . else "" end),
                       display_name:(.model.display_name | if type == "string" then . else "" end)}
                 else {} end)}' \
        > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "${dir}/${sid}.json" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  else
    rm -f "$tmp" 2>/dev/null
  fi
  return 0
}
_oe_heartbeat_write || true

# --- 表示（非破壊）---
# 既存 statusLine を wrap: 元コマンドへ stdin を渡し、その出力をそのまま表示（best-effort）。
# eval は set +u の subshell で走らせ、元コマンドが未設定変数を参照しても（通常 shell 同様に
# 空へ）動くようにする（本 producer 自身の set -u で元 statusLine の意味を変えない）。~/ や $VAR
# の展開は %q（sync 側の退避）→ outer shell の語 parse → eval の再 parse を経て保たれる。
if [[ -n "${OE_HEARTBEAT_WRAP_CMD:-}" ]]; then
  if wrapped_out="$(printf '%s' "$input" | ( set +u; eval "${OE_HEARTBEAT_WRAP_CMD}" ) 2>/dev/null)"; then
    printf '%s\n' "$wrapped_out"
    exit 0
  fi
  # wrap 失敗時は最小行へフォールバック（表示を空にしない）。
fi

# 最小 statusLine（model + context% [+ プラン消費% 7d/5h]）。
#
# 人間が /usage で見ているプラン消費率を statusLine に載せる（#276）。stdin JSON の
# rate_limits.{seven_day,five_hour}（used_percentage / resets_at）を使う。これらは
# Pro/Max 等のサブスク認証時・初回 API 応答後のみ載る（API 利用時などは欠落）。
#   - 7d（週次）  : 常時表示・パーセントのみ。context% の右隣。
#   - 5h（5時間枠）: used_percentage >= 閾値（既定 80・OE_STATUSLINE_5H_THRESHOLD で上書き可）の
#                    ときだけ、7d の右にリセット残り時間つきで表示（出るときは最右）。
# 欠落・非数値・rate_limits 非提供では当該セグメントを黙って出さない（表示は壊さない）。
# context% は既存どおり "N% ctx" を連続文字列で保つ（表示アサートは部分一致）。
if command -v jq >/dev/null 2>&1; then
  # プラン消費% セグメント用パラメータ（既定はインライン宣言・env で上書き可: lib idiom）。
  # now が取れないと残り時間が誤値になる。取得失敗時は _now=null を渡し、jq 側で時間表示を抑止する。
  _now="$(date +%s 2>/dev/null)"; [[ "$_now" =~ ^[0-9]+$ ]] || _now=null
  _th="${OE_STATUSLINE_5H_THRESHOLD:-80}"; [[ "$_th" =~ ^[0-9]+([.][0-9]+)?$ ]] || _th=80
  line="$(printf '%s' "$input" \
    | jq -r --argjson now "$_now" --argjson th "$_th" '
        def n($x): ($x | if type=="number" then . else (tonumber? // null) end);
        def remain($resets):
          (($resets - $now) | floor) as $d
          | if $d <= 0 then "0m"
            elif (($d / 3600) | floor) > 0 then "\(($d/3600)|floor)h\((($d%3600)/60)|floor)m"
            else "\(($d/60)|floor)m" end;
        # resets_at と now が両方揃うときだけ残り時間を出す（now 欠落時の誤表示を回避）。
        def reset_suffix($resets):
          if ($resets != null and $now != null) then " (\(remain($resets)))" else "" end;
        ("[\(.model.display_name // "?")] \(.context_window.used_percentage // 0)% ctx") as $base
        | (n(.rate_limits.seven_day.used_percentage?))  as $d7
        | (n(.rate_limits.five_hour.used_percentage?))  as $d5
        | (n(.rate_limits.five_hour.resets_at?))        as $r5
        | ($base
           + (if $d7 != null then " · 7d \($d7|round)%" else "" end)
           + (if ($d5 != null and $d5 >= $th)
                then " · 5h \($d5|round)%" + reset_suffix($r5)
                else "" end))
      ' 2>/dev/null)" || line=""
  if [[ -n "$line" ]]; then
    printf '%s\n' "$line"
  else
    printf '%s\n' "oe-heartbeat"
  fi
else
  printf '%s\n' "oe-heartbeat"
fi

exit 0
