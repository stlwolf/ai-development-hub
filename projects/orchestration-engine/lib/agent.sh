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
#   - Codex の子の sandbox に渡す書ける場所と tmux のソケット（oe_agent_codex_sandbox_args）
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
OE_AGENT_CODEX_DEVELOPER_INSTRUCTIONS='文末の [oe:<26文字>] は配送の受領印で、依頼の一部ではない。写さず、コマンドに含めない。親への報告は oe send --to-parent で返す。判断を求める問いはファイルに書いて送り、対話の選択肢は使わない。委譲の書面（brief）の固定節に従う。oe は、ほかのコマンドとつながず、それだけで1つのコマンドとして打つ。'

# Codex が新しい workspace を初めて開くときに出す確認の画面の、最初の行の文言（0.167.1 と 0.167.2 の実機）。
# 版が変われば効かなくなるので、ここに置いて README に書く。
OE_AGENT_CODEX_TRUST_PROMPT='Trust this folder?'

# oe_agent_codex_main_worktree <workspace> — workspace のもとのリポジトリ（main の作業ツリー）の絶対パスを出す。
#   worktree なら git の共通ディレクトリ（.git）の親、ふつうのリポジトリなら自分の根。git でなければ 1。
oe_agent_codex_main_worktree() {
  local ws="${1:-}" common
  [ -n "$ws" ] || return 1
  common="$(git -C "$ws" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  [ -n "$common" ] || return 1
  case "$common" in */.git) printf '%s' "${common%/.git}" ;; *) printf '%s' "$(cd "$common/.." 2>/dev/null && pwd -P)" ;; esac
}

# oe_agent_codex_trusted <path> [<config.toml>] — その path を owner が Codex で信頼済みか（config.toml を読むだけ・書かない）。
#   [projects."<path>"] の表に trust_level = "trusted" があれば 0。無ければ 1。config.toml が読めなければ 2（owner の答え Q113・#562）。
oe_agent_codex_trusted() {
  local path="${1:-}" conf="${2:-${CODEX_HOME:-${HOME:-}/.codex}/config.toml}"
  [ -n "$path" ] || return 1
  [ -r "$conf" ] || return 2
  awk -v want="[projects.\"${path}\"]" '
    $0 == want { inside = 1; next }
    /^\[/ { inside = 0 }
    inside && $0 ~ /^[[:space:]]*trust_level[[:space:]]*=[[:space:]]*"trusted"[[:space:]]*$/ { found = 1; exit }
    END { exit (found ? 0 : 1) }' "$conf"
}

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
  local a prev=""
  for a in "$@"; do
    case "$agent" in
      codex)
        case "$a" in
          -a|--ask-for-approval|--ask-for-approval=*|-s|--sandbox|--sandbox=*|--approve-for-me|--dangerously-bypass-approvals-and-sandbox|--yolo) return 0 ;;
          # -c <key>=<value> / --config <key>=<value> で承認のモードを設定の鍵で指定する形（実装SO の指摘）
          --config=sandbox_mode=*|--config=approval_policy=*|--config=approvals_reviewer=*) return 0 ;;
          sandbox_mode=*|approval_policy=*|approvals_reviewer=*)
            if [ "$prev" = "-c" ] || [ "$prev" = "--config" ]; then return 0; fi ;;
        esac ;;
      *)
        case "$a" in
          --permission-mode|--permission-mode=*|--dangerously-skip-permissions) return 0 ;;
        esac ;;
    esac
    prev="$a"
  done
  return 1
}

# oe_agent_default_args <agent> <args...> — 起こすときに利用者の引数の前に置く既定の引数を1行1つで出す。
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

# _oe_agent_realdir <dir> — ディレクトリの実体のパス（symlink を解いた形・/tmp は /private/tmp）を出す。無ければ 1。
_oe_agent_realdir() { [ -d "${1:-}" ] || return 1; (CDPATH='' cd "$1" 2>/dev/null && pwd -P); }

# oe_agent_codex_user_sets_network <args...> — 利用者の引数が Codex のネットワークの設定（sandbox_workspace_write.network_access・
#   features.network_proxy・sandbox_workspace_write 全体・sandbox_permissions）を -c / --config で指定しているか（0 なら指定あり）。
oe_agent_codex_user_sets_network() {
  local a prev="" kv
  for a in "$@"; do
    kv=""
    case "$a" in
      --config=*) kv="${a#--config=}" ;;
      *) if [ "$prev" = "-c" ] || [ "$prev" = "--config" ]; then kv="$a"; fi ;;
    esac
    case "$kv" in
      sandbox_workspace_write=*|sandbox_workspace_write.network_access=*|features.network_proxy=*|features.network_proxy.*|features=*|sandbox_permissions=*) return 0 ;;
    esac
    prev="$a"
  done
  return 1
}

