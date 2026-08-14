#!/usr/bin/env bash
#
# sync-bin.sh
#
# ai-development-hub のスクリプトを ~/bin/ にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync/sync-bin.sh
#   ./scripts/sync/sync-bin.sh --list
#   ./scripts/sync/sync-bin.sh --check
#
# Description:
#   so-compare.sh, arena-compare.sh, wez 等のスクリプトを
#   ~/bin/ にシンボリックリンクとして配置します。
#   リンク名は拡張子なし（so-compare, arena-compare）または
#   元のファイル名のまま（wez）になります。
#
#   既にシンボリックリンクでないファイルが存在する場合はスキップします。
#
#   --list は配布対象のコマンド名（CMD_NAMES）を1行1件で印字して終了します
#   （配置はしません）。ドキュメント側の列挙を置き換えるものではなく、
#   突き合わせて確かめるための出力です。
#
#   --check は配布対象の全件が ~/bin/ に正しく張られているかを検査します
#   （配置はしません）。sync.sh --check bin はこの verb へ委譲するので、
#   配布対象を増やしても検査側を触る必要はありません。終了コードは
#   0=全件一致 / 1=差分あり / 2=呼び方の誤りまたは配布対象の定義が不正、です。
#
# Example:
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync/sync-bin.sh
#   ./scripts/sync/sync-bin.sh --list
#   ./scripts/sync/sync-bin.sh --check
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# TARGET_DIR は main() 内で解決する。トップレベルで "${HOME}/bin" を
# 展開すると set -u 下で HOME 未設定の環境が即エラーになり、配置を伴わない
# --list まで巻き添えで実行不能になるため。

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    # BSD/macOS 互換にするため GNU 拡張を2か所やめている。
    #   末尾1行（set -euo pipefail）の除去: head -n -1 → sed '$d'
    #   行頭 '# ' の除去:                    s/^# \?// → 2つの s コマンド
    # （BSD の基本正規表現は \? を「直前の要素は省略可」と解釈しない）
    sed -n '/^# Usage:/,/^set -euo pipefail/p' "$0" | sed '$d' | sed -e 's/^# //' -e 's/^#$//'
    exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

CMD_NAMES=("so-compare" "arena-compare" "wez" "wt-pane-issue" "oe-tree" "oe-hookfire" "validate-knowledge" "knowledge-list")
CMD_SOURCES=(
    "${REPO_ROOT}/scripts/so-compare.sh"
    "${REPO_ROOT}/projects/arena-compare/arena-compare.sh"
    "${REPO_ROOT}/projects/wezterm-ai-mode/bin/wez"
    "${REPO_ROOT}/scripts/wt/wt-pane-issue.sh"
    "${REPO_ROOT}/projects/orchestration-engine/bin/oe-tree"
    "${REPO_ROOT}/projects/orchestration-engine/bin/oe-hookfire"
    "${REPO_ROOT}/projects/orchestration-engine/scripts/validate-knowledge.sh"
    "${REPO_ROOT}/projects/orchestration-engine/scripts/knowledge-list.sh"
)

list_cmds() {
    printf '%s\n' "${CMD_NAMES[@]}"
    exit 0
}

# sync.sh の resolve_path と同じ考え方。realpath → python3 → 素通しの順に試す。
resolve_path() {
    if command -v realpath &>/dev/null; then
        realpath "$1" 2>/dev/null
    elif command -v python3 &>/dev/null; then
        python3 -c "import os; print(os.path.realpath('$1'))" 2>/dev/null
    else
        echo "$1"
    fi
}

