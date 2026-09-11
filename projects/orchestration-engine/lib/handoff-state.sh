#!/usr/bin/env bash
# handoff-state.sh — 統括の交代で使う「機械で取れる状態」の収集（#390 PR-1）
#
# 引き継ぎ文書のうち観測できる事実の側をここが作る。人が書く側（会話にしか無かったもの）は
# 対象外で、そちらは oe-handoff が空枠として置く。
#
# 本 lib は read-only である。ファイルを1つも書き換えない（呼び出し側が文書を書く）。
#
# 提供する関数:
#   oe_hs_server_pid                  — いまの tmux server の pid（registry と同じ導出）
#   oe_hs_pane_alive <pane>           — pane が tmux に現存するか
#   oe_hs_children_of <pane>          — <pane> を親とする登記のうち、pane が現存するものを1行1件
#   oe_hs_session_for_pane <pane>     — pane から session_id を逆引き（安全側・曖昧なら unknown）
#   oe_hs_context_for_session <sid>   — session_id の拍動から context%（取れなければ unknown）
#   oe_hs_watchdogs                   — 常駐の見張りの登録状態を1行1件
#   oe_hs_repo_state <workspace>      — その workspace の枝 / HEAD / 未 push / worktree の数
#   oe_hs_open_prs <workspace>        — open PR を1行1件（gh が無ければ unknown）
#
# 置き場の env（既存の verb と同じノブを共有する）:
#   OE_DELEGATE_STATE_DIR   登記（既定 ~/.claude/state/oe-delegate）
#   OE_HEARTBEAT_DIR        拍動 sidecar（既定 ~/.claude/state/oe-heartbeat・oe-vitals と共有）
#   OE_TRANSCRIPT_DIR       transcript の置き場（既定 ~/.claude/projects・oe-selfcheck と共有）
#   OE_HS_SERVER_PID        tmux server pid の上書き（主にテストの決定論化用）
#   OE_HS_NOW_EPOCH         now の上書き（主にテストの決定論化用）
#   OE_HS_RESUME_MAX_AGE_SEC  transcript を「開き直せる」と見なす鮮度の窓（既定 86400 秒）
#   OE_HS_BEAT_MAX_AGE_SEC    拍動を「いまの前任のもの」と見なす鮮度の窓（既定 21600 秒）

# HOME を暗黙の既定パスに使ってよいか（delegate-registry.sh と byte 一致させる・#322）。
declare -F _oe_home_usable >/dev/null 2>&1 || _oe_home_usable() {
  case "${HOME:-}" in /|//) return 1;; /*) return 0;; *) return 1;; esac
}

if   [ -n "${OE_DELEGATE_STATE_DIR+x}" ]; then :
elif _oe_home_usable; then OE_DELEGATE_STATE_DIR="${HOME}/.claude/state/oe-delegate"
else                       OE_DELEGATE_STATE_DIR=""
fi
if   [ -n "${OE_HEARTBEAT_DIR+x}" ]; then :
elif _oe_home_usable; then OE_HEARTBEAT_DIR="${HOME}/.claude/state/oe-heartbeat"
else                       OE_HEARTBEAT_DIR=""
fi

# いまの tmux server の pid。$TMUX の2番目のフィールドが server pid（registry と同じ導出）。
# テストでは OE_HS_SERVER_PID で固定する。
oe_hs_server_pid() {
  if [ -n "${OE_HS_SERVER_PID:-}" ]; then printf '%s' "$OE_HS_SERVER_PID"; return 0; fi
  local s="${TMUX:-}"
  s="${s#*,}"; s="${s%%,*}"
  printf '%s' "$s"
}

# 生存するペインの一覧。**引けなかったら失敗する（空を返さない）。**
# 空と「引けなかった」を同じに扱うと、tmux 不在や接続失敗が「生きた子は居ない」に化ける。
oe_hs_alive_panes() {
  command -v tmux >/dev/null 2>&1 || return 2
  local out
  out="$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)" || return 2
  [ -n "$out" ] || return 2
  printf '%s\n' "$out"
}

# pane が tmux に現存するか。list-panes の集合所属で見る（display-message は不在でも
# rc=0 と空を返すので使わない・#291 で踏んだ罠）。
# rc: 0 現存 / 1 不在 / 2 判定できない
oe_hs_pane_alive() {
  local pane="${1:-}" panes
  [ -n "$pane" ] || return 2
  panes="$(oe_hs_alive_panes)" || return 2
  printf '%s\n' "$panes" | grep -qxF -- "$pane"
}

