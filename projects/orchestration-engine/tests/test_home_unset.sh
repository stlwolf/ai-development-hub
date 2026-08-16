#!/usr/bin/env bash
# test_home_unset.sh — HOME が使えないときに oe-* が壊れないことを固定する（#322）
#
# 直した欠陥: set -u の下で未定義の ${HOME} を展開するため、oe-* が引数解析へ到達する前に
# シェルごと終了していた（21本中13本・うち3本は出力ゼロで exit 1）。
#
# 本ファイルは verb 単位と lib 単位の両方を見る。片方では第2の落下点を捕まえられない
# （lib のクラッシュが先に起きて bin 側の ${HOME} を隠していた、というのが #322 の実際の
# 見落としだった）。verb は bin/oe-* の glob で列挙するので、**新しい verb は自動で対象になる**。
#
# 実験の規律: HOME を差し替える形（env -u HOME / HOME=<値>）だけを使い、state dir の変数を
# 直接空にする実験はしない。後者は ${VAR:-} が空を未設定と畳むため実環境へ解決され、
# 実際に registry を汚した事故がある（episode 参照）。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/../bin"
LIB_DIR="${SCRIPT_DIR}/../lib"

pass=0; fail=0
ck() { # <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; pass=$((pass+1));
  else echo "  FAIL: $1 (want='$2' got='$3')"; fail=$((fail+1)); fi
}

# --- 隔離 ---
# 本ファイルの隔離は「HOME を消す/差し替える」ことだけに依っている（OE_*_DIR は設定しない）。
# それで実 ~/.claude を触らないことは [5b] の / 差分検査と合わせて機械的に確かめる。
_TMP_ROOT="$(mktemp -d)" || { echo "FATAL: mktemp -d failed" >&2; exit 1; }
[[ -n "$_TMP_ROOT" && -d "$_TMP_ROOT" ]] || { echo "FATAL: temp root is not a directory" >&2; exit 1; }
trap 'rm -rf "$_TMP_ROOT"' EXIT

echo "[1] verb: HOME 未設定でも --help が rc=0（引数解析へ到達する）"
# oe-ident は --help を持たない（不正な pane として空・rc=0 を返す）。出力非空の対象から外す。
NO_HELP=" oe-ident "
for _f in "$BIN_DIR"/oe-*; do
  [[ -x "$_f" ]] || continue
  _n="$(basename "$_f")"
  _rc=0; _out="$(env -u HOME timeout 20 "$_f" --help 2>&1)" || _rc=$?
  ck "${_n} --help rc=0" "0" "$_rc"
  case "$NO_HELP" in
    *" ${_n} "*) : ;;   # help を持たない verb は出力非空を要求しない
    *) ck "${_n} --help 出力あり" "yes" "$( [[ -n "$_out" ]] && echo yes || echo no )" ;;
  esac
done

echo "[2] verb: 環境の失敗が「宛先が無い」の帯を汚さない"
# oe-send のラベル解決は state を要る。置き場が決まらないのは rc=2（環境）であって
# rc=1（宛先が無い）ではない。%N の素通しは state 不要なのでこの検査に含めない。
_rc=0; env -u HOME timeout 20 "$BIN_DIR/oe-send" '#999999' hello >/dev/null 2>&1 || _rc=$?
ck "oe-send のラベル解決は rc=2（環境エラー）" "2" "$_rc"
_rc=0; env -u HOME timeout 20 "$BIN_DIR/oe-tree" >/dev/null 2>&1 || _rc=$?
ck "oe-tree は空ツリーを成功で返さない" "2" "$_rc"

echo "[3] lib: 4変数が空のままで、後段の再宣言に塗り替えられない（source の両順序）"
# ${VAR:-既定} は未設定と空文字を畳むので、片方の順序でしか試さないと塗り替えを見逃す。
for _order in "delegate-registry.sh event-bus.sh" "event-bus.sh delegate-registry.sh"; do
  # shellcheck disable=SC2016  # 内側シェルで展開させるため単一引用符は意図
  _got="$(env -u HOME bash -c '
    set -uo pipefail
    for _l in '"$_order"'; do source "'"$LIB_DIR"'/$_l"; done
    printf "%s|%s|%s" "${OE_DELEGATE_STATE_DIR}" "${OE_PANE_ISSUE_DIR}" "${OE_EVENT_DIR}"
  ' 2>/dev/null)"
  ck "source 順 [${_order}] で3変数とも空" "||" "$_got"
done
# shellcheck disable=SC2016  # 同上
_got="$(env -u HOME bash -c '
  set -uo pipefail; source "'"$LIB_DIR"'/oe-viewer.sh"; printf "%s" "${OE_VIEW_STATE_DIR}"' 2>/dev/null)"
ck "oe-viewer.sh の state dir も空" "" "$_got"

echo "[4] lib: 書き込みは root へ触らず、経路ごとの契約どおりに返る"
_rc=0; env -u HOME bash -c '
  set -uo pipefail; source "'"$LIB_DIR"'/delegate-registry.sh"
  oe_reg_record "%9" "x" "/ws" "%1"' >/dev/null 2>&1 || _rc=$?
ck "oe_reg_record は非0で落ちる" "1" "$_rc"
# rc だけだと修正前の「source ごと abort（同じく rc=1）」と区別できないので、原因まで見る。
_err="$(env -u HOME bash -c '
  set -uo pipefail; source "'"$LIB_DIR"'/delegate-registry.sh"
  oe_reg_record "%9" "x" "/ws" "%1"' 2>&1 >/dev/null)"
