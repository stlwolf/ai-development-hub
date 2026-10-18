# ADR-005: CLI distribution

- **Status:** Accepted
- **Date:** 2026-02-21 (rewritten 2026-10-18)

## Context

Need a simple way for developers to run `list` / `export` from a terminal. Candidates: `npm link` + `bin`, `npx`, standalone binaries (`pkg` / `nexe`).

## Decision

- Register `cursor-thread-tools` via `package.json` `bin`
- Use **`npm link`** (wrapped by `scripts/setup-cli.sh`) for global command install
- Do not ship standalone native binaries

## Rationale

- `npx` interacts poorly with native modules (repeated install / ABI churn)
- Standalone packagers do not handle native addons well
- Audience is developers already comfortable with Node tooling

## Consequences

| Use | Build | Command |
|-----|--------|---------|
| Extension in Cursor | Electron rebuild | `bash scripts/install.sh` |
| CLI in terminal | Node rebuild | `bash scripts/setup-cli.sh` |

Installed `.vsix` embeds its own native binary and is independent of the local CLI rebuild state.
