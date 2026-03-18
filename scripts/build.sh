#!/usr/bin/env bash
set -euo pipefail

# Fast Markdown Preview — build script
# Usage: ./scripts/build.sh [--debug] [--test] [--no-install] [--xcode]
#
# By default: builds Release, installs to ~/Applications, and launches.
#
# Options:
#   --debug        Build Debug instead of Release
#   --test         Run unit tests only
#   --no-install   Build without copying to ~/Applications
#   --xcode        Generate project and open in Xcode (no build)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="Release"
INSTALL=true
RUN_TESTS=false
OPEN_XCODE=false

for arg in "$@"; do
  case "$arg" in
    --debug)      CONFIG="Debug" ;;
    --test)       RUN_TESTS=true ;;
    --no-install) INSTALL=false ;;
    --xcode)      OPEN_XCODE=true ;;
    *)            echo "Unknown option: $arg"; exit 1 ;;
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

# ── Open in Xcode ───────────────────────────────────────────────────
if $OPEN_XCODE; then
  echo "==> Opening in Xcode..."
  open FastMarkdownPreview.xcodeproj
  exit 0
fi

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
DERIVED="$ROOT/.build/derived"

if [ "$CONFIG" = "Release" ]; then
  echo "==> Building Release (arm64)..."
  xcodebuild \
    -project FastMarkdownPreview.xcodeproj \
    -scheme FastMarkdownPreview \
    -configuration Release \
    -archivePath "$ROOT/build/FastMarkdownPreview.xcarchive" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    -derivedDataPath "$DERIVED" \
    2>&1 | tail -3

  APP_PATH="$ROOT/build/FastMarkdownPreview.xcarchive/Products/Applications/FastMarkdownPreview.app"
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
    -derivedDataPath "$DERIVED" \
    2>&1 | tail -3

  APP_PATH="$DERIVED/Build/Products/Debug/FastMarkdownPreview.app"
fi

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: Build succeeded but app not found at $APP_PATH"
  exit 1
fi

echo ""
echo "==> Build complete: $APP_PATH"

# ── Install + Launch ─────────────────────────────────────────────────
if $INSTALL; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/FastMarkdownPreview.app
  cp -R "$APP_PATH" ~/Applications/
  echo "==> Installed to ~/Applications/FastMarkdownPreview.app"

  # Clear quarantine so Gatekeeper doesn't block the ad-hoc signed app
  xattr -cr ~/Applications/FastMarkdownPreview.app 2>/dev/null || true

  echo "==> Launching..."
  open ~/Applications/FastMarkdownPreview.app
fi
