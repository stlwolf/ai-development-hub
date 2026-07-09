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

sync_claude_statusline() {
    local statusline_source="$1"
    local settings_target="$2"
    local label="$3"

    info "Syncing ${label}: ${statusline_source} → ${settings_target}"

    if [[ ! -f "$statusline_source" ]]; then
        warn "Source not found: ${statusline_source}"
        return
    fi

    if ! command -v jq &>/dev/null; then
        warn "jq not found — skipping statusLine sync"
        return
    fi

    # 配布したい statusLine オブジェクト（type / command / refreshInterval）と、その command（=beat producer）。
    local desired our_cmd marker
    desired=$(jq -c '.statusLine' "$statusline_source")
    our_cmd=$(jq -r '.statusLine.command' "$statusline_source")
    # beat producer 判定は $HOME リテラルや quote に依存しない安定 basename で行う（$HOME 展開・絶対パス化・
    # wrap 済みのいずれでも既存を beat producer と認識でき、再 sync 時の二重 wrap を防ぐ）。
    marker="statusline-oe-heartbeat.sh"

    # settings.json が無ければ statusLine のみで新規作成。
    if [[ ! -e "$settings_target" ]]; then
        mkdir -p "$(dirname "${settings_target}")"
        jq -n --argjson sl "$desired" '{statusLine: $sl}' > "$settings_target"
        info "  Created: $(basename "${settings_target}") (statusLine installed)"
        return
    fi

    # symlink / 通常ファイル以外（dir/fifo 等）は触らない（hooks merge と同じ姿勢・-f で守る）。
    if [[ -L "$settings_target" || ! -f "$settings_target" ]]; then
        warn "Skipping (symlink or non-regular file): ${settings_target}"
        return
    fi

    local backup existing_cmd tmp_settings
    backup="${settings_target}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$settings_target" "$backup"
    info "  Backup: ${backup}"

    existing_cmd=$(jq -r '.statusLine.command // ""' "$settings_target")
    tmp_settings="$(mktemp "${settings_target}.tmp.XXXXXX")"

    # 非破壊 merge（Q4）:
    #   - statusLine 未設定           → beat producer を設定。
    #   - 既に beat producer（wrap 済含む・our_cmd を含む）→ command は保持し type/refreshInterval のみ更新（二重 wrap 防止）。
    #   - ユーザー独自 statusLine      → 表示を壊さず wrap: 元コマンドを OE_HEARTBEAT_WRAP_CMD へ退避し、
    #                                     beat producer 経由で call-through する（beat は side-effect で合成）。
    # いずれの分岐も既存 statusLine の他フィールド（padding / hideVimModeIndicator 等）を保持したまま
    # desired（type / command / refreshInterval）を上書き overlay する（(.statusLine // {}) を土台にする）。
    local jq_ok=1
    if [[ -z "$existing_cmd" ]]; then
        jq --argjson sl "$desired" '.statusLine = ((.statusLine // {}) + $sl)' "$settings_target" > "$tmp_settings" || jq_ok=0
        [[ "$jq_ok" == "1" ]] && info "  Merged statusLine (beat producer installed)"
    elif [[ "$existing_cmd" == *"$marker"* ]]; then
        # command 文字列は既存を保持（wrap 済みなら wrap を維持＝二重 wrap 防止）。他フィールドは desired で更新。
        jq --argjson sl "$desired" '.statusLine = ((.statusLine // {}) + $sl + {command: .statusLine.command})' "$settings_target" > "$tmp_settings" || jq_ok=0
        [[ "$jq_ok" == "1" ]] && info "  Refreshed statusLine (beat producer already present)"
    else
        local wrapped
        wrapped="OE_HEARTBEAT_WRAP_CMD=$(printf '%q' "$existing_cmd") ${our_cmd}"
        jq --argjson sl "$desired" --arg wc "$wrapped" '.statusLine = ((.statusLine // {}) + $sl + {command: $wc})' "$settings_target" > "$tmp_settings" || jq_ok=0
        [[ "$jq_ok" == "1" ]] && info "  Wrapped existing statusLine (display preserved · beat added)"
    fi

    if [[ "$jq_ok" == "1" ]]; then
        mv "$tmp_settings" "$settings_target"
    else
        rm -f "$tmp_settings"
        error "  Failed to merge statusLine into: $(basename "${settings_target}")"
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

    # 7. statusLine producer script (#239 PR-A: beat producer)
    sync_hook_scripts "${CANONICAL_DIR}/statusline" "${TARGET_BASE}/statusline" "statusline scripts"
    echo ""

    # 8. statusLine config (non-destructive merge into settings.json)
    sync_claude_statusline "${CANONICAL_DIR}/statusline/claude.statusline.json" "${TARGET_BASE}/settings.json" "statusLine"
    echo ""

    # 9. MCP servers (merge into ~/.claude.json)
    sync_mcp_servers "${CANONICAL_DIR}/mcp/claude.json" "${HOME}/.claude.json" "MCP servers"
    echo ""

    info "=== sync-claude complete ==="
}

main "$@"
