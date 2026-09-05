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
#   ./scripts/sync/check-orphan-links.sh claude --verbose   # 何も無くても内訳を出す
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
VERBOSE=false

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
        --base)      [[ $# -ge 2 ]] || { error "--base に値がありません"; exit 2; }
                     BASE="$2"; shift 2 ;;
        --canonical) [[ $# -ge 2 ]] || { error "--canonical に値がありません"; exit 2; }
                     CANONICAL="$2"; shift 2 ;;
        -v|--verbose) VERBOSE=true; shift ;;
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
    # リンク先には * や ? や [ が入りうる。分割だけさせたいので、その間だけ
    # パス名展開を止める。止めないとリンク先がファイルシステムに対して展開され、
    # 分類が丸ごと狂う。
    local had_noglob=0
    case "$-" in *f*) had_noglob=1 ;; esac
    set -f
    IFS='/'
    # shellcheck disable=SC2086  # 区切りで分割させるのが目的
    set -- $p
    IFS="$OLD_IFS"
    [[ "${had_noglob}" -eq 0 ]] && set +f
    for part in "$@"; do
        case "${part}" in
            ''|'.') ;;
            '..')
                if [[ "${#out[@]}" -gt 0 ]]; then
                    unset "out[$(( ${#out[@]} - 1 ))]"
                    # bash 3.2 では set -u のもとで空配列の "${a[@]}" が unbound になる。
                    # 全部消えたときは素の代入に落とす（.. がパスの深さを超える相対リンク）。
                    if [[ "${#out[@]}" -gt 0 ]]; then out=("${out[@]}"); else out=(); fi
                fi ;;
            *) out+=("${part}") ;;
        esac
    done
    if [[ "${#out[@]}" -gt 0 ]]; then
        for part in "${out[@]}"; do joined="${joined}/${part}"; done
    fi
    printf '%s' "${joined:-/}"
}

# 解決できないパスでも必ず答えを返す。realpath は実装によって、存在しない
# パスを解決する版と失敗する版がある（macOS は解決し、GNU は -m 無しだと失敗する）。
# 版差で分類が変わると、掃除の対象までぶれる。存在する祖先まで解決して残りを
# 継ぎ足す形にして、どちらの版でも同じ答えにする。
_realpath_raw() {
    if command -v realpath >/dev/null 2>&1; then
        realpath "$1" 2>/dev/null
    else
        python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null
    fi
}

resolve_path() {
    local p="$1" out rest="" cur base
    if out="$(_realpath_raw "$p")" && [[ -n "${out}" ]]; then
        printf '%s' "${out}"
        return 0
    fi
    cur="$p"
    while [[ -n "${cur}" && "${cur}" != "/" && "${cur}" != "." ]]; do
        if [[ -e "${cur}" ]]; then
            base="$(_realpath_raw "${cur}")"
            if [[ -n "${base}" ]]; then
                printf '%s' "${base}${rest}"
                return 0
            fi
            break
        fi
        rest="/$(basename "${cur}")${rest}"
        cur="$(dirname "${cur}")"
    done
    printf '%s' "$p"
}

CANONICAL_REAL="$(resolve_path "${CANONICAL}")"
[[ -z "${CANONICAL_REAL}" ]] && CANONICAL_REAL="${CANONICAL}"

# macOS の既定のファイルシステムは大文字小文字を区別しない。綴りだけが違う
# リンク先は、文字列の前方一致では正本配下と判定できず、孤児を見落とす。
# 実際に試して確かめる（決め打ちしない）。
# 判定はファイルを作らずに行う。読み取り専用の検査が正本の隣にファイルを
# 作って消すのは、たとえ一時的でも筋が悪い（同名ファイルを壊しうるし、
# 割り込まれると残る）。既にあるパスの綴りを変えて到達できるかで見る。
CASE_INSENSITIVE=false
_alt="$(printf '%s' "${CANONICAL_REAL}" | tr '[:lower:]' '[:upper:]')"
if [[ "${_alt}" != "${CANONICAL_REAL}" && -d "${_alt}" ]]; then
    CASE_INSENSITIVE=true
else
    _alt2="$(printf '%s' "${CANONICAL_REAL}" | tr '[:upper:]' '[:lower:]')"
    [[ "${_alt2}" != "${CANONICAL_REAL}" && -d "${_alt2}" ]] && CASE_INSENSITIVE=true
fi

