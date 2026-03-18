#!/usr/bin/env bash
set -euo pipefail

# Fast Markdown Preview — build script
# Usage: ./scripts/build.sh [--debug] [--test] [--no-install] [--xcode]
#
# By default: builds Release, installs to ~/Applications, and launches.
# Automatically rebuilds cmark-gfm from Homebrew if needed.
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

# ── Rebuild vendored cmark-gfm from Homebrew ────────────────────────
# The vendored .a files may have been built on a different macOS version.
# Rebuild from Homebrew to match this machine's SDK.
refresh_cmark_gfm() {
  if ! brew list cmark-gfm &>/dev/null; then
    echo "==> Installing cmark-gfm via Homebrew..."
    brew install cmark-gfm
  fi

  local prefix
  prefix="$(brew --prefix cmark-gfm)"

  echo "==> Refreshing vendored cmark-gfm from $prefix..."
  mkdir -p "$ROOT/Libs/cmark-gfm/include" "$ROOT/Libs/cmark-gfm/lib"

  # Copy headers
  cp -f "$prefix"/include/*.h "$ROOT/Libs/cmark-gfm/include/"

  # Copy static libraries
  cp -f "$prefix"/lib/libcmark-gfm.a "$ROOT/Libs/cmark-gfm/lib/"
  cp -f "$prefix"/lib/libcmark-gfm-extensions.a "$ROOT/Libs/cmark-gfm/lib/"

  echo "==> cmark-gfm refreshed ($(lipo -info "$ROOT/Libs/cmark-gfm/lib/libcmark-gfm.a" 2>&1 | awk -F: '{print $NF}'))"
}

# Check if vendored libs match this machine's macOS version.
# The linker warns when .a files are built for a newer OS than the target.
# Safest: always rebuild from Homebrew — it's fast (<1s, just copying).
refresh_cmark_gfm

# ── Code signing ─────────────────────────────────────────────────────
# Use a real signing identity if available, fall back to ad-hoc.
# macOS 26+ (Tahoe) kills ad-hoc signed apps — "Sign to Run Locally"
# via Xcode or a Developer ID is required.
SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -o '"[^"]*"' | head -1 | tr -d '"' || true)

if [ -z "$SIGN_IDENTITY" ]; then
  echo "WARNING: No signing identity found. Using ad-hoc signing."
  echo "         On macOS 26+, the app may be killed on launch."
  echo "         Fix: open Xcode once to create a local signing certificate,"
  echo "         or use ./scripts/build.sh --xcode and build from Xcode (Cmd+R)."
  SIGN_IDENTITY="-"
  SIGN_STYLE="Manual"
else
  echo "==> Signing with: $SIGN_IDENTITY"
  SIGN_STYLE="Manual"
fi

# ── Generate Xcode project ──────────────────────────────────────────
echo "==> Generating Xcode project from project.yml..."
xcodegen generate --spec project.yml --project .

# ── Open in Xcode ───────────────────────────────────────────────────
if $OPEN_XCODE; then
  echo "==> Opening in Xcode..."
  echo "    In Xcode: select FastMarkdownPreview scheme, set Signing to"
  echo "    'Sign to Run Locally', then Cmd+R to build and run."
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
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
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
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    CODE_SIGN_STYLE="$SIGN_STYLE" \
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
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    CODE_SIGN_STYLE="$SIGN_STYLE" \
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

  # Clear quarantine attribute
  xattr -cr ~/Applications/FastMarkdownPreview.app 2>/dev/null || true

  echo "==> Installed to ~/Applications/FastMarkdownPreview.app"
  echo "==> Launching..."
  open ~/Applications/FastMarkdownPreview.app
fi
