#!/usr/bin/env bash
# oe-viewer.sh — viewer ペイン解決ロジック（oe-view 用・source 専用）
#
# Sourced by bin/oe-view. Not intended for standalone execution.
# 責務: viewer ペイン（md を glow で描画する固定ペイン）の state file 追跡・生存確認・
#       argv-spawn の replace モデル（生存なら kill→新規 spawn / stale・無しなら spawn）。
# Naming: oe_viewer_* for public, _oe_viewer_* for private。wez（engine）ペインの操作は
#         すべて下層プリミティブ `wez pane …` 経由（ADR-001/004 の wez=下層方針を守る）。
#
# viewer 解決（DJ-4・argv-spawn replace モデル・実機検証で確定・§11）:
#   実機検証で「split したシェルへ glow をタイプ送信」する旧モデルが破綻していた
#   （新規 wez ペインのシェル rc が tmux に自動アタッチし、send したコマンドが実行されず
#    glow が描画されない）。代わりに **ペインのプログラムとして glow を直接起動**する:
#     wez pane split --right --percent <P> --cwd <dir> -- glow -p -- <path>
#   （wezterm cli split-pane [PROG]＝シェルの代わりに PROG を実行・公式仕様）。
#   シェルも tmux も経由しないため確実に描画され、path が argv 要素として渡るので
#   再トークナイズが起きず注入面が消滅する（§5・%q 不要）。
#   glow -p はページャ（シェルではない）ため send による再利用ができない。よって再利用は
#   **replace**: state（OE_VIEW_STATE_FILE）の viewer が生存なら kill → 新 glow ペインを
#   spawn → state 更新 / stale・無しなら spawn + state 更新。spawn 後に source ペイン
#   （WEZTERM_PANE）へ activate して focus 奪取を回避（#111）。
#
# 前の viewer を閉じてよいかの確かめ（#509・plan 2026-11-18-plan-509 の DJ-1）:
#   WezTerm のペイン番号はプロセスの中のカウンタで 0 から増やすだけで、同じプロセスの中では
#   使い回さない（wezterm の mux/src/pane.rs）。起動し直すと 0 から振り直す。そこで記録には番号と
#   一緒に「どの GUI のプロセスの番号か」（ソケットの実体のパスと、その GUI のプロセスの開始時刻）を
#   書き、閉じる前に今の接続先と照らす。照らせないとき（古い形の記録・別の GUI・開始時刻が違う・
#   取れない）は閉じずに、新しい viewer を開くだけにする。古い viewer が残るのは受け入れる。
#   wez は呼ぶたびに接続先を決め直すので、1回の resolve の中の pane の呼び出しはすべて同じ
#   --socket に固定する。

