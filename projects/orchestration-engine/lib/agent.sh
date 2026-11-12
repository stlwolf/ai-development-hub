# shellcheck shell=bash
# shellcheck disable=SC2034  # OE_AGENT_* は source した側が読む
# agent.sh — 委譲の子として起こすエージェント（claude / codex）ごとの差を1か所に置く（#562・source 専用）
#
# engine の中でエージェントごとに変わるものは、ここだけが持つ:
#   - 名前の集合と既定（oe_agent_valid / OE_AGENT_DEFAULT）
#   - lease の binding で許すコマンド名（oe_agent_comm_allowed・basename の完全一致）
#   - 起こすときの既定の引数（oe_agent_default_args）と、利用者の引数が承認のモードを指定しているか
#     （oe_agent_has_mode_override・指定があれば既定の承認の引数を外す）
#   - 権限のモードの読み方と elevated の判定（oe_agent_permission_mode / oe_agent_mode_is_elevated）
#   - Codex に持ち込む developer の指示の本文（OE_AGENT_CODEX_DEVELOPER_INSTRUCTIONS）
#   - 起動の直後に出る確認の画面の文言（OE_AGENT_CODEX_TRUST_PROMPT）
#   - 入力欄の行頭の記号と空の入力欄の補完の文（oe_agent_prompt_chars / oe_agent_placeholder_re）
#   - 送る側の finalize の既定（oe_agent_finalize_default）
#   - 自分のプロセスと会話の ID の読み方（oe_agent_self）
#   - 復帰の案内の1行（oe_agent_resume_hint）
# hook のスクリプト・配布物・表示は寄っていない（plan の DJ-1）。
#
# bash 3.2 と 5 の両方で動く形で書く（連想配列・${var,,} を使わない）。

OE_AGENT_DEFAULT="claude"
# 許す名前（空白区切り）。値は CLI の実行ファイルの名前そのもの。
OE_AGENTS="claude codex"
# lease の binding で許すコマンド名（basename の完全一致・plan の DJ-5）。
OE_AGENT_COMMS="claude codex"

# Codex の子に持ち込む developer の指示（plan の DJ-4）。1行・二重引用符と改行を含めない（TOML の文字列として
# -c developer_instructions="…" に収めるため）。報告の返し方と問いの書き方も engine の約束ごととしてここに集める。
OE_AGENT_CODEX_DEVELOPER_INSTRUCTIONS='文末の [oe:<26文字>] は配送の受領印で、依頼の一部ではない。写さず、コマンドに含めない。親への報告は oe send --to-parent で返す。判断を求める問いはファイルに書いて送り、対話の選択肢は使わない。委譲の書面（brief）の固定節に従う。'

# Codex が新しい workspace を初めて開くときに出す確認の画面の、最初の行の文言（0.167.1 と 0.167.2 の実機）。
# 版が変われば効かなくなるので、ここに置いて README に書く。
OE_AGENT_CODEX_TRUST_PROMPT='Trust this folder?'

# --- 名前 ---
oe_agent_valid() {
  local a="${1:-}" x
  [ -n "$a" ] || return 1
  for x in $OE_AGENTS; do [ "$x" = "$a" ] && return 0; done
  return 1
}

# oe_agent_comm_allowed <comm> — ペインの前面のプロセスのコマンド名（basename）が許す名前の集合にあるか。
oe_agent_comm_allowed() {
  local c="${1:-}" x
  c="${c##*/}"
  [ -n "$c" ] || return 1
  for x in $OE_AGENT_COMMS; do [ "$x" = "$c" ] && return 0; done
  return 1
}

