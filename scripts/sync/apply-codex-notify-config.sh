#!/usr/bin/env bash
#
# apply-codex-notify-config.sh
#
# Codex の通知設定を ~/.codex/config.toml に冪等適用する。
#
# config.toml は Codex が実行時に書き換える状態ファイルのため symlink 不可。
# dotfiles の symlink 運用にも乗らない。そこで「正本キーをハーネス側で管理し、
# 有無を検知して挿入する冪等 apply」とする（sync-codex.sh から呼ばれる）。
#
# 管理キー:
#   notify                  完了(agent-turn-complete)で notify.sh を起動（Claude と統一フォーマットの OSC 通知）
#   tui.notifications        入力待ち(approval-requested)を Codex ネイティブ OSC9 で通知
#   tui.notification_method  osc9（WezTerm が描画。notify は完了のみで入力待ちを拾えないため tui 併用）
#
# notify は top-level key のため最初のテーブルより前に置く。tui.* は super-table として末尾に追加。
#
# Usage:
#   ./scripts/sync/apply-codex-notify-config.sh [CONFIG_PATH]
#   CODEX_HOOKS_DIR=/path ./scripts/sync/apply-codex-notify-config.sh   # notify.sh の場所を上書き

set -uo pipefail

CONFIG="${1:-$HOME/.codex/config.toml}"
HOOKS_DIR="${CODEX_HOOKS_DIR:-$HOME/.codex/hooks}"
NOTIFY_LINE="notify = [\"bash\", \"${HOOKS_DIR}/notify.sh\"]"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

NOTIFY_BEGIN="# >>> ai-hub codex notify (managed) >>>"
NOTIFY_END="# <<< ai-hub codex notify (managed) <<<"
TUI_BEGIN="# >>> ai-hub codex tui-notify (managed) >>>"
TUI_END="# <<< ai-hub codex tui-notify (managed) <<<"

if [[ ! -f "$CONFIG" ]]; then
  warn "config.toml not found: ${CONFIG} (skip)"
  exit 0
fi

backup="${CONFIG}.bak.$(date +%Y%m%d-%H%M%S 2>/dev/null || echo manual)"
cp "$CONFIG" "$backup"
changed=0

# 1) notify (top-level key) → 無ければ先頭に挿入（最初のテーブルより前である必要があるため）
if grep -qE '^[[:space:]]*notify[[:space:]]*=' "$CONFIG"; then
  info "notify already present (skip)"
else
  tmp="$(mktemp)"
  {
    printf '%s\n%s\n%s\n\n' "$NOTIFY_BEGIN" "$NOTIFY_LINE" "$NOTIFY_END"
    cat "$CONFIG"
  } > "$tmp"
  mv "$tmp" "$CONFIG"
  changed=1
  info "Inserted notify at top"
fi

# 2) tui.notification_method → 無ければ [tui] super-table を末尾に追加
#    （既存の [tui.model_availability_nux] 等の subtable があっても super-table 後置は TOML 上有効）
if grep -qE '^[[:space:]]*notification_method[[:space:]]*=' "$CONFIG"; then
  info "tui.notification_method already present (skip)"
else
  {
    printf '\n%s\n' "$TUI_BEGIN"
    printf '[tui]\n'
    printf 'notifications = ["approval-requested"]\n'
    printf 'notification_method = "osc9"\n'
    printf '%s\n' "$TUI_END"
  } >> "$CONFIG"
  changed=1
  info "Appended [tui] notifications at bottom"
fi

# 3) TOML 検証（python3 tomllib があれば）。壊れていたら復元
if command -v python3 >/dev/null 2>&1 && python3 -c 'import tomllib' >/dev/null 2>&1; then
  if python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1],"rb"))' "$CONFIG" 2>/dev/null; then
    info "TOML parse OK"
  else
    warn "TOML parse failed after apply -> restoring backup"
    cp "$backup" "$CONFIG"
    exit 1
  fi
else
  warn "python3 tomllib 不在: TOML 検証はスキップ（codex doctor で確認推奨）"
fi

if [[ "$changed" -eq 0 ]]; then
  rm -f "$backup"
  info "No changes (already applied): ${CONFIG}"
else
  info "Applied to ${CONFIG} (backup: ${backup})"
fi
exit 0
