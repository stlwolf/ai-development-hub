#!/usr/bin/env bash
set -euo pipefail

# このスクリプト固有の識別子（shared 区間の外に置く）
HFR_HOOK="block-destructive"

SAFE_DIRS_RE='^(node_modules|dist|\.next|build|coverage|__pycache__|\.cache|tmp|\.turbo|\.parcel-cache)$'

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

# 追記先が「存在するのに通常ファイルでない」なら触らない。
# FIFO への `>>` は reader が現れるまで open(2) でブロックし、`set +e` でも隔離でも解けない。
# ブロックすると deny が exit 2 に到達せず、Claude Code / Codex では**止めるべきものが通る**。
# **tally だけでなく deny.jsonl / diag.jsonl にも通すこと**（実装SO の2レーンが独立に指摘し、
# 実測でも deny のハングと allow のハングを再現した）。HOOK_FIRING_DIR は差し替え可能なので、
# ここを抜くと記録機構そのものが fail-open のレバーになる。
# `[ ... ] && [ ... ] && return 0` と書かないこと（偽のとき非 0 を返し set -e が発動する）。
hfr_appendable() {
  if [ -e "$1" ] && [ ! -f "$1" ]; then
    return 1
  fi
  return 0
}

# 記録は判定経路に影響してはならない。呼び出しは必ず `hfr allow` / `hfr deny` の
# リテラル引数で行う（呼び出し側で変数を展開すると、展開が隔離の外で起きて set -u に殺される）。
hfr() {
  local slot="${1:-}"
  # 記録先が決まらなかった（HOME も HOOK_FIRING_DIR も無い）なら記録しない。
  [ -n "$HFR_DIR" ] || return 0
  # スロット名を白名簿で縛る。引数を忘れると末尾がドットのファイルへ静かに追記し続ける。
  case "$slot" in allow|deny) ;; *) return 0 ;; esac
  hfr_appendable "${HFR_BASE}.${slot}" || return 0
  # fast path は builtin 1つだけ。fork も exec もしない。
  # 2>/dev/null は >> より前に置く（逆だと open 失敗のシェルエラーが stderr へ漏れる）。
  # これは握り潰しではない — 失敗は直後の || が捕まえ、fallback が診断を残す。
  printf 'x' 2>/dev/null >> "${HFR_BASE}.${slot}" || {
    ( set +e +u
      mkdir -p "${HFR_DIR}/tally/${HFR_TOOL}" 2>/dev/null
      printf 'x' 2>/dev/null >> "${HFR_BASE}.${slot}" && exit 0
      hfr_appendable "${HFR_DIR}/diag.jsonl" || exit 0
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
  hfr_appendable "${HFR_DIR}/deny.jsonl" || return 0
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

# --- shared-cmd begin (block-destructive / block-force-push の2本で byte 一致させる。変更は2本同時に) ---
# 行に含まれる各単純コマンドを取り出す（#429）。設計は
# docs/harness/plans/2026-10-15-plan-429-destructive-hook-compound.md の DJ-1〜DJ-5・DJ-8。
#
# 流れ: cmd_analyze <コマンド全文> <判定の関数名>
#   → 仕事の列（CMD_QUEUE）を1件ずつ cmd_scan で segment（単純コマンド）に分け、
#     segment ごとに cmd_segment が token 化して既知の名前の token を見つけ、
#     判定の関数に (token の位置, 正規化した名前) を渡す。判定の関数は CMD_TOKS を読み、
#     止めるなら deny を呼ぶ。shell の -c の文字列と eval の中身は列に積み戻す。
#
# 走査器は文字列を1回だけ通す（各周回で必ず位置が進む）。扱うのは、引用符（'…'・"…"・
# $'…'）、$( ) と ` `（文脈を積んで同じ走査で segment にする）、$(( ))（読み飛ばす）、
# ${ }（1 token に残す）、# の注釈、heredoc（引用ありの本文はデータ・引用なしは $( ) と
# ` ` だけ見る）、転送（演算子と相手を token から除く）、\ と改行の連結である。
# 扱わない形は plan の DJ-9 にある。
#
# bash 3.2 で動く書き方に限る（declare -A・mapfile・負の添字・${var,,} は使わない）。
# 空になりうる配列は ${arr[@]+"${arr[@]}"} の形で展開する（3.2 の set -u 対策）。

CMD_FAST_RE='rm|chmod|chown|mkfs|dd|git|eval|bash|sh|zsh|dash|ksh'
CMD_US=$'\037'          # segment の中で token を区切るバイト（コマンドにはまず現れない）
CMD_MAX_DEPTH=8         # shell -c / eval の入れ子の深さの上限
CMD_MAX_QUEUE=64        # 列の長さの上限（shell -c / eval が異常に多い行を打ち切る）

CMD_QUEUE=(); CMD_QDEPTH=()
CMD_SEGS=(); CMD_TOKS=()

# 既知の名前が1つも無い行は走査しない（早い経路）。\ と改行の組を消し、引用符と \ を
# 除いてから見るので、r\m や "r"m や r\<改行>m はすり抜けない。
cmd_fast_skip() {
  local s="$1"
  s="${s//\\$'\n'/}"
  s="${s//\\/}"
  s="${s//\'/}"
  s="${s//\"/}"
  if [[ "$s" =~ $CMD_FAST_RE ]]; then
    return 1
  fi
  return 0
}

# ---- 走査器の状態（cmd_scan の中だけで使う。関数の外から読まない） ----
_C_SEG=''; _C_SEGN=0; _C_TOK=''; _C_TOKQ=0; _C_Q=''; _C_DROP=0; _C_DEPTH=0; _C_CURDEPTH=0
_C_ST_SEG=(); _C_ST_SEGN=(); _C_ST_TOK=(); _C_ST_TOKQ=(); _C_ST_Q=(); _C_ST_KIND=(); _C_ST_DROP=()
_C_HD_WORD=(); _C_HD_Q=(); _C_HD_STRIP=()

# 今の token を segment に加える。転送の相手（_C_DROP=1）なら捨てる。
_cmd_tok_end() {
  if [[ "$_C_DROP" == 1 ]]; then
    if [[ -n "$_C_TOK" || "$_C_TOKQ" == 1 ]]; then
      _C_DROP=0
    fi
  elif [[ -n "$_C_TOK" || "$_C_TOKQ" == 1 ]]; then
    if (( _C_SEGN > 0 )); then
      _C_SEG+="$CMD_US$_C_TOK"
    else
      _C_SEG="$_C_TOK"
    fi
    _C_SEGN=$((_C_SEGN + 1))
  fi
  _C_TOK=''; _C_TOKQ=0
}

# 今の segment を閉じて CMD_SEGS に積む。
_cmd_seg_end() {
  _cmd_tok_end
  if (( _C_SEGN > 0 )); then
    CMD_SEGS+=("$_C_SEG")
  fi
  _C_SEG=''; _C_SEGN=0; _C_DROP=0
}

# $( または ` に入る。外側の状態を積んで、引用符の外の状態から中身を走査する。
_cmd_push() { # $1 = p ($( ) / b (`)
  _C_ST_SEG+=("$_C_SEG"); _C_ST_SEGN+=("$_C_SEGN"); _C_ST_TOK+=("$_C_TOK"); _C_ST_TOKQ+=("$_C_TOKQ")
  _C_ST_Q+=("$_C_Q"); _C_ST_KIND+=("$1"); _C_ST_DROP+=("$_C_DROP")
  _C_SEG=''; _C_SEGN=0; _C_TOK=''; _C_TOKQ=0; _C_Q=''; _C_DROP=0
  _C_DEPTH=$((_C_DEPTH + 1))
}

# 置換の閉じ。中身の最後の segment を閉じ、外側の状態に戻る。置換を含んだ token は
# 引用扱いにする（既知の名前には当てない。計算される名前は扱わない・DJ-9）。
_cmd_pop() {
  local k=$((_C_DEPTH - 1))
  _cmd_seg_end
  _C_SEG="${_C_ST_SEG[k]}"; _C_SEGN="${_C_ST_SEGN[k]}"; _C_TOK="${_C_ST_TOK[k]}"; _C_TOKQ=1
  _C_Q="${_C_ST_Q[k]}"; _C_DROP="${_C_ST_DROP[k]}"
  unset '_C_ST_SEG[k]' '_C_ST_SEGN[k]' '_C_ST_TOK[k]' '_C_ST_TOKQ[k]' '_C_ST_Q[k]' '_C_ST_KIND[k]' '_C_ST_DROP[k]'
  _C_DEPTH=$((_C_DEPTH - 1))
}

# 以下の _cmd_* は cmd_scan から呼ばれ、cmd_scan のローカル変数 s（文字列）・n（長さ）・
# i（位置）を動的スコープで読み書きする（bash の関数のローカル変数は呼び出し先から見える）。

# $(( … )) を読み飛ばす（i は $ の位置）。中の << を heredoc と取り違えないため。
_cmd_skip_arith() {
  local depth=0
  i=$((i + 1))
  while (( i < n )); do
    case "${s:i:1}" in
      '(') depth=$((depth + 1)) ;;
      ')') depth=$((depth - 1)) ;;
    esac
    i=$((i + 1))
    if (( depth == 0 )); then break; fi
  done
  _C_TOKQ=1
}

