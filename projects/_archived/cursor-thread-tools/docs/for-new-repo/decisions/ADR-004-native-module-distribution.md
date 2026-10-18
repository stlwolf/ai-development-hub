# ADR-004: Native module distribution (Electron + VSIX)

- **Status:** Accepted
- **Date:** 2026-02-21 (rewritten 2026-10-18; Electron target updated)

## Context

`better-sqlite3` ships a native `.node`. Extension Host runs **Electron**; CLI runs **Node**. ABIs differ. Cursor does not expose a reliable `electronVersion` field for auto-detection.

From v13, better-sqlite3 prefers `prebuilds/<platform>-<arch>.node` (Electron rebuild overwrites the matching prebuild; forge-meta records the ABI).

## Decision

- Build with `scripts/install.sh`: `npm install` → esbuild → `@electron/rebuild`
- Default Electron version: **`42.10.0`** (Cursor 3.25.x at last verification). Override via `ELECTRON_VERSION` or script argument
- Require **`better-sqlite3` ^13** for Electron 42 / modern V8 APIs (v12 fails to compile)
- Ship OS/arch-specific `.vsix` including the rebuilt native binary
- Do not use a heavy `postinstall` rebuild on every `npm install`

## Rationale

- Explicit rebuild is easier to debug than silent postinstall
- Platform-specific VSIX matches how native addons are actually consumed
- Same pattern as earlier Electron 39 + better-sqlite3 v12; bumped again when Cursor moved to Electron 42

## Consequences

- Extension and CLI cannot share one `node_modules` ABI (see ADR-005)
- After `install.sh`, CLI users must run `setup-cli.sh` / `npm rebuild` for Node
- Older Cursor / Electron versions are out of support for new releases
