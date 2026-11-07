# shellcheck shell=bash
# shellcheck disable=SC2034  # OE_TARGET_* は source した側が読む
# target-resolve.sh — 送る・飛ぶ・選ぶの宛先を lease の記録から引き、本人を確かめる（#577 PR-3・source 専用）
#
# 設計の正本は projects/orchestration-engine/docs/discussions/2026-11-06-discussion-577-record-identity-key.md の
# DJ-6（送る前に宛先の本人を確かめる順）と DJ-15（送る側の引き方）。
#
#   oe_target_resolve <target>
#     受け付ける形:
#       %N        生のペイン。いままでどおり素通しで、本人は確かめない（移行とフォールバックのため）
#       lease_id  26文字の lease の ID
#       ラベル    #N か名前。lease の記録から先に引く。自分の lease（oe_lease_whoami）を親に持つ開いた lease の
#                 うち、ラベルが合い、binding があり、binding のプロセスが「無い」と確かめられていないものを
#                 候補にする（registry が「いまの親の子」に限っていたのと同じ範囲・実装SO の指摘）。自分の lease が
#                 分からないときと、候補が無いときは、移行のあいだだけ古い引き方（pane-issue と registry・
#                 oe_reg_resolve）に落とす（owner の答え Q77）
#     lease から引いたときは、heartbeat の候補のペイン → tmux に在る → ペインのフォアグラウンドのプロセスが
#     binding の pid と開始時刻、の順で確かめる（lib/lease.sh の oe_lease_resolve_pane）。
#
#   oe_target_resolve_parent
#     子が親へ送る宛先。自分の lease（OE_LEASE_ID）の親の lease を引き、上と同じに確かめる。統括が交代しても、
#     親の lease が同じなら届く。OE_LEASE_ID が無い子（#577 の前に起こした子）と、自分の lease に親が書かれて
#     いない子は、いままでどおり PARENT_TMUX_PANE に落とす（DJ-11「古い子は古い宛先のまま」）。
#
#   結果は変数に入れる（$( ) で呼ぶと変数が外に残らないので、呼ぶ側は直接呼ぶ）:
#     OE_TARGET_PANE   送る・飛ぶペイン（%N）
#     OE_TARGET_LEASE  lease から引いたときだけ "<lease_id>:<generation>"
#     OE_TARGET_HOW    raw / lease / label-lease / label-legacy / parent-lease / parent-legacy
#   rc: 0 引けた / 1 宛先が無い（閉じた lease・引けないラベル・曖昧なラベル・親が分からない）
#       2 環境・呼び方の誤り / 5 宛先の本人を確かめられない（送らない）
#   案内は stderr に、OE_TARGET_CALLER（既定 oe-target）を頭に付けて出す。
#
# 前提: lib/lease.sh と lib/delegate-registry.sh を先に source しておく。

OE_TARGET_PANE=""
OE_TARGET_LEASE=""
OE_TARGET_HOW=""

_oe_target_say() { printf '%s: %s\n' "${OE_TARGET_CALLER:-oe-target}" "$*" >&2; }

