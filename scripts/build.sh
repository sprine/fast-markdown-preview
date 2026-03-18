#!/usr/bin/env bash
set -euo pipefail

# Fast Markdown Preview — build script
# Usage: ./scripts/build.sh [--debug] [--test] [--no-install] [--xcode]
#
# By default: builds Release, installs to ~/Applications, and launches.
# Compiles cmark-gfm from source with the correct deployment target.
#
# Options:
#   --debug        Build Debug instead of Release
#   --test         Run unit tests only
#   --no-install   Build without copying to ~/Applications
#   --xcode        Generate project and open in Xcode (no build)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEPLOY_TARGET="14.0"
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
check_dep cmake "brew install cmake"

# ── Build cmark-gfm from source ─────────────────────────────────────
# Homebrew's .a files are compiled against the host macOS version, which
# causes linker warnings when our project targets macOS 14.0.
# We build from source with the correct MACOSX_DEPLOYMENT_TARGET.
CMARK_CACHE="$ROOT/.build/cmark-gfm"
CMARK_STAMP="$CMARK_CACHE/.built"

build_cmark_gfm() {
  local src_dir="$CMARK_CACHE/src"
  local build_dir="$CMARK_CACHE/build"

  # Skip if already built
  if [ -f "$CMARK_STAMP" ] && [ -f "$ROOT/Libs/cmark-gfm/lib/libcmark-gfm.a" ]; then
    echo "==> cmark-gfm already built (cached)"
    return
  fi

  # Get source via Homebrew
  if ! brew list cmark-gfm &>/dev/null; then
    echo "==> Installing cmark-gfm via Homebrew (for source)..."
    brew install cmark-gfm
  fi

  local formula_src
  formula_src="$(brew --cellar cmark-gfm)/$(brew list --versions cmark-gfm | awk '{print $2}')"

  # Download source tarball
  echo "==> Downloading cmark-gfm source..."
  rm -rf "$src_dir" "$build_dir"
  mkdir -p "$src_dir" "$build_dir"
  brew unpack cmark-gfm --destdir="$src_dir" 2>/dev/null || {
    # Fallback: clone from GitHub
    local version
    version="$(brew list --versions cmark-gfm | awk '{print $2}')"
    echo "==> Cloning cmark-gfm $version from GitHub..."
    rm -rf "$src_dir"
    git clone --depth 1 --branch "$version" \
      https://github.com/github/cmark-gfm.git "$src_dir/cmark-gfm" 2>/dev/null || \
    git clone --depth 1 \
      https://github.com/github/cmark-gfm.git "$src_dir/cmark-gfm"
  }

  # Find the actual source directory (brew unpack creates a subdirectory)
  local cmark_src
  cmark_src="$(find "$src_dir" -name "CMakeLists.txt" -maxdepth 2 -exec dirname {} \; | head -1)"

  if [ -z "$cmark_src" ]; then
    echo "ERROR: Could not find cmark-gfm source. Falling back to Homebrew copy."
    fallback_copy_from_brew
    return
  fi

  echo "==> Building cmark-gfm from source (MACOSX_DEPLOYMENT_TARGET=$DEPLOY_TARGET)..."
  rm -rf "$build_dir" && mkdir -p "$build_dir"
  cmake -S "$cmark_src" -B "$build_dir" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMARK_STATIC=ON \
    -DCMARK_SHARED=OFF \
    -DCMARK_TESTS=OFF \
    -DCMARK_GFM_STATIC=ON \
    -DCMARK_GFM_SHARED=OFF \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    2>&1 | tail -3

  cmake --build "$build_dir" --config Release -j "$(sysctl -n hw.logicalcpu)" 2>&1 | tail -3

  # Copy results
  mkdir -p "$ROOT/Libs/cmark-gfm/include" "$ROOT/Libs/cmark-gfm/lib"

  # Libraries — search for the .a files wherever cmake put them
  find "$build_dir" -name "libcmark-gfm.a" -exec cp -f {} "$ROOT/Libs/cmark-gfm/lib/" \;
  find "$build_dir" -name "libcmark-gfm-extensions.a" -exec cp -f {} "$ROOT/Libs/cmark-gfm/lib/" \;

  # Headers — from source + generated
  cp -f "$cmark_src"/src/cmark-gfm.h "$ROOT/Libs/cmark-gfm/include/" 2>/dev/null || true
  cp -f "$cmark_src"/src/cmark-gfm-extension_api.h "$ROOT/Libs/cmark-gfm/include/" 2>/dev/null || true
  cp -f "$cmark_src"/extensions/cmark-gfm-core-extensions.h "$ROOT/Libs/cmark-gfm/include/" 2>/dev/null || true
  # Generated headers (cmark-gfm_export.h, cmark-gfm_version.h)
  find "$build_dir" -name "*.h" -exec cp -f {} "$ROOT/Libs/cmark-gfm/include/" \;
  # Also copy any headers from source src/ directory
  find "$cmark_src/src" -name "*.h" -exec cp -f {} "$ROOT/Libs/cmark-gfm/include/" \;

  # Verify
  if [ ! -f "$ROOT/Libs/cmark-gfm/lib/libcmark-gfm.a" ]; then
    echo "ERROR: cmark-gfm build failed — .a file not found."
    echo "       Falling back to Homebrew copy."
    fallback_copy_from_brew
    return
  fi

  touch "$CMARK_STAMP"
  echo "==> cmark-gfm built successfully (deployment target: $DEPLOY_TARGET)"
}

fallback_copy_from_brew() {
  local prefix
  prefix="$(brew --prefix cmark-gfm)"
  echo "==> Copying cmark-gfm from Homebrew (may cause linker warnings)..."
  mkdir -p "$ROOT/Libs/cmark-gfm/include" "$ROOT/Libs/cmark-gfm/lib"
  cp -f "$prefix"/include/*.h "$ROOT/Libs/cmark-gfm/include/"
  cp -f "$prefix"/lib/libcmark-gfm.a "$ROOT/Libs/cmark-gfm/lib/"
  cp -f "$prefix"/lib/libcmark-gfm-extensions.a "$ROOT/Libs/cmark-gfm/lib/"
}

build_cmark_gfm

# ── Code signing ─────────────────────────────────────────────────────
SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -o '"[^"]*"' | head -1 | tr -d '"' || true)

if [ -z "$SIGN_IDENTITY" ]; then
  echo "WARNING: No signing identity found. Using ad-hoc signing."
  echo "         On macOS 26+, the app may be killed on launch."
  echo "         Fix: use ./scripts/build.sh --xcode and build from Xcode (Cmd+R)."
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
