#!/usr/bin/env bash
set -euo pipefail

# Fast Markdown Preview — build script
# Usage: ./scripts/build.sh [--release] [--install] [--test]
#
# Options:
#   --release   Build Release configuration (default: Debug)
#   --install   Copy .app to ~/Applications after building
#   --test      Run unit tests instead of building

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="Debug"
INSTALL=false
RUN_TESTS=false

for arg in "$@"; do
  case "$arg" in
    --release) CONFIG="Release" ;;
    --install) INSTALL=true ;;
    --test)    RUN_TESTS=true ;;
    *)         echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# ── Prerequisites ────────────────────────────────────────────────────
check_dep() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: $1 not found. Install it with: $2"
    exit 1
  fi
}

check_dep xcodegen "brew install xcodegen"
check_dep xcodebuild "xcode-select --install"

# ── Generate Xcode project ──────────────────────────────────────────
echo "==> Generating Xcode project from project.yml..."
xcodegen generate --spec project.yml --project .

# ── Tests ────────────────────────────────────────────────────────────
if $RUN_TESTS; then
  echo "==> Running tests..."
  xcodebuild test \
    -project FastMarkdownPreview.xcodeproj \
    -scheme FastMarkdownPreview \
    -destination "platform=macOS" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    ARCHS=arm64 \
    2>&1 | grep -E "Test Case|PASSED|FAILED|BUILD|error:" || true
  exit 0
fi

# ── Build ────────────────────────────────────────────────────────────
if [ "$CONFIG" = "Release" ]; then
  echo "==> Building Release archive (arm64)..."
  xcodebuild \
    -project FastMarkdownPreview.xcodeproj \
    -scheme FastMarkdownPreview \
    -configuration Release \
    -archivePath build/FastMarkdownPreview.xcarchive \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    2>&1 | tail -3

  APP_PATH="build/FastMarkdownPreview.xcarchive/Products/Applications/FastMarkdownPreview.app"
else
  echo "==> Building Debug (arm64)..."
  xcodebuild \
    -project FastMarkdownPreview.xcodeproj \
    -scheme FastMarkdownPreview \
    -configuration Debug \
    build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    ARCHS=arm64 \
    2>&1 | tail -3

  APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "FastMarkdownPreview.app" -type d 2>/dev/null | head -1)
fi

echo ""
echo "==> Build complete: $APP_PATH"

# ── Install ──────────────────────────────────────────────────────────
if $INSTALL; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/FastMarkdownPreview.app
  cp -R "$APP_PATH" ~/Applications/
  echo "==> Installed to ~/Applications/FastMarkdownPreview.app"
  echo "    Run: open ~/Applications/FastMarkdownPreview.app"
fi
