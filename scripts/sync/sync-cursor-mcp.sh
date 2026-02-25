#!/bin/bash
#
# sync-cursor-mcp.sh
#
# ai-development-hub/cursor/mcp.json を
# ~/.cursor/mcp.json にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync-cursor-mcp.sh
#
# Description:
#   このスクリプトは ai-development-hub リポジトリの cursor/mcp.json を
#   ~/.cursor/mcp.json にシンボリックリンクとして配置します。
#
#   既存の通常ファイルがある場合は .bak にバックアップしてからリンクします。
#   既にシンボリックリンクの場合は上書きします。
#
# Example:
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync-cursor-mcp.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SOURCE_FILE="${REPO_ROOT}/cursor/mcp.json"
TARGET_FILE="${HOME}/.cursor/mcp.json"

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

main() {
    info "Source: ${SOURCE_FILE}"
    info "Target: ${TARGET_FILE}"
    echo ""

    if [[ ! -f "${SOURCE_FILE}" ]]; then
        error "Source file not found: ${SOURCE_FILE}"
        exit 1
    fi

    local target_dir
    target_dir="$(dirname "${TARGET_FILE}")"
    if [[ ! -d "${target_dir}" ]]; then
        info "Creating target directory: ${target_dir}"
        mkdir -p "${target_dir}"
    fi

    if [[ -e "${TARGET_FILE}" && ! -L "${TARGET_FILE}" ]]; then
        local backup="${TARGET_FILE}.bak"
        warn "Backing up existing file: ${TARGET_FILE} -> ${backup}"
        mv "${TARGET_FILE}" "${backup}"
    fi

    ln -sf "${SOURCE_FILE}" "${TARGET_FILE}"
    info "Linked: mcp.json -> ${SOURCE_FILE}"

    echo ""
    info "Done!"

    echo ""
    info "Current ~/.cursor/mcp.json status:"
    ls -la "${TARGET_FILE}"
}

main "$@"
