#!/bin/bash
#
# sync.sh — 統合 sync ランナー
#
# canonical/ から各ツール設定ディレクトリへのシンボリックリンク配置を一括実行する
#
# Usage:
#   ./scripts/sync.sh                  # 全ターゲット実行
#   ./scripts/sync.sh cursor           # cursor のみ
#   ./scripts/sync.sh claude codex     # 複数指定
#   ./scripts/sync.sh --cursor --bin   # フラグ形式も可
#   ./scripts/sync.sh --list           # 利用可能ターゲット一覧
#   ./scripts/sync.sh --check          # 全ターゲットの整合チェック
#   ./scripts/sync.sh --check cursor   # cursor のみチェック
#
# Available targets:
#   cursor  — canonical + cursor-specific → ~/.cursor/
#   claude  — canonical → ~/.claude/
#   codex   — canonical → ~/.codex/
#   bin     — projects binaries → ~/bin/
#
# Example:
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_DIR="${SCRIPT_DIR}/sync"

ALL_TARGETS=(cursor claude codex bin)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
header() { echo -e "${CYAN}━━━ $1 ━━━${NC}"; }

usage() {
    sed -n '/^# Usage:/,/^set -euo pipefail/p' "$0" | head -n -1 | sed 's/^# \?//'
    exit 0
}

list_targets() {
    info "Available targets:"
    for target in "${ALL_TARGETS[@]}"; do
        local script="${SYNC_DIR}/sync-${target}.sh"
        if [[ -x "${script}" ]]; then
            echo "  ${target}"
        else
            echo "  ${target} (not found)"
        fi
    done
    exit 0
}

resolve_path() {
    if command -v realpath &>/dev/null; then
        realpath "$1" 2>/dev/null
    elif command -v python3 &>/dev/null; then
        python3 -c "import os; print(os.path.realpath('$1'))" 2>/dev/null
    else
        echo "$1"
    fi
}

check_symlink() {
    local target="$1" expected_source="$2" label="$3"
    local diffs_ref="$4"

    if [[ ! -e "${target}" ]]; then
        warn "  Missing: ${label} → ${target}"
        eval "${diffs_ref}=true"
        return
    fi

    if [[ -L "${target}" ]]; then
        local actual_source
        actual_source="$(resolve_path "${target}")"
        local canonical_source
        canonical_source="$(resolve_path "${expected_source}")"
        if [[ "${actual_source}" != "${canonical_source}" ]]; then
            warn "  Mismatch: ${label}"
            warn "    expected: ${canonical_source}"
            warn "    actual:   ${actual_source}"
            eval "${diffs_ref}=true"
        fi
    else
        if ! diff -q "${expected_source}" "${target}" &>/dev/null; then
            warn "  Content differs: ${label} (not a symlink)"
            eval "${diffs_ref}=true"
        fi
    fi
}

check_symlinks_dir() {
    local source_dir="$1" target_dir="$2" pattern="$3" label="$4"
    local diffs_ref="$5"

    if [[ ! -d "${source_dir}" ]]; then
        return
    fi

    while IFS= read -r -d '' file; do
        local filename
        filename="$(basename "$file")"
        check_symlink "${target_dir}/${filename}" "${file}" "${label}/${filename}" "${diffs_ref}"
    done < <(find "${source_dir}" -maxdepth 1 -type f -name "${pattern}" -print0 2>/dev/null)
}

