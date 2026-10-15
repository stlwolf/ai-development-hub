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
# docs/harness/plans/2026-10-15-plan-429-destructive-hook-compound.md の DJ-1〜DJ-5・DJ-8・DJ-12。
#
# 流れ: cmd_analyze <コマンド全文> <判定の関数名>
#   → 仕事の列（CMD_QUEUE）を1件ずつ cmd_scan で segment（単純コマンド）に分け、
#     segment ごとに cmd_segment が既知の名前の token を見つけ、判定の関数に
#     (token の位置, 正規化した名前) を渡す。判定の関数は CMD_TOKS を読み、止めるなら
#     deny を呼ぶ。shell の -c の文字列・eval の中身・引用なしの heredoc の本文は列に
#     積み戻す（本文は「データの中の $( ) と ` ` だけ実行される」モードで走査する）。
#
# token は1つの配列（CMD_POOL）に直接積み、segment は配列の範囲（開始:個数）の列で表す。
# 区切りのバイトで連結しないので、どんなバイトを含む語も割れない。置換（$( )・` `）から
# 戻るときは、置換の中の segment の範囲を外側の segment の範囲の列に足し、外側はその
# 後ろの範囲で続ける（配列を写さないので語の数に比例する時間で済む）。これで置換の中の
# 語も外側の引数として判定に入る（DJ-12。rm -rf $(echo /) を止める）。
#
# 走査器は文字列を1回だけ通す（各周回で必ず位置が進む）。扱うのは、引用符（'…'・"…"・
# $'…'）、$( ) と ` `（文脈を積んで同じ走査で segment にする）、$(( )) と (( )) と $[ ]
# （算術式。中の $( ) と ` ` だけ見る）、${ }（引用符と ${ の入れ子を追い、1 token に残す。
# 中の $( ) は見る）、# の注釈（語の先頭だけ）、heredoc（区切り語の引用の有無・<<- のタブ・
# 引用なしの本文の \ と改行の連結）、転送（演算子と相手を token から除く）、\ と改行の連結
# である。扱わない形は plan の DJ-9 にある。
#
# bash 3.2 で動く書き方に限る（declare -A・mapfile・負の添字・${var,,} は使わない）。
# 空になりうる配列は ${arr[@]+"${arr[@]}"} の形で展開する（3.2 の set -u 対策）。

CMD_MAX_DEPTH=8         # shell -c / eval の入れ子の深さの上限（列の長さには上限を置かない）

# 早い経路の正規表現。既知の名前の文字の間に、引用符・\・改行・$ が挟まっていても当てる
# （r\m・"r"m・r$'m'・r\<改行>m をすり抜けさせない）。sh は bash/zsh/dash/ksh も含む。
_CMD_Q=$'[\'"\\\\\n$]*'
CMD_FAST_RE="r${_CMD_Q}m|c${_CMD_Q}h${_CMD_Q}m${_CMD_Q}o${_CMD_Q}d|c${_CMD_Q}h${_CMD_Q}o${_CMD_Q}w${_CMD_Q}n|m${_CMD_Q}k${_CMD_Q}f${_CMD_Q}s|d${_CMD_Q}d|g${_CMD_Q}i${_CMD_Q}t|e${_CMD_Q}v${_CMD_Q}a${_CMD_Q}l|s${_CMD_Q}h"

# 走査器は、解釈の要らない文字の並びを窓（_C_WIN バイト）ごとにまとめて進む。1文字ずつ
# token に足すと長い token で2乗の時間がかかるためで、窓を区切るのは残りの文字列を毎回
# 写す費用を抑えるため。状態ごとの「解釈の要らない文字」は次のとおり。
_C_WIN=256
_C_RE_SQ=$'^[^\']*'                          # 単一引用符の中: ' 以外
_C_RE_AN=$'^[^\\\']*'                        # $'…' の中: \ と ' 以外
_C_RE_DQ=$'^[^\\"`$]*'                       # 二重引用符の中: \ " ` $ 以外
_C_RE_HD=$'^[^\\`$]*'                        # 引用なし heredoc の本文: \ ` $ 以外（" は文字）
_C_RE_AR=$'^[^()$`]*'                        # $(( )) / (( )) の中: ( ) $ ` 以外（中身は見ない）
_C_RE_AQ=$'^[^][$`]*'                        # $[ ] の中: [ ] $ ` 以外
_C_RE_VB=$'^[^}{$`"\'\\\\]*'                 # ${ } の中（引用の外）: } { $ ` " ' \ 以外
_C_RE_PL=$'^[^ \t\n\\\'"$`#&|;(){}!<>]*'     # 引用符の外: 区切り・引用・転送などの記号以外

