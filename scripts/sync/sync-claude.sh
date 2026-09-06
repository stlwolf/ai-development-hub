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

sync_mcp_servers() {
    local source_file="$1"
    local target_file="$2"
    local label="$3"

    info "Syncing ${label}: ${source_file} → ${target_file}"

    if [[ ! -f "$source_file" ]]; then
        warn "Source not found: ${source_file}"
        return
    fi

    if ! command -v jq &>/dev/null; then
        warn "jq not found — skipping MCP sync"
        return
    fi

    # claude.json の中身を mcpServers でラップして ~/.claude.json にマージ
    local mcp_servers
    mcp_servers=$(jq -c '.' "$source_file")

    if [[ -f "$target_file" ]]; then
        local backup
        backup="${target_file}.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$target_file" "$backup"
        info "  Backup: ${backup}"

        local tmp_file
        tmp_file="$(mktemp "${target_file}.tmp.XXXXXX")"
        if jq --argjson servers "$mcp_servers" '.mcpServers = (.mcpServers // {} | . * $servers)' "$target_file" > "$tmp_file"; then
            mv "$tmp_file" "$target_file"
        else
            rm -f "$tmp_file"
            error "  Failed to merge mcpServers into: $(basename "${target_file}")"
            return 1
        fi
    else
        jq -n --argjson servers "$mcp_servers" '{mcpServers: $servers}' > "$target_file"
        info "  Created: $(basename "${target_file}")"
    fi

    local count
    count=$(jq 'keys | length' "$source_file")
    info "  ${count} MCP server(s) synced"
}

apply_declared_settings() {
    local settings_target="$1"
    local apply_script="${SCRIPT_DIR}/apply-claude-settings.sh"

    info "Syncing declared settings → ${settings_target}"

    if [[ ! -x "${apply_script}" ]]; then
        error "  適用スクリプトが見つからないか実行できません: ${apply_script}"
        return 1
    fi

    # 素で呼ばない。main はトップレベルで走るので errexit が効き、子の非0で
    # sync 全体が止まる。適用できない相手（symlink・壊れた JSON）は子が 0 で
    # 返すので、ここで止まるのは本当に書けなかったときだけになる。
    local rc=0
    "${apply_script}" --settings "${settings_target}" || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        error "  設定の適用に失敗しました（rc=${rc}）"
        return 1
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

    # 2. Orchestration spec (cross-cutting spec; flat .md like rules)
    sync_md_files "${CANONICAL_DIR}/orchestration-spec" "${TARGET_BASE}/orchestration-spec" "orchestration-spec"
    echo ""

    # 3. Skills (directory symlinks, require SKILL.md)
    sync_dirs "${CANONICAL_DIR}/skills" "${TARGET_BASE}/skills" "skills" "SKILL.md"
    echo ""

    # 4. Agents
    sync_md_files "${CANONICAL_DIR}/agents" "${TARGET_BASE}/agents" "agents"
    echo ""

    # 5. Commands
    sync_md_files "${CANONICAL_DIR}/commands" "${TARGET_BASE}/commands" "commands"
    echo ""

    # 7. Hook scripts
    sync_hook_scripts "${CANONICAL_DIR}/hooks/scripts" "${TARGET_BASE}/hooks" "hook scripts"
    echo ""

    # 8. statusLine producer script (#239 PR-A: beat producer)
    sync_hook_scripts "${CANONICAL_DIR}/claude/statusline" "${TARGET_BASE}/statusline" "statusline scripts"
    echo ""

    # 9. Output styles（正本があるときだけ配る。有効化する鍵は宣言に入れていない）
    if [[ -d "${CANONICAL_DIR}/output-styles" ]]; then
        sync_md_files "${CANONICAL_DIR}/output-styles" "${TARGET_BASE}/output-styles" "output-styles"
        echo ""
    fi

    # 10. 宣言された設定項目を settings.json へ適用する
    #    hooks と statusLine を別々に読み書きしていたのをやめ、宣言（canonical/claude/
    #    settings.harness.json）に書かれた項目を1回の書き込みでまとめて当てる（#359）。
    #    参照するスクリプトを配り終えた後に置く。先に設定だけ書くと、初回の配布では
    #    まだ存在しないコマンドを指す設定が残り、途中で止まるとそれが居座る。
    apply_declared_settings "${TARGET_BASE}/settings.json"
    echo ""


    # 11. MCP servers (merge into ~/.claude.json)
    sync_mcp_servers "${CANONICAL_DIR}/mcp/claude.json" "${HOME}/.claude.json" "MCP servers"
    echo ""

    info "=== sync-claude complete ==="
}

main "$@"
