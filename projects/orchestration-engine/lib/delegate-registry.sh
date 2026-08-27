# shellcheck shell=bash
# delegate-registry.sh — 親子委譲の宛先アドレッシング（source 専用）
#
# 宛先（pane_id）を 2 ソースの union で解決する:
#   1. 親所有 spawn レジストリ（~/.claude/state/oe-delegate/）— 親が spawn した子。
#      parent_pane で「現在の親」にスコープする。ゼロベース調査期の仮ラベルも保持。
#   2. 既存 pane-issue state（~/.claude/state/pane-issue/）— wt switch 済みペインの #N。
#      scripts/wt/wt-pane-issue.sh が書く。読み取りのみ流用する。
#
# 解決は「生存ペイン起点の順引き」: tmux list-panes の生存ペインから同一キー生成で
# state を引く。逆算しないので孤児/別サーバの stale を踏まない。
# Bash 3.2 互換: 連想配列（declare -A）は使わない。

# HOME を暗黙の既定パスに使ってよいかを決める（#322・全箇所で byte 一致させる）。
# 非空だけでは足りない: HOME=/ は //.claude/... ＝ root 直下を掴み、相対 HOME は cwd 配下へ
# state を散らす。先例（canonical/hooks/scripts/cc-lint.sh:39-41）が -n で済むのは、あちらが
# tally を 1 バイト追記するだけの best-effort だからで、state を作る engine には足りない。
declare -F _oe_home_usable >/dev/null 2>&1 || _oe_home_usable() { case "${HOME:-}" in /|//) return 1;; /*) return 0;; *) return 1;; esac; }

if   [ -n "${OE_DELEGATE_STATE_DIR+x}" ]; then :
elif _oe_home_usable; then OE_DELEGATE_STATE_DIR="${HOME}/.claude/state/oe-delegate"
else                       OE_DELEGATE_STATE_DIR=""
fi
if   [ -n "${OE_PANE_ISSUE_DIR+x}" ]; then :
elif _oe_home_usable; then OE_PANE_ISSUE_DIR="${HOME}/.claude/state/pane-issue"
else                       OE_PANE_ISSUE_DIR=""
fi

# _oe_reg_server_pid — $TMUX = "socket,pid,session" の pid を返す（wt-pane-issue.sh と同一）
_oe_reg_server_pid() {
  local s="${TMUX:-}"
  s="${s#*,}"; s="${s%%,*}"
  printf '%s' "$s"
}

# _oe_reg_key <pane> — wt-pane-issue.sh / session-name.sh と同一のキー生成
#   key = "<server_pid>_<pane>" の非英数を "_" に置換（例: 92315_%3 -> 92315__3）
_oe_reg_key() {
  local pane="$1" pid key
  pid="$(_oe_reg_server_pid)"
  key="${pid}_${pane}"
  printf '%s' "${key//[^A-Za-z0-9]/_}"
}

# _oe_label_match <target> <stored_label>
#   #N はトークン境界の完全一致（"#14" は "#142 slug" に一致しない）。
#   任意名は exact 一致。
_oe_label_match() {
  local target="$1" stored="$2"
  if [[ "$target" =~ ^#[0-9]+$ ]]; then
    [[ "$stored" == "$target" || "$stored" == "${target} "* ]]
  else
    [[ "$stored" == "$target" ]]
  fi
}

# oe_reg_record <child_pane> <label> <workspace> <parent_pane>
#   親が spawn した子を per-child JSON で記録する（atomic 書き込み）。
oe_reg_record() {
  local pane="${1:-}" label="${2:-}" workspace="${3:-}" parent="${4:-}"
  [[ -n "$pane" ]] || { echo "oe_reg_record: child pane is required" >&2; return 2; }
  command -v jq >/dev/null 2>&1 || { echo "oe_reg_record: jq is required" >&2; return 2; }
  # 置き場が決まらないときは、空パスを見せずに原因を名乗って落ちる（#322）。
  [[ -n "$OE_DELEGATE_STATE_DIR" ]] || { echo "oe_reg_record: 登記の置き場が決まりません（HOME 未設定・OE_DELEGATE_STATE_DIR も未指定）" >&2; return 1; }
  mkdir -p "$OE_DELEGATE_STATE_DIR" 2>/dev/null || { echo "oe_reg_record: cannot create ${OE_DELEGATE_STATE_DIR}" >&2; return 1; }
  local key file tmp
  key="$(_oe_reg_key "$pane")"
  file="${OE_DELEGATE_STATE_DIR}/${key}.json"
  tmp="${file}.tmp.$$"
  if jq -cn --arg pane "$pane" --arg label "$label" --arg ws "$workspace" --arg parent "$parent" \
        '{pane:$pane, label:$label, workspace:$ws, parent_pane:$parent, role:"child"}' >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$file" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
  else
    rm -f "$tmp" 2>/dev/null
    echo "oe_reg_record: failed to encode registry entry" >&2
    return 1
  fi
  oe_reg_gc 2>/dev/null || true
}

# oe_reg_resolve <target> — 宛先を pane_id に解決して stdout に出力
#   %N は registry を介さず素通し（escape hatch）。
#   ラベル（#N / 名前）は生存ペイン起点で union 解決。pane-issue 優先。
#   0 件 / 複数件はエラー。
oe_reg_resolve() {
  local target="${1:-}"
  [[ -n "$target" ]] || { echo "oe_reg_resolve: target is required" >&2; return 2; }
  if [[ "$target" =~ ^%[0-9]+$ ]]; then
    printf '%s\n' "$target"
    return 0
  fi
  command -v tmux >/dev/null 2>&1 || { echo "oe_reg_resolve: tmux is required" >&2; return 2; }
  command -v jq   >/dev/null 2>&1 || { echo "oe_reg_resolve: jq is required" >&2; return 2; }
  # 置き場が決まらない（HOME 未設定など）は「該当なし (1)」ではなく環境エラー (2)（#322）。
  # 1 に落とすと「登記を引けない」が「その宛先は存在しない」に化け、環境の失敗が宛先の帯を汚す。
  # %N の素通しは state 不要なので上で既に返っている。
  # どちらか一方でも欠けると union が不完全になり、「見つからない」と区別できない（&& ではなく ||）。
  if [[ -z "$OE_DELEGATE_STATE_DIR" || -z "$OE_PANE_ISSUE_DIR" ]]; then
    echo "oe_reg_resolve: state の置き場が決まらないのでラベルを解決できません（HOME 未設定・OE_DELEGATE_STATE_DIR / OE_PANE_ISSUE_DIR も未指定）" >&2
    return 2
  fi

  local self="${TMUX_PANE:-}"
  # list-panes 自体の失敗（サーバ未起動/接続不可）は「該当なし (1)」と区別し環境エラー (2)。
  local live rc
  live="$(tmux list-panes -a -F '#{pane_id}' 2>&1)"; rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "oe_reg_resolve: tmux list-panes failed (rc=${rc}): ${live}" >&2
    return 2
  fi
  local matched=()
  local p key piname plabel pparent
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    key="$(_oe_reg_key "$p")"
    # pane-issue が在れば、そのペインのラベルは pane-issue が所有する（spawn ラベルは抑止）
    if [[ -n "$OE_PANE_ISSUE_DIR" && -f "${OE_PANE_ISSUE_DIR}/${key}" ]]; then
      piname="$(jq -r '.name // empty' "${OE_PANE_ISSUE_DIR}/${key}" 2>/dev/null)"
      if [[ -n "$piname" ]]; then
        if _oe_label_match "$target" "$piname"; then matched+=("$p"); fi
        continue
      fi
    fi
    # pane-issue が無いペインのみ spawn レジストリ（現在の親にスコープ）を見る
    if [[ -n "$OE_DELEGATE_STATE_DIR" && -f "${OE_DELEGATE_STATE_DIR}/${key}.json" ]]; then
      plabel="$(jq -r '.label // empty' "${OE_DELEGATE_STATE_DIR}/${key}.json" 2>/dev/null)"
      pparent="$(jq -r '.parent_pane // empty' "${OE_DELEGATE_STATE_DIR}/${key}.json" 2>/dev/null)"
      if [[ -n "$plabel" && "$pparent" == "$self" ]] && _oe_label_match "$target" "$plabel"; then
        matched+=("$p")
      fi
    fi
  done <<< "$live"

  if [[ ${#matched[@]} -eq 0 ]]; then
    echo "oe_reg_resolve: no live target matches '${target}' (try: oe-list)" >&2
    return 1
  fi
  if [[ ${#matched[@]} -gt 1 ]]; then
    echo "oe_reg_resolve: ambiguous target '${target}' -> ${matched[*]} (use a raw pane id %N)" >&2
    return 1
  fi
  printf '%s\n' "${matched[0]}"
}

# oe_reg_list — 現サーバの生存ペインを宛先候補として一覧（source 列付き）
# _oe_reg_label <pane> [self] [use_registry] — pane のラベルと出所を read 時に解決する。
#
# 2値（label と source）を返すので、bash 3.2 に nameref が無い制約から global 経由で返す:
#   _oe_reg_label_out    解決したラベル（LF/CR は空白へ畳む・下記 sanitize 参照）
#   _oe_reg_source_out   出所（pane-issue | spawn-registry | pane-title）
#
# 引数:
#   <pane>          %N。
#   [self]          spawn-registry 段の比較対象（parent_pane == self の entry だけを採る）。既定は空。
#   [use_registry]  1 で spawn-registry 段を有効化。既定は 0。
#
# **なぜ registry 段が opt-in なのか**: oe_reg_list は「委譲の宛先候補（自分の子）」を出す表なので、
# parent_pane == self の entry だけをラベル源として採る。一方 #327 の観測用途は「誰の子かを問わず、
# そのペインが何なのか」を知りたいので、この段を通さず pane-issue > pane_title の2段で解決する。
# 同じ関数を両者で共有しつつ、意味の違いを引数で明示する（既定を 0 にしたのは、観測側が誤って
# 「自分の子だけラベルが付く」挙動を引き継がないようにするため）。
#
# 出力チョークポイントでの sanitize（消費者 oe-list/oe-select/oe-status を一括防御）。
# label に改行（LF/CR）が混じると 1 行構成の表が複数行化し、消費側の行パース
# （`while read` / `awk '{print $1}'`）に偽の %N 候補行が紛れ込み別ペインへ誤送信し得る。
# 解決直後に改行を空白へ畳んで偽行注入経路を断つ（pane_title 由来の細工を含む）。
# 注: LF/CR のみ対象。U+2028 等 / ANSI / TAB は消費者のレコード境界にならず %N 行を
# 偽造しない（視覚偽装は別軸・scope 外）。書き込み側 hardening は #178 外（follow-up）。
_oe_reg_label() {
  local p="$1" self="${2:-}" use_registry="${3:-0}"
  local key plabel pparent
  _oe_reg_label_out=""; _oe_reg_source_out=""
  key="$(_oe_reg_key "$p")"
  if [[ -n "$OE_PANE_ISSUE_DIR" && -f "${OE_PANE_ISSUE_DIR}/${key}" ]]; then
    _oe_reg_label_out="$(jq -r '.name // empty' "${OE_PANE_ISSUE_DIR}/${key}" 2>/dev/null)"
    [[ -n "$_oe_reg_label_out" ]] && _oe_reg_source_out="pane-issue"
  fi
  if [[ -z "$_oe_reg_source_out" && "$use_registry" == "1" \
        && -n "$OE_DELEGATE_STATE_DIR" && -f "${OE_DELEGATE_STATE_DIR}/${key}.json" ]]; then
    plabel="$(jq -r '.label // empty' "${OE_DELEGATE_STATE_DIR}/${key}.json" 2>/dev/null)"
    pparent="$(jq -r '.parent_pane // empty' "${OE_DELEGATE_STATE_DIR}/${key}.json" 2>/dev/null)"
    if [[ -n "$plabel" && "$pparent" == "$self" ]]; then
      _oe_reg_label_out="$plabel"; _oe_reg_source_out="spawn-registry"
    fi
  fi
  if [[ -z "$_oe_reg_source_out" ]]; then
    _oe_reg_label_out="$(tmux display-message -p -t "$p" '#{pane_title}' 2>/dev/null)"
    _oe_reg_source_out="pane-title"
  fi
  _oe_reg_label_out="${_oe_reg_label_out//$'\n'/ }"
  _oe_reg_label_out="${_oe_reg_label_out//$'\r'/ }"
  return 0
}

oe_reg_list() {
  # 置き場が決まらないときは黙って pane-title へ degrade しない（#322）。
  # 表だけ出ると「登記された子は居ない」と読めてしまい、クラッシュより誤解を生む。
  if [[ -z "$OE_DELEGATE_STATE_DIR" || -z "$OE_PANE_ISSUE_DIR" ]]; then
    echo "oe_reg_list: state の置き場が決まらないので登記を読んでいません（HOME 未設定）。以下は pane-title のみ" >&2
  fi
  command -v tmux >/dev/null 2>&1 || { echo "oe_reg_list: tmux is required" >&2; return 2; }
  command -v jq   >/dev/null 2>&1 || { echo "oe_reg_list: jq is required" >&2; return 2; }
  local self="${TMUX_PANE:-}"
  local live rc
  live="$(tmux list-panes -a -F '#{pane_id}' 2>&1)"; rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "oe_reg_list: tmux list-panes failed (rc=${rc}): ${live}" >&2
    return 2
  fi
  printf '%-8s %-14s %s\n' "PANE" "SOURCE" "LABEL"
  local p label source
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    # ラベル解決は _oe_reg_label（#327 で切り出し）。ここは委譲の宛先一覧なので registry 段を有効に
    # し、self をそのまま渡す（parent_pane == self の entry ＝「自分の子」だけを採る既存の意味）。
    _oe_reg_label "$p" "$self" 1
    label="$_oe_reg_label_out"; source="$_oe_reg_source_out"
    printf '%-8s %-14s %s\n' "$p" "$source" "$label"
  done <<< "$live"
}

# oe_reg_gc — 生存ペインに無い or 別サーバ pid の spawn レジストリ entry を掃除
#   ただし「自分の身元を確立できたとき」だけ走る（#270）。$TMUX が壊れた 1 回の呼び出しで
#   生存中の全 entry を消す事故が 3 回起きたため、入口で身元を検査してから掃除する。
#   掃除そのものの条件（下の削除条件）は従来どおりで変えていない。
oe_reg_gc() {
  [[ -d "$OE_DELEGATE_STATE_DIR" ]] || return 0
  command -v tmux >/dev/null 2>&1 || return 0
  local pid panes live_keys p f base rc server_pid
  pid="$(_oe_reg_server_pid)"
  # 身元が数値でなければ何も掃除しない（掃除せず正常終了＝best-effort）。空・glob メタ文字・
  # 非英数を一括で弾く。数値は _oe_reg_key の sanitize で不変なので、下の prefix 比較（raw pid）
  # とディスク上のキー（sanitize 済み）の非対称もここで消える。
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  # 生存ペインと「応答したサーバ自身が名乗る pid」を同じ 1 回の呼び出しで取る。
  # 2 回に分けると、物差しと母集団が別のサーバから来る隙ができる。
  # #{pid} は tmux 2.1+ の Server PID（#{pane_pid} はペインの先頭プロセスで別物）。
  # 未対応の書式は空に展開されるので、下の非空検査で安全側（掃除しない）に倒れる。
  panes="$(tmux list-panes -a -F '#{pane_id} #{pid}' 2>/dev/null)"; rc=$?
  # list-panes 失敗 or 空（サーバ未起動/接続不可）時は GC をスキップ（全 entry 誤削除を防ぐ）
  [[ "$rc" -eq 0 && -n "$panes" ]] || return 0
  # 物差しが取れない（#{pid} 非対応・awk 不在など）ときは空になる。
  # 次の一致検査は $pid が非空（上の数値検査を通過済み）なので空とは必ず不一致になり、
  # この行が無くても同じ return 0 に落ちる。挙動を変えない冗長な明示であって、独立した
  # 帯ではない。数値検査を将来緩めたときの保険として残している。
  # awk の失敗（不在・実行不可）は握り潰して空にする。呼び出し元が set -e の文脈だと、
  # 握り潰さない形では「空にして安全側へ倒れる」前にスクリプトごと終了しうる（Copilot 指摘）。
  server_pid="$(printf '%s\n' "$panes" | awk 'NR==1{print $2}' 2>/dev/null || true)"
  [[ -n "$server_pid" ]] || return 0
  # $TMUX 由来の pid と、live 一覧を作ったサーバが名乗る pid が食い違うなら身元が壊れている
  # （$TMUX 消失・別 server pid の混入）。掃除せず正常終了する。
  # 注: これは $TMUX の内部整合性の検査である。tmux は $TMUX の第 1 フィールドを接続先ソケット
  # にするため、$TMUX 全体が別の生きたサーバのものに置き換わった形は検出できない（#337）。
  [[ "$pid" == "$server_pid" ]] || return 0
  live_keys="$(printf '%s\n' "$panes" | while IFS= read -r p; do
    p="${p%% *}"
    [[ -n "$p" ]] && printf '%s\n' "$(_oe_reg_key "$p")"
  done)"
  # 空だと "/*.json" ＝ root を走査する。上の -d 検査で到達しないが、#270 で入れた
  # pid の非空検査と同じ理由で明示する（黙って root を掴む形を残さない・#322）。
  [[ -n "$OE_DELEGATE_STATE_DIR" ]] || return 0
  for f in "${OE_DELEGATE_STATE_DIR}"/*.json; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f" .json)"
    if [[ "$base" != "${pid}_"* ]] || ! printf '%s\n' "$live_keys" | grep -qxF "$base"; then
      rm -f "$f" 2>/dev/null
    fi
  done
}