# 配置対象が ~/bin/ に正しく張られているかを、配置と同じ CMD_NAMES / CMD_SOURCES から
# 回して検査する。判定は sync.sh の check_symlink と同じ3ケース（不在 / リンク先違い /
# symlink でない実体の内容差）に、source 不在を足したもの。
#
# 検査を配置と同じファイルに置いているのは、配布対象を増やしたときに片方だけ更新される
# のを防ぐためである（#313）。検査側が別ファイルに対象を手書きしていたころは、対象が
# 8件へ増えても検査は2件のままで、残り6件は張られていなくても緑で通っていた。
check_cmds() {
    local target_dir="${HOME}/bin"

    # 母集団が壊れているときに「差分なし」を名乗らせない。0 件のまま回すと 0 回の
    # ループが緑を返し、検査が素通しになったことが緑と区別できなくなる。
    if [[ ${#CMD_NAMES[@]} -eq 0 || ${#CMD_NAMES[@]} -ne ${#CMD_SOURCES[@]} ]]; then
        error "配布対象の定義が空か、CMD_NAMES と CMD_SOURCES の長さが一致しません"
        exit 2
    fi

    local has_diffs=false
    local i
    for i in "${!CMD_NAMES[@]}"; do
        local cmd_name="${CMD_NAMES[$i]}"
        local source_path="${CMD_SOURCES[$i]}"
        local target_path="${target_dir}/${cmd_name}"

        # 配置側は source 不在を error にして continue するが、検査側は差分として数える。
        # 飛ばすと母集団が静かに縮み、見えない欠落が増える。
        if [[ ! -f "${source_path}" ]]; then
            warn "  Source missing: ${cmd_name} → ${source_path}"
            has_diffs=true
            continue
        fi

        # dangling symlink もここで拾う（-e は解決先が無ければ偽）。
        if [[ ! -e "${target_path}" ]]; then
            warn "  Missing: ${cmd_name} → ${target_path}"
            has_diffs=true
            continue
        fi

        if [[ -L "${target_path}" ]]; then
            local actual_source canonical_source
            actual_source="$(resolve_path "${target_path}")"
            canonical_source="$(resolve_path "${source_path}")"
            if [[ "${actual_source}" != "${canonical_source}" ]]; then
                warn "  Mismatch: ${cmd_name}"
                warn "    expected: ${canonical_source}"
                warn "    actual:   ${actual_source}"
                has_diffs=true
            fi
        else
            if ! diff -q "${source_path}" "${target_path}" &>/dev/null; then
                warn "  Content differs: ${cmd_name} (not a symlink)"
                has_diffs=true
            fi
        fi
    done

    if [[ "${has_diffs}" == true ]]; then
        exit 1
    fi
    exit 0
}

# 引数の検証（-h / --help は上で処理済みなのでここには来ない）。
# 読み取り専用のつもりの誤記（--lis 等）が黙って配置処理へ落ちないよう、
# 既知のもの以外は受け付けない。
if [[ $# -gt 1 ]]; then
    error "引数が多すぎます: $*（1つだけ、または引数なし）"
    exit 2
fi

# 引数そのものが無い場合だけ配置を実行する。空文字列 '' は「引数を渡した」
# ことになるので、黙って配置へ落とさず不正として扱う。
if [[ $# -eq 0 ]]; then
    :
else
    case "$1" in
        --list) list_cmds ;;
        --check) check_cmds ;;
        *)
            error "不明なオプション: '$1'（使えるのは --list / --check / -h / --help、または引数なし）"
            exit 2
            ;;
    esac
fi

main() {
    local TARGET_DIR="${HOME}/bin"

    info "Target: ${TARGET_DIR}"
    echo ""

    if [[ ! -d "${TARGET_DIR}" ]]; then
        info "Creating target directory: ${TARGET_DIR}"
        mkdir -p "${TARGET_DIR}"
    fi

    local count=0
    for i in "${!CMD_NAMES[@]}"; do
        local cmd_name="${CMD_NAMES[$i]}"
        local source_path="${CMD_SOURCES[$i]}"
        local target_path="${TARGET_DIR}/${cmd_name}"

        if [[ ! -f "${source_path}" ]]; then
            error "Source not found: ${source_path}"
            continue
        fi

        if [[ -e "${target_path}" && ! -L "${target_path}" ]]; then
            warn "Skipping (regular file exists): ${target_path}"
            continue
        fi

        ln -sfn "${source_path}" "${target_path}"
        info "Linked: ${cmd_name} -> ${source_path}"
        count=$((count + 1))
    done

    echo ""
    info "Done! ${count} symlink(s) created/updated."

    echo ""
    info "Verify:"
    for cmd_name in "${CMD_NAMES[@]}"; do
        if command -v "${cmd_name}" &>/dev/null; then
            info "  ${cmd_name}: $(command -v "${cmd_name}")"
        else
            warn "  ${cmd_name}: not in PATH"
        fi
    done
}

main "$@"
