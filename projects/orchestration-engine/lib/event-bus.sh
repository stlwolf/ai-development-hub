# shellcheck shell=bash
# event-bus.sh — 親子相互作用の永続 append-only 活動ログ（source 専用・#206 増分1）
#
# 各イベントは from/to の {pane, role, label} を emit 時に焼き込む「自己完結レコード」。
# session_id を主キーにせず（delegate 子は session_id を持たない）、registry の生存にも
# read 時依存しない（GC されても残る ＝ departed children も後から可視）。これは #188
# DJ-188-4 の「session_id 主キー event bus」を、delegate に session_id が無い現実へ精緻化した形
# （decision で昇格判断）。lifecycle/stall は推論しない（DJ-188-2 尊重 ＝ 非対称 lifecycle を
# engine の完了 enum に押し込まない）。viewer 側は read 時に liveness（mux 存在 query）のみ見る。
#
# 設計上の不変条件:
#   - best-effort: emit 失敗（jq 不在・dir 作成不可・encode 失敗）は本体（oe-delegate /
#     oe_send_line）を一切壊さない。全 public 関数は常に return 0。
#   - atomic append: 1 イベント = 1 行 JSON を `>>` で追記。preview を ~100 codepoint に切り詰め
#     行を PIPE_BUF（>=4KB）未満に保つことで、親子同時追記でも write が atomic（O_APPEND）。
#   - read-time projection: role/label は emit 時の registry/pane-issue 焼込（live registry 非依存）。
#
# 識別子解決は oe-ident（#202）と同じ read 時投影だが、emit を self-contained・best-effort に
# 保つため本 lib 内に独立実装する（oe-ident の表示契約と疎結合）。

# delegate-registry.sh の _oe_reg_key / _oe_reg_server_pid / OE_*_DIR を使う。
# 呼び出し側が未 source なら自前で取り込む（多重 source は冪等）。
if ! declare -F _oe_reg_key >/dev/null 2>&1; then
  # shellcheck source=delegate-registry.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/delegate-registry.sh" 2>/dev/null || true
fi

# ログの保存先（cross-session。registry / pane-issue と同じ ~/.claude/state 規約）。
# テストは OE_EVENT_DIR で隔離する。
OE_EVENT_DIR="${OE_EVENT_DIR:-${HOME}/.claude/state}"

# _oe_event_ident <pane> — pane の識別子を read 時投影し "role<TAB>label<TAB>parent_pane" を返す。
#   role  : parent（この pane を parent_pane に持つ子 entry が在る） > child（自身の spawn entry が在る） > ""
#   label : pane-issue(.name) 優先 → spawn-registry(.label)
#   parent_pane : 自身の spawn entry の parent_pane（無ければ空）。message の report/kick 方向判定に使う。
#   file 読みのみ・tmux 不要・best-effort（jq 不在は全空）。
_oe_event_ident() {
  local pane="${1:-}" pid key label="" own parent="" is_child=0 is_parent=0 role=""
  if ! command -v jq >/dev/null 2>&1; then printf '\t\t\n'; return 0; fi
  pid="$(_oe_reg_server_pid 2>/dev/null)" || pid=""
  key="$(_oe_reg_key "$pane" 2>/dev/null)" || key=""
  [[ -n "$key" ]] || { printf '\t\t\n'; return 0; }
  if [[ -f "${OE_PANE_ISSUE_DIR}/${key}" ]]; then
    label="$(jq -r '.name // empty' "${OE_PANE_ISSUE_DIR}/${key}" 2>/dev/null)" || label=""
  fi
  own="${OE_DELEGATE_STATE_DIR}/${key}.json"
  if [[ -f "$own" ]]; then
    is_child=1
    parent="$(jq -r '.parent_pane // empty' "$own" 2>/dev/null)" || parent=""
    [[ -z "$label" ]] && label="$(jq -r '.label // empty' "$own" 2>/dev/null)"
  fi
  # 現サーバ pid の子 entry を走査して parent 判定（別サーバの stale で pane-id 衝突しても誤検知しない）。
  # grep -F で per-file jq を避ける（oe-ident と同イディオム）。
  if [[ -n "$pid" ]] && grep -lF "\"parent_pane\":\"${pane}\"" "${OE_DELEGATE_STATE_DIR}/${pid}"_*.json >/dev/null 2>&1; then
    is_parent=1
  fi
  if [[ "$is_parent" -eq 1 ]]; then role="parent"; elif [[ "$is_child" -eq 1 ]]; then role="child"; fi
  # label の改行（LF/CR）は 1 行 JSON に焼く前に畳む（行境界の偽造防止・oe_reg_list と同方針）。
  label="${label//$'\n'/ }"; label="${label//$'\r'/ }"
  printf '%s\t%s\t%s\n' "$role" "$label" "$parent"
}

