# ADR-001: SQLite library — better-sqlite3

- **Status:** Accepted
- **Date:** 2026-02-20 (rewritten 2026-10-18 for public tree)

## Context

Cursor stores Composer data in `state.vscdb` (SQLite). The extension and CLI must open that DB **read-only** while Cursor may be running.

Candidates considered: `better-sqlite3`, `vscode-node-sqlite3`, `sql.js` (WASM).

## Decision

Use **`better-sqlite3`**.

## Rationale

- Synchronous API fits VS Code command handlers
- Proven read of live `state.vscdb` with `readonly` + `busy_timeout`
- `sql.js` loads the whole DB into memory — risky for multi‑GB stores
- Keep `vscode-node-sqlite3` only as a theoretical fallback if native rebuild fails permanently

## Consequences

- Native addon → Electron (extension) and Node (CLI) need **separate ABI builds**
- Must ship OS/arch-specific binaries in `.vsix` (see ADR-004)
