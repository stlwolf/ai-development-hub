#!/usr/bin/env bash
# 架空のサービス shop の設定ファイルを、反映先へ反映する（見本）。
#
# 使い方: scripts/shop-config.sh <名前> [--dry-run] [--yes]
#   check     前提を確かめる（何も変えない）
#   diff      反映先の今の版と、設定ファイルの差分を出す（何も変えない）
#   apply     反映先を設定ファイルに合わせる（変える。--dry-run と --yes を受ける）
#   verify    反映のあとを確かめ、記録の行を出す（何も変えない）
#   status    反映先の今の版と前の版を出す（何も変えない）
#   rollback  今の版を前の版に合わせる（変える。--dry-run と --yes を受ける）
#
# 変える名前は、何度実行しても同じ結果になる。要る操作だけを実行し、要る操作が無ければ何もしない。
#
# 終了コード:
#   0 期待どおりに終わった（変える名前なら、変えたか、もともと同じで何もしなかった）
#   1 止まった（確かめが外れたか、確認で断った）。何も変えていない
#   2 呼び方の誤りか、前提が足りない（依存・資格情報・反映先・端末が無い）。何も変えていない
#   3 変える途中で失敗した。変わったかもしれない
#
# 反映先は環境変数 SHOP_STATE_DIR（/ 以外の絶対パス）で決める。無ければ ${TMPDIR:-/tmp}/shop-example-state を使う。
# 資格情報 SHOP_TOKEN は長さだけを確かめる。値は画面に出さず、どこにも送らない。
set -euo pipefail

# 実行する場所に頼らず、自分の置き場所からリポジトリの一番上を決める
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG="${ROOT}/config/shop.conf"
STATE="${SHOP_STATE_DIR:-${TMPDIR:-/tmp}/shop-example-state}"
while [ "${STATE}" != "${STATE%/}" ]; do
  STATE="${STATE%/}"
done
export TZ=UTC
KEY_RE='^[a-z][a-z0-9_.]*='
VERSION_RE='^[0-9a-f]{12}$'

usage() {
  printf '使い方: scripts/shop-config.sh check|diff|apply|verify|status|rollback [--dry-run] [--yes]\n' >&2
  exit 2
}

ok() { printf 'OK %s %s\n' "$1" "$2"; }
ng() { printf 'NG %s %s\n' "$1" "$2"; }

have_tools() {
  command -v diff >/dev/null 2>&1 && command -v cmp >/dev/null 2>&1 &&
    { command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1; }
}

# 反映先の誤りを1つ出す。誤りが無ければ何も出さない
state_problem() {
  local parent name
  case "${STATE}" in
    /?*) ;;
    *)
      printf '反映先は / 以外の絶対パスで書く（いまの値: %s）' "${SHOP_STATE_DIR:-}"
      return 0
      ;;
  esac
  parent="${STATE}"
  while [ ! -e "${parent}" ]; do
    parent=$(dirname "${parent}")
  done
  if [ ! -d "${parent}" ] || [ ! -w "${parent}" ]; then
    printf '書けない: %s' "${parent}"
    return 0
  fi
  for name in current previous; do
    if [ -e "${STATE}/${name}" ] && [ ! -L "${STATE}/${name}" ]; then
      printf '%s/%s がリンクでない' "${STATE}" "${name}"
      return 0
    fi
  done
  if [ -e "${STATE}/releases" ] && [ ! -d "${STATE}/releases" ]; then
    printf '%s/releases がフォルダでない' "${STATE}"
  fi
}

# 何も変えない名前の前に、依存と反映先だけを確かめる。外れたら終了コード 2 で止まる
require_basics() {
  local bad
  if ! have_tools; then
    ng C1 '依存（diff・cmp・sha256 の道具）が無い'
    exit 2
  fi
  bad=$(state_problem)
  if [ -n "${bad}" ]; then
    ng C3 "反映先に問題がある: ${bad}"
    exit 2
  fi
}