# ${ … } を1つの token の中にそのまま写す（i は $ の位置）。中身は解釈しない。
_cmd_copy_brace() {
  local depth=0 ch
  _C_TOK+='$'; i=$((i + 1))
  while (( i < n )); do
    ch="${s:i:1}"
    _C_TOK+="$ch"
    case "$ch" in
      '{') depth=$((depth + 1)) ;;
      '}') depth=$((depth - 1)) ;;
    esac
    i=$((i + 1))
    if (( depth == 0 )); then break; fi
  done
  _C_TOKQ=1
}

# 今の token が数字だけなら fd 番号（2>&1 の 2）なので捨てる。それ以外は普通に終える。
_cmd_tok_fd_end() {
  if [[ "$_C_TOKQ" == 0 && "$_C_TOK" =~ ^[0-9]+$ ]]; then
    _C_TOK=''; _C_TOKQ=0
  else
    _cmd_tok_end
  fi
}

# 転送の演算子を読み飛ばし、相手の token を捨てる印を立てる（i は演算子の先頭）。
# << は heredoc、<<< は here-string。相手が ( なら process substitution で、( が segment を切る。
_cmd_redirect() {
  local op="${s:i:1}"
  if [[ "$op" == '<' && "${s:i+1:1}" == '<' ]]; then
    if [[ "${s:i+2:1}" == '<' ]]; then
      _cmd_tok_fd_end
      i=$((i + 3))
      _C_DROP=1
      return 0
    fi
    _cmd_heredoc_start
    return 0
  fi
  _cmd_tok_fd_end
  case "$op" in
    '&')
      i=$((i + 2))
      if [[ "${s:i:1}" == '>' ]]; then i=$((i + 1)); fi
      ;;
    '>')
      i=$((i + 1))
      case "${s:i:1}" in '>'|'|'|'&') i=$((i + 1)) ;; esac
      ;;
    '<')
      i=$((i + 1))
      case "${s:i:1}" in '>'|'&') i=$((i + 1)) ;; esac
      ;;
  esac
  if [[ "${s:i:1}" == '(' ]]; then
    return 0
  fi
  _C_DROP=1
}

