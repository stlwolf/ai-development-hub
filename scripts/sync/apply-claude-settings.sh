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

# JSON として読めるかの判定は jq -e 'type' で行う。素の jq -e . は、最後の出力が
# null か false のときに偽を返すので、正しい JSON である null や false を壊れて
# いると誤判定する。逆に jq empty は空ファイルを通してしまう。type を出させれば、
# 値がある（null や false も含む）ときだけ真になり、空ファイルと壊れた JSON は
# どちらも偽になる。
[[ -f "${DECLARATION}" ]] || { error "宣言ファイルが読めません: ${DECLARATION}"; exit 2; }
jq -e 'type' "${DECLARATION}" >/dev/null 2>&1 || { error "宣言ファイルが JSON として読めません: ${DECLARATION}"; exit 2; }

decl_count="$(jq '.items | length' "${DECLARATION}")"
if [[ "${decl_count}" -eq 0 ]]; then
    error "宣言に項目がありません: ${DECLARATION}"
    exit 2
fi

# ---------------------------------------------------------------------------
# 正本の解決。1項目でも解けなければ何も書かない（部分適用を作らない）。
# ---------------------------------------------------------------------------
resolved="$(mktemp)" || { error "作業ファイルを作れません"; exit 2; }
# 後始末は1本にまとめる。後から trap を張り直すと前のものが消えて、
# 先に作った作業ファイルが残り続ける。
read_copy=""
cleanup() { rm -f "${resolved}" "${resolved}.tmp" "${read_copy}"; }
trap cleanup EXIT
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
    # 形だけでは足りない。"/" は / で始まるが、解いた結果は空になって
    # 文書全体を指す。実際に解いた長さで確かめる。
    ptr_len="$(jq -rn --arg p "${pointer}" '
        def ptr2path($x): if $x == "" then []
          else ($x | ltrimstr("/") | split("/")
                | map(gsub("~1"; "/") | gsub("~0"; "~"))) end;
        ptr2path($p) | length' 2>/dev/null || echo 0)"
    if [[ "${ptr_len}" -eq 0 ]]; then
        error "  文書全体を指すポインタは使えません: [${pointer}]"
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
    # 値を書く操作は正本を要る。source が無いまま通すと null を書き込む。
    case "${op}" in
        replace|merge-object|union-array|handler)
            if [[ -z "${src_file}" || "${src_file}" == "-" ]]; then
                error "  この操作には値の出どころが要ります: ${pointer} (${op})"
                resolve_failed=true; continue
            fi ;;
    esac

    exp_type="$(jq -r 'type' <<< "${expected}")"
    case "${op}" in
        merge-object) [[ "${exp_type}" == "object" ]] || { error "  merge-object の正本がオブジェクトではありません: ${pointer} (${exp_type})"; resolve_failed=true; continue; } ;;
        union-array)  [[ "${exp_type}" == "array" ]] || { error "  union-array の正本が配列ではありません: ${pointer} (${exp_type})"; resolve_failed=true; continue; } ;;
        replace|absent) ;;
        handler)
            # 名前を検証する。知らない名前を通すと、適用側が何もしないまま
            # 「適用した」と返る。宣言の書き間違いが素通りする形になる。
            case "${handler}" in
                statusline-wrap)
                    # 退避する元コマンドの取り出しが .statusLine.command に固定なので、
                    # 別の場所に宣言されるとハンドラの中身とずれる。置き場を縛る。
                    if [[ "${pointer}" != "/statusLine" ]]; then
                        error "  statusline-wrap は /statusLine にしか宣言できません: ${pointer}"
                        resolve_failed=true; continue
                    fi ;;
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
      # 手元の値がオブジェクトでなければ触らない。そのまま重ねると jq の
      # 掛け合わせが例外になり、他の項目も含めて適用が丸ごと止まる。
      # union-array と statusLine と同じ姿勢に揃える。
      (if ((getpath($path)) != null) and (((getpath($path)) | type) != "object") then .
       else setpath($path; ((getpath($path) // {}) * $item.expected)) end)
    elif $item.op == "union-array" then
      # 手元の値が配列でなければ触らない。壊して書き換えるより、そのまま
      # 残して検査に出す方がよい（statusLine の扱いと同じ姿勢）。
      if ((getpath($path)) != null) and (((getpath($path)) | type) != "array") then . else
      # 重複の判定は jq の等価比較で行う（tojson だとキーの順が違うオブジェクトを
      # 別物として残してしまう）。手元の並びは変えず、無いものだけを後ろに足す。
      # 正本側に重複があれば、そちらも取り除いてから足す。
      # 「重複を除く」の契約どおり、手元の側の重複も畳む。並びは先に出た順を保つ。
      (((getpath($path) // [])
        | reduce .[] as $e ([]; if any(.[]; . == $e) then . else . + [$e] end)) as $cur
       | ($item.expected
          | reduce .[] as $e ([]; if any(.[]; . == $e) then . else . + [$e] end)) as $add
       | setpath($path; ($cur + ($add | map(select(. as $e | any($cur[]; . == $e) | not)))))) end
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
before_exists=0
now_exists=0
backups_made=()
ever_existed=0
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

    rm -f "${read_copy}"
    if [[ -e "${SETTINGS}" ]]; then
        before_exists=1
        ever_existed=1
        # 読んだ瞬間の実体をそのまま写し取る。以降の判断も、写しを取る先も、
        # すべてこの複製を使う。ファイルを2度読むと、その間に空にされたり
        # 置き換えられたりして、判断に使った内容と写しの内容が食い違う。
        # 名前を予測できると、先回りして symlink を置かれたときに別の場所へ
        # 書いてしまう。mktemp に作らせる。
        if ! read_copy="$(mktemp "${SETTINGS}.read.XXXXXX")"; then
            error "  作業ファイルを作れません: ${SETTINGS}"
            exit 1
        fi
        if ! cat "${SETTINGS}" > "${read_copy}" 2>/dev/null; then
            error "  読めません: ${SETTINGS}"
            exit 1
        fi
        if ! jq -e 'type' "${read_copy}" >/dev/null 2>&1; then
            warn "  JSON として読めないので触りません（壊れている可能性）: ${SETTINGS}"
            [[ "${#backups_made[@]}" -gt 0 ]] && info "  読んだ時点の内容: ${backups_made[0]}"
            rm -f "${read_copy}"
            exit 0
        fi
        # いちばん外側がオブジェクトでなければ触らない。宣言はキーを指すので、
        # 配列や文字列や null の文書は対象外である。とくに null は、jq の
        # setpath がそこにオブジェクトを作ってしまうので、黙っていると文書を
        # まるごと置き換えることになる。
        top_type="$(jq -r 'type' "${read_copy}" 2>/dev/null || echo unknown)"
        if [[ "${top_type}" != "object" ]]; then
            warn "  いちばん外側がオブジェクトではないので触りません（${top_type}）: ${SETTINGS}"
            rm -f "${read_copy}"
            exit 0
        fi
        current_file="${read_copy}"
    else
        if [[ "${ever_existed}" -eq 1 ]]; then
            # 前の試行では在ったのに消えている。ここで作ると、宣言した項目だけの
            # ファイルになって個人層が失われた形で残る。書かずに止め、写しの
            # 在処を伝える方がよい。
            error "  読んでいる間に settings.json が消えました。何も書きません: ${SETTINGS}"
            [[ "${#backups_made[@]}" -gt 0 ]] && error "  読んだ時点の内容を残しました: ${backups_made[0]}"
            exit 1
        fi
        before_exists=0
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
    if ! jq -e 'type' "${out}" >/dev/null 2>&1; then
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

    # (a) 変更が無いなら、そもそも何もしない。
    if [[ "${before_exists}" -eq 1 ]]; then
        # 2つの正規化の終了コードを両方見る。見ないと、書き込みに失敗して
        # 両方が空ファイルになったときに cmp が一致と判定し、何も適用して
        # いないのに成功を名乗る。
        cmp_ok=1
        jq -S . "${read_copy}" > "${out}.cmp" 2>/dev/null || cmp_ok=0
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

    # (b0) ここまで来たら書き換えが要る。写しを1度だけ取り、以後どの経路でも
    #      消さない。横取りで元の内容が消える（削除・空化・置換）ことがあり、
    #      そのとき手元に残る唯一の写しがこれになる。やり直しのたびに消すと、
    #      いちばん復旧が要る場面で復旧できなくなる。
    if [[ "${before_exists}" -eq 1 ]]; then
        # 試行ごとに1つ取る。最初のものは元の内容を保ち、最後のものが
        # 置き換え直前の版になる。以前のものは消さない（横取りで元が
        # 失われたときに、いちばん古い写しだけが復旧の手がかりになる）。
        # 名前は時刻で読めるようにしつつ、実体の作成は mktemp に任せる
        # （既にあるファイルを踏まないため）。
        # 試行番号を名前に入れておく。同じ秒に2つできたときでも、名前の順で
        # 古い順に並ぶ（最古＝元の内容、最後＝置き換え直前の版）。
        if ! bk="$(mktemp "${SETTINGS}.bak.$(date +%Y%m%d-%H%M%S).${attempt}.XXXXXX")"; then
            rm -f "${out}"
            error "  バックアップを作れないので何も書きません"
            exit 1
        fi
        # 実体からではなく、読んだ瞬間の写しから作る。実体を読み直すと、
        # その間に空にされていた場合に壊れた内容を写してしまう。
        if ! cat "${read_copy}" > "${bk}" 2>/dev/null; then
            rm -f "${out}"
            error "  バックアップを作れないので何も書きません"
            exit 1
        fi
        backups_made+=("${bk}")
    fi

    # (b) 置き換えに関わる相手の種別をもう一度見る。写しを取った直後に見る。
    #     FIFO へ差し替えられていると読み書きが待ち続けるし、ディレクトリなら
    #     置き換えがその中へ移動して成功してしまう。どちらも触らないのが正しい。
    if [[ -L "${SETTINGS}" || ( -e "${SETTINGS}" && ! -f "${SETTINGS}" ) ]]; then
        rm -f "${out}"
        warn "  symlink かディレクトリなどに差し替わったので触りません: ${SETTINGS}"
        [[ "${#backups_made[@]}" -gt 0 ]] && info "  読んだ時点の内容: ${backups_made[0]}"
        exit 0
    fi

    # (c) 最後の確認。ここと置き換えの間には何も置かない。
    #     不在と空を区別する。区別しないと、最初は無かったファイルを別の
    #     プロセスが空で作った場合に「変わっていない」と判定して上書きする。
    if [[ -e "${SETTINGS}" ]]; then
        now_exists=1
    else
        now_exists=0
    fi
    same=1
    if [[ "${now_exists}" -ne "${before_exists}" ]]; then
        same=0
    elif [[ "${before_exists}" -eq 1 ]]; then
        # 文字列ではなくバイト単位で比べる。末尾の改行の違いも取りこぼさない。
        cmp -s "${read_copy}" "${SETTINGS}" || same=0
    fi
    if [[ "${same}" -eq 0 ]]; then
        rm -f "${out}"
        if [[ "${attempt}" -ge "${MAX_RETRY}" ]]; then
            error "  読んでから書くまでの間に他のプロセスが書き換え続けています。中止します"
            [[ "${#backups_made[@]}" -gt 0 ]] && error "  読んだ時点の内容を残しました: ${backups_made[0]}"
            exit 1
        fi
        warn "  他のプロセスが書き換えたので読み直します（${attempt}/${MAX_RETRY}）"
        continue
    fi

    # (d) 置き換える直前にもう一度だけ種別を見る。中身が同じファイルへの
    #     symlink に差し替えられると、上の内容比較は通ってしまう。
    if [[ -L "${SETTINGS}" || ( -e "${SETTINGS}" && ! -f "${SETTINGS}" ) ]]; then
        rm -f "${out}"
        warn "  直前に symlink かディレクトリへ差し替わったので触りません: ${SETTINGS}"
        [[ "${#backups_made[@]}" -gt 0 ]] && info "  読んだ時点の内容: ${backups_made[0]}"
        exit 0
    fi

    if ! mv "${out}" "${SETTINGS}"; then
        rm -f "${out}"
        error "  置き換えに失敗しました"
        exit 1
    fi
    if [[ "${#backups_made[@]}" -gt 0 ]]; then
        info "  Backup: ${backups_made[$(( ${#backups_made[@]} - 1 ))]}"
    fi
    rm -f "${read_copy}"
    info "  ${decl_count} item(s) applied"
    exit 0
done