# oe_agent_codex_sandbox_args <workspace> [<利用者の引数...>] — Codex の子の sandbox（workspace-write）に、そのセッションにだけ渡す権限を
#   1行1つで出す（plan の H10・owner の答え Q118）。owner の設定には書かない。
#   - 書ける場所（--add-dir）: 本体の .git（git の共通ディレクトリ）と worktree の gitdir（本体と同じなら1つ）と
#     engine の状態の置き場（~/.claude/state）。どれも実体のパスで渡す（sandbox は .git を既定で読み取り専用にし、
#     worktree は index を gitdir に、objects を共通の .git に書くので両方が要る）。
#   - tmux のソケット: network_access と network_proxy と unix_sockets の3つ。プロキシに宛先を足さないので、
#     外への通信は閉じたまま、挙げたソケットにだけつなげる（実機・0.167.2）。
#   git でない workspace では git の分を、tmux の外（ソケットを引けない）では tmux の分を出さない。
#   2つ目からの引数は利用者の引数（--agent-arg）で、ネットワークの設定に触れていれば tmux の分を出さない。
#   差し替えの口（テスト用）: OE_AGENT_CODEX_STATE_DIR（状態の置き場）・OE_AGENT_CODEX_TMUX_SOCKET（ソケットのパス）
oe_agent_codex_sandbox_args() {
  local ws="${1:-}" common gitdir state sock sdir esc
  shift || true
  if [ -n "$ws" ]; then
    common="$(git -C "$ws" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || common=""
    gitdir="$(git -C "$ws" rev-parse --path-format=absolute --git-dir 2>/dev/null)" || gitdir=""
    common="$(_oe_agent_realdir "$common")" || common=""
    gitdir="$(_oe_agent_realdir "$gitdir")" || gitdir=""
    if [ -n "$common" ]; then printf '%s\n' '--add-dir' "$common"; fi
    if [ -n "$gitdir" ] && [ "$gitdir" != "$common" ]; then printf '%s\n' '--add-dir' "$gitdir"; fi
  fi
  state="$(_oe_agent_realdir "${OE_AGENT_CODEX_STATE_DIR:-${HOME:-}/.claude/state}")" || state=""
  if [ -n "$state" ]; then printf '%s\n' '--add-dir' "$state"; fi
  # 利用者の引数（残りの引数）がネットワークの設定に触れていたら、ネットワークの3つは出さない。engine の
  # network_access=true だけが残って、利用者がプロキシを外すと外への通信が全部開くのを防ぐ（実装SO の指摘）。
  if oe_agent_codex_user_sets_network "$@"; then return 0; fi
  sock="${OE_AGENT_CODEX_TMUX_SOCKET:-}"
  if [ -z "$sock" ] && [ -n "${TMUX:-}" ]; then
    sock="$(tmux display-message -p '#{socket_path}' 2>/dev/null)" || sock=""
  fi
  if [ -n "$sock" ]; then
    sdir="$(_oe_agent_realdir "$(dirname "$sock")")" || sdir=""
    if [ -n "$sdir" ]; then
      sock="${sdir}/$(basename "$sock")"
      # TOML の基本文字列に埋めるので、\ と " を逃がす。制御文字を含むパスは渡さない（実装SO の指摘）。
      case "$sock" in *[[:cntrl:]]*) return 0 ;; esac
      esc="$(printf '%s' "$sock" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
      printf '%s\n' '-c' 'sandbox_workspace_write.network_access=true' '-c' 'features.network_proxy.enabled=true' \
        '-c' "features.network_proxy.unix_sockets={\"${esc}\"=\"allow\"}"
    fi
  fi
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
      local kv key val
      for a in "$@"; do
        # -c <key>=<value> / --config <key>=<value> / --config=<key>=<value> の値を、flag の形と同じに読む（Copilot の指摘）。
        # TOML の文字列の引用符（"…" / '…'）は外す。
        kv=""
        case "$a" in
          --config=*) kv="${a#--config=}" ;;
          *) if [ "$prev" = "-c" ] || [ "$prev" = "--config" ]; then kv="$a"; fi ;;
        esac
        if [ -n "$kv" ]; then
          key="${kv%%=*}"; val="${kv#*=}"
          val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
          case "$key" in
            sandbox_mode)
              if [ "$val" = "danger-full-access" ]; then mode="bypassPermissions"; elif [ "$mode" != "bypassPermissions" ]; then mode="sandbox:${val}"; fi ;;
            approval_policy) [ "$mode" = "bypassPermissions" ] || mode="$val" ;;
          esac
          prev="$a"; continue
        fi
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
      if [ "$comm" = "codex" ]; then
        # 自分のペインの前面のプロセスと突き合わせる（plan の DJ-8・別のペインの codex を拾う誤りを弾く）。
        # lib/tmux-pane-identity.sh が読み込まれていて TMUX_PANE があるときだけ。前面が読めなければ突き合わせない。
        if [ -n "${TMUX_PANE:-}" ] && declare -F oe_tpi_pane_foreground >/dev/null 2>&1; then
          local fg fpid
          if fg="$(oe_tpi_pane_foreground "$TMUX_PANE" 2>/dev/null)"; then
            fpid="${fg%%"${_OE_TPI_TAB:-	}"*}"
            if [ "$fpid" != "$p" ]; then OE_AGENT_SELF_PID=""; return 1; fi
          fi
        fi
        OE_AGENT_SELF_PID="$p"; return 0
      fi
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