# heredoc の区切り語を読み、待ち行列に積む（i は << の位置）。区切り語に引用符か \ が
# 1つでもあれば「引用あり」とし、値は引用符と \ を外したものにする（空も有効）。
_cmd_heredoc_start() {
  local strip=0 word='' wq=0 ch
  _cmd_tok_fd_end
  i=$((i + 2))
  if [[ "${s:i:1}" == '-' ]]; then strip=1; i=$((i + 1)); fi
  while [[ "${s:i:1}" == ' ' || "${s:i:1}" == $'\t' ]]; do i=$((i + 1)); done
  while (( i < n )); do
    ch="${s:i:1}"
    case "$ch" in
      ' '|$'\t'|$'\n'|';'|'|'|'&'|'<'|'>'|'('|')') break ;;
      "'")
        wq=1; i=$((i + 1))
        while (( i < n )) && [[ "${s:i:1}" != "'" ]]; do word+="${s:i:1}"; i=$((i + 1)); done
        i=$((i + 1))
        ;;
      '"')
        wq=1; i=$((i + 1))
        while (( i < n )) && [[ "${s:i:1}" != '"' ]]; do
          if [[ "${s:i:1}" == "\\" ]]; then i=$((i + 1)); fi
          word+="${s:i:1}"; i=$((i + 1))
        done
        i=$((i + 1))
        ;;
      "\\") wq=1; word+="${s:i+1:1}"; i=$((i + 2)) ;;
      *) word+="$ch"; i=$((i + 1)) ;;
    esac
  done
  _C_HD_WORD+=("$word"); _C_HD_Q+=("$wq"); _C_HD_STRIP+=("$strip")
}

