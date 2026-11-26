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
#   1. rule_excluded が理由を返す          → 載せないと決めたルール。検査せず、WARN で毎回知らせる。
#   2. rule_patterns が語を返す            → その語が全部 AGENTS.md にあること（大文字と小文字を区別する）。
#   3. どちらにも無い（既定）              → ルールの名前（例: `foo-bar-rule`）か、名前から作った見出しの語
#                                            （例: `Foo Bar`。大文字と小文字は区別しない）が AGENTS.md にあること。
# ルールを1本足したときは、AGENTS.md に見出しの語か名前で載せれば、この検査を直さなくても通る。
# AGENTS.md の語がルールの名前と違うときだけ、rule_patterns に足す。

# rule_patterns <ルールの名前> — AGENTS.md に在るべき語を1行に1つ出す。既定の決め方でよいルールは何も出さない。
rule_patterns() {
    case "$1" in
        behavioral-rule)
            printf '%s\n' "Evidence First" "CLI Native" "Safe Operations" "Minimal Scope" \
                "Incremental Steps" "Follow Existing Patterns" "Root Cause" ;;
        execution-policy-rule)    printf '%s\n' "Execution Discipline" ;;
        output-format-rule)       printf '%s\n' "Output Contract" ;;
        input-style-rule)         printf '%s\n' "Input Handling" ;;
        implementation-gate-rule) printf '%s\n' "planning phase" ;;
    esac
}

# rule_excluded <ルールの名前> — AGENTS.md に載せていないルールなら、その理由を出す。
# ここに書いたルールは検査を通すが、実行のたびに WARN に出る（黙って欠けているのと見分けるため）。
rule_excluded() {
    case "$1" in
        careful-operations-rule|evidence-verification-rule|workflow-awareness-rule)
            printf '%s\n' "AGENTS.md にまだ載せていない（載せるかは未決。#332 では検査だけを直した）" ;;
    esac
}

# 上の2つの表に名前があるルール。canonical/rules/ から無くなったルールが表に残っていないかを見るのに使う。
KNOWN_RULES="behavioral-rule execution-policy-rule output-format-rule input-style-rule implementation-gate-rule
careful-operations-rule evidence-verification-rule workflow-awareness-rule"

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
        missing "${name}（rule_excluded と rule_patterns の両方に書かれている。どちらかにする）"
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
    for known in $KNOWN_RULES; do
        case "$names" in
            *" ${known} "*) ;;
            *) missing "${known}（rule_patterns か rule_excluded にあるが、canonical/rules に無い。表から外す）" ;;
        esac
    done

    if [[ "$missing_count" -gt 0 ]]; then
        error "Guardrails check failed (${missing_count} problem(s) / ${rule_count} rule(s))"
        exit 1
    fi

    info "Guardrails check passed (${rule_count} rule(s): $((rule_count - excluded_count)) checked, ${excluded_count} excluded)"
}

main "$@"

