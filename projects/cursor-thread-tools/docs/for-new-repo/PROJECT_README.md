# cursor-thread-tools

Export Cursor Composer / Agent thread conversations to Markdown — as a **Cursor extension** or a **CLI**.

Cursor's built-in "Export Transcript" requires a GUI save dialog and is not available from the Command Palette. This tool reads Cursor's local SQLite store (`state.vscdb`) in **read-only** mode and reconstructs transcripts without using Cursor's private APIs.

**Status:** maintenance / archive-friendly. Built and verified against **Cursor 3.25.x (Electron 42)**. Not published to the VS Code / Cursor Marketplace; install from a `.vsix` release or build from source.

## Features

- List Composer threads (name, message count, Agent/Chat, date)
- Export a thread (or many) to Markdown, including optional thinking blocks
- Change export directory from the Command Palette
- Optionally add the exported file to Composer as an `@` reference
- Optional background auto-save (off by default)
- CLI: `cursor-thread-tools list` / `export`

## Quick start

### Extension (recommended for most users)

1. Download a platform `.vsix` from [GitHub Releases](https://github.com/stlwolf/ai-development-hub/releases?q=cursor-thread-tools) (tag `cursor-thread-tools-v*`).
2. Cursor → `Cmd+Shift+P` → `Extensions: Install from VSIX...` → reload window.
3. `Cmd+Shift+P` → `Thread Tools: List Threads` / `Export Thread to Markdown`.

Native `better-sqlite3` is bundled in the `.vsix`, so the binary must match your OS/arch (e.g. `darwin-arm64`).

### CLI

```bash
cd extension
npm install
bash scripts/setup-cli.sh   # Node-native rebuild + npm link

cursor-thread-tools list
cursor-thread-tools export --all --since 7d
```

Full install / rebuild notes: [extension/INSTALL.md](extension/INSTALL.md) (日本語) · [extension/INSTALL.en.md](extension/INSTALL.en.md) · [extension/CLI_USAGE.md](extension/CLI_USAGE.md).

## Requirements

- macOS (Windows / Linux paths exist but are untested)
- Node.js **20+** for CLI / source builds (**22+** recommended for `@electron/rebuild`)
- Cursor installed and launched at least once (`state.vscdb` must exist)
- Current build target: **Electron 42.10.0** (override with `ELECTRON_VERSION=...`)

## How it works (short)

1. Open `state.vscdb` (SQLite) read-only
2. Read `composerData:*` metadata from `cursorDiskKV`
3. Decode `conversationState` (protobuf) → `agentKv:blob` → message text
4. Emit Markdown

Design choices (SQLite library, protobuf parsing, packaging, ABI split) are recorded under [`docs/decisions/`](docs/decisions/).

## Project layout

```text
cursor-thread-tools/
├── README.md
├── LICENSE                 # MIT
├── docs/decisions/         # ADRs (rationale only)
└── extension/              # VS Code / Cursor extension + CLI
    ├── src/
    ├── scripts/install.sh  # Electron-native rebuild + build
    ├── scripts/setup-cli.sh
    └── INSTALL.md
```

## License

[MIT](LICENSE)

## Disclaimer

This tool depends on Cursor's undocumented on-disk format. Cursor updates can break listing or export. Unsupported / empty thread formats are skipped with a warning rather than failing the whole run. Use at your own risk; the authors do not guarantee compatibility with future Cursor versions.
