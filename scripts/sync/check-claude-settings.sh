#!/usr/bin/env bash
#
# check-claude-settings.sh — 宣言（canonical/claude/settings.harness.json）と
# 手元の ~/.claude/settings.json を突き合わせ、差分を報告する。読み取り専用。
#
# Usage:
#   ./scripts/sync/check-claude-settings.sh
#   ./scripts/sync/check-claude-settings.sh --settings /path/to/settings.json
#   ./scripts/sync/check-claude-settings.sh --declaration /path/to/decl.json
#   ./scripts/sync/check-claude-settings.sh --project-root /path/to/repo
#
# Exit:
#   0  差分なし
#   1  差分あり
#   2  検査を実行できない（宣言が読めない・jq が無い等）
#
# 何も書き換えない。直すのは sync 側の仕事で、こちらは報告だけ（issue #359 HG-D）。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DECLARATION="${REPO_ROOT}/canonical/claude/settings.harness.json"
KNOWN_KEYS="${REPO_ROOT}/canonical/claude/settings-known-keys.txt"
SETTINGS="${HOME}/.claude/settings.json"
PROJECT_ROOT="${REPO_ROOT}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --declaration) DECLARATION="$2"; shift 2 ;;
        --settings)    SETTINGS="$2"; shift 2 ;;
        --known-keys)  KNOWN_KEYS="$2"; shift 2 ;;
        --project-root) PROJECT_ROOT="$2"; shift 2 ;;
        -h|--help)
            sed -n '/^# Usage:/,/^set -uo pipefail/p' "$0" | sed '$d' | sed -e 's/^# //' -e 's/^#$//'
            exit 0 ;;
        *) error "Unknown argument: $1"; exit 2 ;;
    esac
done

if ! command -v jq >/dev/null 2>&1; then
    error "jq が必要です"
    exit 2
fi

if [[ ! -f "${DECLARATION}" ]]; then
    error "宣言ファイルが読めません: ${DECLARATION}"
    exit 2
fi

if ! jq -e . "${DECLARATION}" >/dev/null 2>&1; then
    error "宣言ファイルが JSON として読めません: ${DECLARATION}"
    exit 2
fi

# 宣言が空だと「差分なし」を名乗れてしまう。0 件のループが緑を返すのと、
# 本当に一致しているのを区別できなくなる（sync-bin.sh --check と同じ姿勢）。
decl_count="$(jq '.items | length' "${DECLARATION}")"
if [[ "${decl_count}" -eq 0 ]]; then
    error "宣言に項目がありません（母集団が空のまま緑を返さない）: ${DECLARATION}"
    exit 2
fi

has_diffs=false

# ---------------------------------------------------------------------------
# 期待値の解決: 各項目の source（file + pointer）から正本の値を取り出す。
# ---------------------------------------------------------------------------
# shellcheck disable=SC2016  # jq プログラムなのでシェルに展開させない
PTR_LIB='
def ptr2path($p):
  if $p == "" or $p == "/" then []
  else ($p | ltrimstr("/") | split("/")
        | map(gsub("~1"; "/") | gsub("~0"; "~"))) end;

def haspath($p):
  . as $doc
  | reduce $p[] as $k ({ok: true, cur: $doc};
      if .ok | not then .
      elif (.cur | type) == "object" and (.cur | has($k)) then {ok: true, cur: .cur[$k]}
      elif (.cur | type) == "array" and ($k | test("^[0-9]+$"))
           and ((.cur | length) > ($k | tonumber)) then {ok: true, cur: .cur[$k | tonumber]}
      else {ok: false, cur: null} end)
  | .ok;

# 葉のパス。述語は「値」ではなく「型の判定結果」で書く。paths(scalars) と書くと
# jq が select に値そのものを渡すので、値が false と null の葉が静かに落ちる。
def leafpaths:
  [paths(type != "object" and type != "array")]
  + [paths((type == "object" or type == "array") and length == 0)]
  | unique;
'

resolved="$(mktemp)"
resolve_failed=false
echo "[]" > "${resolved}"

