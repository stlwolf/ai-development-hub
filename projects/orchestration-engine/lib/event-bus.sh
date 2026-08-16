# shellcheck shell=bash
# event-bus.sh — 親子相互作用の永続 append-only 活動ログ（source 専用・#206 増分1 + 増分A）
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
  # 2>/dev/null は付けない（#322）。消せるのは診断だけで、未定義変数による shell の終了は
  # 止められない。実際 oe-send / oe-ack / oe-report は「出力ゼロで rc=1」という最悪の
  # 見え方をしていた。|| true は残す — best-effort な degrade は下の declare -F による
  # no-op フォールバックとセットで意図された設計である。
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/delegate-registry.sh" || true
fi

# #224: 会話到達面へ載る preview を write-time で無害化する共有 helper（多重 source は冪等）。
if ! declare -F oe_sanitize_conversation >/dev/null 2>&1; then
  # shellcheck source=sanitize.sh
  # 2>/dev/null は付けない（#322）。消せるのは診断だけで、未定義変数による shell の終了は
  # 止められない。実際 oe-send / oe-ack / oe-report は「出力ゼロで rc=1」という最悪の
  # 見え方をしていた。|| true は残す — best-effort な degrade は下の declare -F による
  # no-op フォールバックとセットで意図された設計である。
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sanitize.sh" || true
fi
# source 失敗（欠落/権限/source エラー）でも emit は best-effort・noise-free を保つ: 未定義なら
# no-op へフォールバック定義し、oe_event_message_sent 内の呼び出しが `command not found` を
# stderr へ漏らすのを防ぐ（Copilot 指摘・oe-activity/oe-ack と同型の degrade）。
declare -F oe_sanitize_conversation >/dev/null 2>&1 || oe_sanitize_conversation() { printf '%s' "$1"; }

# delegate-registry.sh が source されない（_oe_reg_key を他所が定義済 等）/ 環境で未設定でも、
# 未定義の state dir で `/${pid}_*.json` のように root 配下を誤って glob しないよう、registry と
# 同じ既定値をここでもフォールバック設定する（best-effort・Copilot 指摘）。
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

# ログの保存先（cross-session。registry / pane-issue と同じ ~/.claude/state 規約）。
# テストは OE_EVENT_DIR で隔離する。
if   [ -n "${OE_EVENT_DIR+x}" ]; then :
elif _oe_home_usable; then OE_EVENT_DIR="${HOME}/.claude/state"
else                       OE_EVENT_DIR=""
fi