# 前方一致。区別しないファイルシステムでは綴りを揃えてから比べる。
under_prefix() {
    local path="$1" prefix="$2"
    if [[ "${CASE_INSENSITIVE}" == true ]]; then
        path="$(printf '%s' "${path}" | tr '[:upper:]' '[:lower:]')"
        prefix="$(printf '%s' "${prefix}" | tr '[:upper:]' '[:lower:]')"
    fi
    [[ "${path}" == "${prefix}" || "${path}" == "${prefix}/"* ]]
}

orphan_count=0
scan_failed=false
listing=""
find_rc=0
outside_dangling_count=0
outside_alive_count=0
scanned=0

# 何も見つからないときは既定では黙る。sync.sh --check の正常時の出力を
# 変えないという契約のため。--verbose を付けると走査の内訳を出す。
if [[ "${VERBOSE}" == true ]]; then
    echo "配布先の孤児 symlink（${TARGET}: ${BASE}）"
    echo "  正本: ${CANONICAL_REAL}"
fi

for d in "${dirs[@]}"; do
    dir="${BASE}/${d}"
    if [[ ! -d "${dir}" ]]; then
        # 「無い」のか「あるが辿れない」のかを区別する。親が辿れないと -d は
        # 偽になるので、黙って飛ばすと走査できなかったことが緑に化ける。
        if [[ -e "${dir}" ]]; then
            error "  配布先がディレクトリではありません: ${dir}"
            scan_failed=true
        elif [[ -d "${BASE}" && ! -x "${BASE}" ]]; then
            error "  配布先の親を辿れないので確かめられません: ${dir}"
            scan_failed=true
        fi
        continue
    fi
    # process substitution だと find の終了コードが取れないので、いったん受ける。
    if ! listing="$(mktemp)" || [[ -z "${listing}" ]]; then
        error "作業ファイルを作れません"
        exit 2
    fi
    find_rc=0
    # 名前に改行が入りうるので NUL 区切りで受ける。行区切りだと1件が2件に割れる。
    # 末尾のスラッシュを付ける。付けないと、走査ルート自体が symlink のときに
    # find が中へ降りず、孤児を全件見落として緑を返す。
    find "${dir}/" -maxdepth 1 -mindepth 1 -type l -print0 > "${listing}" 2>/dev/null || find_rc=$?
    while IFS= read -r -d '' entry; do
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
        if [[ -n "${real}" ]]; then
            # 解決できたなら実パスの判定を信じる。ここで字句判定へ落とすと、
            # 正本配下の中間 symlink が外を指す場合に外向きを見落とす。
            under_prefix "${real}" "${CANONICAL_REAL}" && under_canonical=true
        elif under_prefix "${abs}" "${CANONICAL_REAL}" || under_prefix "${abs}" "${CANONICAL}"; then
            # 解決できないときだけ、生のリンク先を字句的に見る。
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
                # 生きている外向きリンクは、worktree から走らせると配備物の全部が
                # 該当する。既定では1件ずつ出さず、末尾の要約だけにする。
                if [[ "${VERBOSE}" == true ]]; then
                    warn "  alive-outside ${rel} → ${raw}"
                    warn "    生きていますが正本の外を指しています（別のチェックアウトに固定されている可能性）"
                fi
                outside_alive_count=$((outside_alive_count + 1))
            fi
        fi
    done < "${listing}"
    # 走査そのものが失敗したら、孤児が無かったのか見られなかったのかを区別できない。
    # 黙って次のディレクトリへ進むと、母集団が縮んだまま緑を返せてしまう。
    if [[ "${find_rc}" -ne 0 ]]; then
        error "  配布先を走査できませんでした: ${dir}"
        scan_failed=true
    fi
    rm -f "${listing}"
done

if [[ "${VERBOSE}" == true ]]; then
    echo ""
    info "  走査した symlink: ${scanned} 件"
fi
if [[ "${outside_dangling_count}" -gt 0 || "${outside_alive_count}" -gt 0 ]]; then
    info "  正本の外: 解決できない ${outside_dangling_count} 件 / 生きている ${outside_alive_count} 件（掃除の対象外）"
fi

if [[ "${scan_failed}" == true ]]; then
    error "  ${TARGET}: 走査できなかった配布先があるため、孤児の有無を判定できません"
    exit 1
fi

if [[ "${orphan_count}" -gt 0 ]]; then
    error "  ${TARGET}: 正本から消えた配布先が ${orphan_count} 件残っています"
    exit 1
fi
[[ "${VERBOSE}" == true ]] && info "  ${TARGET}: 正本から消えた配布先はありません"
exit 0