while IFS=$'\t' read -r idx pointer op handler scope_behavior src_file src_pointer; do
    # jq 側は空欄を "-" で埋めている。bash の IFS はタブの連続を1つに畳むので、
    # 空フィールドをそのまま流すと以降の列がずれる。
    [[ "${handler}" == "-" ]] && handler=""
    [[ "${src_pointer}" == "-" ]] && src_pointer=""
    expected="null"
    if [[ -n "${src_file}" && "${src_file}" != "-" ]]; then
        abs_src="${src_file}"
        [[ "${abs_src}" != /* ]] && abs_src="${REPO_ROOT}/${src_file}"
        if [[ ! -f "${abs_src}" ]]; then
            error "  正本ファイルが見つかりません: ${pointer} → ${src_file}"
            resolve_failed=true
            continue
        fi
        if ! expected="$(jq -c --arg p "${src_pointer}" "${PTR_LIB} getpath(ptr2path(\$p))" "${abs_src}" 2>/dev/null)"; then
            error "  正本ファイルを読めません: ${pointer} → ${src_file}"
            resolve_failed=true
            continue
        fi
        if [[ "${expected}" == "null" ]]; then
            error "  正本に値がありません: ${pointer} → ${src_file}#${src_pointer}"
            resolve_failed=true
            continue
        fi
    fi
    # op と期待値の型が噛み合っていないと、判定が空集合への全称になって
    # 何を壊しても緑になる（merge-object にスカラーを与えた場合が該当）。
    exp_type="$(jq -r 'type' <<< "${expected}")"
    case "${op}" in
        merge-object)
            if [[ "${exp_type}" != "object" ]]; then
                error "  merge-object の正本がオブジェクトではありません: ${pointer} (${exp_type})"
                resolve_failed=true
                continue
            fi ;;
        union-array)
            if [[ "${exp_type}" != "array" ]]; then
                error "  union-array の正本が配列ではありません: ${pointer} (${exp_type})"
                resolve_failed=true
                continue
            fi ;;
        replace|absent|handler) ;;
        *)
            error "  扱えない op です: ${pointer} (${op})"
            resolve_failed=true
            continue ;;
    esac

    if jq -c \
        --arg pointer "${pointer}" \
        --arg op "${op}" \
        --arg handler "${handler}" \
        --arg scope_behavior "${scope_behavior}" \
        --argjson expected "${expected}" \
        --argjson idx "${idx}" \
        '. + [{pointer: $pointer, op: $op, handler: $handler,
               scope_behavior: $scope_behavior, expected: $expected, idx: $idx}]' \
        "${resolved}" > "${resolved}.tmp"; then
        mv "${resolved}.tmp" "${resolved}"
    else
        # 追記に失敗した項目を黙って落とすと、母集団が縮んだまま残りの項目で
        # 緑を返せてしまう。検査そのものを失敗にする。
        rm -f "${resolved}.tmp"
        error "  項目を検査対象に追加できませんでした: ${pointer}"
        resolve_failed=true
    fi
done < <(jq -r '.items | to_entries[]
    | [ (.key|tostring), .value.pointer, .value.op,
        (if (.value.handler // "") == "" then "-" else .value.handler end),
        (.value.scope_behavior // "override"),
        (.value.source.file // "-"),
        (if (.value.source.pointer // "") == "" then "-" else .value.source.pointer end) ]
    | @tsv' "${DECLARATION}")

if [[ "${resolve_failed}" == true ]]; then
    rm -f "${resolved}"
    error "  正本の解決に失敗したので検査を中止します"
    exit 2
fi

# ---------------------------------------------------------------------------
# (5) 適用できない状態 — 対象が通常ファイルか、JSON として読めるか。
# ---------------------------------------------------------------------------
settings_state="ok"
if [[ ! -e "${SETTINGS}" ]]; then
    settings_state="missing"
elif [[ -L "${SETTINGS}" ]]; then
    settings_state="symlink"
elif [[ ! -f "${SETTINGS}" ]]; then
    settings_state="not-regular"
elif ! jq -e . "${SETTINGS}" >/dev/null 2>&1; then
    settings_state="unparsable"
fi

echo "settings.json: ${SETTINGS}"
case "${settings_state}" in
    missing)
        warn "  一度も適用されていません（ファイルがありません）"
        has_diffs=true ;;
    symlink)
        error "  symlink なので適用できません（sync は触らずに skip します）"
        has_diffs=true ;;
    not-regular)
        error "  通常ファイルではないので適用できません"
        has_diffs=true ;;
    unparsable)
        error "  JSON として読めません（壊れている可能性）"
        has_diffs=true ;;
    ok)
        info "  読み取り可能" ;;
esac

# ---------------------------------------------------------------------------
# (1)(2) 項目ごとの一致と、未適用の検出。
# ---------------------------------------------------------------------------
echo ""
echo "宣言した項目（${decl_count} 件）:"

if [[ "${settings_state}" == "ok" ]]; then
    findings="$(jq -r --slurpfile decl "${resolved}" "
${PTR_LIB}
def marker: \"statusline-oe-heartbeat.sh\";

def verdict(\$item):
  . as \$actual
  | (\$item.pointer | ptr2path(.)) as \$path
  | if (\$actual | haspath(\$path) | not) then
      (if \$item.op == \"absent\" then [\"ok\", \"宣言どおり存在しません\"]
       else [\"missing\", \"手元にありません（未適用）\"] end)
    else
      (\$actual | getpath(\$path)) as \$got
      | if \$item.op == \"absent\" then
          [\"diff\", \"手元に残っています。宣言では消す指定です\"]
        elif \$item.op == \"replace\" then
          (if \$got == \$item.expected then [\"ok\", \"一致\"]
           else [\"diff\", \"値が正本と違います\"] end)
        elif \$item.op == \"merge-object\" then
          # all() の中では . が現在のパスなので、先に束縛してから \$got へ渡す。
          # そのまま \$got | haspath(.) と書くと . が \$got に置き換わって壊れる。
          ((\$item.expected | leafpaths) as \$lp
           | if all(\$lp[]; . as \$pp
                    | (\$got | haspath(\$pp))
                      and ((\$got | getpath(\$pp)) == (\$item.expected | getpath(\$pp))))
             then [\"ok\", \"正本の値をすべて含んでいます\"]
             else [\"diff\", \"正本の値のうち手元に無いか違うものがあります\"] end)
        elif \$item.op == \"union-array\" then
          (if (\$got | type) != \"array\" then [\"diff\", \"配列ではありません\"]
           elif all(\$item.expected[]; . as \$e | any(\$got[]; . == \$e))
           then [\"ok\", \"正本の項目をすべて含んでいます\"]
           else [\"diff\", \"正本の項目のうち手元に無いものがあります\"] end)
        elif \$item.op == \"handler\" and \$item.handler == \"statusline-wrap\" then
          ((\$got.command // \"\") as \$cmd
           | if (\$cmd | contains(marker) | not) then
               [\"diff\", \"拍動 producer が statusLine のコマンドにいません\"]
             elif (\$cmd | contains(\"OE_HEARTBEAT_WRAP_CMD\"))
                  and ((\$cmd | capture(\"OE_HEARTBEAT_WRAP_CMD=(?<w>[^ ]+)\").w // \"\") == \"\") then
               [\"diff\", \"包んだ元のコマンドが失われています\"]
             elif \$got.type != \$item.expected.type then
               [\"diff\", \"type が正本と違います\"]
             elif \$got.refreshInterval != \$item.expected.refreshInterval then
               [\"diff\", \"refreshInterval が正本と違います\"]
             else [\"ok\", \"拍動 producer が入っています（包んだ表示は保たれています）\"] end)
        else [\"unknown\", (\"扱えない op です: \" + \$item.op)] end
    end;

\$decl[0][] as \$item
| verdict(\$item) as \$v
| [\$v[0], \$item.pointer, \$item.op, \$v[1]] | @tsv
" "${SETTINGS}" 2>/dev/null)"

    if [[ -z "${findings}" ]]; then
        error "  判定を計算できませんでした"
        has_diffs=true
    else
        while IFS=$'\t' read -r verdict pointer op message; do
            case "${verdict}" in
                ok)      info "  一致 ${pointer} (${op}) — ${message}" ;;
                missing) warn "  未適用 ${pointer} (${op}) — ${message}"; has_diffs=true ;;
                *)       warn "  差分 ${pointer} (${op}) — ${message}"; has_diffs=true ;;
            esac
        done <<< "${findings}"
    fi
else
    while IFS=$'\t' read -r pointer op; do
        warn "  未適用 ${pointer} (${op}) — settings.json を読めないので判定できません"
    done < <(jq -r '.[] | [.pointer, .op] | @tsv' "${resolved}")
    has_diffs=true
fi

# ---------------------------------------------------------------------------
# (3) 上位スコープに同名の項目があるか。マージされる項目と、負ける項目で文言を分ける。
# ---------------------------------------------------------------------------
echo ""
echo "上位スコープの同名項目（対象: ${PROJECT_ROOT}）:"
shadow_found=false
for pf in "${PROJECT_ROOT}/.claude/settings.json" "${PROJECT_ROOT}/.claude/settings.local.json"; do
    [[ -f "${pf}" ]] || continue
    jq -e . "${pf}" >/dev/null 2>&1 || { warn "  読めません: ${pf}"; continue; }
    while IFS=$'\t' read -r pointer scope_behavior; do
        top_key="$(printf '%s' "${pointer}" | sed -e 's|^/||' -e 's|/.*$||' -e 's|~1|/|g' -e 's|~0|~|g')"
        if jq -e --arg k "${top_key}" 'has($k)' "${pf}" >/dev/null 2>&1; then
            shadow_found=true
            if [[ "${scope_behavior}" == "merge" ]]; then
                info "  追加 ${top_key} が $(basename "${pf}") にもあります。この項目はスコープをまたいでマージされるので、hub の分は消えません"
            else
                warn "  上書き ${top_key} が $(basename "${pf}") にもあります。この項目は上位が勝つので、hub の値はこのリポジトリでは効きません"
                has_diffs=true
            fi
        fi
    done < <(jq -r '.[] | [.pointer, .scope_behavior] | @tsv' "${resolved}")
done
[[ "${shadow_found}" == false ]] && info "  同名の項目はありません"

# ---------------------------------------------------------------------------
# (6) 宣言に書いた項目名が公式の一覧にあるか。古くなる一覧なので警告どまり。
# ---------------------------------------------------------------------------
echo ""
echo "宣言した項目名の綴り:"
if [[ -f "${KNOWN_KEYS}" ]]; then
    while IFS= read -r pointer; do
        top_key="$(printf '%s' "${pointer}" | sed -e 's|^/||' -e 's|/.*$||' -e 's|~1|/|g' -e 's|~0|~|g')"
        if grep -qxF "${top_key}" <(grep -vE '^#|^$' "${KNOWN_KEYS}"); then
            info "  ${top_key} は公式の一覧にあります"
        else
            warn "  ${top_key} は公式の一覧にありません（一覧が古い可能性もあるので警告どまり）"
        fi
    done < <(jq -r '.[].pointer' "${resolved}")
else
    warn "  公式キー一覧が見つかりません: ${KNOWN_KEYS}"
fi

# ---------------------------------------------------------------------------
# (4) 見ていないスコープの明示。「一致」を「実際に効いている」と読ませない。
# ---------------------------------------------------------------------------
echo ""
echo "この検査が見ていないもの:"
jq -r '.unchecked_scopes[]? | "  - " + .' "${DECLARATION}"
echo "  - 走っているセッションの実際の値（公式に取得する手段がありません）"

rm -f "${resolved}"

echo ""
if [[ "${has_diffs}" == true ]]; then
    error "claude settings: 差分あり"
    exit 1
fi
info "claude settings: 宣言どおり"
exit 0
