#!/usr/bin/env bash
# 架空のサービス shop の設定ファイルを、反映先へ反映する（見本）。
#
# 使い方: scripts/shop-config.sh <名前> [--dry-run] [--yes]
#   check     前提を確かめる（何も変えない）
#   diff      反映先の今の版と、設定ファイルの差分を出す（何も変えない）
#   apply     設定ファイルを反映する（変える。--dry-run と --yes を受ける）
#   verify    反映のあとを確かめ、記録の行を出す（何も変えない）
#   status    反映先の今の版と前の版を出す（何も変えない）
#   rollback  前の版に戻す（変える。--dry-run と --yes を受ける）
#
# 終了コード:
#   0 期待どおりに終わった（変える名前なら、変えたか、もともと同じで何もしなかった）
#   1 止まった（確かめが外れたか、確認で断った）。何も変えていない
#   2 呼び方の誤りか、前提が足りない（依存・資格情報・端末が無い）。何も変えていない
#   3 変える途中で失敗した。変わったかもしれない
#
# 反映先は環境変数 SHOP_STATE_DIR で決める。無ければ ${TMPDIR:-/tmp}/shop-example-state を使う。
# 資格情報 SHOP_TOKEN は長さだけを確かめる。値は画面に出さず、どこにも送らない。
set -euo pipefail

# 実行する場所に頼らず、自分の置き場所からリポジトリの一番上を決める
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG="${ROOT}/config/shop.conf"
STATE="${SHOP_STATE_DIR:-${TMPDIR:-/tmp}/shop-example-state}"
STATE="${STATE%/}"
export TZ=UTC
KEY_RE='^[a-z][a-z0-9_.]*='

usage() {
  printf '使い方: scripts/shop-config.sh check|diff|apply|verify|status|rollback [--dry-run] [--yes]\n' >&2
  exit 2
}

ok() { printf 'OK %s %s\n' "$1" "$2"; }
ng() { printf 'NG %s %s\n' "$1" "$2"; }

# 設定ファイルの中身から作る12桁の版
version_of_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -c1-12
  else
    shasum -a 256 "$1" | cut -c1-12
  fi
}

# 反映先のリンクが指す版。リンクが無ければ空
version_of_link() {
  if [ -L "$1" ]; then
    basename "$(readlink "$1")"
  fi
}

# 設定ファイルの形の誤りを1つ出す。誤りが無ければ何も出さない
config_problem() {
  if [ ! -f "${CONFIG}" ]; then
    printf '設定ファイルが無い: %s' "${CONFIG}"
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

# 2つの設定ファイルで、値が変わる・足される・消されるキー
changed_keys() {
  local keys
  keys=$(
    {
      grep -Fxv -f "$1" "${CONFIG}" || true
      grep -Fxv -f "${CONFIG}" "$1" || true
    } | { grep -E "${KEY_RE}" || true; } | sed 's/=.*//' | sort -u | tr '\n' ' '
  )
  keys="${keys% }"
  printf '%s' "${keys:-無い}"
}

# 前提の確かめ。C1〜C3 が外れたら 2、C4 が外れたら 1 を返す。何も変えない
check_prereq() {
  local worst=0 parent bad
  if command -v diff >/dev/null 2>&1 && command -v cmp >/dev/null 2>&1 &&
    { command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1; }; then
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
  parent="${STATE}"
  while [ ! -e "${parent}" ]; do
    parent=$(dirname "${parent}")
  done
  if [ -d "${parent}" ] && [ -w "${parent}" ]; then
    ok C3 "反映先に書ける: ${STATE}"
  else
    ng C3 "反映先に書けない: ${STATE}"
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

apply_ops() {
  local mode="$1" new="$2" cur="$3"
  op "${mode}" mkdir -p "${STATE}/releases/${new}"
  op "${mode}" cp "${CONFIG}" "${STATE}/releases/${new}/shop.conf"
  if [ -n "${cur}" ]; then
    op "${mode}" ln -sfn "releases/${cur}" "${STATE}/previous"
  fi
  op "${mode}" ln -sfn "releases/${new}" "${STATE}/current"
}

rollback_ops() {
  local mode="$1" cur="$2" prev="$3"
  op "${mode}" ln -sfn "releases/${prev}" "${STATE}/current"
  op "${mode}" ln -sfn "releases/${cur}" "${STATE}/previous"
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
  local cur old rc=0
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
    printf '差分を出せなかった\n' >&2
    exit 2
  fi
  printf '変わるキー: %s\n' "$(changed_keys "${old}")"
}

cmd_apply() {
  local rc=0 new cur old
  check_prereq || rc=$?
  if [ "${rc}" -ne 0 ]; then
    printf '前提が満たされていないので止めた（何も変えていない）\n'
    exit "${rc}"
  fi
  new=$(version_of_file "${CONFIG}")
  cur=$(version_of_link "${STATE}/current")
  if [ "${new}" = "${cur}" ]; then
    printf '変わっていない: 版 %s はすでに反映先にある（何もしない）\n' "${new}"
    exit 0
  fi
  old="${STATE}/current/shop.conf"
  if [ -z "${cur}" ]; then
    old=/dev/null
  fi
  printf '変わるキー: %s\n' "$(changed_keys "${old}")"
  if [ -n "${cur}" ]; then
    printf '戻し方: scripts/shop-config.sh rollback（今の版 %s に戻る）\n' "${cur}"
  else
    printf '戻し方: はじめての反映なので、戻す先の版は無い\n'
  fi
  apply_ops show "${new}" "${cur}"
  if [ "${DRY}" -eq 1 ]; then
    printf '%s\n' '--dry-run なので何も変えていない'
    exit 0
  fi
  confirm '反映するなら yes と入力する: '
  apply_ops run "${new}" "${cur}"
  printf '反映した: 版 %s（前の版 %s）\n' "${new}" "${cur:-無し}"
}

cmd_verify() {
  local new cur fails=0
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
  cur=$(version_of_link "${STATE}/current")
  prev=$(version_of_link "${STATE}/previous")
  printf '今の版: %s\n' "${cur:-無し}"
  printf '前の版: %s\n' "${prev:-無し}"
}

cmd_rollback() {
  local cur prev
  cur=$(version_of_link "${STATE}/current")
  prev=$(version_of_link "${STATE}/previous")
  if [ -z "${prev}" ] || [ ! -d "${STATE}/releases/${prev}" ]; then
    ng B1 '戻す先の版が無い'
    exit 1
  fi
  ok B1 "戻す先の版がある: ${prev}"
  printf '戻すと、今の版 %s が前の版になる\n' "${cur}"
  rollback_ops show "${cur}" "${prev}"
  if [ "${DRY}" -eq 1 ]; then
    printf '%s\n' '--dry-run なので何も変えていない'
    exit 0
  fi
  confirm '戻すなら yes と入力する: '
  rollback_ops run "${cur}" "${prev}"
  printf '戻した: 版 %s（戻す前の版 %s）\n' "${prev}" "${cur}"
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
