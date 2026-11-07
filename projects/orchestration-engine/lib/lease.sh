# shellcheck shell=bash
# lease.sh — 統括と委譲子の「誰か」を、こちらで作る lease の記録で持つ（#577 PR-1・source 専用）
#
# 設計の正本は projects/orchestration-engine/docs/discussions/2026-11-06-discussion-577-record-identity-key.md
# （DJ-1〜DJ-20）と、同じ木の decision の案（D1〜D19）である。この lib はその記録の読み書きだけを持つ。
# 既存の verb（oe-delegate・oe-send・oe-handoff・oe-tree など）はまだこの lib を使わない（PR-2 以降で切り替える）。
#
# 言葉:
#   lease       人が入れ替わっても続く持ち場（統括の lease・委譲1件の lease）。ID は lease_id（ULID 風）。
#   generation  その lease に座った1つの会話。交代（advance）でだけ進む。resume では進まない。
#   binding     generation と、いまその会話を動かしているプロセス（pid・開始時刻・コマンド名）の結び付き。
#   epoch       binding・generation・親が変わるたびに1つ増える番号。compare-and-swap で比べる。
#
# 記録の形（1つのファイルの中の2つの表・owner の答え Q73）:
#   ~/.claude/state/oe-lease/<lease_id>.json
#   { format, lease_id, kind, label, workspace, parent_lease_id, state, created_at, closed_at, epoch,
#     current_generation, generations: [ { generation, state, started_at, retired_at, successor,
#                                          session_ids: [...], binding: { pid, started, comm, bound_at } | null } ] }
#   型は schemas/oe-lease.schema.json、検査は scripts/validate-lease.sh。
#
# 書き込みの決まり（DJ-5・owner の答え Q72）:
#   - 書き込みは lease ごとのロックの中で行い、epoch を比べてから書く。epoch が効くのは lease の記録への
#     書き込みだけで、古い generation の送信やファイルの編集を止める fencing は入れない。
#   - binding を張り替えてよいのは、前の binding が無いか、張り替える側が前の binding のプロセスそのものか、
#     前の binding のプロセスが生きていないと機械で確かめられたときだけ。生きているか分からなければ断る。
#   - session_id を正本に登録するのは本人だけで、自分の pid と開始時刻が binding と一致するときに限る（DJ-18）。
#     1つの session_id は開いた lease の1か所にしか入れない。この確かめは、すべての lease に共通の1つの
#     ロックの中で行う（lease ごとのロックでは、別々の lease への同時の登録を防げない）。
#   - 保証するのは「正本の binding が1つになる」までである。同じ会話の2つ目のプロセスが起きること自体は防がない。
#
# 置き場の env: OE_LEASE_DIR（既定 ~/.claude/state/oe-lease）
# 差し替えの口（テスト用）: OE_LEASE_NOW_ISO・OE_LEASE_NOW_EPOCH・OE_LEASE_LOCK_RETRY・OE_LEASE_LOCK_STALE_MIN
#
# 戻り値の決まり（関数に共通）:
#   0 成功 / 1 対象が無い・何もしなかった / 2 呼び方の誤り・前提の不足 / 3 epoch が合わない（取り合いに負けた）
#   4 ロックが取れない / 5 張り替えを断った（前の binding が生きている・分からない・本人でない）
#   6 コマンドが claude でない / 7 lease が閉じている・generation が退任している / 8 session_id がほかの lease にある

_OE_LEASE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=session.sh
. "$_OE_LEASE_LIB_DIR/session.sh"
# shellcheck source=tmux-pane-identity.sh
. "$_OE_LEASE_LIB_DIR/tmux-pane-identity.sh"
# shellcheck source=heartbeat-resolve.sh
. "$_OE_LEASE_LIB_DIR/heartbeat-resolve.sh"

