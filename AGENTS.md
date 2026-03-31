# Repository Agent Contract

This file defines the minimal operating rules shared across all AI tools working in this repository.
Behavioral principles are loaded from `~/.codex/AGENTS.md` (global layer); this file adds project-specific context.

## Source of Truth

- Repository overview & usage: `README.md`
- Sync scripts: `scripts/README.md`
- Tool-agnostic canonical resources: `canonical/` (`rules/`, `skills/`, `agents/`, `commands/`)
- Canonical resource catalog: `canonical/CATALOG.md` (全リソース一覧 + 依存関係)
- Codex guardrails: `canonical/codex/AGENTS.md`

## Project Structure

- `canonical/`: Tool-agnostic source of truth (`rules/`, `skills/`, `agents/`, `commands/`)
- `canonical/cursor/`: Cursor-specific extension layer (Cursor-only commands)
- `canonical/codex/`: Codex-specific extension layer
- `canonical/hooks/`: Hook definitions (tool-specific configs + shared scripts, distributed via sync)
- `canonical/mcp/`: MCP server configurations (`cursor.json`)
- `projects/`: Standalone toolkits (each has its own README)
- `ideas/`: Date-based idea snapshots (`YYYYMMDD/`), treated as frozen records
- `scripts/`: Sync scripts and utilities

## Build & Development

No global build system; contributions are Bash scripts and Markdown.

- `./scripts/sync.sh`: unified sync runner (all targets, or specify `cursor`, `claude`, `codex`, `bin`)
- `shellcheck <script>`: run on any modified shell script before committing

## Coding Style

- Bash 3.2+ compatible; `set -euo pipefail` in scripts (not in `.bashrc`)
- `kebab-case` for Markdown/script filenames
- Fenced code blocks with language identifiers; file paths in inline code
- Bullet lists use `-` only (not `*` or `•`)
- Keep changes minimal and scoped; follow existing patterns

## Testing

- No single root test runner exists
- For scripts: run with realistic inputs, verify with `shellcheck`
- For docs/templates: verify paths and command examples from a clean shell

## Commit & PR

- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:` (optional scope)
- One logical change per commit
- PRs include: purpose, impacted paths, validation commands, linked issue/context
