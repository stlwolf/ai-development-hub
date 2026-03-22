#!/bin/bash
#
# sync-claude-rules.sh
#
# ai-development-hub/cursor/user-rules/*.md を
# ~/.claude/rules/ にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync/sync-claude-rules.sh
#
# Description:
#   cursor/user-rules/ 以下の .md ファイルを
#   ~/.claude/rules/ にシンボリックリンクとして配置します。
#
#   既にシンボリックリンクでないファイルが存在する場合はスキップします。
#
# Example:
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync/sync-claude-rules.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SOURCE_DIR="${REPO_ROOT}/cursor/user-rules"
TARGET_DIR="${HOME}/.claude/rules"

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
    info "Source: ${SOURCE_DIR}"
    info "Target: ${TARGET_DIR}"
    echo ""

    if [[ ! -d "${SOURCE_DIR}" ]]; then
        error "Source directory not found: ${SOURCE_DIR}"
        exit 1
    fi

    if [[ ! -d "${TARGET_DIR}" ]]; then
        info "Creating target directory: ${TARGET_DIR}"
        mkdir -p "${TARGET_DIR}"
    fi

    local count=0
    for rule_file in "${SOURCE_DIR}"/*.md; do
        [[ ! -f "${rule_file}" ]] && continue

        local filename
        filename="$(basename "$rule_file")"
        local target_path="${TARGET_DIR}/${filename}"

        if [[ -e "${target_path}" && ! -L "${target_path}" ]]; then
            warn "Skipping (regular file exists): ${target_path}"
            continue
        fi

        ln -sf "${rule_file}" "${target_path}"
        info "Linked: ${filename} -> ${rule_file}"
        ((count++))
    done

    echo ""
    info "Done! ${count} symlink(s) created/updated in ${TARGET_DIR}"
    echo ""
    info "Contents of ${TARGET_DIR}:"
    ls -la "${TARGET_DIR}"
}

main "$@"