declare -F _oe_home_usable >/dev/null 2>&1 || _oe_home_usable() { case "${HOME:-}" in /|//) return 1;; /*) return 0;; *) return 1;; esac; }
if   [ -n "${OE_LEASE_DIR+x}" ]; then :
elif _oe_home_usable; then OE_LEASE_DIR="${HOME}/.claude/state/oe-lease"
else                       OE_LEASE_DIR=""
fi

_oe_lease_now_iso()   { printf '%s' "${OE_LEASE_NOW_ISO:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"; }
_oe_lease_now_epoch() { printf '%s' "${OE_LEASE_NOW_EPOCH:-$(date +%s)}"; }

_oe_lease_valid_id() { case "${1:-}" in *[!0-9A-HJKMNP-TV-Z]*|'') return 1 ;; esac; [ "${#1}" -eq 26 ]; }

_oe_lease_file() { printf '%s/%s.json' "$OE_LEASE_DIR" "$1"; }

_oe_lease_ready() {
  [ -n "$OE_LEASE_DIR" ] || { echo "oe-lease: 置き場が決まりません（HOME 未設定・OE_LEASE_DIR も未指定）" >&2; return 2; }
  command -v jq >/dev/null 2>&1 || { echo "oe-lease: jq is required" >&2; return 2; }
  mkdir -p "$OE_LEASE_DIR" 2>/dev/null || { echo "oe-lease: cannot create ${OE_LEASE_DIR}" >&2; return 2; }
}

# --- ロック ---
# mkdir は原子的なので、取れた1つだけが書き手になる。置き去りのロック（持ち主が死んだ・pid を書く前に落ちた）は
# 引き取って消すが、**生きたロックを一時的にでも動かさない**（Copilot の指摘・PR #580）。引き取りは
# 「引き取りのロック」（<lock>.reclaim）を持つ1人だけが行い、その中で持ち主が死んでいることを確かめ直してから
# 消す。引き取る人は1人なので、確かめ直してから消すまでのあいだにロックの持ち主が替わることはない
# （替えられるのは持ち主の unlock だけで、持ち主は死んでいる）。ループは1回ごとに必ず再試行の数を増やし、
# 引き取りに失敗したときも上限で 4 を返す。
_oe_lease_lock_is_stale() {
  local lock="$1" owner
  owner="$(cat "${lock}/pid" 2>/dev/null)" || owner=""
  if [ -n "$owner" ]; then
    ! kill -0 "$owner" 2>/dev/null
  else
    [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin "+${OE_LEASE_LOCK_STALE_MIN:-10}" 2>/dev/null)" ]
  fi
}

_oe_lease_lock() {
  local lock="$1" i=0 rl="${1}.reclaim"
  while ! mkdir "$lock" 2>/dev/null; do
    if _oe_lease_lock_is_stale "$lock"; then
      # 引き取りのロック自体が置き去りなら（引き取る人が途中で落ちた）、古さで片づける。
      if [ -d "$rl" ] && [ -n "$(find "$rl" -maxdepth 0 -mmin "+${OE_LEASE_LOCK_STALE_MIN:-10}" 2>/dev/null)" ]; then
        rmdir "$rl" 2>/dev/null || true
      fi
      if mkdir "$rl" 2>/dev/null; then
        if _oe_lease_lock_is_stale "$lock"; then rm -rf "$lock" 2>/dev/null || true; fi
        rmdir "$rl" 2>/dev/null || true
      fi
    fi
    i=$((i + 1))
    [ "$i" -lt "${OE_LEASE_LOCK_RETRY:-50}" ] || return 4
    sleep 0.1 2>/dev/null || sleep 1
  done
  printf '%s' "$$" > "${lock}/pid" 2>/dev/null || true
  return 0
}
_oe_lease_unlock() { rm -f "${1}/pid" 2>/dev/null; rmdir "$1" 2>/dev/null || true; }

# 書き換えを、同じディレクトリの一時ファイルへ書いてから mv で被せる（途中で落ちても半端なファイルを残さない）。
_oe_lease_write() {
  local file="$1" json="$2" tmp
  tmp="${file}.tmp.$$"
  ( umask 077; printf '%s\n' "$json" > "$tmp" ) || { rm -f "$tmp" 2>/dev/null; return 2; }
  jq -e . "$tmp" >/dev/null 2>&1 || { rm -f "$tmp" 2>/dev/null; return 2; }
  mv -f "$tmp" "$file" || { rm -f "$tmp" 2>/dev/null; return 2; }
}

