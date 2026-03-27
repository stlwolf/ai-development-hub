#!/bin/bash
#
# sync-codex.sh
#
# canonical/ + canonical/codex/ → ~/.codex/ にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync/sync-codex.sh
#
# Description:
#   canonical/skills/ を ~/.codex/skills/ に同期し、
#   canonical/codex/commands-registry/ を ~/.codex/commands-registry/ に同期します。
#
#   また canonical/agents/*.md から Codex 用の軽量定義（.toml）を生成し、
#   ~/.codex/agents/ に配置します。
#
#   既にシンボリックリンクでないディレクトリ/ファイルが存在する場合はスキップします。
#
# Example:
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync/sync-codex.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CANONICAL_DIR="${REPO_ROOT}/canonical"
CANONICAL_CODEX_DIR="${CANONICAL_DIR}/codex"
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
        ((count++)) || true
    done

    info "  ${count} ${label} symlink(s) created/updated"
}

# .md ファイルをフラット配置
sync_md_files() {
    local source_dir="$1"
    local target_dir="$2"
    local label="$3"

    if [[ ! -d "${source_dir}" ]]; then
        warn "Skipping ${label} (source not found): ${source_dir}"
        return
    fi

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

toml_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

extract_frontmatter_value() {
    local file="$1"
    local key="$2"
    awk -v key="$key" '
        NR == 1 && $0 == "---" { in_fm = 1; next }
        in_fm && $0 == "---" { exit }
        in_fm && $0 ~ "^" key ":[[:space:]]*" {
            sub("^" key ":[[:space:]]*", "", $0)
            gsub(/^"|"$/, "", $0)
            print $0
            exit
        }
    ' "$file"
}

generate_codex_agents() {
    local source_dir="$1"
    local target_dir="$2"

    if [[ ! -d "${source_dir}" ]]; then
        warn "Skipping agents generation (source not found): ${source_dir}"
        return
    fi

    info "Generating codex agents: ${source_dir} → ${target_dir}"
    mkdir -p "${target_dir}"

    local count=0
    local file
    while IFS= read -r -d '' file; do
        local base filename name description
        base="$(basename "$file")"
        filename="${base%.md}"
        name="$(extract_frontmatter_value "$file" "name")"
        description="$(extract_frontmatter_value "$file" "description")"
        [[ -z "${name}" ]] && name="${filename}"
        [[ -z "${description}" ]] && description="Generated from canonical/agents/${base}"

        local name_escaped desc_escaped path_escaped target_toml
        name_escaped="$(toml_escape "${name}")"
        desc_escaped="$(toml_escape "${description}")"
        path_escaped="$(toml_escape "${file}")"
        target_toml="${target_dir}/${filename}.toml"

        if [[ -L "${target_toml}" ]]; then
            warn "Skipping (symlink exists): ${target_toml}"
            continue
        fi

        # Generated agent definitions are owned by this sync script, so regular files are refreshed.
        cat > "${target_toml}" <<EOF
name = "${name_escaped}"
description = "${desc_escaped}"
instruction_file = "${path_escaped}"
EOF
        info "  Generated: ${filename}.toml"
        ((count++)) || true
    done < <(find "${source_dir}" -type f -name "*.md" -print0)

    info "  ${count} codex agent definition(s) generated"
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

    # Codex pseudo command registry
    sync_md_files "${CANONICAL_CODEX_DIR}/commands-registry" "${TARGET_BASE}/commands-registry" "commands-registry"
    echo ""

    # Codex agents generated from canonical/agents
    generate_codex_agents "${CANONICAL_DIR}/agents" "${TARGET_BASE}/agents"
    echo ""

    info "=== sync-codex complete ==="
}

main "$@"
