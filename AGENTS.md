# Repository Guidelines

## Project Structure & Module Organization
- `cursor/`: Cursor command templates and rule files (`command/`, `project-rules/`, `user-rules/`).
- `projects/`: Standalone toolkits.
- `projects/agent-verification-flow/`: API verification scripts and templates.
- `projects/claude-safe/`: wrapper for safe Claude CLI execution in integrated terminals.
- `projects/second-opinion-verification/`: timeout-enabled verification workflow and ADR-style docs.
- `ideas/`: date-based idea snapshots (`YYYYMMDD/`), treated as frozen records.
- `docs/draft/`: work-in-progress docs.
- `scripts/`: repository utilities (for example command sync scripts).

## Build, Test, and Development Commands
This repository has no global build system; contributions are mostly Bash scripts and Markdown.

- `./scripts/sync-cursor-commands.sh`: symlink `cursor/command/*` into `~/.cursor/commands`.
- `cd projects/agent-verification-flow && ./scripts/cognito_auth.sh`: fetch JWT for API verification.
- `cd projects/agent-verification-flow && ./scripts/api_call.sh GET /api/users`: run authenticated API calls.
- `./projects/claude-safe/claude-safe -p "prompt" --output-format text`: run Claude CLI safely via wrapper.
- `CLAUDE_TIMEOUT=60 ./projects/second-opinion-verification/src/claude-safe-with-timeout -p "prompt"`: enforce timeout behavior.

## Coding Style & Naming Conventions
- Use Bash and Markdown with simple, portable patterns (`bash` 3.2+ compatible scripts).
- Prefer `kebab-case` for Markdown/script filenames; keep directory names descriptive.
- For idea records, use `ideas/YYYYMMDD/`.
- In Markdown, use fenced code blocks with language identifiers and inline-code file paths.
- Keep changes minimal and scoped; follow existing layout and phrasing patterns in each subproject.

## Testing Guidelines
- No single root test runner exists.
- For script changes, run the target script with realistic inputs and document results in the related README/docs.
- If available, run `shellcheck <script>` for modified shell scripts before opening a PR.
- For workflow docs/templates, verify links/paths and command examples from a clean shell session.

## Commit & Pull Request Guidelines
- Follow Conventional Commit style seen in history: `feat: ...`, `fix: ...`, `docs: ...`, `chore: ...` (optional scope like `feat(verification): ...`).
- Keep one logical change per commit.
- PRs should include purpose and impacted paths.
- PRs should include validation steps/commands executed.
- PRs should include linked issue/context when available.
- PRs should include sample output or screenshots when behavior/output changes.