CMD_QUEUE=(); CMD_QDEPTH=(); CMD_QMODE=()
CMD_POOL=(); CMD_SEG_RANGES=(); CMD_TOKS=()
CMD_JUDGED=''           # segment の中で判定を済ませた名前（同じ名前は後ろの引数の部分集合なので1回で足りる）

# 既知の名前が1つも無い行は走査しない（早い経路）。文字列置換を使わず正規表現1回で見る
# （bash 3.2 の ${var//…} は一致が多いと極端に遅い）。
cmd_fast_skip() {
  if [[ "$1" =~ $CMD_FAST_RE ]]; then
    return 1
  fi
  return 0
}

# ---- 走査器の状態（cmd_scan の中だけで使う。関数の外から読まない） ----
# _C_SEGRANGES = いまの segment の確定した範囲の列（"開始:個数 …"）。_C_SEGSTART/_C_SEGN = 開いている範囲。
_C_TOK=''; _C_TOKQ=0; _C_SEGRANGES=''; _C_SEGSTART=0; _C_SEGN=0; _C_Q=''; _C_DROP=0; _C_DEPTH=0; _C_CURDEPTH=0; _C_RD=0; _C_WB=1
_C_ST_SEGRANGES=(); _C_ST_TOK=(); _C_ST_TOKQ=(); _C_ST_Q=(); _C_ST_KIND=(); _C_ST_DROP=(); _C_ST_RD=(); _C_ST_NSEG=()
_C_HD_WORD=(); _C_HD_Q=(); _C_HD_STRIP=()

# 開いている範囲を閉じて範囲の列に足す。
_cmd_range_close() {
  if (( _C_SEGN > 0 )); then
    if [[ -n "$_C_SEGRANGES" ]]; then _C_SEGRANGES+=" $_C_SEGSTART:$_C_SEGN"; else _C_SEGRANGES="$_C_SEGSTART:$_C_SEGN"; fi
  fi
  _C_SEGSTART=${#CMD_POOL[@]}; _C_SEGN=0
}

# 今の token を segment に加える（配列の末尾に積む）。転送の相手（_C_DROP=1）なら捨てる。
_cmd_tok_end() {
  if [[ "$_C_DROP" == 1 ]]; then
    if [[ -n "$_C_TOK" || "$_C_TOKQ" == 1 ]]; then
      _C_DROP=0
    fi
  elif [[ -n "$_C_TOK" || "$_C_TOKQ" == 1 ]]; then
    CMD_POOL+=("$_C_TOK")
    _C_SEGN=$((_C_SEGN + 1))
  fi
  _C_TOK=''; _C_TOKQ=0
  _C_WB=1
}

# 今の segment を閉じて範囲の列を登録する。
_cmd_seg_end() {
  _cmd_tok_end
  _cmd_range_close
  if [[ -n "$_C_SEGRANGES" ]]; then
    CMD_SEG_RANGES+=("$_C_SEGRANGES")
  fi
  _C_SEGRANGES=''; _C_DROP=0
}

# 置換や算術式や ${ } に入る。外側の状態を積む。
#   p = $( )  b = ` `  r = $(( )) / (( ))  q = $[ ]  v = ${ }
# p/b/r/q は新しい segment を始める。v は外側の語の続き（語に文字を足し続ける）。
_cmd_push() { # $1 = 種類
  if [[ "$1" != v ]]; then _cmd_range_close; fi
  _C_ST_SEGRANGES+=("$_C_SEGRANGES"); _C_ST_TOK+=("$_C_TOK"); _C_ST_TOKQ+=("$_C_TOKQ")
  _C_ST_Q+=("$_C_Q"); _C_ST_KIND+=("$1"); _C_ST_DROP+=("$_C_DROP"); _C_ST_RD+=("$_C_RD"); _C_ST_NSEG+=("${#CMD_SEG_RANGES[@]}")
  if [[ "$1" != v ]]; then
    _C_SEGRANGES=''; _C_TOK=''; _C_TOKQ=0; _C_DROP=0
  fi
  _C_Q=''; _C_RD=0; _C_WB=1
  _C_DEPTH=$((_C_DEPTH + 1))
}

# 置換の閉じ。中身の最後の segment を閉じ、外側の状態に戻る。
# p/b/r/q: 中の segment の範囲を外側の範囲の列に足し（DJ-12・中の語も外側の引数になる）、
#   外側はその後ろの新しい範囲で続ける。置換を含んだ語は字面に $( ) や ` ` を残し引用扱いに
#   する（絶対パスに見せない・既知の名前に当てない）。
# v: 語は続きなので範囲は触らない。
_cmd_pop() {
  local k=$((_C_DEPTH - 1)) kind n0 m
  kind="${_C_ST_KIND[k]}"
  if [[ "$kind" == v ]]; then
    _C_Q="${_C_ST_Q[k]}"; _C_RD="${_C_ST_RD[k]}"; _C_TOKQ=1
  else
    _cmd_seg_end
    n0="${_C_ST_NSEG[k]}"
    _C_SEGRANGES="${_C_ST_SEGRANGES[k]}"
    m=$n0
    while (( m < ${#CMD_SEG_RANGES[@]} )); do
      if [[ -n "$_C_SEGRANGES" ]]; then _C_SEGRANGES+=" ${CMD_SEG_RANGES[m]}"; else _C_SEGRANGES="${CMD_SEG_RANGES[m]}"; fi
      m=$((m + 1))
    done
    _C_SEGSTART=${#CMD_POOL[@]}; _C_SEGN=0
    _C_TOK="${_C_ST_TOK[k]}"; _C_TOKQ=1
    case "$kind" in p) _C_TOK+=')' ;; b) _C_TOK+='`' ;; r) _C_TOK+='))' ;; q) _C_TOK+=']' ;; esac
    _C_Q="${_C_ST_Q[k]}"; _C_DROP="${_C_ST_DROP[k]}"; _C_RD="${_C_ST_RD[k]}"
  fi
  unset '_C_ST_SEGRANGES[k]' '_C_ST_TOK[k]' '_C_ST_TOKQ[k]' '_C_ST_Q[k]' '_C_ST_KIND[k]' '_C_ST_DROP[k]' '_C_ST_RD[k]' '_C_ST_NSEG[k]'
  _C_DEPTH=$((_C_DEPTH - 1))
  _C_WB=0
}

# 以下の _cmd_* は cmd_scan から呼ばれ、cmd_scan のローカル変数 s（文字列）・n（長さ）・
# i（位置）・line を動的スコープで読み書きする（bash の関数のローカル変数は呼び出し先から見える）。

# 今の token が数字だけなら fd 番号（2>&1 の 2）なので捨てる。それ以外は普通に終える。
_cmd_tok_fd_end() {
  if [[ "$_C_TOKQ" == 0 && "$_C_TOK" =~ ^[0-9]+$ ]]; then
    _C_TOK=''; _C_TOKQ=0
  else
    _cmd_tok_end
  fi
}

# 転送の演算子を読み飛ばし、相手の token を捨てる印を立てる（i は演算子の先頭）。
# << は heredoc、<<< は here-string。相手が ( なら process substitution で、入れ子の文脈として走査する。
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
    _C_TOK+="$op("; _cmd_push p; i=$((i + 1))
    return 0
  fi
  _C_DROP=1
}

