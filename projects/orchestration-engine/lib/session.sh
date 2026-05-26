# shellcheck shell=bash
# session.sh — セッション ID 生成（source 専用）

# oe_generate_session_id — 26 文字の ULID 風 ID を stdout に出力
#
# bin/oe / bin/oe-capture で共有（DI: spawn/monitor を source せずに id 生成するため lib 化）。
oe_generate_session_id() {
  local ts
  local raw
  local rand
  # 26 文字: 先頭 14 は数字（ULID 時刻部相当）、残り 12 は Crockford base32（I/L/O/U 除外）
  #
  # Copilot #4 反映: tr の出力を head -c で早期 close すると tr に SIGPIPE が飛び、
  # set -o pipefail 環境下で assignment が失敗する。固定バイト数を先に読んでから tr で
  # filter する形に変更 (パイプの早期 close を回避)。
  ts="$(date -u +%Y%m%d%H%M%S)"
  raw="$(LC_ALL=C head -c 4096 /dev/urandom | LC_ALL=C tr -dc '0-9A-HJKMNP-TV-Z')"
  rand="${raw:0:12}"
  printf '%s%s\n' "$ts" "$rand"
}
