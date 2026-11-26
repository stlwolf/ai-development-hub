#!/bin/bash
#
# check-codex-guardrails.sh
#
# canonical/rules と canonical/codex/AGENTS.md の整合を検証する。
# canonical/rules にあるルールを全部並べ、1本ずつ AGENTS.md に載っているかを見る。
#
# Usage:
#   ./scripts/check-codex-guardrails.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# 検査（tests/scripts/test_check_codex_guardrails.sh）が、置き場を一時の場所に向けるための2つの変数。
RULES_DIR="${CODEX_GUARDRAILS_RULES_DIR:-${REPO_ROOT}/canonical/rules}"
CODEX_AGENTS_FILE="${CODEX_GUARDRAILS_AGENTS_FILE:-${REPO_ROOT}/canonical/codex/AGENTS.md}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

missing_count=0
excluded_count=0

# 検査の向き（#332）: canonical/rules/ にあるルールを全部並べ、1本ずつ AGENTS.md に載っているかを見る。
# 検査する語をここに並べる向きにすると、ルールを足したときに検査が追随せず、欠けたまま緑で通る。
#
# 「載っている」の決め方は、次の順で1つだけ当たる。
#   1. 表に excluded の行がある            → 載せていないルール。検査せず、WARN で毎回知らせる。
#   2. 表に pattern の行がある             → その語が全部 AGENTS.md にあること（大文字と小文字を区別する）。
#   3. どちらにも無い（既定）              → ルールの名前（例: `foo-bar-rule`）か、名前から作った見出しの語
#                                            （例: `Foo Bar`。大文字と小文字は区別しない）が AGENTS.md にあること。
# ルールを1本足したときは、AGENTS.md に見出しの語か名前で載せれば、この検査を直さなくても通る。
# AGENTS.md の語がルールの名前と違うときだけ、下の表 RULE_TABLE に pattern の行を足す。

# 語と除外の表。1行が `ルールの名前|種類|値` で、種類は pattern（AGENTS.md に在るべき語）か
# excluded（載せていない理由）。語が複数あるルールは、pattern の行を重ねる。
# rule_patterns・rule_excluded・table_rule_names の3つは、どれもこの表だけを読む。名前の一覧を別に持つと、
# 表に足した行が「置き場に無い古い名前」の検査から漏れる。
RULE_TABLE='behavioral-rule|pattern|Evidence First
behavioral-rule|pattern|CLI Native
behavioral-rule|pattern|Safe Operations
behavioral-rule|pattern|Minimal Scope
behavioral-rule|pattern|Incremental Steps
behavioral-rule|pattern|Follow Existing Patterns
behavioral-rule|pattern|Root Cause
execution-policy-rule|pattern|Execution Discipline
output-format-rule|pattern|Output Contract
input-style-rule|pattern|Input Handling
implementation-gate-rule|pattern|planning phase
careful-operations-rule|excluded|AGENTS.md にまだ載せていない（載せるかは未決。#332 では検査だけを直した）
evidence-verification-rule|excluded|AGENTS.md にまだ載せていない（載せるかは未決。#332 では検査だけを直した）
workflow-awareness-rule|excluded|AGENTS.md にまだ載せていない（載せるかは未決。#332 では検査だけを直した）'

# table_values <ルールの名前> <種類> — 表の値を1行に1つ出す。値の中の `|` はそのまま残す。
table_values() {
    printf '%s\n' "$RULE_TABLE" | awk -F'|' -v name="$1" -v kind="$2" '
        $1 == name && $2 == kind { sub(/^[^|]*[|][^|]*[|]/, ""); print }'
}

# rule_patterns <ルールの名前> — AGENTS.md に在るべき語を1行に1つ出す。既定の決め方でよいルールは何も出さない。
rule_patterns() { table_values "$1" pattern; }

# rule_excluded <ルールの名前> — AGENTS.md に載せていないルールなら、その理由を出す。
# 表に excluded で書いたルールは検査を通すが、実行のたびに WARN に出る（黙って欠けているのと見分けるため）。
rule_excluded() { table_values "$1" excluded; }