# <pane> を親とする登記のうち、pane が現存するものを1行1件（"<pane> <label>"）。
#
# 錨は「自ペイン」ではなく引数の pane である。oe_reg_list は parent_pane == 自ペイン で
# 数えるので、後継のセッションから前任の子を数える用途には使えない（使うと常に0件になり、
# 「子が居ないから閉じてよい」へ倒れる）。
oe_hs_children_of() {
  local parent="${1:-}" spid panes
  [ -n "$parent" ] || return 2
  [ -n "$OE_DELEGATE_STATE_DIR" ] || return 2
  command -v jq >/dev/null 2>&1 || return 2
  spid="$(oe_hs_server_pid)"
  [ -n "$spid" ] || return 2
  # 生存判定を1回で引く。引けなければ「数えられない」として失敗する（0 件と言わない）。
  panes="$(oe_hs_alive_panes)" || return 2
  [ -d "$OE_DELEGATE_STATE_DIR" ] || return 0
  # 置き場が読めない・辿れないときも「子0件」にしない。glob が展開されずループが回らないだけで、
  # 「登記を見たが子は居なかった」と区別がつかなくなる。
  [ -r "$OE_DELEGATE_STATE_DIR" ] && [ -x "$OE_DELEGATE_STATE_DIR" ] || return 2
  local f pane label parent_of
  # 登記のファイル名は "<server_pid>_<pane>" の非英数を _ にしたもの。**現 server の分だけ見る。**
  # 旧 server の残骸は pane 番号が再利用されているので、混ぜると無関係なペインを子に数える。
  for f in "$OE_DELEGATE_STATE_DIR/${spid}_"*.json; do
    [ -f "$f" ] || continue
    # 壊れて読めない登記を黙って飛ばさない。**それが唯一の生きた子だったときに0件へ倒れる。**
    # JSON として壊れている場合と、必須の項目が欠けている（または文字列でない）場合の両方を
    # 「数えられない」として扱う。親が違うだけの登記は正当なので、それとは区別する。
    if ! parent_of="$(jq -r 'if (.parent_pane | type) == "string" and (.pane | type) == "string"
                             then .parent_pane else "\u0000invalid" end' "$f" 2>/dev/null)"; then
      return 2
    fi
    case "$parent_of" in *invalid) return 2 ;; esac
    [ "$parent_of" = "$parent" ] || continue
    pane="$(jq -r '.pane' "$f" 2>/dev/null)" || return 2
    [ -n "$pane" ] || return 2
    printf '%s\n' "$panes" | grep -qxF -- "$pane" || continue
    label="$(jq -r '.label // ""' "$f" 2>/dev/null)" || label=""
    printf '%s %s\n' "$pane" "$label"
  done
}

