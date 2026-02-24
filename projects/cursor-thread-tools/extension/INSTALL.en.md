[日本語版はこちら](INSTALL.md)

# Cursor Thread Tools

Export Cursor Composer thread conversations to Markdown.
Two ways to use: as a **Cursor extension** (via Command Palette) or as a **CLI** (via terminal).

## Features

- **Thread listing**: Browse all Composer threads with metadata (name, message count, Agent/Chat mode, creation date)
- **Markdown export**: Export thread conversations to Markdown files with user/assistant messages and thinking blocks
- **Output directory picker**: Change the export destination via the Command Palette folder picker
- **Composer auto-add**: Automatically add exported files to Composer as `@` references
- **Auto-save**: Automatically export updated threads at a configurable interval (opt-in)
- **CLI**: Export threads from the terminal without opening the editor

## Prerequisites

- **macOS** (Windows / Linux path support added but untested)
- **Node.js 20 or later**
- **Cursor 0.40+** (Electron 39)
- Cursor must have been launched at least once (`state.vscdb` needs to exist)

> **Safety**: This tool accesses Cursor data in **read-only** mode. It never modifies or deletes any data.

---

## Quick Start: Extension

Use the Command Palette (`Cmd+Shift+P`) to list and export threads.

### 1. Build

```bash
cd projects/cursor-thread-tools/extension
bash scripts/install.sh
```

`install.sh` automatically runs:
- `npm install` (install dependencies)
- `npm run build` (bundle with esbuild)
- `@electron/rebuild` (rebuild better-sqlite3 for Cursor's Electron runtime)

### 2. Package as .vsix

```bash
npm run package
```

This generates `cursor-thread-tools-0.2.0.vsix` in the `extension/` directory.

### 3. Install in Cursor

1. In Cursor: `Cmd+Shift+P` → `Extensions: Install from VSIX...`
2. Select the generated `.vsix` file
3. Reload the window (`Cmd+Shift+P` → `Developer: Reload Window`)

### 4. Try it out

- `Cmd+Shift+P` → `Thread Tools: List Threads` — browse all threads
- `Cmd+Shift+P` → `Thread Tools: Export Thread to Markdown` — export a selected thread
- `Cmd+Shift+P` → `Thread Tools: Set Output Directory` — change the export destination

Exported files are saved to `.thread-exports/` in the workspace root by default. Use the `Set Output Directory` command to pick a different folder via the folder picker; the choice is saved to workspace settings.

After export, the file is automatically added to Composer as an `@` reference. If Composer is not open, this step is silently skipped.

---

## Quick Start: CLI

Use the terminal to list and export threads. Useful for cron jobs, git workflows, and automation.

### 1. Setup

```bash
cd projects/cursor-thread-tools/extension
npm install
bash scripts/setup-cli.sh
```

`setup-cli.sh` automatically runs:
- `npm rebuild better-sqlite3` (rebuild for Node.js native)
- `npm run build` (bundle with esbuild)
- `npm link` (register `cursor-thread-tools` as a global command)

### 2. Try it out

```bash
# List all threads
cursor-thread-tools list

# Export all threads
cursor-thread-tools export --all

# Export threads from the last 24 hours
cursor-thread-tools export --all --since 24h
```

See [CLI_USAGE.md](CLI_USAGE.md) for detailed usage and examples.

---

## Using Both Extension and CLI

The extension and CLI require different build targets for `better-sqlite3` (Electron vs Node.js). When using both from the same directory, switch the build target as needed:

```bash
# For extension use → rebuild for Electron
bash scripts/install.sh

# For CLI use → rebuild for Node.js
bash scripts/setup-cli.sh
```

> If you primarily use the CLI and have already installed the extension via `.vsix`, you can keep the Node.js build target. The `.vsix` bundles its own binaries and is unaffected by the local build state.

---

## Settings (Extension)

Configurable in Cursor's `settings.json`.

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `cursorThreadTools.export.includeThinking` | boolean | `true` | Include thinking blocks in exported Markdown |
| `cursorThreadTools.export.outputDir` | string | `.thread-exports` | Output directory (relative to workspace root) |
| `cursorThreadTools.export.fileNameFormat` | string | `{name}_{date}` | File name format |
| `cursorThreadTools.autoSave.intervalMinutes` | number | `0` | Auto-save interval in minutes. `0` = disabled |

---

## Troubleshooting

### `MODULE_NOT_FOUND` / `NODE_MODULE_VERSION` mismatch

The better-sqlite3 build target doesn't match your runtime. Rebuild for the correct target:

```bash
# For extension (Electron)
bash scripts/install.sh

# For CLI (Node.js)
bash scripts/setup-cli.sh
```

### `state.vscdb not found`

Ensure Cursor is installed and has been launched at least once. Database location:

- macOS: `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
- Windows: `%APPDATA%\Cursor\User\globalStorage\state.vscdb`
- Linux: `~/.config/Cursor/User/globalStorage/state.vscdb`

### DB busy/locked

The tool opens the database in read-only mode with a 3-second busy timeout. If Cursor is actively writing, it falls back to a temporary copy of the database files (including WAL). Normally no retry is needed.

### Electron version mismatch

If Cursor updates its Electron version, specify the version via environment variable:

```bash
ELECTRON_VERSION=39.4.0 bash scripts/install.sh
```

Check Cursor's Electron version in the About screen, or on macOS via `/Applications/Cursor.app/Contents/Info.plist`.