# lease の宛先を確かめて OE_TARGET_* を埋める。<lease_id> <how> <表示名>
_oe_target_from_lease() {
  local id="$1" how="$2" shown="$3" cur gen ep ep2 pane rc why try=0
  # 引いたペインと、記録に残す generation を同じ記録から取る。ペインを引くあいだに交代（generation を
  # 進める書き込み）が走ったら、epoch が変わるのでもう一度引く（Copilot の指摘・PR #588）。
  while :; do
    cur="$(oe_lease_get "$id" 2>/dev/null)" || { _oe_target_say "${shown}: lease ${id} の記録がありません"; return 1; }
    gen="$(printf '%s' "$cur" | jq -r '.current_generation')"; ep="$(printf '%s' "$cur" | jq -r '.epoch')"
    pane="$(oe_lease_resolve_pane "$id")"; rc=$?
    ep2="$(oe_lease_epoch "$id" 2>/dev/null)" || ep2=""
    [ "$rc" -eq 0 ] && [ "$ep2" != "$ep" ] || break
    try=$((try + 1))
    if [ "$try" -ge 2 ]; then
      _oe_target_say "${shown}: lease ${id} が引くあいだに2回続けて書き換わったので、送りません（少し待ってからもう一度）"
      return 5
    fi
  done
  if [ "$rc" -eq 0 ]; then
    OE_TARGET_PANE="$pane"; OE_TARGET_LEASE="${id}:${gen}"; OE_TARGET_HOW="$how"
    return 0
  fi
  case "$rc" in
    7) _oe_target_say "${shown}: lease ${id} は閉じています（宛先がありません）"; return 1 ;;
    1) why="heartbeat に、いまの generation のペインの候補がありません" ;;
    3) why="heartbeat のいちばん新しい候補が同じ時刻で2つのペインに分かれています" ;;
    5) why="候補のペインのフォアグラウンドのプロセスが binding（pid と開始時刻）と一致しません" ;;
    9) why="lease に binding（プロセス）が書かれていません" ;;
    *) why="ペインかプロセスを確かめられません（rc=${rc}）" ;;
  esac
  _oe_target_say "${shown}: lease ${id}（generation ${gen}）の宛先の本人を確かめられないので、送りません（${why}）"
  _oe_target_say "  生のペイン番号で送るなら oe-send %N を使ってください。記録は oe-lease show ${id} で確かめられます"
  return 5
}