# pane から session_id を逆引きする。**いちばん新しい拍動を採り、それが使えるかを確かめる。**
#
# sidecar は掃除されないので、同じ pane 番号の別世代が貯まる（実測で pane を持つ sidecar
# 198 件に対し異なる番号は 171 個。最も多い番号では7件が同じ pane に貯まっていた）。
#
# 最初は「現 server の一致がちょうど1件のときだけ採る」としたが、**それでは7件貯まった pane が
# 永久に unknown になり、交代そのものが始められない**（実装SO の指摘）。件数で決めるのをやめ、
# 次の3つで決める。
#   (1) いまの tmux server の pid が一致するものだけに絞る
#   (2) そのうち拍動がいちばん新しいものを採る（死んだ世代の拍動は止まっているので更新されない）
#   (3) 採った候補の拍動と transcript が、どちらも鮮度の窓の中にあることを確かめる
# どれかで決められなければ unknown を返す。**誤った session_id を書くくらいなら書かない。**
#
# 残る穴（塞げていないので明記する）: pane が短い間に再利用され、**新しいセッションがまだ一度も
# 拍動を書いていない**あいだは、旧世代の拍動が唯一の候補として残る。それが窓の中なら旧世代の
# session_id を返す。セッションが自分の id を名乗る経路が無いかぎり、この窓は閉じない。
oe_hs_session_for_pane() {
  local pane="${1:-}" spid best_sid="" best_ts=-1 ts f tie=0
  [ -n "$pane" ] || { printf 'unknown'; return 0; }
  [ -n "$OE_HEARTBEAT_DIR" ] || { printf 'unknown'; return 0; }
  [ -d "$OE_HEARTBEAT_DIR" ] || { printf 'unknown'; return 0; }
  command -v jq >/dev/null 2>&1 || { printf 'unknown'; return 0; }
  spid="$(oe_hs_server_pid)"
  [ -n "$spid" ] || { printf 'unknown'; return 0; }
  for f in "$OE_HEARTBEAT_DIR"/*.json; do
    [ -f "$f" ] || continue
    ts="$(jq -r --arg p "$pane" --arg s "$spid" \
      'select((.pane // "") == $p and ((.server_pid // "") | tostring) == $s) | (.ts // empty)' "$f" 2>/dev/null)" || continue
    [ -n "$ts" ] || continue
    case "$ts" in ''|*[!0-9]*) continue ;; esac
    if [ "$ts" -gt "$best_ts" ]; then
      best_ts="$ts"; best_sid="$(basename "$f" .json)"; tie=0
    elif [ "$ts" -eq "$best_ts" ]; then
      # epoch 秒なので同率は起こりうる。同率のときは「どの世代か決められない」ので
      # 先に見つけたほうを黙って採らない。
      tie=1
    fi
  done
  [ -n "$best_sid" ] || { printf 'unknown'; return 0; }
  [ "${tie:-0}" -eq 0 ] || { printf 'unknown'; return 0; }
  # 拍動の鮮度。窓は実測（統括の拍動は2時間古くなることがある）より広く取る。
  local now age
  now="${OE_HS_NOW_EPOCH:-$(date +%s)}"
  age=$(( now - best_ts ))
  [ "$age" -le "${OE_HS_BEAT_MAX_AGE_SEC:-21600}" ] || { printf 'unknown'; return 0; }
  # この値の用途は「停止しても claude --resume で会話を開き直せる」ことの担保なので、
  # 担保の実体（transcript が在り、最近書かれていること）も直接確かめる。
  oe_hs_transcript_usable "$best_sid" || { printf 'unknown'; return 0; }
  printf '%s' "$best_sid"
}

# pane の拍動の古さ（秒）。取れなければ unknown。文書に出して人が判断できるようにする。
oe_hs_beat_age_for_pane() {
  local pane="${1:-}" spid best_ts=-1 ts f now
  if [ -z "$pane" ] || [ -z "$OE_HEARTBEAT_DIR" ] || [ ! -d "$OE_HEARTBEAT_DIR" ]; then printf 'unknown'; return 0; fi
  command -v jq >/dev/null 2>&1 || { printf 'unknown'; return 0; }
  spid="$(oe_hs_server_pid)"
  [ -n "$spid" ] || { printf 'unknown'; return 0; }
  for f in "$OE_HEARTBEAT_DIR"/*.json; do
    [ -f "$f" ] || continue
    ts="$(jq -r --arg p "$pane" --arg s "$spid" \
      'select((.pane // "") == $p and ((.server_pid // "") | tostring) == $s) | (.ts // empty)' "$f" 2>/dev/null)" || continue
    case "$ts" in ''|*[!0-9]*) continue ;; esac
    [ "$ts" -gt "$best_ts" ] && best_ts="$ts"
  done
  [ "$best_ts" -ge 0 ] || { printf 'unknown'; return 0; }
  now="${OE_HS_NOW_EPOCH:-$(date +%s)}"
  printf '%s' "$(( now - best_ts ))"
}

# session_id の transcript が在って、最近書かれているか。
# 在ることが claude --resume の前提そのものである。鮮度の窓は OE_HS_RESUME_MAX_AGE_SEC
# （既定 86400 秒）。statusLine とは別の主体（セッション本体）が書くので、拍動とは独立した信号になる。
oe_hs_transcript_usable() {
  local sid="${1:-}" root age now mtime f
  [ -n "$sid" ] && [ "$sid" != "unknown" ] || return 1
  # 置き場のノブは engine の既存のもの（oe-selfcheck と同じ OE_TRANSCRIPT_DIR）を尊重する。
  # ここだけ別のノブを見ると、非標準の置き場を指している環境で本物の transcript を見落とす。
  root="${OE_TRANSCRIPT_DIR:-}"
  if [ -z "$root" ]; then
    _oe_home_usable || return 1
    root="${HOME}/.claude/projects"
  fi
  [ -d "$root" ] || return 1
  f="$(find "$root" -maxdepth 2 -name "${sid}.jsonl" -type f 2>/dev/null | head -1)"
  [ -n "$f" ] || return 1
  # `date -r <file> +%s` は BSD / GNU どちらでも使える（oe-selfcheck の注記と同じ理由）。
  # `stat -f %m` は GNU では filesystem の情報を返して**成功してしまう**ので使わない。
  mtime="$(date -r "$f" +%s 2>/dev/null)" || return 1
  [ -n "$mtime" ] || return 1
  now="${OE_HS_NOW_EPOCH:-$(date +%s)}"
  age=$(( now - mtime ))
  [ "$age" -le "${OE_HS_RESUME_MAX_AGE_SEC:-86400}" ]
}

# session_id の拍動から context%。取れなければ unknown。
oe_hs_context_for_session() {
  local sid="${1:-}" v
  if [ -z "$sid" ] || [ "$sid" = "unknown" ]; then printf 'unknown'; return 0; fi
  [ -n "$OE_HEARTBEAT_DIR" ] || { printf 'unknown'; return 0; }
  command -v jq >/dev/null 2>&1 || { printf 'unknown'; return 0; }
  local f="${OE_HEARTBEAT_DIR}/${sid}.json"
  [ -f "$f" ] || { printf 'unknown'; return 0; }
  v="$(jq -r '.context_pct // empty' "$f" 2>/dev/null)" || v=""
  if [ -n "$v" ]; then printf '%s' "$v"; else printf 'unknown'; fi
}

# 常駐の見張りの登録状態。launchd が無い環境では unknown を1行返す（不在を「見張り0本」に
# 化かさない）。
oe_hs_watchdogs() {
  if ! command -v launchctl >/dev/null 2>&1; then
    printf 'unknown launchctl-not-found\n'
    return 0
  fi
  local raw out
  # `launchctl list` 自体が失敗したことを「見張り0本」に化かさない。
  if ! raw="$(launchctl list 2>/dev/null)"; then
    printf 'unknown launchctl-call-failed\n'
    return 0
  fi
  out="$(printf '%s\n' "$raw" | awk '$3 ~ /oe-/ {print $3" "$2}')" || out=""
  if [ -z "$out" ]; then
    printf 'none registered\n'
  else
    printf '%s\n' "$out"
  fi
}

# いまの枝の HEAD / 未 push の数 / worktree の数。workspace は git 作業ディレクトリ。
# **`master` の HEAD ではなく、その workspace が指している HEAD である**（名乗りと中身を揃える）。
oe_hs_repo_state() {
  local ws="${1:-.}" head_sha unpushed wt branch
  command -v git >/dev/null 2>&1 || { printf 'branch=unknown head=unknown unpushed=unknown worktrees=unknown\n'; return 0; }
  branch="$(git -C "$ws" rev-parse --abbrev-ref HEAD 2>/dev/null)" || branch="unknown"
  [ -n "$branch" ] || branch="unknown"
  head_sha="$(git -C "$ws" rev-parse --short HEAD 2>/dev/null)" || head_sha="unknown"
  # upstream が無い枝で「未 push 0 件」と言わない（0 は「無い」で unknown は「分からない」）。
  if git -C "$ws" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    unpushed="$(git -C "$ws" log --oneline '@{upstream}..HEAD' 2>/dev/null | wc -l | tr -d ' ')" || unpushed="unknown"
    [ -n "$unpushed" ] || unpushed="unknown"
  else
    unpushed="unknown(no-upstream)"
  fi
  wt="$(git -C "$ws" worktree list 2>/dev/null | wc -l | tr -d ' ')" || wt="unknown"
  printf 'branch=%s head=%s unpushed=%s worktrees=%s\n' "$branch" "$head_sha" "$unpushed" "$wt"
}

# open PR を1行1件（"<番号> draft=<true|false> <タイトル>"）。gh が無ければ unknown。
# **workspace の中で呼ぶ。** gh は cwd の repo を見るので、呼び出し元の cwd のままだと
# repo 節と PR 節が別のリポジトリを指しうる（同じ文書の中で観測が食い違う）。
oe_hs_open_prs() {
  local ws="${1:-.}"
  command -v gh >/dev/null 2>&1 || { printf 'unknown gh-not-found\n'; return 0; }
  [ -d "$ws" ] || { printf 'unknown workspace-not-found\n'; return 0; }
  local out
  out="$(cd "$ws" && gh pr list --state open --json number,title,isDraft \
        -q '.[] | "\(.number) draft=\(.isDraft) \(.title)"' 2>/dev/null)" || {
    printf 'unknown gh-call-failed\n'; return 0; }
  if [ -z "$out" ]; then printf 'none\n'; else printf '%s\n' "$out"; fi
}