# heredoc の区切り語を読み、待ち行列に積む（i は << の位置）。区切り語には token と同じ
# 引用の規則（'…'・"…"・$'…'・\）を当てる。引用符か \ が1つでもあれば「引用あり」とし、
# 値は引用を解いたものにする（空も有効）。\ と改行は連結で引用ではない。
_cmd_heredoc_start() {
  local strip=0 word='' wq=0 ch nx
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
          ch="${s:i:1}"
          if [[ "$ch" == "\\" ]]; then
            nx="${s:i+1:1}"
            case "$nx" in '$'|'`'|'"'|"\\") ch="$nx"; i=$((i + 1)) ;; esac
          fi
          word+="$ch"; i=$((i + 1))
        done
        i=$((i + 1))
        ;;
      '$')
        if [[ "${s:i+1:1}" == "'" ]]; then
          wq=1; i=$((i + 2))
          while (( i < n )) && [[ "${s:i:1}" != "'" ]]; do
            ch="${s:i:1}"
            if [[ "$ch" == "\\" ]]; then
              nx="${s:i+1:1}"
              case "$nx" in "'") ch="'"; i=$((i + 1)) ;; "\\") ch="\\"; i=$((i + 1)) ;; esac
            fi
            word+="$ch"; i=$((i + 1))
          done
          i=$((i + 1))
        else
          word+='$'; i=$((i + 1))
        fi
        ;;
      "\\")
        if [[ "${s:i+1:1}" == $'\n' ]]; then i=$((i + 2)); else wq=1; word+="${s:i+1:1}"; i=$((i + 2)); fi
        ;;
      *) word+="$ch"; i=$((i + 1)) ;;
    esac
  done
  _C_HD_WORD+=("$word"); _C_HD_Q+=("$wq"); _C_HD_STRIP+=("$strip")
}

