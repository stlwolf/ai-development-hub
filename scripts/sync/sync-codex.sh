#!/bin/bash
#
# sync-codex.sh
#
# canonical/ → ~/.codex/skills/ にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync/sync-codex.sh
#
# Description:
#   canonical/skills/ 以下のスキルディレクトリを
#   ~/.codex/skills/ にシンボリックリンクとして配置します。
#
#   Codex の設定体系が拡張され次第、agents/commands/rules も追加予定。
#
#   既にシンボリックリンクでないディレクトリが存在する場合はスキップします。
#
# Example:
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync/sync-codex.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CANONICAL_DIR="${REPO_ROOT}/canonical"
TARGET_BASE="${HOME}/.codex"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    sed -n '/^# Usage:/,/^set -euo pipefail/p' "$0" | head -n -1 | sed 's/^# \?//'
    exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

# ディレクトリ単位でシンリンク（skills 用）
sync_dirs() {
    local source_dir="$1"
    local target_dir="$2"
    local label="$3"
    local marker_file="${4:-}"

    info "Syncing ${label}: ${source_dir} → ${target_dir}"
    mkdir -p "${target_dir}"

    local count=0
    for item_dir in "${source_dir}"/*/; do
        [[ ! -d "${item_dir}" ]] && continue
        if [[ -n "${marker_file}" && ! -f "${item_dir}/${marker_file}" ]]; then
            continue
        fi

        local dirname
        dirname="$(basename "$item_dir")"
        local target_path="${target_dir}/${dirname}"

        if [[ -e "${target_path}" && ! -L "${target_path}" ]]; then
            warn "Skipping (regular directory exists): ${target_path}"
            continue
        fi

        ln -sfn "${item_dir%/}" "${target_path}"
        info "  Linked: ${dirname}"
        ((count++))
    done

    info "  ${count} ${label} symlink(s) created/updated"
}

main() {
    info "=== sync-codex: canonical → ~/.codex/ ==="
    echo ""

    if [[ ! -d "${CANONICAL_DIR}" ]]; then
        error "Canonical directory not found: ${CANONICAL_DIR}"
        exit 1
    fi

    # Skills (directory symlinks, require SKILL.md)
    sync_dirs "${CANONICAL_DIR}/skills" "${TARGET_BASE}/skills" "skills" "SKILL.md"
    echo ""

    info "=== sync-codex complete ==="
}

main "$@"
