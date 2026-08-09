#!/usr/bin/env bash
set -euo pipefail

# このスクリプト固有の識別子（shared 区間の外に置く）
HFR_HOOK="cc-lint"

CC_TYPES="feat|fix|ui|refactor|style|test|docs|revert|ci|infra|chore|local|wip"

deny() {
  local msg="$1"
  if [[ -n "${CURSOR_PROJECT_DIR:-}" || -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    jq -n --arg msg "$msg" '{"permission":"deny","user_message":$msg}'
  else
    echo "$msg" >&2
  fi
  # 記録は制御出力の後・exit の直前に置く。こうすると記録の意味が
  # 「判定が実際に配送された」になる。前に置くと配送されていない状態と区別がつかない。
  hfr deny
  hfr_deny_detail "${2:-unspecified}"
  exit 2
}

allow() {
  if [[ -n "${CURSOR_PROJECT_DIR:-}" || -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    echo '{"permission":"allow"}'
  fi
  hfr allow
  exit 0
}

# --- shared begin (3本で byte 一致させる。変更は3本同時に) ---
# 発火記録（tally）。1イベント1バイトを追記し、ファイルサイズを件数、mtime を
# 最終発火時刻として使う。ローテーションが要らない量に収まる。
#
# HOME が無いときに /tmp へ落とさない。world-writable な場所を記録先にすると、
# 先に FIFO を置かれて deny が exit 2 に到達できなくなる（下の [ -f ] ガード参照）。
HFR_DIR="${HOOK_FIRING_DIR:-${HOME:-}/.claude/state/hook-firing}"

# ツール判別は $0 で行う。$0 は「ホストが使った呼び出しパス」であって symlink の
# 解決先ではないので、~/.codex/hooks/... と ~/.cursor/hooks/... を見分けられる。
# 環境変数（CURSOR_PROJECT_DIR / CLAUDE_PROJECT_DIR）だと Codex を識別できない。
# Codex の silent skip はこの設計がいちばん恐れている故障型なので、名指しできる形を採る。
case "$0" in
  *.codex/*)  HFR_TOOL="codex"  ;;
  *.cursor/*) HFR_TOOL="cursor" ;;
  *.claude/*) HFR_TOOL="claude" ;;
  *)          HFR_TOOL="unknown" ;;
esac
HFR_BASE="${HFR_DIR}/tally/${HFR_TOOL}/${HFR_HOOK}"

# 記録は判定経路に影響してはならない。呼び出しは必ず `hfr allow` / `hfr deny` の
# リテラル引数で行う（呼び出し側で変数を展開すると、展開が隔離の外で起きて set -u に殺される）。
hfr() {
  local slot="${1:-}"
  # スロット名を白名簿で縛る。引数を忘れると末尾がドットのファイルへ静かに追記し続ける。
  case "$slot" in allow|deny) ;; *) return 0 ;; esac
  # 追記先が通常ファイルでないなら触らない。FIFO への追記は open がブロックし、
  # deny が exit 2 に到達しなくなる。HOOK_FIRING_DIR は差し替え可能なので、
  # このガードが無いと fail-open のレバーになる。
  # `[ ... ] && [ ... ] && return 0` と書かないこと（偽のとき非 0 を返し set -e が発動する）。
  if [ -e "${HFR_BASE}.${slot}" ] && [ ! -f "${HFR_BASE}.${slot}" ]; then
    return 0
  fi
  # fast path は builtin 1つだけ。fork も exec もしない。
  # 2>/dev/null は >> より前に置く（逆だと open 失敗のシェルエラーが stderr へ漏れる）。
  # これは握り潰しではない — 失敗は直後の || が捕まえ、fallback が診断を残す。
  printf 'x' 2>/dev/null >> "${HFR_BASE}.${slot}" || {
    ( set +e +u
      mkdir -p "${HFR_DIR}/tally/${HFR_TOOL}" 2>/dev/null
      printf 'x' 2>/dev/null >> "${HFR_BASE}.${slot}" && exit 0
      printf '{"ts":"%s","hook":"%s","tool":"%s","kind":"env-error","reason":"tally-append-failed","slot":"%s"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" "$HFR_HOOK" "$HFR_TOOL" "$slot" \
        2>/dev/null >> "${HFR_DIR}/diag.jsonl"
      printf 'hook-firing: tally-append-failed (%s)\n' "$slot" >&2
    ) >/dev/null || :
  }
  # 呼び出しは素の `hfr allow`（テスト文脈でない）なので必ず 0 を返す。
  return 0
}

# deny の詳細を1行残す。deny は稀なので date の exec を許す。
# コマンドの生文字列は残さない（発火した規則・先頭トークン・長さだけ）。
# 全文はエージェントの transcript に user_message として既に残るので二重に持たない。
hfr_deny_detail() {
  ( set +e +u
    rule="${1:-unknown}"
    c="${cmd:-}"
    argv0="${c%% *}"
    argv0="${argv0//[^A-Za-z0-9._\/-]/}"
    printf '{"ts":"%s","hook":"%s","tool":"%s","rule":"%s","argv0":"%s","cmd_len":%s}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" "$HFR_HOOK" "$HFR_TOOL" "$rule" "$argv0" "${#c}" \
      2>/dev/null >> "${HFR_DIR}/deny.jsonl"
  ) >/dev/null || :
  return 0
}

# jq に頼らない deny の出力。trap の収束先はこれを使う。
# jq 不在こそ trap が捕まえたい死因なので、収束先が jq を要求してはならない。
# メッセージは固定リテラル + exit code（数値）だけにして JSON escape の問題を作らない。
# shellcheck disable=SC2317  # trap 経由で呼ばれるため到達不能に見える
emit_deny_literal() {
  if [[ -n "${CURSOR_PROJECT_DIR:-}" || -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    printf '{"permission":"deny","user_message":"%s"}\n' "$1"
  else
    printf '%s\n' "$1" >&2
  fi
}

# 想定外の終了（0/2 以外）を deny へ収束させる。
# PreToolUse で実際にブロックするのは exit 2 だけで、1 を含む他の非 0 は non-blocking。
# つまり内部エラーで落ちると、止めるべきコマンドが Claude Code / Codex では素通りする。
# EXIT trap は正常終了でも発火するので、0 と 2 は必ずそのまま通すこと。
# shellcheck disable=SC2317  # trap 経由で呼ばれるため到達不能に見える
on_unexpected_exit() {
  local ec=$?
  trap - EXIT                             # 再入を止める
  case "$ec" in 0|2) exit "$ec" ;; esac    # 正常な終了はそのまま通す
  set +e +u                               # ここから先は何があっても止まらない
  emit_deny_literal "hook internal error (exit ${ec}); blocked conservatively"
  hfr deny
  hfr_deny_detail "internal-error"
  exit 2
}
trap on_unexpected_exit EXIT
# --- shared end ---

# grep の「非マッチ」は正常なデータ不在であって失敗ではない。実行できない（環境エラー）
# とは扱いを分ける。`|| true` で握り潰すと、この2つが同じ空出力に化けて区別できなくなる。
#
# パイプラインをやめた理由は2つある。(1) pipefail 下では grep の非マッチ 1 が
# パイプライン全体の非 0 になり、inherit_errexit が有効だと script ごと落ちる（#310）。
# (2) head の早期終了は SIGPIPE 由来の非 0 も生むので、非マッチと環境エラーの区別を壊す。
# head -1 と sed の役割は bash のパラメータ展開へ置き換えた（外部プロセスも2つ減る）。
#
# 正規表現そのものは据え置く。マッチ意味論を変えると非回帰を証明できなくなるため。
extract_commit_segment() {
  local cmd="$1"
  if [[ "$cmd" == *"&&"* ]]; then
    local matches rc=0
    matches="$(grep -oE '(^|&&)[[:space:]]*git[[:space:]]+commit[^&]*' <<< "$cmd")" || rc=$?
    case "$rc" in
      0) ;;                 # マッチした
      1) matches="" ;;      # マッチ無し = 正常なデータ不在
      *) return "$rc" ;;    # 環境エラー。呼び出し側が deny に倒す
    esac
    if [[ -n "$matches" ]]; then
      local segment="${matches%%$'\n'*}"                    # head -1 相当
      local trimmed="${segment#"${segment%%[![:space:]]*}"}"
      if [[ "$trimmed" == "&&"* ]]; then                    # sed の条件付き除去に対応
        trimmed="${trimmed#&&}"
        segment="${trimmed#"${trimmed%%[![:space:]]*}"}"
      fi
      if [[ -n "$segment" ]]; then
        printf '%s\n' "$segment"
        return 0
      fi
    fi
  fi
  printf '%s\n' "$cmd"
}

extract_message() {
  local cmd="$1"
  if [[ "$cmd" =~ \$\( ]] || [[ "$cmd" =~ \` ]]; then
    return 1
  fi

  local msg=""
  local -a tokens
  local in_m=false

  read -ra tokens <<< "$cmd"
  for token in "${tokens[@]}"; do
    if $in_m; then
      if [[ -z "$msg" ]]; then
        msg="$token"
      else
        msg="$msg $token"
      fi
      if [[ "$msg" == \"*\" ]] || [[ "$msg" == \'*\' ]]; then
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
      fi
      if [[ "$msg" != \"* ]] && [[ "$msg" != \'* ]]; then
        echo "$msg"
        return 0
      fi
      if [[ "$msg" == *\" ]] || [[ "$msg" == *\' ]]; then
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
      fi
      continue
    fi
    case "$token" in
      -m|--message)
        in_m=true
        ;;
      -m=*)
        msg="${token#-m=}"
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
        ;;
      --message=*)
        msg="${token#--message=}"
        msg="${msg#[\"\']}"
        msg="${msg%[\"\']}"
        echo "$msg"
        return 0
        ;;
      -[a-zA-Z]*m)
        in_m=true
        ;;
    esac
  done

  if $in_m && [[ -n "$msg" ]]; then
    msg="${msg#[\"\']}"
    msg="${msg%[\"\']}"
    echo "$msg"
    return 0
  fi

  return 1
}

main() {
  local input cmd

  input="$(cat)"
  cmd="$(jq -r '.tool_input.command // .command' <<< "$input")"

  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    allow
  fi

  # 環境エラー（grep が実行できない等）は deny に倒す。握り潰すと、強制が静かに消える。
  # deny は extract_commit_segment の中では呼べない — あの関数はコマンド置換の中で走るので、
  # そこで出した制御 JSON は本物の stdout に届かず置換の戻り値に化ける。
  local commit_segment ecs_rc=0
  commit_segment="$(extract_commit_segment "$cmd")" || ecs_rc=$?
  if (( ecs_rc >= 2 )); then
    deny "cc-lint: could not parse the command (grep failed with ${ecs_rc}). Blocked conservatively." "parse-error"
  fi

  if [[ ! "$commit_segment" =~ ^[[:space:]]*git[[:space:]]+(.*[[:space:]]+)?commit([[:space:]]|$) ]]; then
    allow
  fi

  if [[ "$commit_segment" =~ --fixup[=[:space:]] ]] || [[ "$commit_segment" =~ --squash[=[:space:]] ]]; then
    allow
  fi

  if [[ ! "$commit_segment" =~ [[:space:]]-[a-zA-Z]*m ]] && [[ ! "$commit_segment" =~ --message ]]; then
    allow
  fi

  local message
  if ! message="$(extract_message "$commit_segment")"; then
    allow
  fi

  if [[ -z "$message" ]]; then
    allow
  fi

  local cc_pattern="^(${CC_TYPES})(\(.+\))?: .+"
  if [[ "$message" =~ $cc_pattern ]]; then
    allow
  fi

  deny "Commit message does not follow Conventional Commits format.
Expected: <type>(<optional scope>): <description>
Types: feat, fix, ui, refactor, style, test, docs, revert, ci, infra, chore, local, wip
Example: feat(hooks): add cc-lint pre-command hook
Got: $message" "cc-format"
}

main
