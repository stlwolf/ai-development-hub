# ADR-006: esbuild bundling

- **Status:** Accepted
- **Date:** 2026-02-21 (rewritten 2026-10-18)

## Context

Early builds used `tsc` emitting many files under `out/`. Packaging and load paths benefit from single-file bundles for the extension and CLI entrypoints.

## Decision

- Bundle with **esbuild** (`extension.ts` → `out/extension.js`, `cli.ts` → `out/cli.js`)
- Mark `vscode` and `better-sqlite3` as **external**
- `format: 'cjs'`, `platform: 'node'`, sourcemaps on
- CLI shebang via esbuild `banner` only
- Keep `tsc --noEmit` for typecheck

## Rationale

- Matches VS Code extension bundling guidance
- Native modules break if esbuild inlines them (`__dirname` / binding resolution)

## Consequences

- Runtime still requires `node_modules/better-sqlite3` (or the copy inside the `.vsix`)
