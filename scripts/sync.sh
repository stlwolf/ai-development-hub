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
    # BSD/macOS 互換にするため GNU 拡張を2か所やめている。
    #   末尾1行（set -euo pipefail）の除去: head -n -1 → sed '$d'
    #   行頭 '# ' の除去:                    s/^# \?// → 2つの s コマンド
    # （BSD の head に -n -1 は無く、BSD の基本正規表現は \? を
    #   「直前の要素は省略可」と解釈しない。sync/sync-bin.sh と同じ手当て）
    sed -n '/^# Usage:/,/^set -euo pipefail/p' "$0" | sed '$d' | sed -e 's/^# //' -e 's/^#$//'
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

check_orphan_links() {
    local target="$1" repo_root="$2" diffs_ref="$3"
    # 配布先の側から走査する。正本の側からだけ回していると、正本から消した
    # ファイルの配布先は一度も訪れられず、残ったリンクが壊れても誰も見ない（#359）。
    local orphan_script="${SYNC_DIR}/check-orphan-links.sh"
    if [[ ! -x "${orphan_script}" ]]; then
        error "  ${target}: 孤児リンクの検査を委譲できません（not found or not executable）: ${orphan_script}"
        eval "${diffs_ref}=true"
        return
    fi
    # 素で呼ばない。check_target は main() の `if ! check_target` から呼ばれるので
    # 関数本体の errexit が抑止され、子が差分を返しても握り潰される。
    local orphan_rc=0
    "${orphan_script}" "${target}" --canonical "${repo_root}/canonical" || orphan_rc=$?
    if [[ "${orphan_rc}" -ne 0 ]]; then
        eval "${diffs_ref}=true"
    fi
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
            check_symlinks_dir "${canonical}/orchestration-spec" "${base}/orchestration-spec" "*.md" "orchestration-spec" has_diffs
            check_symlinks_dir "${canonical}/agents" "${base}/agents" "*.md" "agents" has_diffs
            check_symlink "${base}/mcp.json" "${canonical}/mcp/cursor.json" "mcp.json" has_diffs
            check_symlink "${base}/hooks.json" "${canonical}/hooks/cursor.hooks.json" "hooks.json" has_diffs
            check_symlinks_dir "${canonical}/hooks/scripts" "${base}/hooks" "*.sh" "hook-scripts" has_diffs
            check_orphan_links cursor "${repo_root}" has_diffs
            ;;
        claude)
            local base="${HOME}/.claude"
            check_symlinks_dir "${canonical}/rules" "${base}/rules" "*.md" "rules" has_diffs
            check_symlinks_dir "${canonical}/orchestration-spec" "${base}/orchestration-spec" "*.md" "orchestration-spec" has_diffs
            check_skill_dirs "${canonical}/skills" "${base}/skills" "skills" has_diffs
            check_symlinks_dir "${canonical}/agents" "${base}/agents" "*.md" "agents" has_diffs
            check_symlinks_dir "${canonical}/commands" "${base}/commands" "*.md" "commands" has_diffs
            check_symlinks_dir "${canonical}/hooks/scripts" "${base}/hooks" "*.sh" "hook-scripts" has_diffs
            check_symlinks_dir "${canonical}/output-styles" "${base}/output-styles" "*.md" "output-styles" has_diffs
            # settings.json の検査は宣言（canonical/claude/settings.harness.json）を
            # 知っている専用スクリプトへ委譲する。ここに hooks だけを手書きしていると、
            # 宣言に項目が増えたときに検査側だけ古くなる（#313 と同じ理由・#359）。
            local settings_check="${SYNC_DIR}/check-claude-settings.sh"
            if [[ ! -x "${settings_check}" ]]; then
                error "  claude settings: 検査を委譲できません（not found or not executable）: ${settings_check}"
                has_diffs=true
            else
                # 素で呼ばない。check_target は main() の `if ! check_target` から呼ばれるので
                # 関数本体の errexit が抑止され、子が差分（rc=1）を返しても握り潰される
                # （bin ターゲットと同じ手当て）。
                local settings_rc=0
                "${settings_check}" --project-root "${repo_root}" || settings_rc=$?
                # 0 以外はすべて差分として扱う。子を実行できなかったときの終了コードは
                # 呼び出し文脈で変わり、数値では「差分あり」と区別できない。理由は子が印字する。
                if [[ "${settings_rc}" -ne 0 ]]; then
                    has_diffs=true
                fi
            fi
            check_orphan_links claude "${repo_root}" has_diffs
            ;;
        codex)
            local base="${HOME}/.codex"
            check_skill_dirs "${canonical}/skills" "${base}/skills" "skills" has_diffs
            check_symlinks_dir "${canonical}/orchestration-spec" "${base}/orchestration-spec" "*.md" "orchestration-spec" has_diffs
            check_symlink "${base}/AGENTS.md" "${canonical}/codex/AGENTS.md" "AGENTS.md" has_diffs
            check_symlink "${base}/hooks.json" "${canonical}/hooks/codex.hooks.json" "hooks.json" has_diffs
            check_symlinks_dir "${canonical}/hooks/scripts" "${base}/hooks" "*.sh" "hook-scripts" has_diffs
            check_orphan_links codex "${repo_root}" has_diffs
            ;;
        bin)
            # 配布対象を知っているのは sync-bin.sh なので、検査もそちらへ委譲する。
            # ここに対象を手書きすると、配布対象が増えたときに検査側だけ古くなる（#313）。
            local bin_script="${SYNC_DIR}/sync-bin.sh"
            if [[ ! -x "${bin_script}" ]]; then
                error "  bin: 検査を委譲できません（not found or not executable）: ${bin_script}"
                has_diffs=true
            else
                # 素で呼んではいけない。check_target は main() の `if ! check_target` から
                # 呼ばれるので関数本体の errexit が抑止され、子が差分（rc=1）を返しても
                # 素の呼び出しでは握り潰されて up to date と表示される。
                # 先例の sync-codex.sh は子を素で呼んでいるが、あちらは main が
                # トップレベルで実行されるので errexit が効く。前提が違う。
                local bin_rc=0
                "${bin_script}" --check || bin_rc=$?
                # 0 以外はすべて差分として扱う。子を実行できなかったときの終了コードは
                # 呼び出し文脈で 1 にも 126 にもなり、数値では「差分あり」と区別できない。
                # 理由は子が印字するので、ここで細分する必要はない。
                if [[ "${bin_rc}" -ne 0 ]]; then
                    has_diffs=true
                fi
            fi
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