# 設定ファイルの中身から作る12桁の版。作れなければ終了コード 2 で止まる
version_of_file() {
  local v
  if command -v sha256sum >/dev/null 2>&1; then
    v=$(sha256sum "$1" | cut -c1-12) || v=''
  else
    v=$(shasum -a 256 "$1" | cut -c1-12) || v=''
  fi
  if ! printf '%s\n' "${v}" | grep -Eq "${VERSION_RE}"; then
    printf '版を計算できない: %s\n' "$1" >&2
    exit 2
  fi
  printf '%s' "${v}"
}

# 反映先のリンクが指す版。リンクが無ければ空
version_of_link() {
  if [ -L "$1" ]; then
    basename "$(readlink "$1")"
  fi
}

# 設定ファイルの形の誤りを1つ出す。誤りが無ければ何も出さない
config_problem() {
  if [ ! -f "${CONFIG}" ] || [ ! -r "${CONFIG}" ]; then
    printf '設定ファイルが無いか読めない: %s' "${CONFIG}"
    return 0
  fi
  local n=0 line key seen='|'
  while IFS= read -r line || [ -n "${line}" ]; do
    n=$((n + 1))
    case "${line}" in
      '' | '#'*) continue ;;
    esac
    if ! printf '%s\n' "${line}" | grep -Eq "${KEY_RE}"; then
      printf '%s 行目が キー=値 の形でない' "${n}"
      return 0
    fi
    key="${line%%=*}"
    case "${seen}" in
      *"|${key}|"*)
        printf '%s 行目のキー %s が重なっている' "${n}" "${key}"
        return 0
        ;;
    esac
    seen="${seen}${key}|"
  done <"${CONFIG}"
}

# $1 にあって $2 に無い行。grep の終了コード 1（当たり無し）は正常、2 以上は失敗として返す
lines_only_in() {
  local rc=0
  grep -Fxv -f "$2" "$1" || rc=$?
  [ "${rc}" -le 1 ]
}

# 2つの設定ファイルで、値が変わる・足される・消されるキー。読めなければ失敗を返す
changed_keys() {
  local added removed keys
  added=$(lines_only_in "${CONFIG}" "$1") || return 2
  removed=$(lines_only_in "$1" "${CONFIG}") || return 2
  keys=$(printf '%s\n%s\n' "${added}" "${removed}" | { grep -E "${KEY_RE}" || true; } | sed 's/=.*//' | sort -u | tr '\n' ' ')
  keys="${keys% }"
  printf '%s' "${keys:-無い}"
}

# 前提の確かめ。C1〜C3 が外れたら 2、C4 が外れたら 1 を返す。何も変えない
check_prereq() {
  local worst=0 bad
  if have_tools; then
    ok C1 '依存（diff・cmp・sha256 の道具）がある'
  else
    ng C1 '依存（diff・cmp・sha256 の道具）が無い'
    worst=2
  fi
  if [ -n "${SHOP_TOKEN:-}" ]; then
    ok C2 "資格情報 SHOP_TOKEN がある（${#SHOP_TOKEN} 文字・値は出さない）"
  else
    ng C2 '資格情報 SHOP_TOKEN が無いか空'
    worst=2
  fi
  bad=$(state_problem)
  if [ -z "${bad}" ]; then
    ok C3 "反映先に書ける: ${STATE}"
  else
    ng C3 "反映先に問題がある: ${bad}"
    worst=2
  fi
  bad=$(config_problem)
  if [ -z "${bad}" ]; then
    ok C4 "設定ファイルの形が正しい（キー $(grep -Ec "${KEY_RE}" "${CONFIG}" || true) 個）"
  else
    ng C4 "設定ファイルの形が違う: ${bad}"
    if [ "${worst}" -eq 0 ]; then
      worst=1
    fi
  fi
  return "${worst}"
}

# 端末から yes を受け取る。--yes があれば聞かない
confirm() {
  local answer=''
  if [ "${YES}" -eq 1 ]; then
    printf '確認: --yes があるので続ける\n'
    return 0
  fi
  if ! (: </dev/tty) 2>/dev/null; then
    printf '端末が無いので確認を受け取れない。AI が実行するときは --yes を付ける（何も変えていない）\n'
    exit 2
  fi
  printf '%s' "$1" >/dev/tty
  IFS= read -r answer </dev/tty || true
  if [ "${answer}" != yes ]; then
    printf 'yes ではないので止めた（何も変えていない）\n'
    exit 1
  fi
}