# 引用なしの heredoc の本文の1行から、実行される $( ) と ` ` の中身だけを列に積む。
_cmd_body_subst() {
  local l="$1"
  local m=${#l} j=0 ch depth start inner
  while (( j < m )); do
    ch="${l:j:1}"
    if [[ "$ch" == '$' && "${l:j+1:1}" == '(' ]]; then
      j=$((j + 2)); start=$j; depth=1
      while (( j < m && depth > 0 )); do
        case "${l:j:1}" in
          '(') depth=$((depth + 1)) ;;
          ')') depth=$((depth - 1)) ;;
        esac
        j=$((j + 1))
      done
      if (( depth > 0 )); then inner="${l:start}"; else inner="${l:start:j-start-1}"; fi
      CMD_QUEUE+=("$inner"); CMD_QDEPTH+=("$_C_CURDEPTH")
    elif [[ "$ch" == '`' ]]; then
      j=$((j + 1)); start=$j
      while (( j < m )) && [[ "${l:j:1}" != '`' ]]; do j=$((j + 1)); done
      inner="${l:start:j-start}"; j=$((j + 1))
      CMD_QUEUE+=("$inner"); CMD_QDEPTH+=("$_C_CURDEPTH")
    else
      j=$((j + 1))
    fi
  done
}

