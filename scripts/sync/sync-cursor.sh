#!/bin/bash
#
# sync-cursor.sh
#
# canonical/ + cursor/ → ~/.cursor/ にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync/sync-cursor.sh
#
# Description:
#   canonical/ 以下の commands, skills, agents を ~/.cursor/ に配置します。
#   Cursor 固有ファイル (mcp.json, archive-title) も合わせて配置します。
#
#   既にシンボリックリンクでないファイルが存在する場合はスキップします。
#
# Example:
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync/sync-cursor.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CANONICAL_DIR="${REPO_ROOT}/canonical"
CURSOR_DIR="${REPO_ROOT}/cursor"
TARGET_BASE="${HOME}/.cursor"

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

# .md ファイルをフラット配置（サブディレクトリ構造 → ファイル名のみ）
sync_md_files() {
    local source_dir="$1"
    local target_dir="$2"
    local label="$3"

    info "Syncing ${label}: ${source_dir} → ${target_dir}"
    mkdir -p "${target_dir}"

    local count=0
    while IFS= read -r -d '' file; do
        local filename
        filename="$(basename "$file")"
        local target_path="${target_dir}/${filename}"

        if [[ -e "${target_path}" && ! -L "${target_path}" ]]; then
            warn "Skipping (regular file exists): ${target_path}"
            continue
        fi

        ln -sf "${file}" "${target_path}"
        info "  Linked: ${filename}"
        ((count++)) || true
    done < <(find "${source_dir}" -type f -name "*.md" -print0)

    info "  ${count} ${label} symlink(s) created/updated"
}

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
        ((count++)) || true
    done

    info "  ${count} ${label} symlink(s) created/updated"
}

# 単一ファイルのシンリンク（mcp.json 用）
sync_single_file() {
    local source_file="$1"
    local target_path="$2"
    local label="$3"

    info "Syncing ${label}: ${source_file} → ${target_path}"

    if [[ ! -f "${source_file}" ]]; then
        warn "Source not found: ${source_file}"
        return
    fi

    if [[ -e "${target_path}" && ! -L "${target_path}" ]]; then
        local backup="${target_path}.bak"
        warn "Regular file exists: ${target_path} → backing up to ${backup}"
        mv "${target_path}" "${backup}"
    fi

    mkdir -p "$(dirname "${target_path}")"
    ln -sf "${source_file}" "${target_path}"
    info "  Linked: $(basename "${target_path}")"
}

main() {
    info "=== sync-cursor: canonical + cursor-specific → ~/.cursor/ ==="
    echo ""

    if [[ ! -d "${CANONICAL_DIR}" ]]; then
        error "Canonical directory not found: ${CANONICAL_DIR}"
        exit 1
    fi

    # 1. Commands (canonical + Cursor-only)
    sync_md_files "${CANONICAL_DIR}/commands" "${TARGET_BASE}/commands" "commands"
    # Cursor-only: archive-title
    if [[ -f "${CURSOR_DIR}/command/thread/archive-title.md" ]]; then
        local target_path="${TARGET_BASE}/commands/archive-title.md"
        if [[ ! -e "${target_path}" || -L "${target_path}" ]]; then
            ln -sf "${CURSOR_DIR}/command/thread/archive-title.md" "${target_path}"
            info "  Linked: archive-title.md (Cursor-only)"
        fi
    fi
    echo ""

    # 2. Skills (directory symlinks, require SKILL.md)
    sync_dirs "${CANONICAL_DIR}/skills" "${TARGET_BASE}/skills" "skills" "SKILL.md"
    echo ""

    # 3. Agents
    sync_md_files "${CANONICAL_DIR}/agents" "${TARGET_BASE}/agents" "agents"
    echo ""

    # 4. MCP config (Cursor-specific)
    sync_single_file "${CURSOR_DIR}/mcp.json" "${TARGET_BASE}/mcp.json" "mcp.json"
    echo ""

    info "=== sync-cursor complete ==="
}

main "$@"
