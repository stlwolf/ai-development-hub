#!/usr/bin/env bash
#
# sync-bin.sh
#
# ai-development-hub のスクリプトを ~/bin/ にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync/sync-bin.sh
#
# Description:
#   so-compare.sh, arena-compare.sh, wez 等のスクリプトを
#   ~/bin/ にシンボリックリンクとして配置します。
#   リンク名は拡張子なし（so-compare, arena-compare）または
#   元のファイル名のまま（wez）になります。
#
#   既にシンボリックリンクでないファイルが存在する場合はスキップします。
#
# Example:
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync/sync-bin.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TARGET_DIR="${HOME}/bin"

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

CMD_NAMES=("so-compare" "arena-compare" "wez" "wt-pane-issue" "oe-tree" "validate-knowledge" "knowledge-list")
CMD_SOURCES=(
    "${REPO_ROOT}/scripts/so-compare.sh"
    "${REPO_ROOT}/projects/arena-compare/arena-compare.sh"
    "${REPO_ROOT}/projects/wezterm-ai-mode/bin/wez"
    "${REPO_ROOT}/scripts/wt/wt-pane-issue.sh"
    "${REPO_ROOT}/projects/orchestration-engine/bin/oe-tree"
    "${REPO_ROOT}/projects/orchestration-engine/scripts/validate-knowledge.sh"
    "${REPO_ROOT}/projects/orchestration-engine/scripts/knowledge-list.sh"
)

main() {
    info "Target: ${TARGET_DIR}"
    echo ""

    if [[ ! -d "${TARGET_DIR}" ]]; then
        info "Creating target directory: ${TARGET_DIR}"
        mkdir -p "${TARGET_DIR}"
    fi

    local count=0
    for i in "${!CMD_NAMES[@]}"; do
        local cmd_name="${CMD_NAMES[$i]}"
        local source_path="${CMD_SOURCES[$i]}"
        local target_path="${TARGET_DIR}/${cmd_name}"

        if [[ ! -f "${source_path}" ]]; then
            error "Source not found: ${source_path}"
            continue
        fi

        if [[ -e "${target_path}" && ! -L "${target_path}" ]]; then
            warn "Skipping (regular file exists): ${target_path}"
            continue
        fi

        ln -sfn "${source_path}" "${target_path}"
        info "Linked: ${cmd_name} -> ${source_path}"
        count=$((count + 1))
    done

    echo ""
    info "Done! ${count} symlink(s) created/updated."

    echo ""
    info "Verify:"
    for cmd_name in "${CMD_NAMES[@]}"; do
        if command -v "${cmd_name}" &>/dev/null; then
            info "  ${cmd_name}: $(command -v "${cmd_name}")"
        else
            warn "  ${cmd_name}: not in PATH"
        fi
    done
}

main "$@"