# i から次の改行の手前までを line に入れ、i を改行の次へ進める（改行が無ければ末尾まで）。
# 残り全文を写さず、窓を倍にしながら探す（短い行が何千もある heredoc で2乗にしないため）。
_cmd_next_line() {
  local w=$_C_WIN chunk
  while :; do
    chunk="${s:i:w}"
    if [[ "$chunk" == *$'\n'* ]]; then
      line="${chunk%%$'\n'*}"; i=$((i + ${#line} + 1)); return 0
    fi
    if (( ${#chunk} < w )); then
      line="$chunk"; i=$((i + ${#chunk})); return 0
    fi
    w=$((w * 2))
  done
}

# 行末の \ の数が奇数なら 0（次の行と連結する）、偶数なら 1。
_cmd_odd_trailing_backslash() {
  local t="$1" cnt=0
  while [[ "$t" == *"\\" ]]; do t="${t%"\\"}"; cnt=$((cnt + 1)); done
  if (( cnt % 2 == 1 )); then return 0; fi
  return 1
}

# 改行の直後に、待ち行列の heredoc の本文を順に読む（i は本文の先頭）。
# 区切り語の行（<<- なら先頭のタブを除いて比べる）まで。無ければ残り全部が本文。
# 引用ありの本文はデータで何もしない。引用なしの本文は \ と改行を連結してから区切り語と
# 比べ、本文全体を「データの中の $( ) と ` ` だけ実行される」モード（h）で列に積む。
_cmd_heredoc_bodies() {
  local k=0 cnt=${#_C_HD_WORD[@]} word wq strip line cmp body tab=$'\t'
  while (( k < cnt )); do
    word="${_C_HD_WORD[k]}"; wq="${_C_HD_Q[k]}"; strip="${_C_HD_STRIP[k]}"
    body=''
    while (( i < n )); do
      _cmd_next_line
      if (( wq == 0 )); then
        while (( i < n )) && _cmd_odd_trailing_backslash "$line"; do
          cmp="${line%"\\"}"; _cmd_next_line; line="$cmp$line"
        done
      fi
      cmp="$line"
      if (( strip == 1 )); then cmp="${cmp#"${cmp%%[!"$tab"]*}"}"; fi
      if [[ "$cmp" == "$word" ]]; then break; fi
      if (( wq == 0 )); then body+="$line"$'\n'; fi
    done
    if (( wq == 0 )) && [[ "$body" == *"\$("* || "$body" == *'`'* ]]; then
      CMD_QUEUE+=("$body"); CMD_QDEPTH+=("$_C_CURDEPTH"); CMD_QMODE+=(h)
    fi
    k=$((k + 1))
  done
  _C_HD_WORD=(); _C_HD_Q=(); _C_HD_STRIP=()
}

# 文字列を1回走査して segment を登録する。$2 はこの文字列の入れ子の深さ、$3 はモード
# （'' = コマンド行 / h = 引用なし heredoc の本文。h では外側はデータで、$( ) と ` ` の中
# だけがコマンドになる）。
# LC_ALL=C はこの関数の中だけ（バイト単位の走査にして 3.2 でも速くする。判定するのは
# ASCII の構文だけなので、UTF-8 の文字をバイトで扱っても壊れない）。
# shellcheck disable=SC2016  # '$(' '${' などは語の字面に残す文字列で、展開させない
cmd_scan() {
  local LC_ALL=C
  local s="$1" n i=0 c nx k st line
  _C_CURDEPTH="$2"
  n=${#s}
  _C_TOK=''; _C_TOKQ=0; _C_SEGRANGES=''; _C_SEGSTART=${#CMD_POOL[@]}; _C_SEGN=0; _C_Q="${3:-}"; _C_DROP=0; _C_DEPTH=0; _C_RD=0; _C_WB=1
  _C_ST_SEGRANGES=(); _C_ST_TOK=(); _C_ST_TOKQ=(); _C_ST_Q=(); _C_ST_KIND=(); _C_ST_DROP=(); _C_ST_RD=(); _C_ST_NSEG=()
  _C_HD_WORD=(); _C_HD_Q=(); _C_HD_STRIP=()
  while (( i < n )); do
    # いまの状態。引用の中はその引用、引用の外で算術式や ${ } の中ならその種類、それ以外は引用の外。
    st="$_C_Q"
    if [[ -z "$st" ]] && (( _C_DEPTH > 0 )); then
      case "${_C_ST_KIND[_C_DEPTH-1]}" in r) st=r ;; q) st=q ;; v) st=v ;; esac
    fi
    # 解釈の要らない文字の並びは窓ごとにまとめて進む（上の _C_RE_*）。
    case "$st" in
      "'") [[ "${s:i:_C_WIN}" =~ $_C_RE_SQ ]] ;;
      a)   [[ "${s:i:_C_WIN}" =~ $_C_RE_AN ]] ;;
      '"') [[ "${s:i:_C_WIN}" =~ $_C_RE_DQ ]] ;;
      h)   [[ "${s:i:_C_WIN}" =~ $_C_RE_HD ]] ;;
      r)   [[ "${s:i:_C_WIN}" =~ $_C_RE_AR ]] ;;
      q)   [[ "${s:i:_C_WIN}" =~ $_C_RE_AQ ]] ;;
      v)   [[ "${s:i:_C_WIN}" =~ $_C_RE_VB ]] ;;
      *)   [[ "${s:i:_C_WIN}" =~ $_C_RE_PL ]] ;;
    esac
    k=${#BASH_REMATCH[0]}
    if (( k > 0 )); then
      case "$st" in r|q) ;; *) _C_TOK+="${BASH_REMATCH[0]}" ;; esac
      _C_WB=0
      i=$((i + k)); continue
    fi
    c="${s:i:1}"
    case "$st" in
      "'")
        _C_TOK+="$c"; i=$((i + 1))
        if [[ "$c" == "'" ]]; then
          _C_Q=''
          # ${ } の中の引用でなければ、引用符そのものは語の値に入れない
          if (( _C_DEPTH == 0 )) || [[ "${_C_ST_KIND[_C_DEPTH-1]}" != v ]]; then _C_TOK="${_C_TOK%\'}"; fi
        fi
        continue ;;
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
      '"'|h)
        case "$c" in
          "\\")
            nx="${s:i+1:1}"
            case "$nx" in
              '$'|'`'|"\\") _C_TOK+="$nx"; i=$((i + 2)) ;;
              '"') if [[ "$st" == h ]]; then _C_TOK+='\"'; i=$((i + 2)); else _C_TOK+='"'; i=$((i + 2)); fi ;;
              $'\n') i=$((i + 2)) ;;
              *) _C_TOK+="\\"; i=$((i + 1)) ;;
            esac
            continue ;;
          '"')
            if [[ "$st" == h ]]; then
              _C_TOK+='"'
            else
              _C_Q=''
              # ${ } の中の引用なら引用符そのものも語の値に残す
              if (( _C_DEPTH > 0 )) && [[ "${_C_ST_KIND[_C_DEPTH-1]}" == v ]]; then _C_TOK+='"'; fi
            fi
            i=$((i + 1)); continue ;;
          '`') _C_TOK+='`'; _cmd_push b; i=$((i + 1)); continue ;;
          '$')
            nx="${s:i+1:1}"
            if [[ "$nx" == '(' ]]; then
              if [[ "${s:i+2:1}" == '(' ]]; then _C_TOK+='$(('; _cmd_push r; i=$((i + 3)); else _C_TOK+='$('; _cmd_push p; i=$((i + 2)); fi
              continue
            fi
            if [[ "$nx" == '{' ]]; then _C_TOK+='${'; _cmd_push v; _C_TOKQ=1; i=$((i + 2)); continue; fi
            if [[ "$nx" == '[' ]]; then _C_TOK+='$['; _cmd_push q; i=$((i + 2)); continue; fi
            _C_TOK+='$'; i=$((i + 1)); continue ;;
          *) _C_TOK+="$c"; i=$((i + 1)); continue ;;
        esac ;;
      r|q)
        # 算術式の中。中身は見ず、$( ) と ` ` だけ拾う。括弧の入れ子を数え、)) か ] で抜ける。
        case "$c" in
          '('|'[') _C_RD=$((_C_RD + 1)); i=$((i + 1)) ;;
          ')'|']')
            if (( _C_RD > 0 )); then
              _C_RD=$((_C_RD - 1)); i=$((i + 1))
            else
              _cmd_pop
              if [[ "$c" == ')' && "${s:i+1:1}" == ')' ]]; then i=$((i + 2)); else i=$((i + 1)); fi
            fi
            ;;
          '$')
            nx="${s:i+1:1}"
            if [[ "$nx" == '(' ]]; then
              if [[ "${s:i+2:1}" == '(' ]]; then _cmd_push r; i=$((i + 3)); else _cmd_push p; i=$((i + 2)); fi
            elif [[ "$nx" == '[' ]]; then
              _cmd_push q; i=$((i + 2))
            else
              i=$((i + 1))
            fi
            ;;
          '`') _cmd_push b; i=$((i + 1)) ;;
          *) i=$((i + 1)) ;;
        esac
        continue ;;
      v)
        # ${ } の中（引用の外）。文字は語に足す。${ の入れ子を数え、} で抜ける。素の { は数えない。
        case "$c" in
          '}')
            _C_TOK+='}'; i=$((i + 1))
            if (( _C_RD > 0 )); then _C_RD=$((_C_RD - 1)); else _cmd_pop; fi
            ;;
          '$')
            nx="${s:i+1:1}"
            if [[ "$nx" == '{' ]]; then _C_TOK+='${'; _C_RD=$((_C_RD + 1)); i=$((i + 2))
            elif [[ "$nx" == '(' ]]; then
              if [[ "${s:i+2:1}" == '(' ]]; then _C_TOK+='$(('; _cmd_push r; i=$((i + 3)); else _C_TOK+='$('; _cmd_push p; i=$((i + 2)); fi
            elif [[ "$nx" == '[' ]]; then _C_TOK+='$['; _cmd_push q; i=$((i + 2))
            else _C_TOK+='$'; i=$((i + 1)); fi
            ;;
          '`') _C_TOK+='`'; _cmd_push b; i=$((i + 1)) ;;
          '"') _C_TOK+='"'; _C_Q='"'; i=$((i + 1)) ;;
          "'") _C_TOK+="'"; _C_Q="'"; i=$((i + 1)) ;;
          "\\") _C_TOK+="\\${s:i+1:1}"; i=$((i + 2)) ;;
          *) _C_TOK+="$c"; i=$((i + 1)) ;;
        esac
        continue ;;
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
          _C_TOK+="$nx"; _C_TOKQ=1; _C_WB=0; i=$((i + 2))
        fi
        ;;
      "'") _C_Q="'"; _C_TOKQ=1; _C_WB=0; i=$((i + 1)) ;;
      '"') _C_Q='"'; _C_TOKQ=1; _C_WB=0; i=$((i + 1)) ;;
      '$')
        nx="${s:i+1:1}"
        case "$nx" in
          "'") _C_Q=a; _C_TOKQ=1; _C_WB=0; i=$((i + 2)) ;;
          '(')
            if [[ "${s:i+2:1}" == '(' ]]; then _C_TOK+='$(('; _cmd_push r; i=$((i + 3)); else _C_TOK+='$('; _cmd_push p; i=$((i + 2)); fi
            ;;
          '{') _C_TOK+='${'; _cmd_push v; _C_TOKQ=1; i=$((i + 2)) ;;
          '[') _C_TOK+='$['; _cmd_push q; i=$((i + 2)) ;;
          *) _C_TOK+='$'; _C_WB=0; i=$((i + 1)) ;;
        esac
        ;;
      '`')
        if (( _C_DEPTH > 0 )) && [[ "${_C_ST_KIND[_C_DEPTH-1]}" == b ]]; then _cmd_pop; else _C_TOK+='`'; _cmd_push b; fi
        i=$((i + 1))
        ;;
      '#')
        if (( _C_WB == 1 )); then
          _cmd_next_line; i=$((i - 1))
          if (( i < 0 )); then i=0; fi
          if [[ "${s:i:1}" != $'\n' ]]; then i=$n; fi
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
      '(')
        if (( _C_WB == 1 )) && [[ "${s:i+1:1}" == '(' ]]; then
          # 行の先頭の (( … )) は算術式のコマンド
          _cmd_seg_end; _cmd_push r; i=$((i + 2))
        else
          # サブシェルの開き。置換の中では ( ) の入れ子を数え、対応する ) で置換を閉じない
          _cmd_seg_end; _C_RD=$((_C_RD + 1)); i=$((i + 1))
        fi
        ;;
      ')')
        if (( _C_RD > 0 )); then
          _C_RD=$((_C_RD - 1)); _cmd_seg_end
        elif (( _C_DEPTH > 0 )) && [[ "${_C_ST_KIND[_C_DEPTH-1]}" == p ]]; then
          _cmd_pop
        else
          _cmd_seg_end
        fi
        i=$((i + 1))
        ;;
      '{'|'}') _cmd_tok_end; _C_WB=0; i=$((i + 1)) ;;
      '!')
        if (( _C_WB == 1 )); then _C_WB=0; i=$((i + 1)); else _C_TOK+='!'; i=$((i + 1)); fi
        ;;
      '<'|'>') _cmd_redirect ;;
      *) _C_TOK+="$c"; _C_WB=0; i=$((i + 1)) ;;
    esac
  done
  # 閉じていない置換は、中身を segment として残し、外側へ戻ってから閉じる（外側を捨てない）。
  while (( _C_DEPTH > 0 )); do _cmd_pop; done
  # h モードの外側（heredoc の本文そのもの）はデータなので segment にしない。
  if [[ "$_C_Q" == h ]]; then _C_TOK=''; _C_TOKQ=0; _C_SEGRANGES=''; _C_SEGN=0; _C_SEGSTART=${#CMD_POOL[@]}; fi
  _cmd_seg_end
}

