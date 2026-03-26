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
    # Parse arguments
    local targets=()

    for arg in "$@"; do
        case "${arg}" in
            -h|--help) usage ;;
            -l|--list) list_targets ;;
            --*) targets+=("${arg#--}") ;;
            *) targets+=("${arg}") ;;
        esac
    done

    # Default: all targets
    if [[ ${#targets[@]} -eq 0 ]]; then
        targets=("${ALL_TARGETS[@]}")
    fi

    # Validate targets
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

    info "Targets: ${targets[*]}"
    echo ""

    # Run each target, collect failures
    local failed=()
    for target in "${targets[@]}"; do
        if ! run_target "${target}"; then
            failed+=("${target}")
        fi
    done

    # Summary
    if [[ ${#failed[@]} -gt 0 ]]; then
        error "Failed targets: ${failed[*]}"
        exit 1
    fi

    info "All targets completed successfully."
}

main "$@"
