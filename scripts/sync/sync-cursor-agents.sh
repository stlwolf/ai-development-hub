#!/bin/bash
#
# sync-cursor-agents.sh
#
# ai-development-hub/cursor/agents/ 以下のファイルを
# ~/.cursor/agents/ にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync-cursor-agents.sh
#
# Description:
#   このスクリプトは ai-development-hub リポジトリの cursor/agents/ 以下にある
#   .md ファイルを ~/.cursor/agents/ にシンボリックリンクとして配置します。
#
#   シンボリックリンクを使用することで、どちら側から編集しても同じファイルが
#   変更され、リポジトリ側でバージョン管理できます。
#
#   個人用サブエージェント（リポジトリに含めたくないもの）は
#   ~/.cursor/agents/ に直接通常ファイルとして配置してください。
#   スクリプトは通常ファイルをスキップします。
#
# Example:
#   # 初回セットアップ
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync-cursor-agents.sh
#
#   # リポジトリにサブエージェントを追加した後
#   ./scripts/sync-cursor-agents.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SOURCE_DIR="${REPO_ROOT}/cursor/agents"
TARGET_DIR="${HOME}/.cursor/agents"

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
    while IFS= read -r -d '' file; do
        local filename
        filename="$(basename "$file")"
        local target_path="${TARGET_DIR}/${filename}"

        if [[ -e "${target_path}" && ! -L "${target_path}" ]]; then
            warn "Skipping (regular file exists): ${target_path}"
            continue
        fi

        ln -sf "${file}" "${target_path}"
        info "Linked: ${filename} -> ${file}"
        ((count++))
    done < <(find "${SOURCE_DIR}" -type f -name "*.md" -print0)

    echo ""
    info "Done! ${count} symlink(s) created/updated."

    echo ""
    info "Current ~/.cursor/agents/ contents:"
    ls -la "${TARGET_DIR}"
}

main "$@"