# viewer の記録（最後の viewer 1 件のみ・上書き・key=value の3行・#509）。テストは env で隔離する。
#   pane_id=<viewer のペイン番号>
#   socket=<viewer を開いた GUI のソケットの実体のパス>
#   mux_started=<その GUI のプロセスの開始時刻（LC_ALL=C ps -o lstart= の前後の空白を削った値）>
# ファイル名（viewer-pane-id）は #509 より前と同じにしてある。前の形（番号だけの1行）は照らせないので、
# 形を変えたあとの最初の1回は前の viewer を閉じない。
# HOME を暗黙の既定パスに使ってよいかを決める（#322・全箇所で byte 一致させる）。
# 非空だけでは足りない: HOME=/ は //.claude/... ＝ root 直下を掴み、相対 HOME は cwd 配下へ
# state を散らす。先例（canonical/hooks/scripts/cc-lint.sh:39-41）が -n で済むのは、あちらが
# tally を 1 バイト追記するだけの best-effort だからで、state を作る engine には足りない。
declare -F _oe_home_usable >/dev/null 2>&1 || _oe_home_usable() { case "${HOME:-}" in /|//) return 1;; /*) return 0;; *) return 1;; esac; }

if   [ -n "${OE_VIEW_STATE_DIR+x}" ]; then :
elif _oe_home_usable; then OE_VIEW_STATE_DIR="${HOME}/.claude/state/oe-view"
else                       OE_VIEW_STATE_DIR=""
fi
OE_VIEW_STATE_FILE="${OE_VIEW_STATE_DIR}/viewer-pane-id"

# 新規 viewer split のジオメトリ（既定: 右 40%）。
OE_VIEW_SPLIT_DIR="${OE_VIEW_SPLIT_DIR:---right}"
OE_VIEW_SPLIT_PERCENT="${OE_VIEW_SPLIT_PERCENT:-40}"

# _oe_viewer_read_state — 記録を読み、_OE_VIEWER_REC_PANE / _OE_VIEWER_REC_SOCKET /
#   _OE_VIEWER_REC_STARTED に入れる（無い項目は空・常に rc 0）。source や eval は使わず、
#   各行を最初の `=` で分ける。前の形（番号だけの1行）は `=` が無いので、3つとも空になる。
_oe_viewer_read_state() {
  _OE_VIEWER_REC_PANE=""; _OE_VIEWER_REC_SOCKET=""; _OE_VIEWER_REC_STARTED=""
  [[ -r "$OE_VIEW_STATE_FILE" ]] || return 0
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || continue
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
      pane_id)     _OE_VIEWER_REC_PANE="$val" ;;
      socket)      _OE_VIEWER_REC_SOCKET="$val" ;;
      mux_started) _OE_VIEWER_REC_STARTED="$val" ;;
    esac
  done < "$OE_VIEW_STATE_FILE"
  return 0
}

# _oe_viewer_write_state <pane_id> <socket> <mux_started> — 記録を atomic に書く（oe-jump 同型）。
_oe_viewer_write_state() {
  local pane_id="$1" socket="$2" started="$3"
  mkdir -p "$OE_VIEW_STATE_DIR" 2>/dev/null || {
    echo "oe-view: cannot create state dir ${OE_VIEW_STATE_DIR}" >&2; return 1; }
  local tmp="${OE_VIEW_STATE_FILE}.tmp.$$"
  if printf 'pane_id=%s\nsocket=%s\nmux_started=%s\n' "$pane_id" "$socket" "$started" >"$tmp" 2>/dev/null \
    && mv -f "$tmp" "$OE_VIEW_STATE_FILE" 2>/dev/null; then
    return 0
  fi
  rm -f "$tmp" 2>/dev/null
  echo "oe-view: failed to record viewer pane id to ${OE_VIEW_STATE_FILE}" >&2
  return 1
}

# _oe_viewer_clear_state — 記録を消す（次の回は前の viewer を閉じない）。rc 0=消した・無かった / 1=消せない。
_oe_viewer_clear_state() {
  rm -f "$OE_VIEW_STATE_FILE" 2>/dev/null && return 0
  echo "oe-view: failed to remove viewer record ${OE_VIEW_STATE_FILE}" >&2
  return 1
}

# _oe_viewer_socket — 今回の接続先の WezTerm のソケットを、symlink をたどった実体のパスで stdout へ。
#   `wez discover --quiet` を1回だけ呼ぶ。realpath が無ければ、たどらずにそのまま使う（symlink の
#   名前は gui-sock-<番号> の形にならないので、照らせず閉じない側に倒れる）。
#   rc 0=決まった / 1=決まらない（discover の失敗・空の出力）。
_oe_viewer_socket() {
  local socket real
  socket="$(wez discover --quiet 2>/dev/null)" || return 1
  [[ -n "$socket" ]] || return 1
  if command -v realpath >/dev/null 2>&1 && real="$(realpath -- "$socket" 2>/dev/null)" && [[ -n "$real" ]]; then
    socket="$real"
  fi
  printf '%s\n' "$socket"
}