check_skill_dirs() {
    local source_dir="$1" target_dir="$2" label="$3"
    local diffs_ref="$4"

    for item_dir in "${source_dir}"/*/; do
        [[ ! -d "${item_dir}" ]] && continue
        [[ ! -f "${item_dir}/SKILL.md" ]] && continue
        local dirname
        dirname="$(basename "$item_dir")"
        check_symlink "${target_dir}/${dirname}" "${item_dir%/}" "${label}/${dirname}" "${diffs_ref}"
    done
}

check_target() {
    local target="$1"
    local repo_root
    repo_root="$(cd "$(dirname "$0")/.." && pwd)"
    local canonical="${repo_root}/canonical"
    local has_diffs=false

    header "check-${target}"

    case "${target}" in
        cursor)
            local base="${HOME}/.cursor"
            check_symlinks_dir "${canonical}/commands" "${base}/commands" "*.md" "commands" has_diffs
            check_skill_dirs "${canonical}/skills" "${base}/skills" "skills" has_diffs
            check_symlinks_dir "${canonical}/agents" "${base}/agents" "*.md" "agents" has_diffs
            check_symlink "${base}/mcp.json" "${canonical}/mcp/cursor.json" "mcp.json" has_diffs
            check_symlink "${base}/hooks.json" "${canonical}/hooks/cursor.hooks.json" "hooks.json" has_diffs
            check_symlinks_dir "${canonical}/hooks/scripts" "${base}/hooks" "*.sh" "hook-scripts" has_diffs
            ;;
        claude)
            local base="${HOME}/.claude"
            check_symlinks_dir "${canonical}/rules" "${base}/rules" "*.md" "rules" has_diffs
            check_skill_dirs "${canonical}/skills" "${base}/skills" "skills" has_diffs
            check_symlinks_dir "${canonical}/agents" "${base}/agents" "*.md" "agents" has_diffs
            check_symlinks_dir "${canonical}/commands" "${base}/commands" "*.md" "commands" has_diffs
            check_symlinks_dir "${canonical}/hooks/scripts" "${base}/hooks" "*.sh" "hook-scripts" has_diffs
            if [[ -f "${base}/settings.json" ]]; then
                local expected_hooks actual_hooks
                expected_hooks="$(jq -S '.hooks' "${canonical}/hooks/claude.hooks.json" 2>/dev/null)"
                actual_hooks="$(jq -S '.hooks' "${base}/settings.json" 2>/dev/null)"
                if [[ "${expected_hooks}" != "${actual_hooks}" ]]; then
                    warn "  Hooks section differs in settings.json"
                    has_diffs=true
                fi
            fi
            ;;
        codex)
            local base="${HOME}/.codex"
            check_skill_dirs "${canonical}/skills" "${base}/skills" "skills" has_diffs
            check_symlink "${base}/AGENTS.md" "${canonical}/codex/AGENTS.md" "AGENTS.md" has_diffs
            check_symlink "${base}/hooks.json" "${canonical}/hooks/codex.hooks.json" "hooks.json" has_diffs
            check_symlinks_dir "${canonical}/hooks/scripts" "${base}/hooks" "*.sh" "hook-scripts" has_diffs
            ;;
        bin)
            local base="${HOME}/bin"
            local so_compare="${repo_root}/scripts/so-compare.sh"
            local arena_compare="${repo_root}/projects/arena-compare/arena-compare.sh"
            [[ -f "${so_compare}" ]] && check_symlink "${base}/so-compare" "${so_compare}" "so-compare" has_diffs
            [[ -f "${arena_compare}" ]] && check_symlink "${base}/arena-compare" "${arena_compare}" "arena-compare" has_diffs
            ;;
    esac

    if [[ "${has_diffs}" == true ]]; then
        error "  ${target}: diffs found"
        echo ""
        return 1
    fi

    info "  ${target}: up to date"
    echo ""
    return 0
}

run_target() {
    local target="$1"
    local script="${SYNC_DIR}/sync-${target}.sh"

    if [[ ! -x "${script}" ]]; then
        error "Script not found or not executable: ${script}"
        return 1
    fi

    header "sync-${target}"
    "${script}"
    echo ""
}

main() {
    local targets=()
    local check_mode=false

    for arg in "$@"; do
        case "${arg}" in
            -h|--help) usage ;;
            -l|--list) list_targets ;;
            --check) check_mode=true ;;
            --*) targets+=("${arg#--}") ;;
            *) targets+=("${arg}") ;;
        esac
    done

    if [[ ${#targets[@]} -eq 0 ]]; then
        targets=("${ALL_TARGETS[@]}")
    fi

    for target in "${targets[@]}"; do
        local valid=false
        for known in "${ALL_TARGETS[@]}"; do
            if [[ "${target}" == "${known}" ]]; then
                valid=true
                break
            fi
        done
        if [[ "${valid}" == false ]]; then
            error "Unknown target: ${target}"
            info "Available: ${ALL_TARGETS[*]}"
            exit 1
        fi
    done

    if [[ "${check_mode}" == true ]]; then
        info "Check mode: ${targets[*]}"
        echo ""
        local failed=()
        for target in "${targets[@]}"; do
            if ! check_target "${target}"; then
                failed+=("${target}")
            fi
        done
        if [[ ${#failed[@]} -gt 0 ]]; then
            error "Targets with diffs: ${failed[*]}"
            exit 1
        fi
        info "All targets up to date."
        exit 0
    fi

    info "Targets: ${targets[*]}"
    echo ""

    local failed=()
    for target in "${targets[@]}"; do
        if ! run_target "${target}"; then
            failed+=("${target}")
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        error "Failed targets: ${failed[*]}"
        exit 1
    fi

    info "All targets completed successfully."
}

main "$@"
