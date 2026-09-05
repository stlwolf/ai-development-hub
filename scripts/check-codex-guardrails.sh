#!/bin/bash
#
# check-codex-guardrails.sh
#
# canonical/rules と canonical/codex/AGENTS.md の整合を検証する。
#
# Usage:
#   ./scripts/check-codex-guardrails.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
RULES_DIR="${REPO_ROOT}/canonical/rules"
CODEX_AGENTS_FILE="${REPO_ROOT}/canonical/codex/AGENTS.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

missing_count=0

require_pattern() {
    local pattern="$1"
    local label="$2"
    if ! grep -Fq "$pattern" "$CODEX_AGENTS_FILE"; then
        error "Missing in canonical/codex/AGENTS.md: ${label} (pattern: ${pattern})"
        missing_count=$((missing_count + 1))
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

    # behavioral-rule.md
    require_pattern "Evidence First" "behavioral-rule / Evidence First"
    require_pattern "CLI Native" "behavioral-rule / CLI Native"
    require_pattern "Safe Operations" "behavioral-rule / Safe Operations"
    require_pattern "Minimal Scope" "behavioral-rule / Minimal Scope"
    require_pattern "Incremental Steps" "behavioral-rule / Incremental Steps"
    require_pattern "Follow Existing Patterns" "behavioral-rule / Follow Existing Patterns"

    # decision-pacing-rule.md
    require_pattern "Decision Pacing" "decision-pacing-rule"

    # execution-policy-rule.md
    require_pattern "Execution Discipline" "execution-policy-rule"

    # output-format-rule.md
    require_pattern "Output Contract" "output-format-rule"

    # implementation-principles-rule.md
    require_pattern "Implementation Principles" "implementation-principles-rule"

    # input-style-rule.md
    require_pattern "Input Handling" "input-style-rule"

    # subagent-strategy-rule.md
    require_pattern "Subagent Strategy" "subagent-strategy-rule"

    # implementation-gate-rule.md
    require_pattern "planning phase" "implementation-gate-rule"


    if [[ "$missing_count" -gt 0 ]]; then
        error "Guardrails check failed (${missing_count} missing pattern(s))"
        exit 1
    fi

    info "Guardrails check passed"
}

main "$@"

