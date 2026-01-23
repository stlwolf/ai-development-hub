#!/bin/bash
#
# sync-cursor-commands.sh
#
# ai-development-hub/cursor/command/ 以下のファイルを
# ~/.cursor/commands/ にシンボリックリンクとして配置する
#
# Usage:
#   ./scripts/sync-cursor-commands.sh
#
# Description:
#   このスクリプトは ai-development-hub リポジトリの cursor/command/ 以下にある
#   .md ファイルを ~/.cursor/commands/ にシンボリックリンクとして配置します。
#
#   シンボリックリンクを使用することで、どちら側から編集しても同じファイルが
#   変更され、リポジトリ側でバージョン管理できます。
#
#   プロジェクト固有のコマンド（リポジトリに含めたくないもの）は
#   ~/.cursor/commands/ に直接通常ファイルとして配置してください。
#   スクリプトは通常ファイルをスキップします。
#
# Example:
#   # 初回セットアップ
#   cd ~/work/repos/github.com/stlwolf/ai-development-hub
#   ./scripts/sync-cursor-commands.sh
#
#   # リポジトリにコマンドを追加した後
#   ./scripts/sync-cursor-commands.sh
#

set -euo pipefail

# 設定
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="${REPO_ROOT}/cursor/command"
TARGET_DIR="${HOME}/.cursor/commands"

# 色付き出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    sed -n '/^# Usage:/,/^set -euo pipefail/p' "$0" | head -n -1 | sed 's/^# \?//'
    exit 0
}

# ヘルプオプション
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

# メイン処理
main() {
    info "Source: ${SOURCE_DIR}"
    info "Target: ${TARGET_DIR}"
    echo ""

    # ターゲットディレクトリ作成
    if [[ ! -d "${TARGET_DIR}" ]]; then
        info "Creating target directory: ${TARGET_DIR}"
        mkdir -p "${TARGET_DIR}"
    fi

    # ソースディレクトリ確認
    if [[ ! -d "${SOURCE_DIR}" ]]; then
        error "Source directory not found: ${SOURCE_DIR}"
        exit 1
    fi

    # .mdファイルを再帰的に検索してシンボリックリンク作成
    local count=0
    while IFS= read -r -d '' file; do
        local filename
        filename="$(basename "$file")"
        local target_path="${TARGET_DIR}/${filename}"

        # 既存ファイルの確認
        if [[ -e "${target_path}" && ! -L "${target_path}" ]]; then
            warn "Skipping (regular file exists): ${target_path}"
            continue
        fi

        # シンボリックリンク作成（既存リンクは上書き）
        ln -sf "${file}" "${target_path}"
        info "Linked: ${filename} -> ${file}"
        ((count++))
    done < <(find "${SOURCE_DIR}" -type f -name "*.md" -print0)

    echo ""
    info "Done! ${count} symlink(s) created/updated."

    # 現在の状態を表示
    echo ""
    info "Current ~/.cursor/commands/ contents:"
    ls -la "${TARGET_DIR}"
}

main "$@"
