# Building Fast Markdown Preview

Native macOS menu bar app for previewing GitHub-Flavored Markdown files.

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon Mac** (arm64 — the vendored cmark-gfm libraries are arm64 only)
- **Xcode** (with command line tools)
- **xcodegen** (`brew install xcodegen`)

## Quick Start

```bash
# Clone the repo
git clone <repo-url>
cd fast-markdown-preview

# Build and install
./scripts/build.sh --release --install

# Launch
open ~/Applications/FastMarkdownPreview.app
```

## Build Script

The `scripts/build.sh` script handles project generation, building, testing, and installation.

```
Usage: ./scripts/build.sh [--release] [--install] [--test]

Options:
  --release   Build Release configuration (default: Debug)
  --install   Copy .app to ~/Applications after building
  --test      Run unit tests instead of building
```

### Examples

```bash
# Debug build (for development)
./scripts/build.sh

# Run tests
./scripts/build.sh --test

# Release build + install to ~/Applications
./scripts/build.sh --release --install
```

## Manual Build Steps

If you prefer not to use the script:

```bash
# 1. Install xcodegen
brew install xcodegen

# 2. Generate Xcode project
xcodegen generate --spec project.yml --project .

# 3. Build
xcodebuild \
  -project FastMarkdownPreview.xcodeproj \
  -scheme FastMarkdownPreview \
  -configuration Release \
  -archivePath build/FastMarkdownPreview.xcarchive \
  archive \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES

# 4. Copy to Applications
cp -R build/FastMarkdownPreview.xcarchive/Products/Applications/FastMarkdownPreview.app \
  ~/Applications/
```

## Project Structure

```
fast-markdown-preview/
├── project.yml                          # xcodegen spec (source of truth)
├── scripts/build.sh                     # Build/test/install script
├── Libs/cmark-gfm/                      # Vendored cmark-gfm 0.29.0 (arm64)
│   ├── include/                         # C headers
│   └── lib/                             # Static libraries
├── Sources/FastMarkdownPreview/
│   ├── AppDelegate.swift                # Menu bar item, app lifecycle
│   ├── MarkdownRenderer.swift           # cmark-gfm wrapper (GFM → HTML)
│   ├── HTMLTemplate.swift               # CSS themes + highlight.js wrapper
│   ├── WebViewController.swift          # WKWebView with scroll preservation
│   ├── PanelController.swift            # Floating NSPanel + drag-and-drop
│   ├── FileWatcher.swift                # FSEvents file change detection
│   ├── HotkeyManager.swift             # Carbon global hotkey (⌥⌘P)
│   ├── FinderBridge.swift              # AppleScript Finder selection
│   ├── SettingsViewController.swift    # Settings popover UI
│   ├── LaunchServicesRegistrar.swift   # Default .md viewer registration
│   └── FastMarkdownPreview-Bridging-Header.h
├── Resources/
│   ├── github.css                       # GitHub-faithful theme (light/dark)
│   ├── system.css                       # macOS native theme
│   └── highlight.min.js                 # Syntax highlighting
└── Tests/FastMarkdownPreviewTests/
    ├── MarkdownRendererTests.swift       # 7 GFM rendering tests
    └── FileWatcherTests.swift            # 2 FSEvents tests
```

## Notes

- **No Xcode project in git.** The `.xcodeproj` is generated from `project.yml` by xcodegen and is gitignored. Always run `xcodegen generate` (or use the build script) before opening in Xcode.
- **arm64 only.** The vendored cmark-gfm static libraries are compiled for Apple Silicon. Building for x86_64 (Intel) requires recompiling cmark-gfm from source — see below.
- **Ad-hoc signed.** The app uses `CODE_SIGN_IDENTITY="-"` (ad-hoc signing). It runs fine locally but won't pass Gatekeeper on other machines without proper code signing.
- **No sandbox.** The app uses NSAppleScript for Finder integration, which requires no sandbox.

## Building for Intel (x86_64)

If you need to run on an Intel Mac, rebuild the cmark-gfm libraries:

```bash
brew install cmark-gfm

# Copy headers
cp -R $(brew --prefix cmark-gfm)/include/* Libs/cmark-gfm/include/

# Copy libraries
cp $(brew --prefix cmark-gfm)/lib/libcmark-gfm.a Libs/cmark-gfm/lib/
cp $(brew --prefix cmark-gfm)/lib/libcmark-gfm-extensions.a Libs/cmark-gfm/lib/

# Then build without ARCHS restriction
./scripts/build.sh --release --install
```

Remove the `ARCHS=arm64` and `ONLY_ACTIVE_ARCH=YES` flags from the script if building universal or x86_64.