# 改行の直後に、待ち行列の heredoc の本文を順に読む（i は本文の先頭）。
# 区切り語の行（<<- なら先頭のタブを除いて比べる）まで。無ければ残り全部が本文。
_cmd_heredoc_bodies() {
  local k=0 cnt=${#_C_HD_WORD[@]} word wq strip line cmp len tab=$'\t'
  while (( k < cnt )); do
    word="${_C_HD_WORD[k]}"; wq="${_C_HD_Q[k]}"; strip="${_C_HD_STRIP[k]}"
    while (( i < n )); do
      line="${s:i}"; line="${line%%$'\n'*}"; len=${#line}
      i=$((i + len + 1))
      cmp="$line"
      if (( strip == 1 )); then cmp="${cmp#"${cmp%%[!"$tab"]*}"}"; fi
      if [[ "$cmp" == "$word" ]]; then break; fi
      if (( wq == 0 )) && [[ "$line" == *"\$("* || "$line" == *'`'* ]]; then
        _cmd_body_subst "$line"
      fi
    done
    k=$((k + 1))
  done
  _C_HD_WORD=(); _C_HD_Q=(); _C_HD_STRIP=()
}

# 文字列を1回走査して CMD_SEGS に segment を積む。$2 はこの文字列の入れ子の深さ。
# LC_ALL=C はこの関数の中だけ（バイト単位の走査にして 3.2 でも速くする。判定するのは
# ASCII の構文だけなので、UTF-8 の文字をバイトで扱っても壊れない）。
cmd_scan() {
  local LC_ALL=C
  local s="$1" n i=0 c nx k
  _C_CURDEPTH="$2"
  n=${#s}
  _C_SEG=''; _C_SEGN=0; _C_TOK=''; _C_TOKQ=0; _C_Q=''; _C_DROP=0; _C_DEPTH=0
  _C_ST_SEG=(); _C_ST_SEGN=(); _C_ST_TOK=(); _C_ST_TOKQ=(); _C_ST_Q=(); _C_ST_KIND=(); _C_ST_DROP=()
  _C_HD_WORD=(); _C_HD_Q=(); _C_HD_STRIP=()
  while (( i < n )); do
    c="${s:i:1}"
    case "$_C_Q" in
      "'")
        if [[ "$c" == "'" ]]; then _C_Q=''; else _C_TOK+="$c"; fi
        i=$((i + 1)); continue ;;
      a)
        if [[ "$c" == "\\" ]]; then
          nx="${s:i+1:1}"
          case "$nx" in
            "'") _C_TOK+="'" ;;
            "\\") _C_TOK+="\\" ;;
            '') ;;
            *) _C_TOK+="\\$nx" ;;
          esac
          i=$((i + 2)); continue
        fi
        if [[ "$c" == "'" ]]; then _C_Q=''; else _C_TOK+="$c"; fi
        i=$((i + 1)); continue ;;
      '"')
        case "$c" in
          "\\")
            nx="${s:i+1:1}"
            case "$nx" in
              '$'|'`'|'"'|"\\") _C_TOK+="$nx"; i=$((i + 2)) ;;
              $'\n') i=$((i + 2)) ;;
              *) _C_TOK+="\\"; i=$((i + 1)) ;;
            esac
            continue ;;
          '"') _C_Q=''; i=$((i + 1)); continue ;;
          '`') _cmd_push b; i=$((i + 1)); continue ;;
          '$')
            nx="${s:i+1:1}"
            if [[ "$nx" == '(' ]]; then
              if [[ "${s:i+2:1}" == '(' ]]; then _cmd_skip_arith; else _cmd_push p; i=$((i + 2)); fi
              continue
            fi
            if [[ "$nx" == '{' ]]; then _cmd_copy_brace; continue; fi
            _C_TOK+='$'; i=$((i + 1)); continue ;;
          *) _C_TOK+="$c"; i=$((i + 1)); continue ;;
        esac ;;
    esac
    # ここから引用符の外
    case "$c" in
      ' '|$'\t') _cmd_tok_end; i=$((i + 1)) ;;
      $'\n')
        _cmd_seg_end; i=$((i + 1))
        if (( ${#_C_HD_WORD[@]} > 0 )); then _cmd_heredoc_bodies; fi
        ;;
      "\\")
        nx="${s:i+1:1}"
        if [[ "$nx" == $'\n' ]]; then
          i=$((i + 2))
        elif [[ -z "$nx" ]]; then
          i=$((i + 1))
        else
          _C_TOK+="$nx"; _C_TOKQ=1; i=$((i + 2))
        fi
        ;;
      "'") _C_Q="'"; _C_TOKQ=1; i=$((i + 1)) ;;
      '"') _C_Q='"'; _C_TOKQ=1; i=$((i + 1)) ;;
      '$')
        nx="${s:i+1:1}"
        case "$nx" in
          "'") _C_Q=a; _C_TOKQ=1; i=$((i + 2)) ;;
          '(')
            if [[ "${s:i+2:1}" == '(' ]]; then _cmd_skip_arith; else _cmd_push p; i=$((i + 2)); fi
            ;;
          '{') _cmd_copy_brace ;;
          *) _C_TOK+='$'; i=$((i + 1)) ;;
        esac
        ;;
      '`')
        if (( _C_DEPTH > 0 )) && [[ "${_C_ST_KIND[_C_DEPTH-1]}" == b ]]; then _cmd_pop; else _cmd_push b; fi
        i=$((i + 1))
        ;;
      '#')
        if [[ -z "$_C_TOK" && "$_C_TOKQ" == 0 ]]; then
          k="${s:i}"; k="${k%%$'\n'*}"; i=$((i + ${#k}))
        else
          _C_TOK+='#'; i=$((i + 1))
        fi
        ;;
      '&')
        nx="${s:i+1:1}"
        case "$nx" in
          '&') _cmd_seg_end; i=$((i + 2)) ;;
          '>') _cmd_redirect ;;
          *) _cmd_seg_end; i=$((i + 1)) ;;
        esac
        ;;
      '|')
        _cmd_seg_end
        nx="${s:i+1:1}"
        if [[ "$nx" == '|' || "$nx" == '&' ]]; then i=$((i + 2)); else i=$((i + 1)); fi
        ;;
      ';') _cmd_seg_end; i=$((i + 1)) ;;
      '(') _cmd_seg_end; i=$((i + 1)) ;;
      ')')
        if (( _C_DEPTH > 0 )) && [[ "${_C_ST_KIND[_C_DEPTH-1]}" == p ]]; then _cmd_pop; else _cmd_seg_end; fi
        i=$((i + 1))
        ;;
      '{'|'}') _cmd_tok_end; i=$((i + 1)) ;;
      '!')
        if [[ -z "$_C_TOK" && "$_C_TOKQ" == 0 ]]; then i=$((i + 1)); else _C_TOK+='!'; i=$((i + 1)); fi
        ;;
      '<'|'>') _cmd_redirect ;;
      *) _C_TOK+="$c"; i=$((i + 1)) ;;
    esac
  done
  # 閉じていない置換は、中身を segment として残し、外側へ戻ってから閉じる（外側を捨てない）。
  while (( _C_DEPTH > 0 )); do _cmd_pop; done
  _cmd_seg_end
}

