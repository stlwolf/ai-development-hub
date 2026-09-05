#!/usr/bin/env bash
#
# apply-claude-settings.sh — 宣言（canonical/claude/settings.harness.json）に書かれた
# 項目だけを ~/.claude/settings.json へ適用する。宣言に無い項目には一切触らない。
#
# Usage:
#   ./scripts/sync/apply-claude-settings.sh
#   ./scripts/sync/apply-claude-settings.sh --settings /path/to/settings.json
#   ./scripts/sync/apply-claude-settings.sh --declaration /path/to/decl.json
#   ./scripts/sync/apply-claude-settings.sh --repo-root /path/to/repo
#     （宣言の source.file は相対パスなので、その基準点を明示したいときに使う）
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
        --repo-root)   [[ $# -ge 2 ]] || { error "--repo-root に値がありません"; exit 2; }
                       REPO_ROOT="$2"; shift 2 ;;
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

    # ポインタの妥当性。空文字は JSON Pointer では文書全体を指すので、これを
    # 通すと設定ファイルの根をまるごと置き換えて個人層を消してしまう。
    # 配列の添字は扱わない（宣言はオブジェクトのキーだけを指す契約）。
    if [[ -z "${pointer}" || "${pointer}" != /* ]]; then
        error "  ポインタは / で始まる必要があります: [${pointer}]"
        resolve_failed=true; continue
    fi
    bad_seg=""
    for chk in "${pointer}" "${src_pointer}"; do
      [[ -z "${chk}" ]] && continue
      while IFS= read -r seg; do
        [[ -z "${seg}" ]] && continue
        if [[ "${seg}" =~ ^[0-9]+$ ]]; then bad_seg="${seg}"; break; fi
      # 末尾に改行を付ける。付けないと最後の区切りが read に拾われない。
      done < <(printf '%s\n' "${chk#/}" | tr '/' '\n')
      [[ -n "${bad_seg}" ]] && break
    done
    if [[ -n "${bad_seg}" ]]; then
        error "  配列の添字は宣言で扱えません: ${pointer}（区切り: ${bad_seg}）"
        resolve_failed=true; continue
    fi

    expected="null"
    if [[ -n "${src_file}" && "${src_file}" != "-" ]]; then
        abs_src="${src_file}"
        [[ "${abs_src}" != /* ]] && abs_src="${REPO_ROOT}/${src_file}"
        if [[ ! -f "${abs_src}" ]]; then
            error "  正本ファイルが見つかりません: ${pointer} → ${src_file}"
            resolve_failed=true; continue
        fi
        # 値が null であることと、パスが無いことを区別する。区別しないと、
        # 正本に置いた null を適用できない。
        # shellcheck disable=SC2016  # jq プログラムなのでシェルに展開させない
        if ! probe="$(jq -c --arg p "${src_pointer}" '
              def ptr2path($p): if $p == "" then []
                else ($p | ltrimstr("/") | split("/")
                      | map(gsub("~1"; "/") | gsub("~0"; "~"))) end;
              (ptr2path($p)) as $path
              | {found: ([paths] | any(. == $path)) or ($path | length) == 0,
                 value: getpath($path)}' "${abs_src}" 2>/dev/null)"; then
            error "  正本ファイルを読めません: ${pointer} → ${src_file}"
            resolve_failed=true; continue
        fi
        if [[ "$(jq -r '.found' <<< "${probe}")" != "true" ]]; then
            error "  正本にそのパスがありません: ${pointer} → ${src_file}#${src_pointer}"
            resolve_failed=true; continue
        fi
        expected="$(jq -c '.value' <<< "${probe}")"
    fi
    exp_type="$(jq -r 'type' <<< "${expected}")"
    case "${op}" in
        merge-object) [[ "${exp_type}" == "object" ]] || { error "  merge-object の正本がオブジェクトではありません: ${pointer} (${exp_type})"; resolve_failed=true; continue; } ;;
        union-array)  [[ "${exp_type}" == "array" ]] || { error "  union-array の正本が配列ではありません: ${pointer} (${exp_type})"; resolve_failed=true; continue; } ;;
        replace|absent) ;;
        handler)
            # 名前を検証する。知らない名前を通すと、適用側が何もしないまま
            # 「適用した」と返る。宣言の書き間違いが素通りする形になる。
            case "${handler}" in
                statusline-wrap) ;;
                *) error "  知らないハンドラです: ${pointer} (${handler:-空})"; resolve_failed=true; continue ;;
            esac ;;
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

# shellcheck disable=SC2016  # jq プログラムなのでシェルに展開させない
JQ_APPLY='
# JSON Pointer: 空文字が文書全体を指し、"/" は空文字のキーを指す。
# 添字は解決時に弾いているので、ここでは文字列のキーだけを扱う。
def ptr2path($p): if $p == "" then []
  else ($p | ltrimstr("/") | split("/") | map(gsub("~1"; "/") | gsub("~0"; "~"))) end;

def apply_item($item):
  (ptr2path($item.pointer)) as $path
  | if $item.op == "replace" then setpath($path; $item.expected)
    elif $item.op == "absent" then delpaths([$path])
    elif $item.op == "merge-object" then
      setpath($path; ((getpath($path) // {}) * $item.expected))
    elif $item.op == "union-array" then
      # 重複の判定は jq の等価比較で行う（tojson だとキーの順が違うオブジェクトを
      # 別物として残してしまう）。手元の並びは変えず、無いものだけを後ろに足す。
      # 正本側に重複があれば、そちらも取り除いてから足す。
      # 「重複を除く」の契約どおり、手元の側の重複も畳む。並びは先に出た順を保つ。
      (((getpath($path) // [])
        | reduce .[] as $e ([]; if any(.[]; . == $e) then . else . + [$e] end)) as $cur
       | ($item.expected
          | reduce .[] as $e ([]; if any(.[]; . == $e) then . else . + [$e] end)) as $add
       | setpath($path; ($cur + ($add | map(select(. as $e | any($cur[]; . == $e) | not))))))
    elif $item.op == "handler" and $item.handler == "statusline-wrap" then
      # 現行の3分岐をそのまま写す。
      #   未設定           → 正本を載せる
      #   既に beat producer → command は保持し他のフィールドだけ更新（二重に包まない）
      #   独自のもの        → 元コマンドを退避して包む。padding 等の既存フィールドは残す
      # 現在値がオブジェクトでも空でもないなら触らない。旧実装は .statusLine.command
      # の取り出しに失敗して、その項目だけ skip していた。挙動を揃える。
      ((getpath($path)) as $raw
       | if ($raw != null) and (($raw | type) != "object") then .
         else
      (($raw // {}) as $cur
       | (if ($cur | type) == "object" and ($cur.command | type) == "string"
          then $cur.command else "" end) as $cmd
       | if $cmd == "" then
           setpath($path; (( if ($cur|type)=="object" then $cur else {} end) + $item.expected))
         elif ($cmd | contains($marker)) then
           setpath($path; ($cur + $item.expected + {command: $cmd}))
         else
           setpath($path; ($cur + $item.expected + {command: ($wrap_prefix + " " + $item.expected.command)}))
         end) end)
    else . end;

reduce $decl[0][] as $item (.; apply_item($item))
'

attempt=0
while :; do
    attempt=$((attempt + 1))

    # 書けない相手かどうかは毎回見る。1回目の後に symlink へ差し替えられると、
    # 次の試行でリンク先を読んで、置き換えで symlink 自体を通常ファイルにしてしまう。
    if [[ -L "${SETTINGS}" ]]; then
        # -L を先に見る。-e はリンクを辿るので、解決先が消えた symlink を取り逃がす。
        warn "  symlink なので触りません: ${SETTINGS}"
        exit 0
    fi
    if [[ -e "${SETTINGS}" && ! -f "${SETTINGS}" ]]; then
        warn "  通常ファイルではないので触りません: ${SETTINGS}"
        exit 0
    fi

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

    # 一時ファイルは settings と同じディレクトリに作る（mv を同一 FS の rename に
    # するため）。親が無いと mktemp がそこで失敗するので、先に作っておく。
    if ! mkdir -p "$(dirname "${SETTINGS}")"; then
        error "  置き場のディレクトリを作れません: $(dirname "${SETTINGS}")"
        exit 1
    fi
    out="$(mktemp "${SETTINGS}.tmp.XXXXXX")" || { error "  一時ファイルを作れません"; exit 1; }
    # settings は argv でなくファイルから読む。文書全体を引数に載せると、
    # 大きな設定で引数長の上限に当たって落ちる。宣言側と同じ渡し方に揃える。
    base_file="${current_file}"
    if [[ -z "${base_file}" ]]; then
        base_file="${out}.base"
        echo '{}' > "${base_file}" || { rm -f "${out}"; error "  作業ファイルに書けません"; exit 1; }
    fi
    if ! jq -n --slurpfile decl "${resolved}" --slurpfile base "${base_file}" \
            --arg marker "${marker}" --arg wrap_prefix "${wrap_prefix}" \
            "\$base[0] | ${JQ_APPLY}" > "${out}" 2>/dev/null; then
        rm -f "${out}.base"
        rm -f "${out}"
        error "  適用の計算に失敗しました"
        exit 1
    fi
    rm -f "${out}.base"
    if ! jq -e . "${out}" >/dev/null 2>&1; then
        rm -f "${out}"
        error "  適用の結果が JSON として壊れています。何も書きません"
        exit 1
    fi

    # ここから先の順序が要になる。確かめてから置き換えるまでの間に、比較や
    # バックアップのような時間のかかる処理を挟むと、その隙に他のプロセスが
    # 書いた内容を古い計算結果で踏み潰す。だから重い処理を全部先に済ませ、
    # 最後の確認の直後に置き換えだけを行う。
    #
    # rename の直前と直後の隙間そのものは、どう並べても無くせない。ここで
    # できるのは窓を最小にすることだけである。

    # (a) 変更が無いなら、そもそも何もしない（バックアップも作らない）。
    if [[ -n "${before}" ]]; then
        # 2つの正規化の終了コードを両方見る。見ないと、書き込みに失敗して
        # 両方が空ファイルになったときに cmp が一致と判定し、何も適用して
        # いないのに成功を名乗る。
        cmp_ok=1
        jq -S . <<< "${before}" > "${out}.cmp" 2>/dev/null || cmp_ok=0
        jq -S . "${out}" > "${out}.cmp2" 2>/dev/null || cmp_ok=0
        if [[ "${cmp_ok}" -eq 1 && -s "${out}.cmp" && -s "${out}.cmp2" ]] && cmp -s "${out}.cmp" "${out}.cmp2"; then
            rm -f "${out}" "${out}.cmp" "${out}.cmp2"
            info "  変更はありません"
            exit 0
        fi
        if [[ "${cmp_ok}" -eq 0 ]]; then
            rm -f "${out}" "${out}.cmp" "${out}.cmp2"
            error "  変更の有無を比べられませんでした。何も書きません"
            exit 1
        fi
    fi
    rm -f "${out}.cmp" "${out}.cmp2"

    # (b) バックアップを先に取る。中身は下の確認で before と一致することを
    #     保証するので、「置き換える直前の版」と同じものになる。
    backup=""
    if [[ -e "${SETTINGS}" ]]; then
        # 秒精度だけだと、同じ秒に走った2つの実行が同じ名前を共有してしまう。
        backup="${SETTINGS}.bak.$(date +%Y%m%d-%H%M%S).$$"
        if ! cp "${SETTINGS}" "${backup}"; then
            rm -f "${out}"
            error "  バックアップを作れないので何も書きません"
            exit 1
        fi
    fi

    # (c) 最後の確認。ここと置き換えの間には何も置かない。
    if [[ -e "${SETTINGS}" ]]; then
        now="$(cat "${SETTINGS}" 2>/dev/null || echo "")"
    else
        now=""
    fi
    if [[ "${now}" != "${before}" ]]; then
        rm -f "${out}"
        if [[ "${attempt}" -ge "${MAX_RETRY}" ]]; then
            # 諦めるときはバックアップを残す。何が起きていたかを後から見られる
            # ようにするためで、やり直す場合だけ消す。
            error "  読んでから書くまでの間に他のプロセスが書き換え続けています。中止します"
            [[ -n "${backup}" ]] && error "  読んだ時点の内容を残しました: ${backup}"
            exit 1
        fi
        [[ -n "${backup}" ]] && rm -f "${backup}"
        warn "  他のプロセスが書き換えたので読み直します（${attempt}/${MAX_RETRY}）"
        continue
    fi

    # 置き換える直前にもう一度 symlink を見る。中身が同じファイルへの symlink に
    # 差し替えられると、上の内容比較は通ってしまう。ここで見ないと rename が
    # symlink そのものを通常ファイルに変えてしまう（全体 symlink を棄却した
    # 理由と同じ現象を、自分の配布スクリプトで起こすことになる）。
    if [[ -L "${SETTINGS}" || ( -e "${SETTINGS}" && ! -f "${SETTINGS}" ) ]]; then
        rm -f "${out}"
        [[ -n "${backup}" ]] && rm -f "${backup}"
        # ディレクトリへ差し替えられていると mv がその中へ移動して成功してしまう。
        warn "  直前に symlink かディレクトリへ差し替わったので触りません: ${SETTINGS}"
        exit 0
    fi

    if ! mv "${out}" "${SETTINGS}"; then
        rm -f "${out}"
        error "  置き換えに失敗しました"
        exit 1
    fi
    [[ -n "${backup}" ]] && info "  Backup: ${backup}"
    info "  ${decl_count} item(s) applied"
    exit 0
done