# --- 作る ---
# oe_lease_create <kind> <label> <workspace> <parent_lease_id> [<generation>]
#   新しい lease を作って lease_id を出す。generation は既定 1（統括の lease は、いまの代の番号から始めてよい）。
oe_lease_create() {
  local kind="${1:-}" label="${2:-}" ws="${3:-}" parent="${4:-}" gen="${5:-1}" id file now
  case "$kind" in supervisor|delegation) ;; *) echo "oe_lease_create: kind must be supervisor|delegation" >&2; return 2 ;; esac
  case "$gen" in ''|*[!0-9]*|0) echo "oe_lease_create: generation must be a positive integer" >&2; return 2 ;; esac
  if [ -n "$parent" ] && ! _oe_lease_valid_id "$parent"; then echo "oe_lease_create: bad parent_lease_id" >&2; return 2; fi
  _oe_lease_ready || return 2
  id="$(oe_generate_session_id)"
  file="$(_oe_lease_file "$id")"
  [ ! -e "$file" ] || return 2
  now="$(_oe_lease_now_iso)"
  _oe_lease_write "$file" "$(jq -cn --arg id "$id" --arg kind "$kind" --arg label "$label" --arg ws "$ws" \
      --arg parent "$parent" --arg now "$now" --argjson gen "$gen" '
    { format: 1, lease_id: $id, kind: $kind, label: $label, workspace: $ws, parent_lease_id: $parent,
      state: "open", created_at: $now, closed_at: "", epoch: 0, current_generation: $gen,
      generations: [ { generation: $gen, state: "active", started_at: $now, retired_at: "", successor: null,
                       session_ids: [], binding: null } ] }')" || return 2
  printf '%s\n' "$id"
}

oe_lease_get() {
  local id="${1:-}" file
  _oe_lease_valid_id "$id" || return 2
  [ -n "$OE_LEASE_DIR" ] || return 2
  file="$(_oe_lease_file "$id")"
  [ -f "$file" ] || return 1
  cat "$file"
}

oe_lease_epoch() { oe_lease_get "${1:-}" | jq -r '.epoch'; }

# --- binding を書く・張り替える ---
# oe_lease_bind <lease_id> <expect_epoch> <pid> <started> <comm>
#   いまの generation の binding を書く。同じ pid と開始時刻なら何もせず 0 を返す（epoch も増やさない）。
oe_lease_bind() {
  local id="${1:-}" expect="${2:-}" pid="${3:-}" started="${4:-}" comm="${5:-}" file lock rc=0 cur cur_epoch gen old_pid old_started st now
  _oe_lease_valid_id "$id" || return 2
  case "$expect" in ''|*[!0-9]*) return 2 ;; esac
  case "$pid" in ''|*[!0-9]*) return 2 ;; esac
  [ -n "$started" ] || return 2
  case "$comm" in *claude*) ;; *) return 6 ;; esac
  _oe_lease_ready || return 2
  file="$(_oe_lease_file "$id")"; [ -f "$file" ] || return 1
  lock="${file}.lock"
  _oe_lease_lock "$lock" || return 4
  cur="$(cat "$file")" || rc=2
  if [ "$rc" -eq 0 ]; then
    cur_epoch="$(printf '%s' "$cur" | jq -r '.epoch')"
    if [ "$(printf '%s' "$cur" | jq -r '.state')" != "open" ]; then rc=7
    elif [ "$cur_epoch" != "$expect" ]; then rc=3
    else
      gen="$(printf '%s' "$cur" | jq -r '.current_generation')"
      if [ "$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | .state')" != "active" ]; then rc=7
      else
        old_pid="$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | (.binding.pid // "") | tostring')"
        old_started="$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | (.binding.started // "")')"
        started="$(_oe_tpi_norm "$started")"
        if [ -n "$old_pid" ] && [ "$old_pid" = "$pid" ] && [ "$(_oe_tpi_norm "$old_started")" = "$started" ]; then
          rc=0   # 本人がもう一度書く。何も変えない。
        else
          if [ -n "$old_pid" ]; then
            st="$(oe_tpi_proc_state "$old_pid" "$old_started")"
            [ "$st" = "dead" ] || rc=5
          fi
          if [ "$rc" -eq 0 ]; then
            now="$(_oe_lease_now_iso)"
            _oe_lease_write "$file" "$(printf '%s' "$cur" | jq -c --argjson g "$gen" --argjson pid "$pid" \
                --arg st "$started" --arg comm "$comm" --arg now "$now" '
              .epoch += 1
              | .generations |= map(if .generation == $g
                  then .binding = { pid: $pid, started: $st, comm: $comm, bound_at: $now } else . end)')" || rc=2
          fi
        fi
      fi
    fi
  fi
  _oe_lease_unlock "$lock"
  return "$rc"
}