# shell の token の後ろをオプションとして歩き、-c があればその文字列を列に積む。
# -- はオプションの終わり。-o X・+o X・--rcfile X・--init-file X は次も飛ばす。
# -c が無ければスクリプトファイルなので扱わない（DJ-9）。
_cmd_shell_c() { # $1 = shell の token の位置, $2 = 深さ
  local j=$(($1 + 1)) n=${#CMD_TOKS[@]} seen=0 t
  while (( j < n )); do
    t="${CMD_TOKS[j]}"
    case "$t" in
      --) j=$((j + 1)); break ;;
      -o|+o|--rcfile|--init-file) j=$((j + 2)) ;;
      -c) seen=1; j=$((j + 1)) ;;
      --*) j=$((j + 1)) ;;
      -*c*) seen=1; j=$((j + 1)) ;;
      -*|+*) j=$((j + 1)) ;;
      *) break ;;
    esac
  done
  if (( seen == 1 && j < n )); then
    CMD_QUEUE+=("${CMD_TOKS[j]}"); CMD_QDEPTH+=("$(($2 + 1))")
  fi
}

# eval の後ろの token を空白で連結して列に積む。
_cmd_eval() { # $1 = eval の位置, $2 = 深さ
  local j=$(($1 + 1)) n=${#CMD_TOKS[@]} joined=''
  while (( j < n )); do
    if [[ -n "$joined" ]]; then joined+=" ${CMD_TOKS[j]}"; else joined="${CMD_TOKS[j]}"; fi
    j=$((j + 1))
  done
  if [[ -n "$joined" ]]; then
    CMD_QUEUE+=("$joined"); CMD_QDEPTH+=("$(($2 + 1))")
  fi
}

# segment を token に分け、既知の名前に一致する token を**すべて**判定の関数に渡す（DJ-3）。
# 名前は先頭の \ を解いた後の値の basename で比べる。shell と eval は segment の最初の
# 1つだけを列に積む（後ろのものはその引数であって実行されない）。
cmd_segment() { # $1 = segment, $2 = 深さ, $3 = 判定の関数名
  local seg="$1" d="$2" judge="$3" rest tok i=0 n name shell_done=0
  CMD_TOKS=()
  rest="$seg"
  while :; do
    if [[ "$rest" == *"$CMD_US"* ]]; then
      tok="${rest%%"$CMD_US"*}"; rest="${rest#*"$CMD_US"}"
      CMD_TOKS+=("$tok")
    else
      CMD_TOKS+=("$rest")
      break
    fi
  done
  n=${#CMD_TOKS[@]}
  while (( i < n )); do
    name="${CMD_TOKS[i]}"
    if [[ "$name" == */* ]]; then name="${name##*/}"; fi
    case "$name" in
      bash|sh|zsh|dash|ksh)
        if (( shell_done == 0 )); then shell_done=1; _cmd_shell_c "$i" "$d"; fi
        ;;
      eval)
        if (( shell_done == 0 )); then shell_done=1; _cmd_eval "$i" "$d"; fi
        ;;
      rm|chmod|chown|dd|git|mkfs*)
        "$judge" "$i" "$name"
        ;;
    esac
    i=$((i + 1))
  done
  return 0
}