ck "oe_reg_record は理由を名乗る（abort と区別）" "yes" \
  "$( printf '%s' "$_err" | grep -q '置き場が決まりません' && echo yes || echo no )"
_rc=0; env -u HOME bash -c '
  set -uo pipefail; source "'"$LIB_DIR"'/event-bus.sh"
  oe_event_child_spawned "%1" "%9" "x"' >/dev/null 2>&1 || _rc=$?
ck "oe_event_emit は rc=0 のまま（best-effort 不変条件）" "0" "$_rc"
_err="$(env -u HOME bash -c '
  set -uo pipefail; source "'"$LIB_DIR"'/event-bus.sh"
  oe_event_child_spawned "%1" "%9" "x"' 2>&1 >/dev/null)"
ck "oe_event_emit は理由を名乗る" "yes" "$( [[ -n "$_err" ]] && echo yes || echo no )"

echo "[5] HOME が「非空だが使えない」形でも root を組み立てない"
# HOME=/ は -n を通ってしまう。相対 HOME は cwd 配下に state を散らす。
for _h in "/" "relative/path" ""; do
  _got="$(HOME="$_h" bash -c '
    set -uo pipefail; source "'"$LIB_DIR"'/delegate-registry.sh"; printf "%s" "${OE_DELEGATE_STATE_DIR}"' 2>/dev/null)"
  ck "HOME='${_h}' では state dir を決めない" "" "$_got"
done
# 正常な HOME では従来どおり決まる（ガードが効きすぎて常に空、を防ぐ対の検査）
_got="$(HOME="$_TMP_ROOT" bash -c '
  set -uo pipefail; source "'"$LIB_DIR"'/delegate-registry.sh"; printf "%s" "${OE_DELEGATE_STATE_DIR}"' 2>/dev/null)"
ck "正常な HOME では従来どおり決まる" "${_TMP_ROOT}/.claude/state/oe-delegate" "$_got"

# shellcheck disable=SC2016  # ${VAR+x} は説明の文字列であって展開させない
echo "[5b] / 直下に何も作られない（plan Step 5 の約束・root 書き込みの検知）"
# root glob / root mkdir は「/ に該当ファイルが無い機械では気づけない」ので、
# 実行前後の / の中身を比較して機械的に捕まえる。
# 限界: 一般ユーザで走らせると / への mkdir は権限で失敗するため、この検査は「作れてしまう
# 環境（root / コンテナ）で効く」ものである。読み取り側の root glob もここでは検出できない。
# それでも置くのは、root で回る CI やコンテナで初めて出る類の退行を、そこで確実に落とすためである。
# shellcheck disable=SC2012  # / 直下の名前一覧を比べるだけなので ls で足りる
_root_before="$(ls -a / 2>/dev/null | sort)"
for _v in oe-activity oe-undelivered oe-vitals oe-hookfire oe-selfcheck oe-tree; do
  env -u HOME timeout 20 "$BIN_DIR/$_v" >/dev/null 2>&1 || true
done
env -u HOME bash -c '
  set -uo pipefail; source "'"$LIB_DIR"'/delegate-registry.sh"
  oe_reg_record "%9" "x" "/ws" "%1"' >/dev/null 2>&1 || true
# shellcheck disable=SC2012  # 同上
_root_after="$(ls -a / 2>/dev/null | sort)"
ck "verb 実行の前後で / の中身が変わらない" "same" \
  "$( [[ "$_root_before" == "$_root_after" ]] && echo same || echo changed )"

echo "[5c] OE_VIEW_ROOTS が空なら --from-link は全拒否（gate 3 裁定 4）"
_rc=0; env -u HOME timeout 20 "$BIN_DIR/oe-view" --from-link "/tmp/nonexistent-322.md" >/dev/null 2>&1 || _rc=$?
ck "空 allowlist で --from-link が通らない" "yes" "$( [[ "$_rc" -ne 0 ]] && echo yes || echo no )"

echo "[5d] 重複した helper の定義が全ファイルで byte 一致している"
_n="$(grep -rh '_oe_home_usable() {' "$BIN_DIR" "$LIB_DIR" 2>/dev/null | sed 's/^ *//' | sort -u | grep -c .)"
ck "_oe_home_usable の定義は1種類" "1" "$_n"
_n="$(grep -rh 'declare -F _oe_state_dir' "$BIN_DIR" 2>/dev/null | sed 's/^ *//' | sort -u | grep -c .)"
ck "_oe_state_dir の定義は1種類" "1" "$_n"

# shellcheck disable=SC2016  # ${VAR+x} は説明の文字列であって展開させない
echo '[6] 明示指定は空文字でも尊重される（${VAR+x} 判定の要）'
# shellcheck disable=SC2016  # 同上
_got="$(env -u HOME OE_DELEGATE_STATE_DIR="" bash -c '
  set -uo pipefail; source "'"$LIB_DIR"'/delegate-registry.sh"; source "'"$LIB_DIR"'/event-bus.sh"
  printf "%s" "${OE_DELEGATE_STATE_DIR}"' 2>/dev/null)"
ck "明示的な空文字が既定値へ塗り替えられない" "" "$_got"
_got="$(HOME="$_TMP_ROOT" OE_DELEGATE_STATE_DIR="${_TMP_ROOT}/explicit" bash -c '
  set -uo pipefail; source "'"$LIB_DIR"'/delegate-registry.sh"; printf "%s" "${OE_DELEGATE_STATE_DIR}"' 2>/dev/null)"
ck "明示的な値は HOME より優先される" "${_TMP_ROOT}/explicit" "$_got"

echo "=== RESULT: pass=${pass} fail=${fail} ==="
[[ "$fail" -eq 0 ]]