# shell の token の後ろをオプションとして歩き、-c があればその文字列を列に積む（積んだら 0）。
# -- はオプションの終わり。-o X・+o X・-O X・+O X・--rcfile X・--init-file X は次も飛ばす。
# -c が無ければスクリプトファイルなので扱わない（DJ-9）。
_cmd_shell_c() { # $1 = shell の token の位置, $2 = 深さ
  local j=$(($1 + 1)) n=${#CMD_TOKS[@]} seen=0 t
  while (( j < n )); do
    t="${CMD_TOKS[j]}"
    case "$t" in
      --) j=$((j + 1)); break ;;
      -o|+o|-O|+O|--rcfile|--init-file) j=$((j + 2)) ;;
      -c) seen=1; j=$((j + 1)) ;;
      --*) j=$((j + 1)) ;;
      -*c*) seen=1; j=$((j + 1)) ;;
      -*|+*) j=$((j + 1)) ;;
      *) break ;;
    esac
  done
  if (( seen == 1 && j < n )); then
    CMD_QUEUE+=("${CMD_TOKS[j]}"); CMD_QDEPTH+=("$(($2 + 1))"); CMD_QMODE+=('')
    return 0
  fi
  return 1
}

# eval の後ろの token を空白で連結して列に積む。
_cmd_eval() { # $1 = eval の位置, $2 = 深さ
  local j=$(($1 + 1)) n=${#CMD_TOKS[@]} joined=''
  while (( j < n )); do
    if [[ -n "$joined" ]]; then joined+=" ${CMD_TOKS[j]}"; else joined="${CMD_TOKS[j]}"; fi
    j=$((j + 1))
  done
  if [[ -n "$joined" ]]; then
    CMD_QUEUE+=("$joined"); CMD_QDEPTH+=("$(($2 + 1))"); CMD_QMODE+=('')
  fi
}

# segment の token を CMD_TOKS に取り出し、既知の名前に一致する token を**すべて**判定の
# 関数に渡す（DJ-3）。名前は先頭の \ を解いた後の値の basename で比べる。shell は、-c の
# 文字列を取れた最初の1つだけを列に積む（env -u bash sh -c '…' の bash のように文字列の
# 無いものは飛ばす）。eval は segment の最初の1つだけ。
cmd_segment() { # $1 = 範囲の列（"開始:個数 …"）, $2 = 深さ, $3 = 判定の関数名
  local d="$2" judge="$3" i=0 n name shell_done=0 r s c j
  # 範囲は配列の中で昇順なので、添字を増やしながら読む（bash 3.2 の配列は順に読むと速い）
  CMD_TOKS=()
  for r in $1; do
    s="${r%%:*}"; c="${r#*:}"; j=$s
    while (( j < s + c )); do CMD_TOKS+=("${CMD_POOL[j]}"); j=$((j + 1)); done
  done
  CMD_JUDGED=''
  n=${#CMD_TOKS[@]}
  while (( i < n )); do
    name="${CMD_TOKS[i]}"
    if [[ "$name" == */* ]]; then name="${name##*/}"; fi
    case "$name" in
      bash|sh|zsh|dash|ksh)
        if (( shell_done == 0 )) && _cmd_shell_c "$i" "$d"; then shell_done=1; fi
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

# 判定の関数が使う。同じ名前の判定を segment の中で1回に抑える（後ろに現れた同じ名前の
# 引数は、先に現れたものの引数の部分集合なので、先の判定で足りる。git の subcommand は
# 位置で決まるので git 自体は毎回見て、reset / clean / push の判定だけをここで1回にする）。
# shellcheck disable=SC2317  # 判定の関数（名前で間接に呼ばれる）から呼ばれる
cmd_once() { # $1 = 判定の鍵。初めてなら 0、済みなら 1
  case " $CMD_JUDGED " in *" $1 "*) return 1 ;; esac
  CMD_JUDGED+=" $1"
  return 0
}

# 入口。列の深さが上限を超えたら「解析できない」として deny する（保守的）。
cmd_analyze() { # $1 = コマンド全文, $2 = 判定の関数名
  local judge="$2" qi=0 text d m
  CMD_QUEUE=("$1"); CMD_QDEPTH=(0); CMD_QMODE=('')
  while (( qi < ${#CMD_QUEUE[@]} )); do
    text="${CMD_QUEUE[qi]}"; d="${CMD_QDEPTH[qi]}"
    if (( d > CMD_MAX_DEPTH )); then
      deny "Command nesting too deep to analyze (bash -c / eval); blocked conservatively: $cmd" "nesting-limit"
    fi
    CMD_POOL=(); CMD_SEG_RANGES=()
    cmd_scan "$text" "$d" "${CMD_QMODE[qi]}"
    qi=$((qi + 1))
    m=0
    while (( m < ${#CMD_SEG_RANGES[@]} )); do
      cmd_segment "${CMD_SEG_RANGES[m]}" "$d" "$judge"
      m=$((m + 1))
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
  # 同じ segment で判定済みなら見ない（印は下で、-- を見なかったときだけ付ける）
  case " $CMD_JUDGED " in *" rm "*) return 0 ;; esac
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
  # -- を見た rm は、その後ろに現れる別の rm の引数の読み方（フラグの有無）が変わるので、
  # 同じ名前の判定を1回に抑える鍵には入れない（env -u rm -- rm -rf / の2つ目を見るため）
  if (( saw_dd == 0 )); then CMD_JUDGED+=" rm"; fi
  if (( has_r == 0 || has_f == 0 || nt == 0 )); then return 0; fi
  for t in "${targets[@]}"; do
    while [[ "$t" == */ && "$t" != / ]]; do t="${t%/}"; done
    # 先頭の ./ を落とし、続く余分な / も落とす（.//node_modules は相対パスのまま）
    while [[ "$t" == ./?* ]]; do t="${t#./}"; t="${t#"${t%%[!/]*}"}"; done
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

# mkfs*: /dev/ で始まる引数か、変数や置換の引数（$ で始まる。判断9）があれば位置にかかわらず deny。
# segment の先頭（コマンドの位置）に在って - で始まらない引数があるときも deny（イメージ
# ファイルへの mkfs を今までどおり止める）。名前だけでは止めない（command -v mkfs.ext4 や
# git grep mkfs.ext4 <file> を通す・DJ-3）。
# shellcheck disable=SC2317  # cmd_analyze から名前で間接に呼ばれる
bd_check_mkfs() {
  local pos="$1" i=$(($1 + 1)) n=${#CMD_TOKS[@]} t
  while (( i < n )); do
    t="${CMD_TOKS[i]}"; i=$((i + 1))
    case "$t" in
      /dev/*|'$'*) deny "Destructive mkfs blocked: $cmd" "mkfs" ;;
      -*) ;;
      *) if (( pos == 0 )); then deny "Destructive mkfs blocked: $cmd" "mkfs"; fi ;;
    esac
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
  local i=$(($1 + 1)) n=${#CMD_TOKS[@]} t sub='' f=0 d=0 x=0 dry=0 letters ch
  while (( i < n )); do
    t="${CMD_TOKS[i]}"
    case "$t" in
      -C|-c|--git-dir|--work-tree|--namespace|--config-env|--attr-source|--shallow-file|--super-prefix) i=$((i + 2)); continue ;;
      -*) i=$((i + 1)); continue ;;
      *) sub="$t"; i=$((i + 1)); break ;;
    esac
  done
  case "$sub" in
    reset)
      cmd_once git-reset || return 0
      while (( i < n )); do
        if [[ "${CMD_TOKS[i]}" == --hard ]]; then
          deny "Destructive git reset blocked: $cmd" "git-reset-hard"
        fi
        i=$((i + 1))
      done
      ;;
    clean)
      cmd_once git-clean || return 0
      while (( i < n )); do
        t="${CMD_TOKS[i]}"; i=$((i + 1))
        case "$t" in
          --) break ;;
          --force) f=1 ;;
          --dry-run) dry=1 ;;
          --no-dry-run) dry=0 ;;                                          # 後ろのものが勝つ
          --exclude=*|--e=*|--ex=*|--exc=*|--excl=*|--exclu=*|--exclud=*) ;;   # 付けて書いた除外パターン（省略形を含む）
          --exclude|--e|--ex|--exc|--excl|--exclu|--exclud) i=$((i + 1)) ;;     # 除外パターンは次の token
          --*) ;;
          -?*)
            # 短オプションの束。e から後ろは除外パターンの値（無ければ次の token が値）
            letters="${t#-}"
            while [[ -n "$letters" ]]; do
              ch="${letters:0:1}"; letters="${letters:1}"
              case "$ch" in
                f) f=1 ;;
                d) d=1 ;;
                x) x=1 ;;
                n) dry=1 ;;
                e) if [[ -z "$letters" ]]; then i=$((i + 1)); fi; break ;;
              esac
            done
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
    chmod) cmd_once chmod && bd_check_chmod "$1" ;;
    chown) cmd_once chown && bd_check_chown "$1" ;;
    mkfs*) cmd_once "$2" && bd_check_mkfs "$1" ;;
    dd)    cmd_once dd && bd_check_dd "$1" ;;
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