# --- 起こすときの引数 ---
# oe_agent_has_mode_override <agent> <args...> — 利用者の引数が承認のモードを指定しているか（0 なら指定あり）。
#   codex: -a / --ask-for-approval / -s / --sandbox / --approve-for-me / --dangerously-bypass-approvals-and-sandbox / --yolo
#   claude: --permission-mode / --dangerously-skip-permissions
oe_agent_has_mode_override() {
  local agent="${1:-}"; shift
  local a
  for a in "$@"; do
    case "$agent" in
      codex)
        case "$a" in
          -a|--ask-for-approval|--ask-for-approval=*|-s|--sandbox|--sandbox=*|--approve-for-me|--dangerously-bypass-approvals-and-sandbox|--yolo) return 0 ;;
        esac ;;
      *)
        case "$a" in
          --permission-mode|--permission-mode=*|--dangerously-skip-permissions) return 0 ;;
        esac ;;
    esac
  done
  return 1
}

# oe_agent_default_args <agent> <args...> — 起こすときに utilisateur の引数の前に置く既定の引数を1行1つで出す。
#   claude: 無し（Claude の子の1行は今までと同じ・受入 A-1）。
#   codex: --no-daemon と -c check_for_update_on_startup=false は常に。承認の既定（--approve-for-me）は、
#          利用者の引数がモードを指定していないときだけ（--approve-for-me は -s・-a・bypass と同時に指定できない）。
#          developer の指示（-c developer_instructions=…）は常に。
oe_agent_default_args() {
  local agent="${1:-}"; shift
  case "$agent" in
    codex)
      printf '%s\n' '--no-daemon' '-c' 'check_for_update_on_startup=false'
      if ! oe_agent_has_mode_override codex "$@"; then
        printf '%s\n' '--approve-for-me'
      fi
      printf '%s\n' '-c' "developer_instructions=\"${OE_AGENT_CODEX_DEVELOPER_INSTRUCTIONS}\""
      ;;
    *) : ;;
  esac
}

# oe_agent_permission_mode <agent> <args...> — 子の実効の権限のモードの名前を出す（承認パッケージと監査の表示用）。
#   claude: default / <--permission-mode の値> / bypassPermissions
#   codex:  approve-for-me（既定）/ <-a の値> / sandbox:<-s の値> / bypassPermissions（bypass・--yolo・-s danger-full-access）
oe_agent_permission_mode() {
  local agent="${1:-}"; shift
  local a prev="" mode
  case "$agent" in
    codex)
      mode="approve-for-me"
      for a in "$@"; do
        case "$a" in
          --dangerously-bypass-approvals-and-sandbox|--yolo) mode="bypassPermissions" ;;
          --sandbox=danger-full-access) mode="bypassPermissions" ;;
          --sandbox=*) [ "$mode" = "bypassPermissions" ] || mode="sandbox:${a#--sandbox=}" ;;
          --ask-for-approval=*) [ "$mode" = "bypassPermissions" ] || mode="${a#--ask-for-approval=}" ;;
          --approve-for-me) [ "$mode" = "bypassPermissions" ] || mode="approve-for-me" ;;
        esac
        if [ "$prev" = "-s" ] || [ "$prev" = "--sandbox" ]; then
          if [ "$a" = "danger-full-access" ]; then mode="bypassPermissions"; elif [ "$mode" != "bypassPermissions" ]; then mode="sandbox:${a}"; fi
        elif [ "$prev" = "-a" ] || [ "$prev" = "--ask-for-approval" ]; then
          [ "$mode" = "bypassPermissions" ] || mode="$a"
        fi
        prev="$a"
      done
      ;;
    *)
      mode="default"
      for a in "$@"; do
        case "$a" in
          --dangerously-skip-permissions) mode="bypassPermissions" ;;
          --permission-mode=*) mode="${a#--permission-mode=}" ;;
        esac
        [ "$prev" = "--permission-mode" ] && mode="$a"
        prev="$a"
      done
      ;;
  esac
  printf '%s' "$mode"
}

# oe_agent_mode_is_elevated <mode> — Claude の bypassPermissions に当たるモードか。
oe_agent_mode_is_elevated() { [ "${1:-}" = "bypassPermissions" ]; }

