#!/usr/bin/env bash
#
# sync-bin.sh
#
# ai-development-hub のスクリプトを ~/bin/ にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync/sync-bin.sh
#   ./scripts/sync/sync-bin.sh --list
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
# Example:
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync/sync-bin.sh
#   ./scripts/sync/sync-bin.sh --list
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
        *)
            error "不明なオプション: '$1'（使えるのは --list / -h / --help、または引数なし）"
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