# _oe_event_ident <pane> — pane の識別子を read 時投影し "role<US>label<US>parent_pane" を返す。
#   role  : parent（この pane を parent_pane に持つ子 entry が在る） > child（自身の spawn entry が在り かつ parent_pane 非空・#259） > ""
#   label : pane-issue(.name) 優先 → spawn-registry(.label)
#   parent_pane : 自身の spawn entry の parent_pane（無ければ空）。message の report/kick 方向判定に使う。
#   file 読みのみ・tmux 不要・best-effort（jq 不在は全空）。
#   区切りは US (\037)。TAB は IFS 空白扱いのため read が先頭 TAB を剥ぎ、role 空 + label あり
#   （registry GC 後の departed pane 等）で label が role 位置へシフトし schema 違反の role を
#   焼いていた（#206A テストで検出した増分1 の潜在バグ）。oe-activity の列区切りと同じ理由で US。
_oe_event_ident() {
  local pane="${1:-}" pid key label="" own parent="" is_child=0 is_parent=0 role=""
  if ! command -v jq >/dev/null 2>&1; then printf '\037\037\n'; return 0; fi
  pid="$(_oe_reg_server_pid 2>/dev/null)" || pid=""
  key="$(_oe_reg_key "$pane" 2>/dev/null)" || key=""
  [[ -n "$key" ]] || { printf '\037\037\n'; return 0; }
  if [[ -n "$OE_PANE_ISSUE_DIR" && -f "${OE_PANE_ISSUE_DIR}/${key}" ]]; then
    label="$(jq -r '.name // empty' "${OE_PANE_ISSUE_DIR}/${key}" 2>/dev/null)" || label=""
  fi
  own="${OE_DELEGATE_STATE_DIR}/${key}.json"
  if [[ -f "$own" ]]; then
    parent="$(jq -r '.parent_pane // empty' "$own" 2>/dev/null)" || parent=""
    # role=child は「自 entry が在り かつ parent 非空」に限る（#259）。parent 空の自己 root entry
    # を child と誤導出しない。既存 entry は全て parent 非空ゆえ既存データに挙動不変。
    [[ -n "$parent" ]] && is_child=1
    [[ -z "$label" ]] && label="$(jq -r '.label // empty' "$own" 2>/dev/null)"
  fi
  # 現サーバ pid の子 entry を走査して parent 判定（別サーバの stale で pane-id 衝突しても誤検知しない）。
  # grep -F で per-file jq を避ける（oe-ident と同イディオム）。
  # state dir が空だと "/<pid>_*.json" ＝ root を走査する（#322）。pid と同じ理由で非空を要求する。
  if [[ -n "$pid" && -n "$OE_DELEGATE_STATE_DIR" ]] && grep -lF "\"parent_pane\":\"${pane}\"" "${OE_DELEGATE_STATE_DIR}/${pid}"_*.json >/dev/null 2>&1; then
    is_parent=1
  fi
  if [[ "$is_parent" -eq 1 ]]; then role="parent"; elif [[ "$is_child" -eq 1 ]]; then role="child"; fi
  # label の制御文字を畳む: US は本関数の内部プロトコル（role<US>label<US>parent）の区切りを
  # 壊し parent/role の焼き込みを誤らせる（実装SO cursor 指摘の TAB 版を US へ引継ぎ）。TAB も
  # 表示崩れ防止で従来どおり畳む。LF/CR は 1 行 JSON の行境界を壊す（oe_reg_list / oe-ident と
  # 同方針）。いずれも空白へ畳んでから返す。
  label="${label//$'\037'/ }"; label="${label//$'\t'/ }"; label="${label//$'\n'/ }"; label="${label//$'\r'/ }"
  printf '%s\037%s\037%s\n' "$role" "$label" "$parent"
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
  # 置き場が決まらないときは root へ触らず、理由を 1 回だけ名乗って諦める（#322）。
  # rc は 0 のまま — 本 lib の不変条件（全 public 関数は常に return 0）を優先する。
  # 非0にすると oe-ack:154 の裸呼び出しが set -e で死に、受領印が取れない環境事情が
  # oe-ack 本体を殺す。gate 3 の裁定でこの優先順位を確定した。
  if [[ -z "$dir" ]]; then
    if [[ -z "${_OE_EVENT_DIR_WARNED:-}" ]]; then
      _OE_EVENT_DIR_WARNED=1
      echo "oe-event: 活動ログの置き場が決まらないので記録していません（HOME 未設定・OE_EVENT_DIR も未指定）" >&2
    fi
    return 0
  fi
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

# oe_event_child_spawned <parent_pane> <child_pane> [child_label] [permission_mode] [elevated]
#   oe-delegate が子 spawn + registry 登録の直後に呼ぶ。role は構築上 parent/child で確定。
#   permission_mode / elevated（任意・#262）を渡すと extra に焼き込み、elevated spawn を通常
#   spawn と事後区別できるようにする（append-only ログへの additive 追記・registry は変更しない）。
#   permission_mode が auto でも elevated=true の有無で区別できる（実装SO D5）。起動コマンド自体は
#   出さない（schema 方針の維持）。両方省略時は従来どおり extra={}。
oe_event_child_spawned() {
  [[ "${OE_EVENT_LOG:-1}" != "0" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local pp="${1:-}" cp="${2:-}" clabel="${3:-}" pmode="${4:-}" elevated="${5:-}"
  local plabel clabel_r extra="{}"
  # role/parent は構築上 parent/child で確定するため捨てる（label だけ使う）。
  IFS=$'\037' read -r _ plabel _ < <(_oe_event_ident "$pp") || true
  if [[ -z "$clabel" ]]; then
    IFS=$'\037' read -r _ clabel_r _ < <(_oe_event_ident "$cp") || true
    clabel="$clabel_r"
  fi
  # permission_mode / elevated が来たら extra へ（encode 失敗は best-effort で extra={} に degrade）。
  if [[ -n "$pmode" || -n "$elevated" ]]; then
    extra="$(jq -cn --arg pm "$pmode" --argjson el "$([[ "$elevated" == "true" ]] && echo true || echo false)" \
      '({} + (if $pm != "" then {permission_mode:$pm} else {} end) + {elevated:$el})' 2>/dev/null)" || extra="{}"
  fi
  oe_event_emit "child_spawned" "$pp" "parent" "$plabel" "$cp" "child" "$clabel" "$extra"
}

# oe_event_message_sent <from_pane> <to_pane> <preview-text> [delivery_signal] [nonce]
#   oe_send_line が送信成功後に呼ぶ。delivery_signal は unknown|none（#299 P0 以降 suspected_miss は
#   書かない。delivered は名乗らない）。nonce（#299・任意）を渡すと delivery_receipt.nonce を焼く。
#   preview は先頭 ~100 codepoint に jq で切り詰め（マルチバイトを壊さず行を小さく保つ）。
oe_event_message_sent() {
  [[ "${OE_EVENT_LOG:-1}" != "0" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local fp="${1:-}" tp="${2:-}" preview="${3:-}" delivery="${4:-none}" nonce="${5:-}"
  local frole flabel fparent trole tlabel tparent
  IFS=$'\037' read -r frole flabel fparent < <(_oe_event_ident "$fp") || true
  IFS=$'\037' read -r trole tlabel tparent < <(_oe_event_ident "$tp") || true
  # 直接の親子リンク（spawn entry の parent_pane）で report/kick の方向を honest に確定する。
  # 多段ツリーで pane が parent かつ child のとき per-pane role は曖昧なので、関係で上書きする。
  if [[ -n "$fparent" && "$fparent" == "$tp" ]]; then
    frole="child"; trole="parent"      # report: 子 → 親
  elif [[ -n "$tparent" && "$tparent" == "$fp" ]]; then
    frole="parent"; trole="child"      # kick: 親 → 子
  fi
  local maxc="${OE_EVENT_PREVIEW_MAX:-100}" extra
  # 非数値の OE_EVENT_PREVIEW_MAX だと `jq --argjson n` が失敗し emit 丸ごと no-op になる
  # （best-effort のはずがサイレント no-op になる・Copilot 指摘）。非数値は 100 へ落として warn を出す。
  case "$maxc" in ''|*[!0-9]*) echo "oe_event_message_sent: OE_EVENT_PREVIEW_MAX='${maxc}' は非数値 → 100 を使用" >&2; maxc=100 ;; esac
  # delivery_signal を enum へ正規化（未知値は none）。#299 で unknown を additive 追加した。
  # suspected_miss は書き込みを止めた（#299 P0・過去レコードにのみ残る）が、正規化の受理値としては
  # 残す。呼び出し側が渡してきた値を黙って none へ潰すと、渡された事実が消えるためである。
  case "$delivery" in unknown|suspected_miss|none) ;; *) delivery="none" ;; esac
  # #299: nonce は ULID（Crockford base32・26 桁）のみ受理する。形が違えば delivery_receipt を
  # 付けないが、**黙って捨てずに warn を出す**。呼び出し側の生成不具合を「受領印なし」へ無言で
  # 縮退させると、受領印が付かない理由が「送っていない」のか「壊れていた」のか読めなくなる
  # （採用 NK 01KYA7C9NN4VDM7H2NYXZB2PSX: 環境エラーとデータ不在を別に記録する）。
  if [[ -n "$nonce" && ! "$nonce" =~ ^[0-9A-HJKMNP-TV-Z]{26}$ ]]; then
    echo "oe_event_message_sent: nonce が ULID の形ではないため delivery_receipt を付けない: ${nonce}" >&2
    nonce=""
  fi
  # #224: 会話到達面（oe-activity/oe-ack が読む preview）へ載る前に write-time で無害化する。
  # ここ1箇所で全 read consumer を drift なくカバーする（DJ-4=write-time）。tool-call タグ列・
  # box-drawing・制御文字・行頭孤立 court を無害化。この後の 100cp truncate は preview 長の
  # 責務として据え置く（helper 既定 OE_SANITIZE_MAX_CP はこれより十分大きく干渉しない）。
  # read 側（oe-activity/oe-ack）の [[:cntrl:]] gsub は US 区切り protocol 防御として温存する。
  # best-effort: サニタイズが万一失敗しても emit を落とさず raw preview で続行（set -e 下でも安全）。
  local _san
  if _san="$(oe_sanitize_conversation "$preview")"; then preview="$_san"; fi
  extra="$(jq -cn --arg p "$preview" --arg d "$delivery" --arg nc "$nonce" --argjson n "$maxc" \
    '{preview: (if ($p|length) > $n then ($p[0:$n] + "…") else $p end), delivery_signal: $d}
     + (if $nc != "" then {delivery_receipt: {nonce: $nc}} else {} end)' 2>/dev/null)" || return 0
  oe_event_emit "message_sent" "$fp" "$frole" "$flabel" "$tp" "$trole" "$tlabel" "$extra"
}

# oe_event_prompt_received <from_pane(取り込んだ側=受け手)> <to_pane(送信元)> <nonce>
#   取り込み印（#299 P1）。受け手セッションの UserPromptSubmit hook が、注入された 1 行を
#   自分のターンとして取り込んだ瞬間に撃つ。from は hook が $TMUX_PANE から焼くので、
#   **ペインに束縛された一次記録**になる（送信側の推測ではない）。
#
#   report_received（#206A・「読んだ」）とは別イベントである。意味を継がないので covers_* を
#   持たない。prompt_received が言うのは「そのセッションが 1 ターンとして取り込んだ」までで、
#   読んだ・実行した・作業に反映した、ではない。両者を同じ語で扱ってはならない。
#
#   冪等: 同じ nonce の prompt_received が複数行あっても、read 側は受領 1 件として畳む
#   （書き込み側で重複排除しない ＝ append-only の不変条件を崩さない。write は常に追記のみ）。
oe_event_prompt_received() {
  [[ "${OE_EVENT_LOG:-1}" != "0" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local fp="${1:-}" tp="${2:-}" nonce="${3:-}"
  # nonce 無しの取り込み印は突き合わせ先が無く受領印として意味を成さないので emit しない。
  # ここは「データ不在」（タグの無い通常のプロンプト）であって環境エラーではないため warn を出さない
  # ＝ 人が手で打ったプロンプトのたびに stderr が鳴るのを避ける。形が壊れている場合だけ下で warn する。
  [[ -n "$nonce" ]] || return 0
  if [[ ! "$nonce" =~ ^[0-9A-HJKMNP-TV-Z]{26}$ ]]; then
    echo "oe_event_prompt_received: nonce が ULID の形ではないため emit しない: ${nonce}" >&2
    return 0
  fi
  local frole flabel fparent trole tlabel tparent
  IFS=$'\037' read -r frole flabel fparent < <(_oe_event_ident "$fp") || true
  IFS=$'\037' read -r trole tlabel tparent < <(_oe_event_ident "$tp") || true
  # message_sent と同じ関係上書き: 直接の親子リンクで役割を honest に確定する。
  if [[ -n "$fparent" && "$fparent" == "$tp" ]]; then
    frole="child"; trole="parent"
  elif [[ -n "$tparent" && "$tparent" == "$fp" ]]; then
    frole="parent"; trole="child"
  fi
  local extra
  extra="$(jq -cn --arg nc "$nonce" '{nonce: $nc}' 2>/dev/null)" || return 0
  oe_event_emit "prompt_received" "$fp" "$frole" "$flabel" "$tp" "$trole" "$tlabel" "$extra"
}

# oe_event_report_received <from_pane(受領者=ackした側)> <to_pane(報告元)> <covers_count> <covers_last_ts>
#   受領印（#206A）。covers_count / covers_last_ts は frontier snapshot（この ack がカバーする
#   to→from 宛て message_sent の累計数と最終 ts）。本関数は「引数のみの純 emit」——
#   ログ（oe-events.jsonl）を read しない（emit primitive は registry/pane-issue の小さな
#   state file しか読まない既存規約の維持・DJ-206A-6）。covers の計算・0 件 no-op 判定・
#   acker への echo は verb 層（bin/oe-ack）の責務。将来の追加 emitter（oe-send --ack 等の
#   sugar / フック）もこの口に乗る。
oe_event_report_received() {
  [[ "${OE_EVENT_LOG:-1}" != "0" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local fp="${1:-}" tp="${2:-}" covers="${3:-}" lts="${4:-}"
  # covers_count は正の整数のみ（schema minimum 1）。0/非数値/空・frontier ts 空は
  # 受領印として無意味なので emit しない（best-effort の範囲で schema 違反行を作らない）。
  case "$covers" in ''|*[!0-9]*) return 0 ;; esac
  [[ "$covers" -ge 1 ]] || return 0
  [[ -n "$lts" ]] || return 0
  local frole flabel fparent trole tlabel tparent
  IFS=$'\037' read -r frole flabel fparent < <(_oe_event_ident "$fp") || true
  IFS=$'\037' read -r trole tlabel tparent < <(_oe_event_ident "$tp") || true
  # message_sent と同じ関係上書き: 直接の親子リンクで役割を honest に確定する。
  # 典型は from=親（受領者）/ to=子（報告元）だが、構築上でなく registry で決める。
  if [[ -n "$fparent" && "$fparent" == "$tp" ]]; then
    frole="child"; trole="parent"      # 子が親からの message に受領印（対称ケース）
  elif [[ -n "$tparent" && "$tparent" == "$fp" ]]; then
    frole="parent"; trole="child"      # 親が子の報告に受領印（主用途）
  fi
  local extra
  extra="$(jq -cn --argjson c "$covers" --arg lts "$lts" \
    '{covers_count: $c, covers_last_ts: $lts}' 2>/dev/null)" || return 0
  oe_event_emit "report_received" "$fp" "$frole" "$flabel" "$tp" "$trole" "$tlabel" "$extra"
}