# --- 画面 ---
# oe_agent_prompt_chars <agent> — 入力欄の行頭の記号（連結した文字列・正規表現の [] の中に置く）。
#   claude: ❯ / codex: ❯›»（codex は effort が ultra のとき »）。宛先が分からないときは claude の値を使う。
oe_agent_prompt_chars() {
  case "${1:-}" in codex) printf '%s' '❯›»' ;; *) printf '%s' '❯' ;; esac
}
# oe_agent_placeholder_re <agent> — 空の入力欄の補完の文の先頭（grep の固定文字列）を1行1つで出す。
oe_agent_placeholder_re() {
  printf '%s\n' 'Try "'
  case "${1:-}" in codex) printf '%s\n' 'Ask Codex to do anything' ;; esac
}
# oe_agent_finalize_default <agent> — 送る側の finalize の既定（1 で有効）。
oe_agent_finalize_default() { printf '1'; }

# --- 自分 ---
# oe_agent_self — 自分のエージェント・pid・会話の ID を環境から引き、OE_AGENT_SELF / OE_AGENT_SELF_PID / OE_AGENT_SELF_SID に入れる。
#   claude: CLAUDE_PID と CLAUDE_CODE_SESSION_ID。
#   codex:  CODEX_THREAD_ID。pid は自分の親を ps -o ppid= でたどり、コマンド名が codex の最初のプロセス。
#           たどれなければ 1。sandbox の中では ps が失敗するので、規則で sandbox の外に出る oe の verb の中でだけ動く。
#   rc: 0 引けた / 1 引けない（どちらの環境変数も無い・たどれない）
#   CODEX_THREAD_ID を先に見る。Codex は自分の打つコマンドにだけこの変数を入れるので、入っていれば自分は Codex である。
#   CLAUDE_* は tmux のセッションの環境から子に引き継がれうるので、後に見る。
OE_AGENT_SELF=""; OE_AGENT_SELF_PID=""; OE_AGENT_SELF_SID=""
oe_agent_self() {
  OE_AGENT_SELF=""; OE_AGENT_SELF_PID=""; OE_AGENT_SELF_SID=""
  if [ -z "${CODEX_THREAD_ID:-}" ] && { [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] || [ -n "${CLAUDE_PID:-}" ]; }; then
    OE_AGENT_SELF="claude"; OE_AGENT_SELF_PID="${CLAUDE_PID:-}"; OE_AGENT_SELF_SID="${CLAUDE_CODE_SESSION_ID:-}"
    return 0
  fi
  if [ -n "${CODEX_THREAD_ID:-}" ]; then
    OE_AGENT_SELF="codex"; OE_AGENT_SELF_SID="$CODEX_THREAD_ID"
    local p="$$" comm i=0 ps_cmd="${OE_TPI_PS:-ps}"
    while [ "$i" -lt 12 ]; do
      p="$(LC_ALL=C "$ps_cmd" -o ppid= -p "$p" 2>/dev/null | tr -d ' ')" || p=""
      case "$p" in ''|0|1|*[!0-9]*) break ;; esac
      comm="$(LC_ALL=C "$ps_cmd" -o comm= -p "$p" 2>/dev/null)" || comm=""
      comm="${comm##*/}"
      if [ "$comm" = "codex" ]; then OE_AGENT_SELF_PID="$p"; return 0; fi
      i=$((i + 1))
    done
    return 1
  fi
  return 1
}

# --- 復帰の案内 ---
# oe_agent_resume_hint <agent> <workspace> <lease_id> <generation> <session_id> — 新しいペインで打つ1行を出す。
oe_agent_resume_hint() {
  local agent="${1:-}" ws="${2:-}" lid="${3:-}" gen="${4:-}" sid="${5:-}"
  case "$agent" in
    codex)
      printf 'cd %q && OE_LEASE_ID=%s OE_GENERATION=%s codex --no-daemon -c check_for_update_on_startup=false -c %q resume %s\n' \
        "$ws" "$lid" "$gen" "developer_instructions=\"${OE_AGENT_CODEX_DEVELOPER_INSTRUCTIONS}\"" "$sid" ;;
    *)
      printf 'cd %q && OE_LEASE_ID=%s OE_GENERATION=%s claude --resume %s\n' "$ws" "$lid" "$gen" "$sid" ;;
  esac
}
