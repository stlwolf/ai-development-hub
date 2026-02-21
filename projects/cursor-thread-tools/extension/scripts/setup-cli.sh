#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$EXT_DIR"

echo "=== cursor-thread-tools CLI setup ==="
echo ""

echo "[1/3] Rebuild better-sqlite3 for Node.js..."
npm rebuild better-sqlite3

echo ""
echo "[2/3] Build (esbuild)..."
npm run build

echo ""
echo "[3/3] npm link..."
npm link

echo ""
echo "=== Done ==="
echo ""
echo "  cursor-thread-tools list"
echo "  cursor-thread-tools list --json"
echo "  cursor-thread-tools export --all --since 24h"
