#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_ELECTRON_VERSION="39.4.0"

electron_version="${ELECTRON_VERSION:-${1:-$DEFAULT_ELECTRON_VERSION}}"

echo "=== cursor-thread-tools install ==="
echo "Extension dir : $EXT_DIR"
echo "Electron version: $electron_version"
echo ""

cd "$EXT_DIR"

echo "[1/3] npm install..."
npm install

echo ""
echo "[2/3] esbuild..."
npm run build

echo ""
echo "[3/3] @electron/rebuild (Electron $electron_version)..."
if ! npx @electron/rebuild -v "$electron_version" -m .; then
  echo ""
  echo "ERROR: @electron/rebuild failed."
  echo ""
  echo "Troubleshooting:"
  echo "  - Ensure Xcode Command Line Tools are installed: xcode-select --install"
  echo "  - Try specifying Electron version explicitly:"
  echo "    ELECTRON_VERSION=39.4.0 bash scripts/install.sh"
  echo "  - Or pass as argument:"
  echo "    bash scripts/install.sh 39.4.0"
  exit 1
fi

echo ""
echo "=== Install complete ==="
echo ""
echo "Usage:"
echo "  Extension: Open in Cursor, press F5 to launch Extension Development Host"
echo "  CLI:       node out/cli.js list"
echo "  CLI (npm link): npm link && cursor-thread-tools list"
echo ""
echo "Note: CLI requires Node.js-native better-sqlite3 build."
echo "  If you used this script (Electron rebuild), run:"
echo "    npm rebuild better-sqlite3"
echo "  before using the CLI outside of Cursor."
