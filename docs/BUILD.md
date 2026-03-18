# Building Fast Markdown Preview

Native macOS menu bar app for previewing GitHub-Flavored Markdown files.

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon Mac** (arm64 — the vendored cmark-gfm libraries are arm64 only)
- **Xcode** (with command line tools)
- **xcodegen** (`brew install xcodegen`)

## Quick Start

```bash
git clone <repo-url>
cd fast-markdown-preview

# Build, install to ~/Applications, and launch
./scripts/build.sh
```

That's it. The app appears as a **menu bar icon** (top-right of screen) — there is no Dock icon.

## Build Script

```
Usage: ./scripts/build.sh [--debug] [--test] [--no-install] [--xcode]

Default: builds Release, installs to ~/Applications, launches the app.

Options:
  --debug        Build Debug instead of Release
  --test         Run unit tests only
  --no-install   Build without installing or launching
  --xcode        Generate project and open in Xcode (no build)
```

### Examples

```bash
# Default: build + install + launch
./scripts/build.sh

# Run tests
./scripts/build.sh --test

# Open in Xcode for development
./scripts/build.sh --xcode
```

## Building with Xcode

If you prefer using Xcode's GUI:

```bash
# One-time: generate the Xcode project and open it
./scripts/build.sh --xcode
```

Then in Xcode:
1. Select the **FastMarkdownPreview** scheme (top toolbar)
2. Set destination to **My Mac**
3. Press **Cmd+R** to build and run

The `.xcodeproj` is generated from `project.yml` and gitignored. You need to re-run `./scripts/build.sh --xcode` (or `xcodegen generate`) after pulling changes that modify `project.yml`.

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

- **No Xcode project in git.** The `.xcodeproj` is generated from `project.yml` by xcodegen and is gitignored. Run `./scripts/build.sh --xcode` or `xcodegen generate` to create it.
- **Menu bar only.** The app uses `LSUIElement = true` so it has no Dock icon. Look for the document icon in the menu bar (top-right).
- **arm64 only.** The vendored cmark-gfm static libraries are compiled for Apple Silicon. See below for Intel.
- **Ad-hoc signed.** The build script clears the quarantine attribute automatically. If macOS still blocks the app, run: `xattr -cr ~/Applications/FastMarkdownPreview.app`
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
```

Then edit `scripts/build.sh` and remove the `ARCHS=arm64` and `ONLY_ACTIVE_ARCH=YES` flags.