# ラベルが合う lease を探す。出力: 1行1件 "<lease_id>\t<binding の有無 yes|no>"。
# 自分の lease を親に持つものだけを見る（別の統括の子へ送らない）。binding のプロセスが「無い」と
# 確かめられた lease（終わった子）は出さない。
_oe_target_leases_for_label() {
  local target="$1" f row id pid st state me
  [ -n "${OE_LEASE_DIR:-}" ] && [ -d "$OE_LEASE_DIR" ] || return 0
  me="$(oe_lease_whoami 2>/dev/null | jq -r '.lease_id // ""' 2>/dev/null)" || me=""
  [ -n "$me" ] || return 0
  for f in "$OE_LEASE_DIR"/*.json; do
    [ -f "$f" ] || continue
    # ラベルは jq の中で JSON の値のまま比べる（@tsv はバックスラッシュとタブを書き換え、read -r は戻さない
    # ので、bash で比べると、その文字を含むラベルを見落とす・Copilot の指摘）。比べ方は registry の
    # _oe_label_match と同じ（#N は「#N」か「#N 」で始まるもの・名前は完全一致）。
    row="$(jq -r --arg me "$me" --arg t "$target" '
      def hit($l): if ($t | test("^#[0-9]+$")) then ($l == $t or ($l | startswith($t + " "))) else $l == $t end;
      select(.state=="open" and (.parent_lease_id // "") == $me and hit(.label // "")) | .current_generation as $g
      | [ .lease_id,
          ((.generations[] | select(.generation==$g) | .binding.pid // "") | tostring),
          (.generations[] | select(.generation==$g) | .binding.started // "") ] | @tsv' "$f" 2>/dev/null)" || continue
    [ -n "$row" ] || continue
    IFS="$_OE_TPI_TAB" read -r id pid st <<EOF
$row
EOF
    if [ -z "$pid" ] || [ -z "$st" ]; then printf '%s\tno\n' "$id"; continue; fi
    state="$(oe_tpi_proc_state "$pid" "$st")"
    [ "$state" != "dead" ] || continue
    printf '%s\tyes\n' "$id"
  done
}

oe_target_resolve() {
  local target="${1:-}" cands bound unbound n
  OE_TARGET_PANE=""; OE_TARGET_LEASE=""; OE_TARGET_HOW=""
  [ -n "$target" ] || { _oe_target_say "宛先がありません"; return 2; }
  if [[ "$target" =~ ^%[0-9]+$ ]]; then
    OE_TARGET_PANE="$target"; OE_TARGET_HOW="raw"; return 0
  fi
  if [[ "$target" =~ ^[0-9A-HJKMNP-TV-Z]{26}$ ]]; then
    _oe_target_from_lease "$target" lease "$target"; return
  fi
  cands="$(_oe_target_leases_for_label "$target")"
  bound="$(printf '%s\n' "$cands" | awk -F '\t' '$2=="yes" {print $1}')"
  unbound="$(printf '%s\n' "$cands" | awk -F '\t' '$2=="no" {print $1}')"
  n="$(printf '%s\n' "$bound" | grep -c . || true)"
  if [ "$n" -eq 1 ]; then
    _oe_target_from_lease "$bound" label-lease "$target"; return
  fi
  if [ "$n" -gt 1 ]; then
    _oe_target_say "${target}: ラベルが合う lease が ${n} 件あり、1つに決まりません: $(printf '%s' "$bound" | tr '\n' ' ')"
    _oe_target_say "  lease_id か生のペイン番号で送ってください（oe-lease show で確かめられます）"
    return 1
  fi
  # lease の記録で引けない。移行のあいだだけ古い引き方に落とす（Q77）。
  if [ -n "$unbound" ]; then
    _oe_target_say "${target}: ラベルが合う lease に binding が無い（$(printf '%s' "$unbound" | tr '\n' ' ')）ので、古い引き方（registry）で引きます"
  fi
  local pane
  pane="$(oe_reg_resolve "$target")" || return
  OE_TARGET_PANE="$pane"; OE_TARGET_HOW="label-legacy"
  return 0
}

oe_target_resolve_parent() {
  local cur parent rc
  OE_TARGET_PANE=""; OE_TARGET_LEASE=""; OE_TARGET_HOW=""
  if [ -n "${OE_LEASE_ID:-}" ]; then
    # 記録を読めない・読み解けないときは、PARENT_TMUX_PANE に落とさず止まる。交代のあとなら前任を指して
    # いるので、本人を確かめないまま前任へ送ることになる（Copilot の指摘・PR #588）。落とすのは、正しく
    # 読めた記録に親が書かれていないときだけにする。
    if ! cur="$(oe_lease_get "$OE_LEASE_ID" 2>/dev/null)"; then
      _oe_target_say "自分の lease ${OE_LEASE_ID} の記録を読めないので、送りません。oe-lease show ${OE_LEASE_ID} で確かめ、宛先を明示して送ってください"
      return 2
    fi
    if ! parent="$(printf '%s' "$cur" | jq -er '.parent_lease_id // ""' 2>/dev/null)" && [ "$(printf '%s' "$cur" | jq -r 'has("parent_lease_id")' 2>/dev/null)" != "true" ]; then
      _oe_target_say "自分の lease ${OE_LEASE_ID} の記録を読み解けないので、送りません。宛先を明示して送ってください"
      return 2
    fi
    if [ -n "$parent" ]; then
      _oe_target_from_lease "$parent" parent-lease "親の lease"; rc=$?
      return "$rc"
    fi
    _oe_target_say "自分の lease ${OE_LEASE_ID} に親の lease が書かれていないので、PARENT_TMUX_PANE に送ります"
  fi
  if [ -z "${PARENT_TMUX_PANE:-}" ]; then
    _oe_target_say "親が分かりません（OE_LEASE_ID も PARENT_TMUX_PANE もありません）。宛先を明示して送ってください"
    return 1
  fi
  if ! [[ "$PARENT_TMUX_PANE" =~ ^%[0-9]+$ ]]; then
    _oe_target_say "PARENT_TMUX_PANE の形が違います（${PARENT_TMUX_PANE}）。宛先を明示して送ってください"
    return 2
  fi
  if [ -z "${OE_LEASE_ID:-}" ]; then
    _oe_target_say "OE_LEASE_ID が無い子なので PARENT_TMUX_PANE（${PARENT_TMUX_PANE}）に送ります。統括が交代していれば届かないので、そのときは宛先を明示してください"
  fi
  OE_TARGET_PANE="$PARENT_TMUX_PANE"; OE_TARGET_HOW="parent-legacy"
  return 0
}
