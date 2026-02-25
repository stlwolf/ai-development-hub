#!/bin/bash
#
# sync-cursor-skills.sh
#
# ai-development-hub/cursor/skill/ 以下のスキルディレクトリを
# ~/.cursor/skills/ にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync-cursor-skills.sh
#
# Description:
#   cursor/skill/ 以下の各ディレクトリ（SKILL.md を含む）を
#   ~/.cursor/skills/ にシンボリックリンクとして配置します。
#
#   既にシンボリックリンクでないディレクトリが存在する場合はスキップします。
#
# Example:
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync-cursor-skills.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SOURCE_DIR="${REPO_ROOT}/cursor/skill"
TARGET_DIR="${HOME}/.cursor/skills"

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

    if [[ ! -d "${TARGET_DIR}" ]]; then
        info "Creating target directory: ${TARGET_DIR}"
        mkdir -p "${TARGET_DIR}"
    fi

    if [[ ! -d "${SOURCE_DIR}" ]]; then
        error "Source directory not found: ${SOURCE_DIR}"
        exit 1
    fi

    local count=0
    for skill_dir in "${SOURCE_DIR}"/*/; do
        [[ ! -d "${skill_dir}" ]] && continue
        [[ ! -f "${skill_dir}/SKILL.md" ]] && continue

        local dirname
        dirname="$(basename "$skill_dir")"
        local target_path="${TARGET_DIR}/${dirname}"

        if [[ -e "${target_path}" && ! -L "${target_path}" ]]; then
            warn "Skipping (regular directory exists): ${target_path}"
            continue
        fi

        ln -sfn "${skill_dir%/}" "${target_path}"
        info "Linked: ${dirname} -> ${skill_dir%/}"
        ((count++))
    done

    echo ""
    info "Done! ${count} symlink(s) created/updated."

    echo ""
    info "Current ~/.cursor/skills/ contents:"
    ls -la "${TARGET_DIR}"
}

main "$@"