# _oe_viewer_mux_started <socket> — そのソケットを持つ GUI のプロセスの開始時刻を stdout へ。
#   GUI はソケットを gui-sock-<自分のプロセス番号> と名付ける（wezterm の wezterm-gui/src/main.rs）。
#   名前がこの形でなければ（mux サーバのソケットなど）、または ps が失敗すれば、空を出す（常に rc 0）。
#   値は LC_ALL=C ps -o lstart= の前後の空白を削ったもの（ps は末尾に空白を付ける）。
_oe_viewer_mux_started() {
  local base pid out
  base="${1##*/}"
  [[ "$base" =~ ^gui-sock-([0-9]+)$ ]] || return 0
  pid="${BASH_REMATCH[1]}"
  out="$(LC_ALL=C ps -o lstart= -p "$pid" 2>/dev/null)" || return 0
  out="${out#"${out%%[![:space:]]*}"}"
  out="${out%"${out##*[![:space:]]}"}"
  printf '%s' "$out"
}

# _oe_viewer_pane_exists <socket> <pane_id> — そのソケットの GUI に pane があるか（`wez pane --socket
#   <socket> list` の JSON を引く・pane.sh:_wez_pane_exists 相当）。rc 0=在る / 1=無い・非数値・list 失敗。
_oe_viewer_pane_exists() {
  local socket="$1" pane_id="$2"
  [[ "$pane_id" =~ ^[0-9]+$ ]] || return 1
  local json
  json="$(wez pane --socket "$socket" list 2>/dev/null)" || return 1
  if command -v jq >/dev/null 2>&1; then
    jq -e --arg id "$pane_id" 'map(select((.pane_id | tostring) == $id)) | length > 0' \
      <<< "$json" >/dev/null 2>&1
  else
    [[ "$json" == *"\"pane_id\":${pane_id},"* ]] \
      || [[ "$json" == *"\"pane_id\":${pane_id}}"* ]] \
      || [[ "$json" == *"\"pane_id\": ${pane_id},"* ]] \
      || [[ "$json" == *"\"pane_id\": ${pane_id}}"* ]]
  fi
}

# _oe_viewer_spawn <socket> <path> — viewer ペインを argv-spawn で新規作成し、新 pane_id を stdout へ。
#   ペインのプログラムとして glow を直接起動する（DJ-4・shell/tmux 非経由）:
#     wez pane --socket <socket> split --right --percent <P> --cwd <dir> -- glow -p -- <path>
#   --cwd は path の dirname（glow の相対参照・cwd 表示の整合用）。path は argv 要素で渡す
#   （`-- glow -p -- <path>`）ため再トークナイズが起きず %q 不要・注入面が消滅（§5）。
#   作成後に source ペイン（WEZTERM_PANE）へ activate して focus 奪取を回避（#111）。
#   rc 0=成功（pane_id 出力）/ 1=state の置き場が無い or 書込失敗/ 2=spawn 失敗（環境エラー）。
_oe_viewer_spawn() {
  local socket="$1" path="$2" new_pane source_pane dir
  source_pane="${WEZTERM_PANE:-}"
  dir="$(dirname -- "$path")"
  if ! new_pane="$(wez pane --socket "$socket" split "$OE_VIEW_SPLIT_DIR" --percent "$OE_VIEW_SPLIT_PERCENT" --cwd "$dir" -- glow -p -- "$path" 2>/dev/null)"; then
    echo "oe-view: failed to spawn viewer pane (wez pane split -- glow)" >&2
    return 2
  fi
  if ! [[ "$new_pane" =~ ^[0-9]+$ ]]; then
    echo "oe-view: unexpected pane id from wez pane split: ${new_pane}" >&2
    return 2
  fi
  # #111: split は新ペインへ focus を奪うため、作業ペインへ focus を戻す（best-effort）。
  if [[ -n "$source_pane" && "$source_pane" =~ ^[0-9]+$ ]]; then
    wez pane --socket "$socket" activate "$source_pane" 2>/dev/null || true
  fi
  printf '%s\n' "$new_pane"
}

# _oe_viewer_may_kill <socket> <mux_started> — 記録の viewer を閉じてよいか（#509）。rc 0=閉じてよい。
#   記録したときと同じ GUI のプロセスに、同じソケットで問い合わせられると確かめたときだけ 0 を返す。
#   ペイン番号は同じプロセスの中で使い回されないので、そのとき記録の番号のペインは oe-view が開いた
#   viewer である。事前に _oe_viewer_read_state を呼んでおくこと。
_oe_viewer_may_kill() {
  local socket="$1" started="$2"
  [[ "$_OE_VIEWER_REC_PANE" =~ ^[0-9]+$ ]] || return 1                        # 古い形・壊れた記録
  [[ -n "$_OE_VIEWER_REC_SOCKET" && -n "$_OE_VIEWER_REC_STARTED" ]] || return 1
  [[ "$_OE_VIEWER_REC_SOCKET" == "$socket" ]] || return 1                     # 別の GUI・起動し直した GUI
  [[ -n "$started" && "$_OE_VIEWER_REC_STARTED" == "$started" ]] || return 1  # 番号を使い回した別の GUI
  [[ "$_OE_VIEWER_REC_PANE" != "${WEZTERM_PANE:-}" ]] || return 1             # 呼び出し元のペインは閉じない
  _oe_viewer_pane_exists "$socket" "$_OE_VIEWER_REC_PANE"
}

# oe_viewer_resolve <path> — viewer ペインに <path> を glow で表示し、使った viewer
#   pane id を stdout へ出す（argv-spawn replace モデル）。
#   記録の viewer が同じ GUI のプロセスにあると確かめられた → kill → 新 glow ペインを spawn →
#   記録の更新 / 確かめられない・無い → spawn + 記録の更新（#509）。
#   glow -p はページャ（シェルではない）ため send による再利用はできず、毎回 replace する。
#   rc 0=成功（pane_id 出力）/ 1=state の置き場が無い or 書込失敗 /
#   2=接続先が決まらない・spawn 失敗（環境エラー）。
oe_viewer_resolve() {
  local path="$1" socket started new_pane
  # state の置き場が決まらないなら、旧 pane の kill も新 pane の spawn もしない（#322）。
  # 書き込みの直前だけで失敗させると、spawn 済みの glow ペインが未追跡のまま残る。
  if [[ -z "$OE_VIEW_STATE_DIR" ]]; then
    echo "oe-view: viewer state の置き場が決まりません（HOME 未設定・OE_VIEW_STATE_DIR も未指定）" >&2
    return 1
  fi
  # 接続先を1回だけ決め、このあとの pane の呼び出しはすべてこのソケットに固定する（#509）。
  if ! socket="$(_oe_viewer_socket)"; then
    echo "oe-view: WezTerm のソケットが決まりません（wez discover が失敗した）" >&2
    return 2
  fi
  started="$(_oe_viewer_mux_started "$socket")"
  _oe_viewer_read_state
  # 同じ GUI のプロセスの viewer と確かめられたときだけ kill する（replace モデル）。
  # best-effort: kill 失敗（既に消えた等）は新規 spawn を妨げない。
  if _oe_viewer_may_kill "$socket" "$started"; then
    wez pane --socket "$socket" kill "$_OE_VIEWER_REC_PANE" 2>/dev/null || true
  fi
  new_pane="$(_oe_viewer_spawn "$socket" "$path")" || return
  # 記録は spawn のあとに取った開始時刻で書く。取れなければ記録を消す（次の回は閉じない）。
  started="$(_oe_viewer_mux_started "$socket")"
  if [[ -n "$started" ]]; then
    _oe_viewer_write_state "$new_pane" "$socket" "$started" || return 1
  else
    _oe_viewer_clear_state || return 1
  fi
  printf '%s\n' "$new_pane"
}
