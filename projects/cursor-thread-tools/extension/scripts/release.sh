#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<EOF
Usage: bash scripts/release.sh [--dry-run]

Build .vsix and create a GitHub Release.

Options:
  --dry-run   Build and package only. Skip GitHub Release creation.
  -h, --help  Show this help.

Environment:
  ELECTRON_VERSION  Electron version for native rebuild (default: from install.sh)
EOF
}

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg"; usage; exit 1 ;;
  esac
done

cd "$EXT_DIR"

VERSION=$(node -p "require('./package.json').version")
NAME="cursor-thread-tools"
TAG="${NAME}-v${VERSION}"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)        ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac
PLATFORM="${OS}-${ARCH}"

VSIX_ORIGINAL="${NAME}-${VERSION}.vsix"
VSIX_RELEASE="${NAME}-${VERSION}-${PLATFORM}.vsix"

echo "=== cursor-thread-tools release ==="
echo "Version : ${VERSION}"
echo "Tag     : ${TAG}"
echo "Platform: ${PLATFORM}"
echo "Dry run : ${DRY_RUN}"
echo ""

for cmd in node npm; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: ${cmd} is required but not found."
    exit 1
  fi
done

if [[ "$DRY_RUN" == "false" ]] && ! command -v gh &>/dev/null; then
  echo "ERROR: gh (GitHub CLI) is required for release creation."
  echo "  Install: brew install gh"
  exit 1
fi

echo "[1/3] Building extension..."
bash scripts/install.sh
echo ""

echo "[2/3] Packaging .vsix..."
npm run package

if [[ -f "$VSIX_ORIGINAL" ]]; then
  mv "$VSIX_ORIGINAL" "$VSIX_RELEASE"
else
  echo "ERROR: Expected ${VSIX_ORIGINAL} not found after packaging."
  exit 1
fi

echo "  -> ${VSIX_RELEASE} ($(du -h "$VSIX_RELEASE" | cut -f1 | xargs))"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== Dry run complete ==="
  echo "VSIX: ${EXT_DIR}/${VSIX_RELEASE}"
  echo ""
  echo "To install locally:"
  echo "  Cursor: Cmd+Shift+P -> Extensions: Install from VSIX..."
  exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel)

if git tag -l "$TAG" | grep -q "^${TAG}$"; then
  echo "ERROR: Tag ${TAG} already exists."
  echo "  Bump version in package.json or delete the existing tag/release:"
  echo "    gh release delete ${TAG} --yes && git tag -d ${TAG} && git push origin :refs/tags/${TAG}"
  exit 1
fi

echo "[3/3] Creating GitHub Release..."

NOTES_FILE=$(mktemp)
trap 'rm -f "$NOTES_FILE" "${EXT_DIR}/${VSIX_RELEASE}"' EXIT

cat > "$NOTES_FILE" <<EOF
## インストール方法

1. 下の Assets から \`.vsix\` ファイルをダウンロード
2. Cursor: \`Cmd+Shift+P\` → \`Extensions: Install from VSIX...\`
3. ダウンロードした \`.vsix\` を選択
4. ウィンドウをリロード: \`Cmd+Shift+P\` → \`Developer: Reload Window\`

\`gh\` CLI がある場合:
\`\`\`bash
gh release download ${TAG} --repo stlwolf/ai-development-hub --pattern '*.vsix'
\`\`\`

## 対応プラットフォーム

| ファイル | OS | アーキテクチャ |
|---------|-----|--------------|
| \`${VSIX_RELEASE}\` | ${OS} | ${ARCH} |

> ネイティブモジュール (better-sqlite3) を含むため、ビルド元と同じ OS/アーキテクチャでのみ動作します。
> 別プラットフォーム用が必要な場合は[ソースからビルド](projects/cursor-thread-tools/extension/INSTALL.md)してください。

## 前提条件

- Cursor 0.40+ (Electron 39)
- Cursor が一度は起動済みであること
EOF

cd "$REPO_ROOT"

gh release create "$TAG" \
  "${EXT_DIR}/${VSIX_RELEASE}" \
  --title "Cursor Thread Tools v${VERSION}" \
  --notes-file "$NOTES_FILE"

RELEASE_URL=$(gh release view "$TAG" --json url -q .url)

echo ""
echo "=== Release complete ==="
echo "URL: ${RELEASE_URL}"
echo ""
echo "Share this URL with team members!"
