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

OE_DELEGATE_STATE_DIR="${OE_DELEGATE_STATE_DIR:-${HOME}/.claude/state/oe-delegate}"
OE_PANE_ISSUE_DIR="${OE_PANE_ISSUE_DIR:-${HOME}/.claude/state/pane-issue}"

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
    if [[ -f "${OE_PANE_ISSUE_DIR}/${key}" ]]; then
      piname="$(jq -r '.name // empty' "${OE_PANE_ISSUE_DIR}/${key}" 2>/dev/null)"
      if [[ -n "$piname" ]]; then
        if _oe_label_match "$target" "$piname"; then matched+=("$p"); fi
        continue
      fi
    fi
    # pane-issue が無いペインのみ spawn レジストリ（現在の親にスコープ）を見る
    if [[ -f "${OE_DELEGATE_STATE_DIR}/${key}.json" ]]; then
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
oe_reg_list() {
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
  local p key label source plabel pparent
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    key="$(_oe_reg_key "$p")"
    label=""; source=""
    if [[ -f "${OE_PANE_ISSUE_DIR}/${key}" ]]; then
      label="$(jq -r '.name // empty' "${OE_PANE_ISSUE_DIR}/${key}" 2>/dev/null)"
      [[ -n "$label" ]] && source="pane-issue"
    fi
    if [[ -z "$source" && -f "${OE_DELEGATE_STATE_DIR}/${key}.json" ]]; then
      plabel="$(jq -r '.label // empty' "${OE_DELEGATE_STATE_DIR}/${key}.json" 2>/dev/null)"
      pparent="$(jq -r '.parent_pane // empty' "${OE_DELEGATE_STATE_DIR}/${key}.json" 2>/dev/null)"
      if [[ -n "$plabel" && "$pparent" == "$self" ]]; then
        label="$plabel"; source="spawn-registry"
      fi
    fi
    if [[ -z "$source" ]]; then
      label="$(tmux display-message -p -t "$p" '#{pane_title}' 2>/dev/null)"
      source="pane-title"
    fi
    printf '%-8s %-14s %s\n' "$p" "$source" "$label"
  done <<< "$live"
}

# oe_reg_gc — 生存ペインに無い or 別サーバ pid の spawn レジストリ entry を掃除
oe_reg_gc() {
  [[ -d "$OE_DELEGATE_STATE_DIR" ]] || return 0
  command -v tmux >/dev/null 2>&1 || return 0
  local pid panes live_keys p f base rc
  pid="$(_oe_reg_server_pid)"
  panes="$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)"; rc=$?
  # list-panes 失敗 or 空（サーバ未起動/接続不可）時は GC をスキップ（全 entry 誤削除を防ぐ）
  [[ "$rc" -eq 0 && -n "$panes" ]] || return 0
  live_keys="$(printf '%s\n' "$panes" | while IFS= read -r p; do
    [[ -n "$p" ]] && printf '%s\n' "$(_oe_reg_key "$p")"
  done)"
  for f in "${OE_DELEGATE_STATE_DIR}"/*.json; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f" .json)"
    if [[ "$base" != "${pid}_"* ]] || ! printf '%s\n' "$live_keys" | grep -qxF "$base"; then
      rm -f "$f" 2>/dev/null
    fi
  done
}
