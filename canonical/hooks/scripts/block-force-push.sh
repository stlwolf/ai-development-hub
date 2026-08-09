#!/usr/bin/env bash
set -euo pipefail

# このスクリプト固有の識別子（shared 区間の外に置く）
HFR_HOOK="block-force-push"

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
# HOME も HOOK_FIRING_DIR も無いなら **記録を諦める**（空にする）。
# ${HOME:-}/... と書くと HOME 空のとき /.claude/... へ書きに行ってしまう（実測で踏んだ）。
if   [ -n "${HOOK_FIRING_DIR:-}" ]; then HFR_DIR="$HOOK_FIRING_DIR"
elif [ -n "${HOME:-}" ];           then HFR_DIR="${HOME}/.claude/state/hook-firing"
else                                    HFR_DIR=""
fi

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
  # 記録先が決まらなかった（HOME も HOOK_FIRING_DIR も無い）なら記録しない。
  [ -n "$HFR_DIR" ] || return 0
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
# 第2引数に exit code を渡すと `"exit":N` を足す（trap 収束のとき何で落ちたかを残すため）。
hfr_deny_detail() {
  [ -n "$HFR_DIR" ] || return 0
  ( set +e +u
    rule="${1:-unknown}"
    ec="${2:-}"
    c="${cmd:-}"
    argv0="${c%% *}"
    argv0="${argv0//[^A-Za-z0-9._\/-]/}"
    extra=""
    case "$ec" in ''|*[!0-9]*) ;; *) extra=",\"exit\":${ec}" ;; esac
    printf '{"ts":"%s","hook":"%s","tool":"%s","rule":"%s","argv0":"%s","cmd_len":%s%s}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" "$HFR_HOOK" "$HFR_TOOL" "$rule" "$argv0" "${#c}" "$extra" \
      2>/dev/null >> "${HFR_DIR}/deny.jsonl"
  ) >/dev/null || :
  return 0
}

# 前提コマンドの検査。jq 不在は trap でも rc=2 へ収束するが、それだと利用者に出る
# メッセージが「hook internal error (exit 127)」という汎用文になる。入口で明示的に
# 検査して何が足りないかを伝える（trap は backstop として残す）。
# **deny() は使えない** — あれは jq で JSON を組むので、jq 不在ではそれ自体が落ちる。
require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  emit_deny_literal "hook prerequisite missing: jq is required. Blocked conservatively."
  hfr deny
  hfr_deny_detail "missing-jq"
  exit 2
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
  hfr_deny_detail "internal-error" "$ec"
  exit 2
}
trap on_unexpected_exit EXIT
# --- shared end ---

main() {
  local input cmd

  require_jq

  input="$(cat)"
  cmd="$(jq -r '.tool_input.command // .command' <<< "$input")"

  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    allow
  fi

  # Match `git push` even with intervening git options like `git -C . push`
  if [[ ! "$cmd" =~ ^[[:space:]]*git([[:space:]]+[^[:space:]]+)*[[:space:]]+push([[:space:]]|$) ]]; then
    allow
  fi

  # Parse arguments to distinguish plain --force/-f from lease-style options
  local -a args
  local has_plain_force=false
  local has_lease=false

  read -r -a args <<< "$cmd"
  for arg in "${args[@]}"; do
    case "$arg" in
      --force-with-lease|--force-with-lease=*)
        has_lease=true
        ;;
      --force-if-includes)
        has_lease=true
        ;;
      --force|-f)
        has_plain_force=true
        ;;
    esac
  done

  # Plain --force present → deny regardless of lease options
  if [[ "$has_plain_force" == true ]]; then
    deny "Force push blocked: $cmd. Use --force-with-lease instead." "force-push"
  fi

  # Only lease-style force → allow
  if [[ "$has_lease" == true ]]; then
    allow
  fi

  allow
}

main