# table_rule_names — 表に名前があるルールを、重なりを除いて1行に1つ出す。
table_rule_names() { printf '%s\n' "$RULE_TABLE" | awk -F'|' 'NF && !seen[$1]++ { print $1 }'; }

# table_bad_lines — 形が崩れた行（名前か値が空、種類が pattern でも excluded でもない）を出す。
# 種類を打ち間違えた行は、どの決め方にも当たらず、そのルールが既定の決め方に落ちてしまう。
table_bad_lines() {
    printf '%s\n' "$RULE_TABLE" | awk -F'|' '
        NF == 0 { next }
        NF < 3 || $1 == "" || $3 == "" || ($2 != "pattern" && $2 != "excluded") { print }'
}

# rule_title <ルールの名前> — `foo-bar-rule` から `Foo Bar` を作る。
rule_title() {
    printf '%s\n' "${1%-rule}" | awk -F- '{
        out = ""
        for (i = 1; i <= NF; i++) out = out (i > 1 ? " " : "") toupper(substr($i, 1, 1)) substr($i, 2)
        print out
    }'
}

missing() {
    error "Missing in canonical/codex/AGENTS.md: $1"
    missing_count=$((missing_count + 1))
}

check_rule() {
    local name="$1" reason patterns pattern title
    reason="$(rule_excluded "$name")"
    patterns="$(rule_patterns "$name")"
    if [[ -n "$reason" && -n "$patterns" ]]; then
        missing "${name}（表 RULE_TABLE に pattern と excluded の両方がある。どちらかにする）"
        return 0
    fi
    if [[ -n "$reason" ]]; then
        warn "Excluded: ${name} — ${reason}"
        excluded_count=$((excluded_count + 1))
        return 0
    fi
    if [[ -n "$patterns" ]]; then
        while IFS= read -r pattern; do
            grep -Fq -- "$pattern" "$CODEX_AGENTS_FILE" || missing "${name} (pattern: ${pattern})"
        done <<< "$patterns"
        return 0
    fi
    title="$(rule_title "$name")"
    if ! grep -Fq -- "$name" "$CODEX_AGENTS_FILE" && ! grep -Fqi -- "$title" "$CODEX_AGENTS_FILE"; then
        missing "${name} (pattern: ${title} か ${name})"
    fi
}

main() {
    if [[ ! -d "$RULES_DIR" ]]; then
        error "Rules directory not found: $RULES_DIR"
        exit 1
    fi
    if [[ ! -f "$CODEX_AGENTS_FILE" ]]; then
        error "Codex AGENTS file not found: $CODEX_AGENTS_FILE"
        exit 1
    fi

    info "Checking codex guardrails against canonical/rules"

    local file name known rule_count=0 names=" "
    while IFS= read -r file; do
        name="$(basename "$file" .md)"
        names="${names}${name} "
        rule_count=$((rule_count + 1))
        check_rule "$name"
    done < <(find "$RULES_DIR" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort)

    # ルールが1本も無いのは、置き場の指し間違いである。0本を「全部載っている」として通さない。
    if [[ "$rule_count" -eq 0 ]]; then
        error "No rule files (*.md) found in: $RULES_DIR"
        exit 1
    fi

    # 表に残った古い名前（ルールが消えたか、名前が変わった）を通さない。残すと、表の行が何も検査しなくなる。
    while IFS= read -r known; do
        [[ -n "$known" ]] || continue
        case "$names" in
            *" ${known} "*) ;;
            *) missing "${known}（表 RULE_TABLE にあるが、canonical/rules に無い。表から外す）" ;;
        esac
    done < <(table_rule_names)

    local bad
    while IFS= read -r bad; do
        [[ -n "$bad" ]] || continue
        missing "表 RULE_TABLE の行の形が崩れている: ${bad}"
    done < <(table_bad_lines)

    if [[ "$missing_count" -gt 0 ]]; then
        error "Guardrails check failed (${missing_count} problem(s) / ${rule_count} rule(s))"
        exit 1
    fi

    info "Guardrails check passed (${rule_count} rule(s): $((rule_count - excluded_count)) checked, ${excluded_count} excluded)"
}

main "$@"