# 操作を1つ。show なら「実行する: 」の行だけを出し、run なら実行して「実行した: 」の行を出す
op() {
  local mode="$1"
  shift
  if [ "${mode}" = show ]; then
    printf '実行する:'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  if ! "$@"; then
    printf '変える途中で失敗した。反映先が変わったかもしれない。手順書の「失敗や中断のとき」を読む\n'
    exit 3
  fi
  printf '実行した:'
  printf ' %q' "$@"
  printf '\n'
}

# 反映先を版 new に合わせる操作のうち、要るものだけ
apply_ops() {
  local mode="$1" new="$2" cur="$3" prev="$4"
  if [ ! -d "${STATE}/releases/${new}" ]; then
    op "${mode}" mkdir -p "${STATE}/releases/${new}"
  fi
  if ! cmp -s "${CONFIG}" "${STATE}/releases/${new}/shop.conf" 2>/dev/null; then
    op "${mode}" cp "${CONFIG}" "${STATE}/releases/${new}/shop.conf"
  fi
  if [ -n "${cur}" ] && [ "${cur}" != "${new}" ] && [ "${prev}" != "${cur}" ]; then
    op "${mode}" ln -sfn "releases/${cur}" "${STATE}/previous"
  fi
  if [ "${cur}" != "${new}" ]; then
    op "${mode}" ln -sfn "releases/${new}" "${STATE}/current"
  fi
}

cmd_check() {
  local rc=0
  check_prereq || rc=$?
  if [ "${rc}" -eq 0 ]; then
    printf '前提はすべて満たした\n'
  fi
  exit "${rc}"
}

cmd_diff() {
  local cur old rc=0 keys
  require_basics
  cur=$(version_of_link "${STATE}/current")
  if [ -z "${cur}" ]; then
    printf '反映先にまだ版が無い。設定ファイルのすべての行が足される\n'
    old=/dev/null
  else
    printf '反映先の今の版: %s\n' "${cur}"
    old="${STATE}/current/shop.conf"
  fi
  diff -u "${old}" "${CONFIG}" || rc=$?
  if [ "${rc}" -gt 1 ]; then
    printf '差分を出せなかった\n'
    exit 2
  fi
  keys=$(changed_keys "${old}") || {
    printf '変わるキーを出せなかった\n'
    exit 2
  }
  printf '変わるキー: %s\n' "${keys}"
}

cmd_apply() {
  local rc=0 new cur prev old keys plan
  check_prereq || rc=$?
  if [ "${rc}" -ne 0 ]; then
    printf '前提が満たされていないので止めた（何も変えていない）\n'
    exit "${rc}"
  fi
  new=$(version_of_file "${CONFIG}")
  cur=$(version_of_link "${STATE}/current")
  prev=$(version_of_link "${STATE}/previous")
  plan=$(apply_ops show "${new}" "${cur}" "${prev}")
  if [ -z "${plan}" ]; then
    printf '変わっていない: 版 %s はすでに反映先にある（何もしない）\n' "${new}"
    exit 0
  fi
  old="${STATE}/current/shop.conf"
  if [ -z "${cur}" ]; then
    old=/dev/null
  fi
  keys=$(changed_keys "${old}") || {
    printf '変わるキーを出せなかった（何も変えていない）\n'
    exit 2
  }
  printf '変わるキー: %s\n' "${keys}"
  if [ -n "${cur}" ] && [ "${cur}" != "${new}" ]; then
    printf '戻し方: scripts/shop-config.sh rollback（今の版 %s に戻る）\n' "${cur}"
  elif [ -z "${cur}" ]; then
    printf '戻し方: はじめての反映なので、戻す先の版は無い\n'
  else
    printf '戻し方: 版は変わらない。反映先の中身を設定ファイルに合わせ直すだけである\n'
  fi
  printf '%s\n' "${plan}"
  if [ "${DRY}" -eq 1 ]; then
    printf '%s\n' '--dry-run なので何も変えていない'
    exit 0
  fi
  confirm '反映するなら yes と入力する: '
  if [ "$(version_of_file "${CONFIG}")" != "${new}" ]; then
    printf '確認のあいだに設定ファイルが変わった。手順の2からやり直す（何も変えていない）\n'
    exit 1
  fi
  apply_ops run "${new}" "${cur}" "${prev}"
  if [ "$(version_of_file "${STATE}/releases/${new}/shop.conf")" != "${new}" ]; then
    printf '写した中身の版が %s でない。反映先が変わったかもしれない。手順書の「失敗や中断のとき」を読む\n' "${new}"
    exit 3
  fi
  if [ "${cur}" = "${new}" ]; then
    printf '反映した: 版 %s（版は変わらず、中身を合わせ直した）\n' "${new}"
  else
    printf '反映した: 版 %s（前の版 %s）\n' "${new}" "${cur:-無し}"
  fi
}