# oe_event_emit <type> <from_pane> <from_role> <from_label> <to_pane> <to_role> <to_label> [extra_json]
#   1 イベントを oe-events.jsonl に best-effort 追記。常に return 0。
oe_event_emit() {
  [[ "${OE_EVENT_LOG:-1}" != "0" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local type="${1:-}" fp="${2:-}" frole="${3:-}" flabel="${4:-}" tp="${5:-}" trole="${6:-}" tlabel="${7:-}" extra="${8:-}"
  # `${8:-{}}` は default の `}` が展開閉じ括弧と衝突して壊れるため別代入で `{}` を補う。
  [[ -n "$extra" ]] || extra='{}'
  [[ -n "$type" ]] || return 0
  local dir="$OE_EVENT_DIR" file ts line
  mkdir -p "$dir" 2>/dev/null || return 0
  file="${dir}/oe-events.jsonl"
  ts="$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")" || return 0
  line="$(jq -cn \
    --arg ts "$ts" --arg type "$type" \
    --arg fp "$fp" --arg frole "$frole" --arg flabel "$flabel" \
    --arg tp "$tp" --arg trole "$trole" --arg tlabel "$tlabel" \
    --argjson extra "$extra" \
    '{ts:$ts, type:$type,
      from:{pane:$fp, role:$frole, label:$flabel},
      to:{pane:$tp, role:$trole, label:$tlabel}} + $extra' 2>/dev/null)" || return 0
  [[ -n "$line" ]] || return 0
  # 1 行 printf（< PIPE_BUF）を O_APPEND で追記 ＝ 同時追記でも atomic。
  printf '%s\n' "$line" >> "$file" 2>/dev/null || return 0
  return 0
}

# oe_event_child_spawned <parent_pane> <child_pane> [child_label]
#   oe-delegate が子 spawn + registry 登録の直後に呼ぶ。role は構築上 parent/child で確定。
oe_event_child_spawned() {
  [[ "${OE_EVENT_LOG:-1}" != "0" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local pp="${1:-}" cp="${2:-}" clabel="${3:-}"
  local plabel clabel_r
  # role/parent は構築上 parent/child で確定するため捨てる（label だけ使う）。
  IFS=$'\t' read -r _ plabel _ < <(_oe_event_ident "$pp") || true
  if [[ -z "$clabel" ]]; then
    IFS=$'\t' read -r _ clabel_r _ < <(_oe_event_ident "$cp") || true
    clabel="$clabel_r"
  fi
  oe_event_emit "child_spawned" "$pp" "parent" "$plabel" "$cp" "child" "$clabel" "{}"
}

# oe_event_message_sent <from_pane> <to_pane> <preview-text> [delivery_signal]
#   oe_send_line が送信成功後に呼ぶ。delivery_signal は suspected_miss|none（delivered は名乗らない）。
#   preview は先頭 ~100 codepoint に jq で切り詰め（マルチバイトを壊さず行を小さく保つ）。
oe_event_message_sent() {
  [[ "${OE_EVENT_LOG:-1}" != "0" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local fp="${1:-}" tp="${2:-}" preview="${3:-}" delivery="${4:-none}"
  local frole flabel fparent trole tlabel tparent
  IFS=$'\t' read -r frole flabel fparent < <(_oe_event_ident "$fp") || true
  IFS=$'\t' read -r trole tlabel tparent < <(_oe_event_ident "$tp") || true
  # 直接の親子リンク（spawn entry の parent_pane）で report/kick の方向を honest に確定する。
  # 多段ツリーで pane が parent かつ child のとき per-pane role は曖昧なので、関係で上書きする。
  if [[ -n "$fparent" && "$fparent" == "$tp" ]]; then
    frole="child"; trole="parent"      # report: 子 → 親
  elif [[ -n "$tparent" && "$tparent" == "$fp" ]]; then
    frole="parent"; trole="child"      # kick: 親 → 子
  fi
  local maxc="${OE_EVENT_PREVIEW_MAX:-100}" extra
  # delivery_signal を suspected_miss|none に正規化（未知値は none）。
  case "$delivery" in suspected_miss|none) ;; *) delivery="none" ;; esac
  extra="$(jq -cn --arg p "$preview" --arg d "$delivery" --argjson n "$maxc" \
    '{preview: (if ($p|length) > $n then ($p[0:$n] + "…") else $p end), delivery_signal: $d}' 2>/dev/null)" || return 0
  oe_event_emit "message_sent" "$fp" "$frole" "$flabel" "$tp" "$trole" "$tlabel" "$extra"
}