# 入口。列が深さの上限か長さの上限を超えたら「解析できない」として deny する（保守的）。
cmd_analyze() { # $1 = コマンド全文, $2 = 判定の関数名
  local judge="$2" qi=0 text d seg
  CMD_QUEUE=("$1"); CMD_QDEPTH=(0)
  while (( qi < ${#CMD_QUEUE[@]} )); do
    text="${CMD_QUEUE[qi]}"; d="${CMD_QDEPTH[qi]}"; qi=$((qi + 1))
    if (( d > CMD_MAX_DEPTH || ${#CMD_QUEUE[@]} > CMD_MAX_QUEUE )); then
      deny "Command nesting too deep to analyze (bash -c / eval); blocked conservatively: $cmd" "nesting-limit"
    fi
    CMD_SEGS=()
    cmd_scan "$text" "$d"
    for seg in ${CMD_SEGS[@]+"${CMD_SEGS[@]}"}; do
      cmd_segment "$seg" "$d" "$judge"
    done
  done
  return 0
}
# --- shared-cmd end ---

# ---- block-destructive の判定（segment の token 配列 CMD_TOKS と既知の名前の位置を受ける） ----
# 以下の関数は cmd_analyze に名前で渡して間接に呼ばれるので、shellcheck には到達不能に見える。

# rm: -r/-R と -f がそろい、対象が1つでも危険なら deny。対象は正規化してから見る（DJ-5）。
# 安全ディレクトリだけなら何もしない（早期 allow はしない。後ろの segment も見る・DJ-1）。
# shellcheck disable=SC2317  # cmd_analyze から名前で間接に呼ばれる
bd_check_rm() { # $1 = rm の位置
  local i=$(($1 + 1)) n=${#CMD_TOKS[@]} has_r=0 has_f=0 saw_dd=0 arg t nt=0
  local -a targets=()
  while (( i < n )); do
    arg="${CMD_TOKS[i]}"; i=$((i + 1))
    if (( saw_dd == 0 )); then
      case "$arg" in
        --)          saw_dd=1; continue ;;
        --recursive) has_r=1; continue ;;
        --force)     has_f=1; continue ;;
        -*)
          if [[ "$arg" == *[rR]* ]]; then has_r=1; fi
          if [[ "$arg" == *f* ]]; then has_f=1; fi
          continue
          ;;
      esac
    fi
    targets+=("$arg"); nt=$((nt + 1))
  done
  if (( has_r == 0 || has_f == 0 || nt == 0 )); then return 0; fi
  for t in "${targets[@]}"; do
    while [[ "$t" == */ && "$t" != / ]]; do t="${t%/}"; done
    while [[ "$t" == ./?* ]]; do t="${t#./}"; done
    if [[ "$t" =~ $SAFE_DIRS_RE ]]; then continue; fi
    # shellcheck disable=SC2088,SC2016  # matching literal ~ and $HOME in command strings
    case "$t" in
      /*|.|..|'~'*|'$HOME'|'$HOME/'*|'${HOME}'|'${HOME}/'*)
        deny "Destructive rm blocked: $cmd" "rm-destructive"
        ;;
    esac
  done
  return 0
}

# chmod: 再帰（-R）と 777 と / で始まる対象がそろえば deny。
# shellcheck disable=SC2317  # cmd_analyze から名前で間接に呼ばれる
bd_check_chmod() {
  local i=$(($1 + 1)) n=${#CMD_TOKS[@]} t rec=0 mode=0 root=0
  while (( i < n )); do
    t="${CMD_TOKS[i]}"; i=$((i + 1))
    case "$t" in
      --recursive) rec=1 ;;
      -*R*) rec=1 ;;
      -*) ;;
      777) mode=1 ;;
      /*) root=1 ;;
    esac
  done
  if (( rec == 1 && mode == 1 && root == 1 )); then
    deny "Destructive chmod blocked: $cmd" "chmod-recursive-root"
  fi
  return 0
}

# chown: 再帰（-R）と / で始まる対象がそろえば deny。
# shellcheck disable=SC2317  # cmd_analyze から名前で間接に呼ばれる
bd_check_chown() {
  local i=$(($1 + 1)) n=${#CMD_TOKS[@]} t rec=0 root=0
  while (( i < n )); do
    t="${CMD_TOKS[i]}"; i=$((i + 1))
    case "$t" in
      --recursive) rec=1 ;;
      -*R*) rec=1 ;;
      -*) ;;
      /*) root=1 ;;
    esac
  done
  if (( rec == 1 && root == 1 )); then
    deny "Destructive chown blocked: $cmd" "chown-recursive-root"
  fi
  return 0
}

# mkfs*: - で始まらない引数が1つでもあれば deny（名前だけでは止めない。command -v mkfs.ext4 を通すため・DJ-3）。
# shellcheck disable=SC2317  # cmd_analyze から名前で間接に呼ばれる
bd_check_mkfs() {
  local i=$(($1 + 1)) n=${#CMD_TOKS[@]}
  while (( i < n )); do
    case "${CMD_TOKS[i]}" in
      -*) ;;
      *) deny "Destructive mkfs blocked: $cmd" "mkfs" ;;
    esac
    i=$((i + 1))
  done
  return 0
}

# dd: of=/dev/… があれば deny。
# shellcheck disable=SC2317  # cmd_analyze から名前で間接に呼ばれる
bd_check_dd() {
  local i=$(($1 + 1)) n=${#CMD_TOKS[@]}
  while (( i < n )); do
    case "${CMD_TOKS[i]}" in
      of=/dev/*) deny "Destructive dd blocked: $cmd" "dd-device" ;;
    esac
    i=$((i + 1))
  done
  return 0
}

# git: git 自身のオプションを飛ばして subcommand を取る（-C・-c・--git-dir・--work-tree・
# --namespace は次も飛ばす）。reset は --hard の token、clean は option の文字を集めて
# f・d・x がそろい dry-run でなければ deny（DJ-6）。
# shellcheck disable=SC2317  # cmd_analyze から名前で間接に呼ばれる
bd_check_git() {
  local i=$(($1 + 1)) n=${#CMD_TOKS[@]} t sub='' f=0 d=0 x=0 dry=0
  while (( i < n )); do
    t="${CMD_TOKS[i]}"
    case "$t" in
      -C|-c|--git-dir|--work-tree|--namespace) i=$((i + 2)); continue ;;
      -*) i=$((i + 1)); continue ;;
      *) sub="$t"; i=$((i + 1)); break ;;
    esac
  done
  case "$sub" in
    reset)
      while (( i < n )); do
        if [[ "${CMD_TOKS[i]}" == --hard ]]; then
          deny "Destructive git reset blocked: $cmd" "git-reset-hard"
        fi
        i=$((i + 1))
      done
      ;;
    clean)
      while (( i < n )); do
        t="${CMD_TOKS[i]}"; i=$((i + 1))
        case "$t" in
          --) break ;;
          --force) f=1 ;;
          --dry-run) dry=1 ;;
          --*) ;;
          -?*)
            if [[ "$t" == *f* ]]; then f=1; fi
            if [[ "$t" == *d* ]]; then d=1; fi
            if [[ "$t" == *x* ]]; then x=1; fi
            if [[ "$t" == *n* ]]; then dry=1; fi
            ;;
        esac
      done
      if (( f == 1 && d == 1 && x == 1 && dry == 0 )); then
        deny "Destructive git clean blocked: $cmd" "git-clean-fdx"
      fi
      ;;
  esac
  return 0
}

# shellcheck disable=SC2317  # cmd_analyze から名前で間接に呼ばれる
bd_judge() { # $1 = 既知の名前の token の位置, $2 = 正規化した名前
  case "$2" in
    rm)    bd_check_rm "$1" ;;
    chmod) bd_check_chmod "$1" ;;
    chown) bd_check_chown "$1" ;;
    mkfs*) bd_check_mkfs "$1" ;;
    dd)    bd_check_dd "$1" ;;
    git)   bd_check_git "$1" ;;
  esac
  return 0
}

main() {
  local input cmd

  require_jq

  input="$(cat)"
  cmd="$(jq -r '.tool_input.command // .command' <<< "$input")"

  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    allow
  fi

  # 行に含まれる各単純コマンドを判定する（#429）。既知の名前が無い行は走査しない。
  if ! cmd_fast_skip "$cmd"; then
    cmd_analyze "$cmd" bd_judge
  fi

  # SQL は全文の部分一致のまま（DJ-6。README の陽性対照と heredoc 経由の psql の扱いを変えない）。
  shopt -s nocasematch
  if [[ "$cmd" =~ drop[[:space:]]+table ]] ||
     [[ "$cmd" =~ drop[[:space:]]+database ]] ||
     [[ "$cmd" =~ truncate[[:space:]]+table ]]; then
    shopt -u nocasematch
    deny "Destructive SQL blocked: $cmd" "sql-destructive"
  fi
  shopt -u nocasematch

  allow
}

main