cmd_verify() {
  local new cur fails=0
  require_basics
  new=$(version_of_file "${CONFIG}")
  cur=$(version_of_link "${STATE}/current")
  if [ "${cur}" = "${new}" ]; then
    ok V1 "反映先の版が設定ファイルと同じ: ${new}"
  else
    ng V1 "反映先の版 ${cur:-無し} が設定ファイルの版 ${new} と違う"
    fails=1
  fi
  if [ -n "${cur}" ] && cmp -s "${STATE}/current/shop.conf" "${CONFIG}"; then
    ok V2 '反映先の中身が設定ファイルと同じ'
  else
    ng V2 '反映先の中身が設定ファイルと違う'
    fails=1
  fi
  if [ "${fails}" -ne 0 ]; then
    exit 1
  fi
  printf '確かめた: すべて期待どおり\n'
  printf '記録: shop の設定を反映した・版 %s・反映先 %s・時刻 %s\n' "${new}" "${STATE}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

cmd_status() {
  local cur prev
  require_basics
  cur=$(version_of_link "${STATE}/current")
  prev=$(version_of_link "${STATE}/previous")
  printf '今の版: %s\n' "${cur:-無し}"
  printf '前の版: %s\n' "${prev:-無し}"
}

cmd_rollback() {
  local cur prev
  require_basics
  cur=$(version_of_link "${STATE}/current")
  prev=$(version_of_link "${STATE}/previous")
  if [ -z "${prev}" ] || [ ! -f "${STATE}/releases/${prev}/shop.conf" ]; then
    ng B1 '戻す先の版が無い'
    exit 1
  fi
  ok B1 "戻す先の版がある: ${prev}"
  if [ "${cur}" = "${prev}" ]; then
    printf '変わっていない: すでに前の版 %s を使っている（何もしない）\n' "${prev}"
    exit 0
  fi
  printf '戻すと、今の版は %s になる。元に戻すときは、設定ファイルの版を apply する\n' "${prev}"
  op show ln -sfn "releases/${prev}" "${STATE}/current"
  if [ "${DRY}" -eq 1 ]; then
    printf '%s\n' '--dry-run なので何も変えていない'
    exit 0
  fi
  confirm '戻すなら yes と入力する: '
  op run ln -sfn "releases/${prev}" "${STATE}/current"
  printf '戻した: 版 %s（戻す前の版 %s）\n' "${prev}" "${cur:-無し}"
}

if [ "$#" -lt 1 ]; then
  usage
fi
NAME="$1"
shift
DRY=0
YES=0
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY=1 ;;
    --yes) YES=1 ;;
    *) usage ;;
  esac
done
case "${NAME}" in
  apply | rollback) ;;
  *)
    if [ "${DRY}" -eq 1 ] || [ "${YES}" -eq 1 ]; then
      usage
    fi
    ;;
esac

case "${NAME}" in
  check) cmd_check ;;
  diff) cmd_diff ;;
  apply) cmd_apply ;;
  verify) cmd_verify ;;
  status) cmd_status ;;
  rollback) cmd_rollback ;;
  *) usage ;;
esac
