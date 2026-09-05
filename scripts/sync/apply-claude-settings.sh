#!/usr/bin/env bash
#
# apply-claude-settings.sh — 宣言（canonical/claude/settings.harness.json）に書かれた
# 項目だけを ~/.claude/settings.json へ適用する。宣言に無い項目には一切触らない。
#
# Usage:
#   ./scripts/sync/apply-claude-settings.sh
#   ./scripts/sync/apply-claude-settings.sh --settings /path/to/settings.json
#   ./scripts/sync/apply-claude-settings.sh --declaration /path/to/decl.json
#
# Exit:
#   0  適用した（変更が無かった場合を含む）
#   1  適用できなかった（書き込みに失敗した 等）
#   2  実行できない（宣言が読めない・jq が無い 等）
#
# 設計上の約束:
#   - 書き込みは1回にまとめる。項目ごとに読んで書き戻すと、その間に CLI が
#     別のキーを書いたときに消してしまう。窓は少ないほどよい。
#   - 置き換える直前に、読んだときと同じ内容かを確かめる。違っていたら読み直して
#     宣言項目だけを当て直す。上限まで試して駄目なら止める。
#   - これは同時書き込みを防ぐものではない。CLI 側は同じロックを取らないので、
#     ロックを足しても効かない。ここで守れるのは「配布が CLI の無関係な項目を
#     消さない」ところまでである。
#   - 対象が symlink / 通常ファイル以外 / JSON として読めない場合の態度は1箇所に
#     集める。読めなければ何も書かない。空のファイルを作らない。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DECLARATION="${REPO_ROOT}/canonical/claude/settings.harness.json"
SETTINGS="${HOME}/.claude/settings.json"
MAX_RETRY=3

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info() { printf '%b[INFO]%b %s\n' "${GREEN}" "${NC}" "$1"; }
warn() { printf '%b[WARN]%b %s\n' "${YELLOW}" "${NC}" "$1"; }
error() { printf '%b[ERROR]%b %s\n' "${RED}" "${NC}" "$1"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --declaration) [[ $# -ge 2 ]] || { error "--declaration に値がありません"; exit 2; }
                       DECLARATION="$2"; shift 2 ;;
        --settings)    [[ $# -ge 2 ]] || { error "--settings に値がありません"; exit 2; }
                       SETTINGS="$2"; shift 2 ;;
        -h|--help)
            sed -n '/^# Usage:/,/^set -.*pipefail/p' "$0" | sed '$d' | sed -e 's/^# //' -e 's/^#$//'
            exit 0 ;;
        *) error "Unknown argument: $1"; exit 2 ;;
    esac
done

command -v jq >/dev/null 2>&1 || { error "jq が必要です"; exit 2; }
[[ -f "${DECLARATION}" ]] || { error "宣言ファイルが読めません: ${DECLARATION}"; exit 2; }
jq -e . "${DECLARATION}" >/dev/null 2>&1 || { error "宣言ファイルが JSON として読めません: ${DECLARATION}"; exit 2; }

decl_count="$(jq '.items | length' "${DECLARATION}")"
if [[ "${decl_count}" -eq 0 ]]; then
    error "宣言に項目がありません: ${DECLARATION}"
    exit 2
fi

# ---------------------------------------------------------------------------
# 正本の解決。1項目でも解けなければ何も書かない（部分適用を作らない）。
# ---------------------------------------------------------------------------
resolved="$(mktemp)" || { error "作業ファイルを作れません"; exit 2; }
trap 'rm -f "${resolved}" "${resolved}.tmp"' EXIT
echo "[]" > "${resolved}" || { error "作業ファイルに書けません"; exit 2; }

resolve_failed=false
while IFS=$'\t' read -r pointer op handler src_file src_pointer; do
    [[ "${handler}" == "-" ]] && handler=""
    [[ "${src_pointer}" == "-" ]] && src_pointer=""
    expected="null"
    if [[ -n "${src_file}" && "${src_file}" != "-" ]]; then
        abs_src="${src_file}"
        [[ "${abs_src}" != /* ]] && abs_src="${REPO_ROOT}/${src_file}"
        if [[ ! -f "${abs_src}" ]]; then
            error "  正本ファイルが見つかりません: ${pointer} → ${src_file}"
            resolve_failed=true; continue
        fi
        # shellcheck disable=SC2016  # jq プログラムなのでシェルに展開させない
        if ! expected="$(jq -c --arg p "${src_pointer}" '
              def ptr2path($p): if $p == "" or $p == "/" then []
                else ($p | ltrimstr("/") | split("/")
                      | map(gsub("~1"; "/") | gsub("~0"; "~"))) end;
              getpath(ptr2path($p))' "${abs_src}" 2>/dev/null)"; then
            error "  正本ファイルを読めません: ${pointer} → ${src_file}"
            resolve_failed=true; continue
        fi
        if [[ "${expected}" == "null" ]]; then
            error "  正本に値がありません: ${pointer} → ${src_file}#${src_pointer}"
            resolve_failed=true; continue
        fi
    fi
    exp_type="$(jq -r 'type' <<< "${expected}")"
    case "${op}" in
        merge-object) [[ "${exp_type}" == "object" ]] || { error "  merge-object の正本がオブジェクトではありません: ${pointer} (${exp_type})"; resolve_failed=true; continue; } ;;
        union-array)  [[ "${exp_type}" == "array" ]] || { error "  union-array の正本が配列ではありません: ${pointer} (${exp_type})"; resolve_failed=true; continue; } ;;
        replace|absent|handler) ;;
        *) error "  扱えない op です: ${pointer} (${op})"; resolve_failed=true; continue ;;
    esac
    if jq -c --arg pointer "${pointer}" --arg op "${op}" --arg handler "${handler}" \
            --argjson expected "${expected}" \
            '. + [{pointer: $pointer, op: $op, handler: $handler, expected: $expected}]' \
            "${resolved}" > "${resolved}.tmp" && mv "${resolved}.tmp" "${resolved}"; then
        :
    else
        rm -f "${resolved}.tmp"
        error "  項目を適用対象に追加できませんでした: ${pointer}"
        resolve_failed=true
    fi
done < <(jq -r '.items[]
    | [ .pointer, .op,
        (if (.handler // "") == "" then "-" else .handler end),
        (.source.file // "-"),
        (if (.source.pointer // "") == "" then "-" else .source.pointer end) ]
    | @tsv' "${DECLARATION}")

if [[ "${resolve_failed}" == true ]]; then
    error "  正本の解決に失敗したので何も書きません"
    exit 2
fi

resolved_count="$(jq 'length' "${resolved}")"
if [[ "${resolved_count}" -ne "${decl_count}" ]]; then
    error "  解決できた項目が宣言より少ないです（${resolved_count} / ${decl_count}）。何も書きません"
    exit 2
fi

# ---------------------------------------------------------------------------
# 書けない相手の判定を1箇所に集める。
# ---------------------------------------------------------------------------
info "Applying ${decl_count} declared item(s) → $(basename "${SETTINGS}")"

if [[ -L "${SETTINGS}" ]]; then
    # -L を先に見る。-e はリンクを辿るので、解決先が消えた symlink を取り逃がす。
    warn "  symlink なので触りません: ${SETTINGS}"
    exit 0
fi
if [[ -e "${SETTINGS}" && ! -f "${SETTINGS}" ]]; then
    warn "  通常ファイルではないので触りません: ${SETTINGS}"
    exit 0
fi

# shellcheck disable=SC2016  # jq プログラムなのでシェルに展開させない
JQ_APPLY='
def ptr2path($p): if $p == "" or $p == "/" then []
  else ($p | ltrimstr("/") | split("/") | map(gsub("~1"; "/") | gsub("~0"; "~"))) end;

def apply_item($item):
  (ptr2path($item.pointer)) as $path
  | if $item.op == "replace" then setpath($path; $item.expected)
    elif $item.op == "absent" then delpaths([$path])
    elif $item.op == "merge-object" then
      setpath($path; ((getpath($path) // {}) * $item.expected))
    elif $item.op == "union-array" then
      setpath($path; (((getpath($path) // []) + $item.expected) | unique_by(tojson)))
    elif $item.op == "handler" and $item.handler == "statusline-wrap" then
      # 現行の3分岐をそのまま写す。
      #   未設定           → 正本を載せる
      #   既に beat producer → command は保持し他のフィールドだけ更新（二重に包まない）
      #   独自のもの        → 元コマンドを退避して包む。padding 等の既存フィールドは残す
      ((getpath($path) // {}) as $cur
       | (if ($cur | type) == "object" and ($cur.command | type) == "string"
          then $cur.command else "" end) as $cmd
       | if $cmd == "" then
           setpath($path; (( if ($cur|type)=="object" then $cur else {} end) + $item.expected))
         elif ($cmd | contains($marker)) then
           setpath($path; ($cur + $item.expected + {command: $cmd}))
         else
           setpath($path; ($cur + $item.expected + {command: ($wrap_prefix + " " + $item.expected.command)}))
         end)
    else . end;

reduce $decl[0][] as $item (.; apply_item($item))
'

attempt=0
while :; do
    attempt=$((attempt + 1))

    if [[ -e "${SETTINGS}" ]]; then
        if ! before="$(cat "${SETTINGS}" 2>/dev/null)"; then
            error "  読めません: ${SETTINGS}"
            exit 1
        fi
        if ! jq -e . "${SETTINGS}" >/dev/null 2>&1; then
            warn "  JSON として読めないので触りません（壊れている可能性）: ${SETTINGS}"
            exit 0
        fi
        current_file="${SETTINGS}"
    else
        before=""
        current_file=""
    fi

    # statusline-wrap が退避に使う元コマンドを、いまの内容から取り出す。
    existing_cmd=""
    if [[ -n "${current_file}" ]]; then
        existing_cmd="$(jq -r '(.statusLine.command // "") | if type == "string" then . else "" end' "${current_file}" 2>/dev/null || echo "")"
    fi
    marker="statusline-oe-heartbeat.sh"
    wrap_prefix=""
    if [[ -n "${existing_cmd}" && "${existing_cmd}" != *"${marker}"* ]]; then
        wrap_prefix="OE_HEARTBEAT_WRAP_CMD=$(printf '%q' "${existing_cmd}")"
    fi

    out="$(mktemp "${SETTINGS}.tmp.XXXXXX")" || { error "  一時ファイルを作れません"; exit 1; }
    if ! jq -n --slurpfile decl "${resolved}" \
            --arg marker "${marker}" --arg wrap_prefix "${wrap_prefix}" \
            --argjson base "$( [[ -n "${current_file}" ]] && cat "${current_file}" || echo '{}' )" \
            "\$base | ${JQ_APPLY}" > "${out}" 2>/dev/null; then
        rm -f "${out}"
        error "  適用の計算に失敗しました"
        exit 1
    fi
    if ! jq -e . "${out}" >/dev/null 2>&1; then
        rm -f "${out}"
        error "  適用の結果が JSON として壊れています。何も書きません"
        exit 1
    fi

    # テスト用の継ぎ目。横取りの検知は安全に関わる分岐なので、実際に横取りを
    # 起こして確かめられるようにしておく。通常の実行では未設定で何もしない。
    if [[ -n "${OE_APPLY_TEST_RACE:-}" ]]; then
        eval "${OE_APPLY_TEST_RACE}" || true
    fi

    # 置き換える直前に、読んだときと同じ内容かを確かめる。
    if [[ -e "${SETTINGS}" ]]; then
        now="$(cat "${SETTINGS}" 2>/dev/null || echo "")"
    else
        now=""
    fi
    if [[ "${now}" != "${before}" ]]; then
        rm -f "${out}"
        if [[ "${attempt}" -ge "${MAX_RETRY}" ]]; then
            error "  読んでから書くまでの間に他のプロセスが書き換え続けています。中止します"
            exit 1
        fi
        warn "  他のプロセスが書き換えたので読み直します（${attempt}/${MAX_RETRY}）"
        continue
    fi

    # 内容が変わらないなら書かない。バックアップも作らない。
    if [[ -n "${before}" ]] && jq -S . <<< "${before}" > "${out}.cmp" 2>/dev/null \
       && jq -S . "${out}" > "${out}.cmp2" 2>/dev/null \
       && cmp -s "${out}.cmp" "${out}.cmp2"; then
        rm -f "${out}" "${out}.cmp" "${out}.cmp2"
        info "  変更はありません"
        exit 0
    fi
    rm -f "${out}.cmp" "${out}.cmp2"

    # バックアップは「置き換える直前の版」を取る。最初に読んだ版ではない。
    if [[ -e "${SETTINGS}" ]]; then
        backup="${SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"
        if ! cp "${SETTINGS}" "${backup}"; then
            rm -f "${out}"
            error "  バックアップを作れないので何も書きません"
            exit 1
        fi
        info "  Backup: ${backup}"
    else
        mkdir -p "$(dirname "${SETTINGS}")"
    fi

    if ! mv "${out}" "${SETTINGS}"; then
        rm -f "${out}"
        error "  置き換えに失敗しました"
        exit 1
    fi
    info "  ${decl_count} item(s) applied"
    exit 0
done
