#!/bin/bash
#
# sync-claude.sh
#
# canonical/ → ~/.claude/{rules,skills,agents,commands} にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync/sync-claude.sh
#
# Description:
#   canonical/ 以下の rules, skills, agents, commands を
#   ~/.claude/ にシンボリックリンクとして配置します。
#
#   既にシンボリックリンクでないファイルが存在する場合はスキップします。
#
# Example:
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync/sync-claude.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CANONICAL_DIR="${REPO_ROOT}/canonical"
TARGET_BASE="${HOME}/.claude"

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

# .md ファイルをフラット配置
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

sync_hook_scripts() {
    local source_dir="$1"
    local target_dir="$2"
    local label="$3"

    info "Syncing ${label}: ${source_dir} → ${target_dir}"

    if [[ ! -d "${source_dir}" ]]; then
        warn "Source directory not found: ${source_dir}"
        return
    fi

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
        if [[ ! -x "${file}" ]]; then
            chmod +x "${file}" 2>/dev/null || warn "Failed to set executable bit (non-fatal): ${file}"
        fi
        info "  Linked: ${filename}"
        ((count++)) || true
    done < <(find "${source_dir}" -type f -name "*.sh" -print0)

    info "  ${count} ${label} symlink(s) created/updated"
}

sync_claude_hooks() {
    local hooks_source="$1"
    local settings_target="$2"
    local label="$3"

    info "Syncing ${label}: ${hooks_source} → ${settings_target}"

    if [[ ! -f "$hooks_source" ]]; then
        warn "Source not found: ${hooks_source}"
        return
    fi

    local hooks_json
    hooks_json=$(jq '.hooks' "$hooks_source")

    if [[ -f "$settings_target" && ! -L "$settings_target" ]]; then
        local backup
        backup="${settings_target}.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$settings_target" "$backup"
        info "  Backup: ${backup}"
        local tmp_settings
        tmp_settings="$(mktemp "${settings_target}.tmp.XXXXXX")"
        if jq --argjson hooks "$hooks_json" '.hooks = $hooks' "$settings_target" > "$tmp_settings"; then
            mv "$tmp_settings" "$settings_target"
        else
            rm -f "$tmp_settings"
            error "  Failed to merge hooks into: $(basename "${settings_target}")"
            return 1
        fi
        info "  Merged hooks into: $(basename "${settings_target}")"
    elif [[ ! -e "$settings_target" ]]; then
        mkdir -p "$(dirname "${settings_target}")"
        jq -n --argjson hooks "$hooks_json" '{hooks: $hooks}' > "$settings_target"
        info "  Created: $(basename "${settings_target}")"
    else
        warn "Skipping (symlink or special file): ${settings_target}"
    fi
}

main() {
    info "=== sync-claude: canonical → ~/.claude/ ==="
    echo ""

    if [[ ! -d "${CANONICAL_DIR}" ]]; then
        error "Canonical directory not found: ${CANONICAL_DIR}"
        exit 1
    fi

    # 1. Rules
    sync_md_files "${CANONICAL_DIR}/rules" "${TARGET_BASE}/rules" "rules"
    echo ""

    # 2. Skills (directory symlinks, require SKILL.md)
    sync_dirs "${CANONICAL_DIR}/skills" "${TARGET_BASE}/skills" "skills" "SKILL.md"
    echo ""

    # 3. Agents
    sync_md_files "${CANONICAL_DIR}/agents" "${TARGET_BASE}/agents" "agents"
    echo ""

    # 4. Commands
    sync_md_files "${CANONICAL_DIR}/commands" "${TARGET_BASE}/commands" "commands"
    echo ""

    # 5. Hooks config (merge into settings.json)
    sync_claude_hooks "${CANONICAL_DIR}/hooks/claude.hooks.json" "${TARGET_BASE}/settings.json" "hooks"
    echo ""

    # 6. Hook scripts
    sync_hook_scripts "${CANONICAL_DIR}/hooks/scripts" "${TARGET_BASE}/hooks" "hook scripts"
    echo ""

    info "=== sync-claude complete ==="
}

main "$@"
