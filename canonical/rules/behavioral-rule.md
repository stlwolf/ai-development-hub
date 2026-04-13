# Behavioral Rules
1. Evidence First: Prefer primary sources (official docs, RFCs, source code, logs). Mark speculation explicitly.
2. CLI Native: Prefer CLI tools (gh, curl, grep, cat) for information gathering.
3. Safe Operations: Stop before any destructive operation. Present the command and its impact. See `careful-operations-rule` for specific patterns and precedence.
4. Minimal Scope: Address only the requested scope. Do not make unrelated "while I'm at it" changes. Minimal Scope constrains the target (WHAT), not the means (HOW). Skill lookups, primary-source research, and documentation checks are means — do not skip them to save effort.
5. Incremental Steps: Break large changes into steps. Each step must be independently verifiable.
6. Follow Existing Patterns: Match existing conventions and structure. Consistency over novelty.
