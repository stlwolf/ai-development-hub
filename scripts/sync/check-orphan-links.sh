#!/usr/bin/env bash
#
# check-orphan-links.sh — 配布先に残った symlink のうち、正本から消えたものを列挙する。
# 読み取り専用。何も削除しない。
#
# なぜ要るか:
#   配置も検査も正本の側からファイルを列挙して配布先を見に行く形になっている。
#   そのため正本から消したファイルの配布先は、配置でも検査でも一度も訪れられない。
#   訪れられない場所に残ったリンクは、解決先が消えても誰も見ない（#359）。
#
# Usage:
#   ./scripts/sync/check-orphan-links.sh claude
#   ./scripts/sync/check-orphan-links.sh cursor
#   ./scripts/sync/check-orphan-links.sh codex
#   ./scripts/sync/check-orphan-links.sh claude --base /tmp/fake-home/.claude
#   ./scripts/sync/check-orphan-links.sh claude --canonical /path/to/canonical
#
# 分類:
#   orphan-canonical  リンク先が今の正本ディレクトリ配下を指しているのに、正本にその実体が無い。
#                     これだけが後の掃除（--prune）の対象になる。
#   dangling-outside  リンク先が解決できないが、正本配下でもない。報告だけ。別の仕組みが
#                     張ったリンクを消さないため。
#   alive-outside     リンク先は生きているが正本の外（別のチェックアウトや worktree）。
#                     触らないが、配備が古い場所に固定されている状態なので分けて報告する。
#
# 通常ファイルは対象にしない。正本から消えた後に残る通常ファイルは別の負債として扱う。
# ここに足すと運用者が手で置いたファイルを消しにかかる。
#
# Exit:
#   0  孤児なし
#   1  孤児あり（orphan-canonical が1件以上）
#   2  検査を実行できない（正本が見つからない・引数が不正 等）

# -e は付けない。孤児を数え上げてから結論を出す設計で、途中で抜けると
# 走査が尻切れになったことと孤児が無かったことが区別できなくなる。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CANONICAL="${REPO_ROOT}/canonical"
BASE=""
TARGET=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 配布先ディレクトリの allowlist。sync が書き込む場所だけを歩く。
# ~/.claude 全体を歩くとセッションデータや cache に触るか、ノイズで溺れる。
claude_dirs=(rules skills agents commands hooks orchestration-spec statusline)
cursor_dirs=(rules skills agents commands hooks orchestration-spec)
codex_dirs=(skills agents commands-registry hooks orchestration-spec)

while [[ $# -gt 0 ]]; do
    case "$1" in
        claude|cursor|codex) TARGET="$1"; shift ;;
        --base)      BASE="$2"; shift 2 ;;
        --canonical) CANONICAL="$2"; shift 2 ;;
        -h|--help)
            sed -n '/^# Usage:/,/^set -.*pipefail/p' "$0" | sed '$d' | sed -e 's/^# //' -e 's/^#$//'
            exit 0 ;;
        *) error "Unknown argument: $1"; exit 2 ;;
    esac
done

if [[ -z "${TARGET}" ]]; then
    error "ターゲットを指定してください（claude / cursor / codex）"
    exit 2
fi

case "${TARGET}" in
    claude) dirs=("${claude_dirs[@]}"); default_base="${HOME}/.claude" ;;
    cursor) dirs=("${cursor_dirs[@]}"); default_base="${HOME}/.cursor" ;;
    codex)  dirs=("${codex_dirs[@]}");  default_base="${HOME}/.codex" ;;
esac
[[ -z "${BASE}" ]] && BASE="${default_base}"

# 正本が見つからない状態で歩くと、配備物のすべてが孤児に見える。
# worktree から sync した後にその worktree を消す事故が実際に起きているので、
# ここで止める（掃除の側では致命的になる）。
if [[ ! -d "${CANONICAL}" ]]; then
    error "正本ディレクトリが見つかりません: ${CANONICAL}"
    error "  この状態で歩くと配備物のすべてが孤児に見えます。検査を中止します。"
    exit 2
fi