# --- session_id を登録する（本人だけ・すべての lease に共通のロックの中で） ---
# oe_lease_register_session <lease_id> <session_id> <pid> <started>
oe_lease_register_session() {
  local id="${1:-}" sid="${2:-}" pid="${3:-}" started="${4:-}" file glock lock rc=0 cur gen bpid bst f other
  _oe_lease_valid_id "$id" || return 2
  case "$sid" in ''|*[!A-Za-z0-9._-]*) return 2 ;; esac
  case "$pid" in ''|*[!0-9]*) return 2 ;; esac
  [ -n "$started" ] || return 2
  _oe_lease_ready || return 2
  file="$(_oe_lease_file "$id")"; [ -f "$file" ] || return 1
  glock="${OE_LEASE_DIR}/.sessions.lock"; lock="${file}.lock"
  _oe_lease_lock "$glock" || return 4
  if ! _oe_lease_lock "$lock"; then _oe_lease_unlock "$glock"; return 4; fi
  cur="$(cat "$file")" || rc=2
  if [ "$rc" -eq 0 ]; then
    gen="$(printf '%s' "$cur" | jq -r '.current_generation')"
    bpid="$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | (.binding.pid // "") | tostring')"
    bst="$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | (.binding.started // "")')"
    if [ "$(printf '%s' "$cur" | jq -r '.state')" != "open" ]; then rc=7
    elif [ "$bpid" != "$pid" ] || [ "$(_oe_tpi_norm "$bst")" != "$(_oe_tpi_norm "$started")" ]; then rc=5
    else
      for f in "$OE_LEASE_DIR"/*.json; do
        [ -f "$f" ] || continue
        [ "$f" != "$file" ] || continue
        other="$(jq -r --arg s "$sid" 'select(.state=="open") | select(any(.generations[]; (.session_ids // []) | index($s))) | .lease_id' "$f" 2>/dev/null)"
        if [ -n "$other" ]; then rc=8; break; fi
      done
      if [ "$rc" -eq 0 ]; then
        if printf '%s' "$cur" | jq -e --argjson g "$gen" --arg s "$sid" 'any(.generations[]; .generation==$g and ((.session_ids // []) | index($s)))' >/dev/null; then
          rc=0  # もう入っている
        elif printf '%s' "$cur" | jq -e --arg s "$sid" 'any(.generations[]; (.session_ids // []) | index($s))' >/dev/null; then
          rc=8  # 同じ lease の別の generation（退任した代など）に入っている。2か所に入れない
        else
          _oe_lease_write "$file" "$(printf '%s' "$cur" | jq -c --argjson g "$gen" --arg s "$sid" '
            .generations |= map(if .generation == $g then .session_ids += [$s] else . end)')" || rc=2
        fi
      fi
    fi
  fi
  _oe_lease_unlock "$lock"; _oe_lease_unlock "$glock"
  return "$rc"
}

# --- 本人が binding と session_id を一緒に取る（bind の verb と create --root が使う） ---
# oe_lease_claim <lease_id> <expect_epoch> <pid> <started> <comm> <session_id>
#   binding の張り替え（oe_lease_bind と同じ決まり）と session_id の登録（oe_lease_register_session と同じ決まり）を、
#   すべての lease に共通のロック → lease のロックの中で確かめてから、1回の書き込みで行う。session_id がほかの
#   開いた lease か、同じ lease の別の generation にあれば、binding も変えずに 8 で止まる（実装SO の指摘）。
oe_lease_claim() {
  local id="${1:-}" expect="${2:-}" pid="${3:-}" started="${4:-}" comm="${5:-}" sid="${6:-}" file glock lock rc=0 cur gen old_pid old_started f other self=0 now
  _oe_lease_valid_id "$id" || return 2
  case "$expect" in ''|*[!0-9]*) return 2 ;; esac
  case "$pid" in ''|*[!0-9]*) return 2 ;; esac
  case "$sid" in ''|*[!A-Za-z0-9._-]*) return 2 ;; esac
  [ -n "$started" ] || return 2
  case "$comm" in *claude*) ;; *) return 6 ;; esac
  _oe_lease_ready || return 2
  file="$(_oe_lease_file "$id")"; [ -f "$file" ] || return 1
  glock="${OE_LEASE_DIR}/.sessions.lock"; lock="${file}.lock"
  _oe_lease_lock "$glock" || return 4
  if ! _oe_lease_lock "$lock"; then _oe_lease_unlock "$glock"; return 4; fi
  cur="$(cat "$file")" || rc=2
  started="$(_oe_tpi_norm "$started")"
  if [ "$rc" -eq 0 ]; then
    gen="$(printf '%s' "$cur" | jq -r '.current_generation')"
    if [ "$(printf '%s' "$cur" | jq -r '.state')" != "open" ]; then rc=7
    elif [ "$(printf '%s' "$cur" | jq -r '.epoch')" != "$expect" ]; then rc=3
    elif [ "$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | .state')" != "active" ]; then rc=7
    fi
  fi
  if [ "$rc" -eq 0 ]; then
    for f in "$OE_LEASE_DIR"/*.json; do
      [ -f "$f" ] || continue
      [ "$f" != "$file" ] || continue
      other="$(jq -r --arg s "$sid" 'select(.state=="open") | select(any(.generations[]; (.session_ids // []) | index($s))) | .lease_id' "$f" 2>/dev/null)"
      if [ -n "$other" ]; then rc=8; break; fi
    done
  fi
  if [ "$rc" -eq 0 ] && printf '%s' "$cur" | jq -e --argjson g "$gen" --arg s "$sid" 'any(.generations[]; .generation != $g and ((.session_ids // []) | index($s)))' >/dev/null; then
    rc=8
  fi
  if [ "$rc" -eq 0 ]; then
    old_pid="$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | (.binding.pid // "") | tostring')"
    old_started="$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | (.binding.started // "")')"
    if [ -n "$old_pid" ] && [ "$old_pid" = "$pid" ] && [ "$(_oe_tpi_norm "$old_started")" = "$started" ]; then self=1
    elif [ -n "$old_pid" ] && [ "$(oe_tpi_proc_state "$old_pid" "$old_started")" != "dead" ]; then rc=5
    fi
  fi
  if [ "$rc" -eq 0 ]; then
    now="$(_oe_lease_now_iso)"
    _oe_lease_write "$file" "$(printf '%s' "$cur" | jq -c --argjson g "$gen" --argjson pid "$pid" --arg st "$started" \
        --arg comm "$comm" --arg now "$now" --arg s "$sid" --argjson self "$self" '
      (if $self == 1 then . else .epoch += 1 end)
      | .generations |= map(if .generation == $g then
          (if $self == 1 then . else .binding = { pid: $pid, started: $st, comm: $comm, bound_at: $now } end)
          | (if ((.session_ids // []) | index($s)) then . else .session_ids += [$s] end)
        else . end)')" || rc=2
  fi
  _oe_lease_unlock "$lock"; _oe_lease_unlock "$glock"
  return "$rc"
}

# --- generation を進める（交代） ---
# oe_lease_advance <lease_id> <expect_epoch> <planned|recover> <pid> <started> <comm>
#   planned: 前の generation が退任を申告した（計画的な交代・呼ぶ側が確かめる）。
#   recover: 前の generation の binding のプロセスが生きていないと機械で確かめられたときだけ進める。
#   進めたら新しい generation の番号を出す。
oe_lease_advance() {
  local id="${1:-}" expect="${2:-}" mode="${3:-}" pid="${4:-}" started="${5:-}" comm="${6:-}" file lock rc=0 cur gen next old_pid old_started now
  _oe_lease_valid_id "$id" || return 2
  case "$expect" in ''|*[!0-9]*) return 2 ;; esac
  case "$mode" in planned|recover) ;; *) return 2 ;; esac
  case "$pid" in ''|*[!0-9]*) return 2 ;; esac
  [ -n "$started" ] || return 2
  case "$comm" in *claude*) ;; *) return 6 ;; esac
  _oe_lease_ready || return 2
  file="$(_oe_lease_file "$id")"; [ -f "$file" ] || return 1
  lock="${file}.lock"
  _oe_lease_lock "$lock" || return 4
  cur="$(cat "$file")" || rc=2
  if [ "$rc" -eq 0 ]; then
    if [ "$(printf '%s' "$cur" | jq -r '.state')" != "open" ]; then rc=7
    elif [ "$(printf '%s' "$cur" | jq -r '.epoch')" != "$expect" ]; then rc=3
    else
      gen="$(printf '%s' "$cur" | jq -r '.current_generation')"; next=$((gen + 1))
      if [ "$mode" = "recover" ]; then
        old_pid="$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | (.binding.pid // "") | tostring')"
        old_started="$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | (.binding.started // "")')"
        if [ -z "$old_pid" ] || [ "$(oe_tpi_proc_state "$old_pid" "$old_started")" != "dead" ]; then rc=5; fi
      fi
      if [ "$rc" -eq 0 ]; then
        now="$(_oe_lease_now_iso)"
        _oe_lease_write "$file" "$(printf '%s' "$cur" | jq -c --argjson g "$gen" --argjson n "$next" --argjson pid "$pid" \
            --arg st "$(_oe_tpi_norm "$started")" --arg comm "$comm" --arg now "$now" '
          .epoch += 1 | .current_generation = $n
          | .generations |= map(if .generation == $g then .state = "retired" | .retired_at = $now | .successor = $n else . end)
          | .generations += [ { generation: $n, state: "active", started_at: $now, retired_at: "", successor: null,
                                session_ids: [], binding: { pid: $pid, started: $st, comm: $comm, bound_at: $now } } ]')" || rc=2
        [ "$rc" -ne 0 ] || printf '%s\n' "$next"
      fi
    fi
  fi
  _oe_lease_unlock "$lock"
  return "$rc"
}

# --- 親を書き換える（子を自分の下に付ける）。epoch を増やす ---
oe_lease_set_parent() {
  local id="${1:-}" expect="${2:-}" parent="${3:-}" file lock rc=0 cur
  _oe_lease_valid_id "$id" || return 2
  case "$expect" in ''|*[!0-9]*) return 2 ;; esac
  if [ -n "$parent" ]; then _oe_lease_valid_id "$parent" || return 2; [ "$parent" != "$id" ] || return 2; fi
  _oe_lease_ready || return 2
  file="$(_oe_lease_file "$id")"; [ -f "$file" ] || return 1
  lock="${file}.lock"
  _oe_lease_lock "$lock" || return 4
  cur="$(cat "$file")" || rc=2
  if [ "$rc" -eq 0 ]; then
    if [ "$(printf '%s' "$cur" | jq -r '.state')" != "open" ]; then rc=7
    elif [ "$(printf '%s' "$cur" | jq -r '.epoch')" != "$expect" ]; then rc=3
    else
      _oe_lease_write "$file" "$(printf '%s' "$cur" | jq -c --arg p "$parent" '.epoch += 1 | .parent_lease_id = $p')" || rc=2
    fi
  fi
  _oe_lease_unlock "$lock"
  return "$rc"
}

# --- 閉じる ---
oe_lease_close() {
  local id="${1:-}" file lock rc=0 cur
  _oe_lease_valid_id "$id" || return 2
  _oe_lease_ready || return 2
  file="$(_oe_lease_file "$id")"; [ -f "$file" ] || return 1
  lock="${file}.lock"
  _oe_lease_lock "$lock" || return 4
  cur="$(cat "$file")" || rc=2
  if [ "$rc" -eq 0 ]; then
    if [ "$(printf '%s' "$cur" | jq -r '.state')" = "closed" ]; then rc=1
    else
      _oe_lease_write "$file" "$(printf '%s' "$cur" | jq -c --arg now "$(_oe_lease_now_iso)" '.state = "closed" | .closed_at = $now')" || rc=2
    fi
  fi
  _oe_lease_unlock "$lock"
  return "$rc"
}

# --- 探す ---
# oe_lease_find_by_session <session_id> — 開いた lease のうち、その session_id を持つものを "<lease_id>\t<generation>" で出す
oe_lease_find_by_session() {
  local sid="${1:-}" f out=""
  [ -n "$sid" ] && [ -n "$OE_LEASE_DIR" ] && [ -d "$OE_LEASE_DIR" ] || return 1
  for f in "$OE_LEASE_DIR"/*.json; do
    [ -f "$f" ] || continue
    out="${out}$(jq -r --arg s "$sid" 'select(.state=="open") | .lease_id as $l
      | .generations[] | select((.session_ids // []) | index($s)) | "\($l)\t\(.generation)"' "$f" 2>/dev/null)"
  done
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

# oe_lease_find_by_label <label> — 開いた lease のうち、label が一致するものの lease_id を1行1件で出す
oe_lease_find_by_label() {
  local label="${1:-}" f out=""
  [ -n "$label" ] && [ -n "$OE_LEASE_DIR" ] && [ -d "$OE_LEASE_DIR" ] || return 1
  for f in "$OE_LEASE_DIR"/*.json; do
    [ -f "$f" ] || continue
    out="${out}$(jq -r --arg l "$label" 'select(.state=="open" and .label==$l) | .lease_id' "$f" 2>/dev/null)
"
  done
  out="$(printf '%s' "$out" | grep -v '^$')" || return 1
  printf '%s\n' "$out"
}

# oe_lease_find_by_binding <pid> <started> — 開いた lease のうち、いまの generation の binding がそのプロセスのものを出す
#   （adopt が同じプロセスを2回取り込まないため・oe-register link が相手の lease を見つけるため）
oe_lease_find_by_binding() {
  local pid="${1:-}" started="${2:-}" f out=""
  case "$pid" in ''|*[!0-9]*) return 2 ;; esac
  [ -n "$started" ] && [ -n "$OE_LEASE_DIR" ] && [ -d "$OE_LEASE_DIR" ] || return 1
  started="$(_oe_tpi_norm "$started")"
  for f in "$OE_LEASE_DIR"/*.json; do
    [ -f "$f" ] || continue
    out="${out}$(jq -r --argjson p "$pid" --arg st "$started" 'select(.state=="open") | .current_generation as $g
      | select(any(.generations[]; .generation==$g and .binding != null and .binding.pid==$p and .binding.started==$st))
      | .lease_id' "$f" 2>/dev/null)
"
  done
  out="$(printf '%s' "$out" | grep -v '^$')" || return 1
  printf '%s\n' "$out"
}

# --- 名乗る ---
# oe_lease_whoami — 自分の lease と generation を、環境変数（方法1）か自分の session_id（方法2）で決めて JSON で出す。
#   どちらでも決まらなければ rc 1。方法3（会話の記録の lease_id を bind に渡す）は verb の側で扱う。
#   退任した generation なら state に "retired" と、いまの generation を出す（D8）。
oe_lease_whoami() {
  local id="${OE_LEASE_ID:-}" gen="${OE_GENERATION:-}" src="env" hit cur
  if [ -z "$id" ]; then
    [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] || return 1
    hit="$(oe_lease_find_by_session "$CLAUDE_CODE_SESSION_ID")" || return 1
    [ "$(printf '%s\n' "$hit" | grep -c .)" -eq 1 ] || return 2
    id="${hit%%"$_OE_TPI_TAB"*}"; gen="${hit#*"$_OE_TPI_TAB"}"; src="session"
  fi
  cur="$(oe_lease_get "$id")" || return 1
  [ -n "$gen" ] || gen="$(printf '%s' "$cur" | jq -r '.current_generation')"
  printf '%s' "$cur" | jq -c --argjson g "$gen" --arg src "$src" '
    { lease_id, kind, label, workspace, parent_lease_id, lease_state: .state, generation: $g,
      state: ((.generations[] | select(.generation==$g) | .state) // "unknown"),
      current_generation, source: $src }'
}

# --- いまのペインを引く（送る前の確かめ・DJ-6） ---
# oe_lease_resolve_pane <lease_id> — いまの generation の binding と照らしたペインを出す。
#   rc: 0 引けた / 1 候補が無い / 3 候補が分かれた / 5 本人を確かめられない（不一致）/ 6 確かめられない（ps や tmux）
#       / 7 lease が閉じている / 9 binding が無い / 2 呼び方の誤り
oe_lease_resolve_pane() {
  local id="${1:-}" cur gen bpid bst spid maxage cand rc pane sids=()
  cur="$(oe_lease_get "$id")" || return $?
  [ "$(printf '%s' "$cur" | jq -r '.state')" = "open" ] || return 7
  gen="$(printf '%s' "$cur" | jq -r '.current_generation')"
  bpid="$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | (.binding.pid // "") | tostring')"
  bst="$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | (.binding.started // "")')"
  [ -n "$bpid" ] && [ -n "$bst" ] || return 9
  while IFS= read -r s; do [ -n "$s" ] && sids+=("$s"); done <<EOF
$(printf '%s' "$cur" | jq -r --argjson g "$gen" '.generations[] | select(.generation==$g) | (.session_ids // [])[]')
EOF
  spid="${OE_LEASE_SERVER_PID:-}"
  if [ -z "$spid" ]; then spid="${TMUX:-}"; spid="${spid#*,}"; spid="${spid%%,*}"; fi
  [ -n "$spid" ] || return 6
  maxage="${OE_LEASE_BEAT_MAX_AGE_SEC:-21600}"
  cand="$(oe_hb_pane_for "$spid" "$maxage" "$id" "$gen" ${sids[@]+"${sids[@]}"})"; rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  pane="${cand%%"$_OE_TPI_TAB"*}"
  oe_tpi_verify_pane "$pane" "$bpid" "$bst"; rc=$?
  case "$rc" in 0) printf '%s\n' "$pane" ;; 1) return 5 ;; *) return 6 ;; esac
}

# --- 掃除（DJ-4・owner の答え Q78） ---
# oe_lease_gc <days> [dry-run]
#   閉じてから <days> 日を過ぎた lease と、<days> 日より古く、開いた lease のいまの generation の session_id に
#   当たらない heartbeat の sidecar を消す。書き込みの途中の一時ファイル（.hb.*）は触らない（別 issue）。
#   消した（dry-run なら消すはずの）パスを1行1件で出す。
oe_lease_gc() {
  local days="${1:-}" dry="${2:-}" now cutoff f closed keep sid ts
  case "$days" in ''|*[!0-9]*) return 2 ;; esac
  _oe_lease_ready || return 2
  now="$(_oe_lease_now_epoch)"; cutoff=$((now - days * 86400))
  keep=""
  for f in "$OE_LEASE_DIR"/*.json; do
    [ -f "$f" ] || continue
    closed="$(jq -r 'if .state=="closed" and (.closed_at // "") != "" then (.closed_at | fromdateiso8601 | tostring) else "" end' "$f" 2>/dev/null)" || continue
    if [ -n "$closed" ] && [ "$closed" -lt "$cutoff" ]; then
      printf '%s\n' "$f"; [ "$dry" = "dry-run" ] || rm -f "$f"
      continue
    fi
    keep="${keep}$(jq -r 'select(.state=="open") | .current_generation as $g | .generations[] | select(.generation==$g) | (.session_ids // [])[]' "$f" 2>/dev/null)
"
  done
  [ -n "$OE_HEARTBEAT_DIR" ] && [ -d "$OE_HEARTBEAT_DIR" ] || return 0
  for f in "$OE_HEARTBEAT_DIR"/*.json; do
    [ -f "$f" ] || continue
    sid="$(basename "$f" .json)"
    if printf '%s' "$keep" | grep -qxF -- "$sid"; then continue; fi
    ts="$(jq -r '(.ts // "") | tostring' "$f" 2>/dev/null)" || continue
    case "$ts" in ''|*[!0-9]*) continue ;; esac
    if [ "$ts" -lt "$cutoff" ]; then
      printf '%s\n' "$f"; [ "$dry" = "dry-run" ] || rm -f "$f"
    fi
  done
  return 0
}
