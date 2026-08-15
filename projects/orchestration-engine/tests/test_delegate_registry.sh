#!/usr/bin/env bash
# test_delegate_registry.sh — delegate-registry.sh の resolve/list/gc 単体テスト
#
# 誤送信防止の核ロジックを自動検証する（Issue #142 / Copilot 指摘）。
# tmux を関数モックし、state ディレクトリを mktemp で隔離するため、実 tmux サーバ不要。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="${SCRIPT_DIR}/../lib/delegate-registry.sh"

# --- 隔離した state dir ---
# mktemp が失敗すると変数が空になり、lib 側の "${VAR:-既定}" が実環境（~/.claude/state/...）へ
# 解決してしまう。本ファイルは身元をわざと壊して GC を走らせるので、そのまま進むと実 registry を
# 消しにいく唯一のテストになる。したがってここで fail-fast する（#270）。
_TMP_ROOT="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
[[ -n "$_TMP_ROOT" && -d "$_TMP_ROOT" ]] || { echo "FATAL: temp root is not a directory" >&2; exit 1; }
trap 'rm -rf "$_TMP_ROOT"' EXIT
export OE_DELEGATE_STATE_DIR="${_TMP_ROOT}/oe-delegate"
export OE_PANE_ISSUE_DIR="${_TMP_ROOT}/pane-issue"
mkdir -p "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR" || { echo "FATAL: cannot create isolated dirs" >&2; exit 1; }
# 実環境配下を指していないことの最終確認。この時点では lib 未 source なので lib の :- fallback は
# まだ走っておらず、ここで見るのは代入した値そのものである。実際にこの検査が効くのは、
# TMPDIR が ~/.claude 配下を指していて mktemp がそこへ掘った場合である。
# HOME 未設定でも set -u で落ちないよう ${HOME:-} で参照する（未設定なら照合は成立しないだけで、
# 意図した FATAL メッセージ無しに unbound variable で死ぬのを避ける）。
for _d in "$OE_DELEGATE_STATE_DIR" "$OE_PANE_ISSUE_DIR"; do
  case "$_d" in
    "${HOME:-}"/.claude/*) echo "FATAL: 隔離が外れて実環境を指している: $_d" >&2; exit 1 ;;
  esac
done

# --- モック環境 ---
# _oe_reg_server_pid は $TMUX の 2 番目フィールドを pid として読む。
export TMUX="/tmp/mock-tmux-socket,99999,0"
export TMUX_PANE="%1"   # 親（self）

# モック tmux: list-panes は $MOCK_LIVE_PANES（空白区切り）を 1 行ずつ返す。
# display-message は固定の pane title を返す。サブシェル（パイプ/プロセス置換）にも継承される。
# 実 tmux と同じく、要求された -F 書式に応じて返す形にしてある（#270）: oe_reg_gc は
# '#{pane_id} #{pid}' を要求し、oe_reg_resolve / oe_reg_list は '#{pane_id}' だけを要求する。
# 分岐しないと resolve/list が pane id として "%5 99999" を受け取って壊れる。
# MOCK_SERVER_PID は「応答したサーバが名乗る pid」= $TMUX の pid と既定で一致させる。
# 既定値は "${MOCK_SERVER_PID-99999}"（:- ではなく - ）である。空を明示代入したときに空のまま
# 渡さないと「#{pid} が取れない環境」を再現できない（:- だと空が既定値に置き換わってしまう）。
MOCK_LIVE_PANES=""
tmux() {
  case "${1:-} ${2:-}" in
    "list-panes -a"|"list-panes"*)
      if [[ -n "${MOCK_TMUX_FAIL:-}" ]]; then echo "no server running on socket" >&2; return 1; fi
      if [[ "$*" == *'#{pid}'* ]]; then
        # shellcheck disable=SC2086
        for _mp in $MOCK_LIVE_PANES; do printf '%s %s\n' "$_mp" "${MOCK_SERVER_PID-99999}"; done
      else
        # shellcheck disable=SC2086
        printf '%s\n' $MOCK_LIVE_PANES
      fi ;;
    "display-message"*) printf '%s\n' "${MOCK_PANE_TITLE:-mock-pane-title}" ;;
    *) return 0 ;;
  esac
}

# shellcheck source=../lib/delegate-registry.sh
source "$LIB"

pass=0; fail=0
ck() { # <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; pass=$((pass+1));
  else echo "  FAIL: $1 (want='$2' got='$3')"; fail=$((fail+1)); fi
}

keyA="$(_oe_reg_key '%5')"   # 99999__5
keyB="$(_oe_reg_key '%7')"   # 99999__7
MOCK_LIVE_PANES="%5 %7"

# A = pane-issue #142、B = spawn ラベル my-task（親 = self %1）
printf '{"name":"#142 redesign"}\n' > "${OE_PANE_ISSUE_DIR}/${keyA}"
oe_reg_record "%7" "my-task" "/ws" "%1"

echo "[1] resolve: pane-issue / spawn / %N passthrough / #N 境界"
ck "resolve #142 -> %5 (pane-issue)" "%5" "$(oe_reg_resolve '#142' 2>/dev/null)"
ck "resolve my-task -> %7 (spawn)"   "%7" "$(oe_reg_resolve 'my-task' 2>/dev/null)"
ck "resolve %999 passthrough"        "%999" "$(oe_reg_resolve '%999' 2>/dev/null)"
ck "resolve #14 (token boundary) empty" "" "$(oe_reg_resolve '#14' 2>/dev/null)"

echo "[2] parent scope: 別親の spawn ラベルは解決しない"
oe_reg_record "%7" "other-task" "/ws" "%99999"   # 別親で上書き
ck "other-task (foreign parent) empty" "" "$(oe_reg_resolve 'other-task' 2>/dev/null)"
oe_reg_record "%7" "my-task" "/ws" "%1"           # 戻す

echo "[3] pane-issue 優先（ドリフト）: %7 に pane-issue #150"
printf '{"name":"#150 switched"}\n' > "${OE_PANE_ISSUE_DIR}/${keyB}"
ck "my-task suppressed by pane-issue" "" "$(oe_reg_resolve 'my-task' 2>/dev/null)"
ck "resolve #150 -> %7"               "%7" "$(oe_reg_resolve '#150' 2>/dev/null)"
rm -f "${OE_PANE_ISSUE_DIR}/${keyB}"

echo "[4] ambiguity: %5,%7 両方に pane-issue #142"
printf '{"name":"#142 dup"}\n' > "${OE_PANE_ISSUE_DIR}/${keyB}"
amb_rc=0; oe_reg_resolve '#142' >/dev/null 2>&1 || amb_rc=$?
ck "ambiguous #142 -> rc 1" "1" "$amb_rc"
rm -f "${OE_PANE_ISSUE_DIR}/${keyB}"

echo "[5] list: source 列"
LIST="$(oe_reg_list 2>/dev/null)"
ck "list shows %5 pane-issue" "yes" "$(echo "$LIST" | grep -q "%5 .*pane-issue .*#142" && echo yes || echo no)"
ck "list shows %7 spawn"      "yes" "$(echo "$LIST" | grep -q "%7 .*spawn-registry .*my-task" && echo yes || echo no)"

echo "[6] gc: 別サーバ pid の stale entry を掃除、生存 %7 は残す"
printf '{"pane":"%%9","label":"stale","parent_pane":"%%1","role":"child"}\n' > "${OE_DELEGATE_STATE_DIR}/00000001__9.json"
oe_reg_gc
ck "stale foreign-pid removed" "no"  "$( [[ -e "${OE_DELEGATE_STATE_DIR}/00000001__9.json" ]] && echo yes || echo no)"
ck "live %7 entry kept"        "yes" "$( [[ -e "${OE_DELEGATE_STATE_DIR}/${keyB}.json" ]] && echo yes || echo no)"

echo "[7] gc: 死んだペインの entry を掃除"
MOCK_LIVE_PANES="%5"   # %7 が消えた
oe_reg_gc
ck "dead %7 entry removed" "no" "$( [[ -e "${OE_DELEGATE_STATE_DIR}/${keyB}.json" ]] && echo yes || echo no)"

echo "[8] tmux list-panes 失敗時: resolve=環境エラー(2) / gc は誤削除しない"
MOCK_LIVE_PANES="%5 %7"
oe_reg_record "%7" "guard-task" "/ws" "%1"   # 内部 gc は %7 live なので保持
ck "事前: %7 entry 存在" "yes" "$( [[ -e "${OE_DELEGATE_STATE_DIR}/${keyB}.json" ]] && echo yes || echo no)"
MOCK_TMUX_FAIL=1
rrc=0; oe_reg_resolve 'guard-task' >/dev/null 2>&1 || rrc=$?
ck "list-panes 失敗 → resolve rc=2 (環境エラー)" "2" "$rrc"
oe_reg_gc 2>/dev/null
ck "list-panes 失敗 → gc が entry を残す(誤削除なし)" "yes" "$( [[ -e "${OE_DELEGATE_STATE_DIR}/${keyB}.json" ]] && echo yes || echo no)"
unset MOCK_TMUX_FAIL

echo "[9] oe_reg_list: 改行混入ラベルを sanitize（偽 %N 行注入を断つ・#178 hardening-2）"
# (a) pane_title 由来（tmux の untrusted ソース）: 改行 + 偽 %99 行を仕込む
MOCK_LIVE_PANES="%8"
MOCK_PANE_TITLE=$'safe\n%99 forged-injection'
LIST="$(oe_reg_list 2>/dev/null)"
ck "pane-title: 偽 %99 行が無い" "0" "$(printf '%s\n' "$LIST" | grep -c '^%99')"
ck "pane-title: 改行を空白へ畳み 1 行化" "yes" \
  "$(printf '%s\n' "$LIST" | grep -q '^%8 .*pane-title .*safe %99 forged-injection' && echo yes || echo no)"
unset MOCK_PANE_TITLE
# (b) pane-issue .name 由来（jq デコードで実改行になるデータ経路）
MOCK_LIVE_PANES="%8"
key8="$(_oe_reg_key '%8')"
printf '{"name":"#142 redesign\\n%%99 evil"}\n' > "${OE_PANE_ISSUE_DIR}/${key8}"
LIST="$(oe_reg_list 2>/dev/null)"
ck "pane-issue: 偽 %99 行が無い" "0" "$(printf '%s\n' "$LIST" | grep -c '^%99')"
ck "pane-issue: sanitize 後も #142 を保持" "yes" \
  "$(printf '%s\n' "$LIST" | grep -q '^%8 .*pane-issue .*#142 redesign' && echo yes || echo no)"
rm -f "${OE_PANE_ISSUE_DIR}/${key8}"

# --- #270: 壊れた身元で GC が全 entry を消す事故の回帰 ---------------------------
# 用語: 型A = $TMUX の pid が別値 / 型B = $TMUX が空 / 型C = 別 server が同時に生きている。
# 型B の再現は $TMUX だけを unset する（TMUX_PANE は正常のまま）。実際の事故もその形で、
# oe-delegate は TMUX_PANE が空だと登記前に exit 1 するため「両方消えた」再現は起こり得ない。
gc_seed() {  # 自 pid(99999) の live %5 / dead %7 と、別 server(11111) の entry を置く
  rm -f "${OE_DELEGATE_STATE_DIR}"/*.json 2>/dev/null
  printf '{"pane":"%%5","label":"live","parent_pane":"%%1","role":"child"}\n' \
    > "${OE_DELEGATE_STATE_DIR}/$(_oe_reg_key '%5').json"
  printf '{"pane":"%%7","label":"dead","parent_pane":"%%1","role":"child"}\n' \
    > "${OE_DELEGATE_STATE_DIR}/$(_oe_reg_key '%7').json"
  printf '{"pane":"%%9","label":"other-server","parent_pane":"%%1","role":"child"}\n' \
    > "${OE_DELEGATE_STATE_DIR}/11111__9.json"
}
gc_count() { local _n=0 _f; for _f in "${OE_DELEGATE_STATE_DIR}"/*.json; do [[ -e "$_f" ]] && _n=$((_n+1)); done; printf '%s' "$_n"; }
gc_has()   { [[ -e "${OE_DELEGATE_STATE_DIR}/$1" ]] && echo yes || echo no; }
key5="$(_oe_reg_key '%5')"; key7="$(_oe_reg_key '%7')"

# 型の名前と実装のガードは1対1ではない。型B（[10]）と引き金（[12]）は $TMUX が空になるので
# 数値検査で止まり、一致検査まで到達しない。一致検査を撃っているのは [11] だけである。
echo "[10] gc: 型B（\$TMUX 消失）で全 entry を消さない（#270）"
MOCK_LIVE_PANES="%5 %7"; gc_seed
( unset TMUX; oe_reg_gc )
ck "型B: 3 entry すべて残る" "3" "$(gc_count)"

echo "[11] gc: 型A（別 server pid を名乗る）で全 entry を消さない（#270）"
gc_seed
# MOCK_SERVER_PID は非空のまま（99999）。空にすると「物差しが取れない」経路で通ってしまい、
# 身元の不一致を検査していることにならない。
# shellcheck disable=SC2030,SC2031  # 副シェルへの閉じ込めは意図（$TMUX の改変を外へ漏らさない）
( export TMUX="/tmp/mock-tmux-socket,11111,0"; MOCK_SERVER_PID=99999 oe_reg_gc )
ck "型A: 3 entry すべて残る（誤認先 11111 も守る）" "3" "$(gc_count)"

echo "[12] gc: 実際の引き金（\$TMUX 消失下の oe_reg_record）で正規 entry が残る（#270）"
gc_seed
( unset TMUX; oe_reg_record "%330" "broken-env" "/ws" "%1" >/dev/null 2>&1 )
# record が実際に書いたことを先に確かめる。書かない退行でも「正規 entry が残る」は成立して
# しまうので、これが無いと [12] は空振りしうる（実装SO 指摘）。
ck "引き金: 壊れた環境の entry が実際に記録された" "yes" "$(gc_has '__330.json')"
ck "引き金: 自 server の正規 entry が残る" "yes" "$(gc_has "${key5}.json")"
ck "引き金: dead entry も消えない（GC 自体が走らない）" "yes" "$(gc_has "${key7}.json")"

echo "[13] gc: 健全な身元では自名前空間だけを選別する（混在・#270）"
MOCK_LIVE_PANES="%5"; gc_seed          # %7 は死亡、%9 は別 server
printf '{"pane":"%%330"}\n' > "${OE_DELEGATE_STATE_DIR}/__330.json"   # 壊れた環境が残した stray
oe_reg_gc
ck "混在: 自 pid の live は残る"        "yes" "$(gc_has "${key5}.json")"
ck "混在: 自 pid の dead は消える"      "no"  "$(gc_has "${key7}.json")"
ck "混在: 別 server の entry は消える（従来契約=リーク防止の維持）" "no" "$(gc_has '11111__9.json')"
ck "混在: stray（pid 部なし）も消える（自己修復）" "no" "$(gc_has '__330.json')"

echo "[14] gc: pid が数値でなければ何もしない（glob メタ文字 / 非英数・#270）"
MOCK_LIVE_PANES="%5 %7"
for badpid in '*' 'abc-1'; do
  gc_seed
  # shellcheck disable=SC2030,SC2031  # 同上
  ( export TMUX="/tmp/mock-tmux-socket,${badpid},0"; oe_reg_gc )
  ck "pid='${badpid}': 削除 0 件" "3" "$(gc_count)"
done

echo "[15] gc: 物差し（#{pid}）が取れるかで挙動が変わる（DJ-4 の失敗モード・#270）"
# [15a] と [15b] は同じ fixture で物差しだけを振る。片方だけだと「削除しない実装」が
# 何でも通ってしまい、「測れないときに触らない」ことを証明できない。
# 固定しているのは「物差しが取れなければ掃除しない」という振る舞いであって、実装上の
# どの行かではない。物差しが空のとき実際に止めているのは一致検査である（空 != 数値 pid）。
# lib 側の -n 検査は挙動を変えない冗長な明示なので、それを外しても本節は緑のまま通る。
MOCK_LIVE_PANES="%5"; gc_seed
MOCK_SERVER_PID="" oe_reg_gc
ck "[15a] 物差しが取れない: dead entry も消えない" "yes" "$(gc_has "${key7}.json")"
gc_seed
MOCK_SERVER_PID="99999" oe_reg_gc
ck "[15b] 物差しが取れる: 同じ dead entry は消える" "no" "$(gc_has "${key7}.json")"
# 関数呼び出しへの一時代入が呼び出し後も残るかは bash のモードで差があるため、明示的に消す。
unset MOCK_SERVER_PID

echo "[16] gc: 型C（別 server が並行）は塞がない — 意図の固定（#270 DJ-6 / follow-up #337）"
# $TMUX は自分の server に対して完全に正しく、別 server の entry が同居する状況。
# 身元は整合するので検査は通り、別名前空間の entry は従来どおり削除される。
# これは案K が型C を塞がないという設計判断の明文化であって、バグの固定ではない。
MOCK_LIVE_PANES="%9"; gc_seed
# shellcheck disable=SC2030,SC2031  # 同上
( export TMUX="/tmp/other-socket,11111,0"; MOCK_SERVER_PID="11111" oe_reg_gc )
ck "型C: 自 server(11111) の live entry は残る" "yes" "$(gc_has '11111__9.json')"
ck "型C: 別 server(99999) の entry は消える（受容した既知の穴）" "no" "$(gc_has "${key5}.json")"

echo "=== RESULT: pass=${pass} fail=${fail} ==="
[[ "$fail" -eq 0 ]]
