# shellcheck shell=bash
# via-entry.sh — 既存の検査の verb を、入口 bin/oe 越しの呼び出しに差し替える口（テスト用・source して使う・#605 の T-9）
#
# OE_TEST_VIA_ENTRY=1 のときだけ働く。それ以外では何も変えず、渡した verb のパスをそのまま返す。
#
#   via_entry_verb <verb のパス> <一時ディレクトリ>
#       OE_TEST_VIA_ENTRY=1 なら、<一時ディレクトリ>/via-entry-<verb> に小さなスクリプトを作り、そのパスを出す。
#       スクリプトは呼ばれるたびに <一時ディレクトリ>/via-entry.log へ1行を足してから、同じ bin の入口 oe を
#       exec し、入口が oe-<verb> を exec する（プロセスは1段も増えない）。
#       それ以外なら <verb のパス> をそのまま出す。
#   via_entry_count <一時ディレクトリ>
#       入口越しに呼んだ回数を出す（口を有効にしたのに直の呼び出しが残って緑になるのを見分けるため）。
#
# 呼び出し元は、口を有効にした回の最後に via_entry_count が 0 でないことを確かめる。

via_entry_verb() {
  local path="${1:?}" tmp="${2:?}" bin name shim
  if [ "${OE_TEST_VIA_ENTRY:-}" != "1" ]; then
    printf '%s\n' "$path"
    return 0
  fi
  bin="$(cd "$(dirname "$path")" && pwd)"
  name="$(basename "$path")"
  name="${name#oe-}"
  shim="${tmp}/via-entry-${name}"
  {
    printf '#!/usr/bin/env bash\n'
    printf "printf '%%s\\\\n' %q >> %q\n" "$name" "${tmp}/via-entry.log"
    printf 'exec %q %q "$@"\n' "${bin}/oe" "$name"
  } > "$shim"
  chmod +x "$shim"
  printf '%s\n' "$shim"
}

via_entry_count() {
  local tmp="${1:?}"
  if [ -f "${tmp}/via-entry.log" ]; then
    wc -l < "${tmp}/via-entry.log" | tr -d ' '
  else
    printf '0\n'
  fi
}