# 存在しないパスでも使える字句的な正規化。realpath は解決先が無いと失敗するので、
# 壊れた相対リンクの行き先を判定するにはこれが要る。
normalize_path() {
    local p="$1" part joined=""
    local -a out=()
    local OLD_IFS="$IFS"
    IFS='/'
    # shellcheck disable=SC2086  # 区切りで分割させるのが目的
    set -- $p
    IFS="$OLD_IFS"
    for part in "$@"; do
        case "${part}" in
            ''|'.') ;;
            '..') if [[ "${#out[@]}" -gt 0 ]]; then unset "out[$(( ${#out[@]} - 1 ))]"; out=("${out[@]}"); fi ;;
            *) out+=("${part}") ;;
        esac
    done
    if [[ "${#out[@]}" -gt 0 ]]; then
        for part in "${out[@]}"; do joined="${joined}/${part}"; done
    fi
    printf '%s' "${joined:-/}"
}

resolve_path() {
    if command -v realpath >/dev/null 2>&1; then
        realpath "$1" 2>/dev/null
    else
        python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null
    fi
}

CANONICAL_REAL="$(resolve_path "${CANONICAL}")"
[[ -z "${CANONICAL_REAL}" ]] && CANONICAL_REAL="${CANONICAL}"

orphan_count=0
outside_dangling_count=0
outside_alive_count=0
scanned=0

echo "配布先の孤児 symlink（${TARGET}: ${BASE}）"
echo "  正本: ${CANONICAL_REAL}"

for d in "${dirs[@]}"; do
    dir="${BASE}/${d}"
    [[ -d "${dir}" ]] || continue
    while IFS= read -r entry; do
        [[ -n "${entry}" ]] || continue
        scanned=$((scanned + 1))
        raw="$(readlink "${entry}")"
        # 相対リンクはリンクのあるディレクトリからの相対として絶対化する。
        abs="${raw}"
        [[ "${abs}" != /* ]] && abs="$(dirname "${entry}")/${abs}"
        # 相対リンクは ../ を含んだままだと文字列比較で正本配下かを判定できない。
        abs="$(normalize_path "${abs}")"

        # 正本配下かどうかは、解決できた実パスと生のターゲット文字列の両方で見る。
        # 解決先が消えていると realpath は失敗するので、生の文字列が要る。
        under_canonical=false
        real="$(resolve_path "${abs}")"
        if [[ -n "${real}" && ( "${real}" == "${CANONICAL_REAL}" || "${real}" == "${CANONICAL_REAL}/"* ) ]]; then
            under_canonical=true
        elif [[ "${abs}" == "${CANONICAL_REAL}"/* || "${abs}" == "${CANONICAL}"/* ]]; then
            under_canonical=true
        fi

        alive=false
        [[ -e "${entry}" ]] && alive=true

        rel="${d}/$(basename "${entry}")"
        if [[ "${under_canonical}" == true ]]; then
            if [[ "${alive}" == false ]]; then
                warn "  orphan-canonical ${rel} → ${raw}"
                warn "    正本を指していますが、そこに実体がありません"
                orphan_count=$((orphan_count + 1))
            fi
        else
            if [[ "${alive}" == false ]]; then
                warn "  dangling-outside ${rel} → ${raw}"
                warn "    解決できませんが正本の外なので触りません（別の仕組みが張った可能性）"
                outside_dangling_count=$((outside_dangling_count + 1))
            else
                warn "  alive-outside ${rel} → ${raw}"
                warn "    生きていますが正本の外を指しています（別のチェックアウトに固定されている可能性）"
                outside_alive_count=$((outside_alive_count + 1))
            fi
        fi
    done < <(find "${dir}" -maxdepth 1 -mindepth 1 -type l 2>/dev/null)
done

echo ""
info "  走査した symlink: ${scanned} 件"
if [[ "${outside_dangling_count}" -gt 0 || "${outside_alive_count}" -gt 0 ]]; then
    info "  正本の外: 解決できない ${outside_dangling_count} 件 / 生きている ${outside_alive_count} 件（掃除の対象外）"
fi

if [[ "${orphan_count}" -gt 0 ]]; then
    error "  ${TARGET}: 正本から消えた配布先が ${orphan_count} 件残っています"
    exit 1
fi
info "  ${TARGET}: 正本から消えた配布先はありません"
exit 0
