# Cursor Thread Tools

Export Cursor Composer thread conversations to Markdown. Available as a VS Code/Cursor extension and a CLI tool.

## Features

- **Thread listing**: Browse all Composer threads with metadata (name, message count, Agent/Chat mode, creation date)
- **Markdown export**: Export thread conversations to Markdown files with user/assistant messages and thinking blocks
- **Auto-save**: Automatically export updated threads at a configurable interval (opt-in)
- **CLI**: Export threads from the terminal without opening the editor

## Installation

### VS Code / Cursor Extension (.vsix)

1. Download the `.vsix` file from the [releases](https://github.com/stlwolf/ai-development-hub/releases) or build it yourself (see [Building from source](#building-from-source))
2. In Cursor: `Cmd+Shift+P` -> `Extensions: Install from VSIX...` -> select the `.vsix` file
3. Reload the window

### CLI

```bash
cd extension/
npm install
npm run build
npm link
cursor-thread-tools list
```

> **Note**: The CLI requires a Node.js-native build of better-sqlite3. If you previously ran `install.sh` (which builds for Electron), you need to rebuild for Node.js first:
> ```bash
> npm rebuild better-sqlite3
> ```

## Commands

| Command | Palette Title | Description |
|---------|--------------|-------------|
| `threadTools.list` | Thread Tools: List Threads | Show all Composer threads in a QuickPick |
| `threadTools.export` | Thread Tools: Export Thread to Markdown | Export a selected thread to Markdown |

## CLI Usage

```bash
# List all threads
cursor-thread-tools list
cursor-thread-tools list --json

# Export a single thread
cursor-thread-tools export <composerId>

# Export all threads
cursor-thread-tools export --all

# Export threads from the last 24 hours
cursor-thread-tools export --all --since 24h

# Options
cursor-thread-tools export --all --no-thinking --output-dir ./exports --format "{name}_{date}"
```

### CLI Options

| Option | Description | Default |
|--------|-------------|---------|
| `--json` | Output list as JSON | false |
| `--all` | Export all threads | false |
| `--no-thinking` | Exclude thinking blocks | false |
| `--output-dir <path>` | Output directory | `.thread-exports` |
| `--format <pattern>` | File name format (`{name}`, `{date}`, `{id}`) | `{name}_{date}` |
| `--since <duration>` | Only threads within duration (`24h`, `7d`, `30m`) | - |
| `--app-name <name>` | App name: `Cursor` or `Code` | `Cursor` |

## Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `cursorThreadTools.export.includeThinking` | boolean | `true` | Include thinking blocks in exported Markdown |
| `cursorThreadTools.export.outputDir` | string | `.thread-exports` | Output directory (relative to workspace root) |
| `cursorThreadTools.export.fileNameFormat` | string | `{name}_{date}` | File name format |
| `cursorThreadTools.autoSave.intervalMinutes` | number | `0` | Auto-save interval in minutes. `0` = disabled |

## Platform Support

| Platform | Extension | CLI |
|----------|-----------|-----|
| macOS | Supported | Supported |
| Windows | Path support added (untested) | Path support added (untested) |
| Linux | Path support added (untested) | Path support added (untested) |

## Requirements

- **Node.js**: 20 or later (the CLI uses `util.parseArgs()` and targets ES2020)
- **Cursor**: 0.40+ (Electron 39)

## Constraints

- **Cursor only**: Reads `state.vscdb` from Cursor's data directory. VS Code support is possible but untested.
- **Read-only**: Does not modify any Cursor data.
- **Native module**: Uses `better-sqlite3` which requires platform-specific binaries. The `.vsix` includes macOS binaries; other platforms need to build from source.

## Building from source

```bash
cd extension/

# Full install (Extension + Electron rebuild)
bash scripts/install.sh

# Or step by step:
npm install
npm run build

# For Extension development (rebuild for Electron)
npx @electron/rebuild -v 39.4.0 -m .

# For CLI usage (rebuild for Node.js)
npm rebuild better-sqlite3

# Package as .vsix
npm run package
```

## Troubleshooting

### `MODULE_NOT_FOUND` or `NODE_MODULE_VERSION` mismatch

better-sqlite3 needs to be built for the correct runtime:

```bash
# For Cursor Extension (Electron)
npx @electron/rebuild -v 39.4.0 -m .

# For CLI (Node.js)
npm rebuild better-sqlite3
```

### `state.vscdb not found`

Ensure Cursor is installed and has been opened at least once. The database is located at:

- macOS: `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
- Windows: `%APPDATA%\Cursor\User\globalStorage\state.vscdb`
- Linux: `~/.config/Cursor/User/globalStorage/state.vscdb`

### DB busy/locked

The tool opens the database in read-only mode with a 3-second busy timeout. If Cursor is actively writing, the tool falls back to a temporary copy of the database files (including WAL).
