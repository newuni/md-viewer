# MDViewer

Native macOS Markdown preview utility with Finder Quick Look support.

## Why

macOS preview support for `.md` files is inconsistent across tools and workflows. `MDViewer` provides:

- A lightweight native Markdown viewer app.
- A Quick Look extension to preview Markdown directly in Finder.
- A small CLI (`md-viewer`) for opening files or exporting HTML.

## Status

Public beta: core workflow is complete. The app and Quick Look now use a **native rendering path by default** (with HTML/WebView retained as compatibility fallback). Current focus is release hardening (code signing/notarization) and very-large-file performance tuning.

## Features

- Native renderer path (attributed text) is the default in app and Quick Look.
- Theme + appearance + typography controls (System/GitHub/Solarized/Dracula, Light/Dark/System, body/code sizes).
- Automatic render tiers (`small`/`medium`/`large`/`huge`) with manual Fast Mode override.
- Render `.md` and `.markdown` files with app-level viewing.
- Quick Look extension (`space` in Finder) for Markdown previews.
- HTML export from CLI for debugging and integrations.
- Basic HTML sanitization to strip active script content.
- Automatic heading anchors so table-of-contents links (`#...`) work.
- Lightweight syntax highlighting for fenced code blocks (Swift/JS/TS/Python/Shell/SQL).
- Live preview refresh when the source file changes on disk.
- Find-in-document (`Cmd+F`) with next/previous navigation and case-sensitive toggle.
- Collapsible outline sidebar for heading navigation (`h1`-`h4`) with active-section sync while you scroll.
- Copy-link action for headings directly from the outline context menu.
- Command Palette (`Cmd+K`) for quick actions (outline/theme/fast mode/open/export/reading mode/paste preview).
- Ultra-clean Reading Mode (`Ctrl+Cmd+R`) with centered text and hidden chrome.
- Quick paste-preview (`Cmd+Shift+V`) to open Markdown from clipboard without creating a file.
- Typography zoom shortcuts (`Cmd+=`, `Cmd+-`, `Cmd+0`).
- Large-file handling with automatic tiers and optional manual fast mode override.
- Front matter support (`--- ... ---`) without rendering it as document content.
- GitHub-flavored Markdown baseline support (tables, task lists, strikethrough).
- Enriched Quick Look preview metadata (title/description/keywords extraction).

## Requirements

- macOS 14+
- Xcode (full app build)
- Swift 6.0+

## Local development

1. Install dependencies:

```bash
brew install xcodegen
```

2. Generate Xcode project:

```bash
./scripts/generate_xcodeproj.sh
```

3. Build/test core package:

```bash
swift test
```

4. Open project:

```bash
open MDViewer.xcodeproj
```

## CLI usage

```bash
swift run md-viewer --help
swift run md-viewer README.md
swift run md-viewer --export-html README.md -o README.html
```

## Installation from releases

Each release publishes `MDViewer.app.zip` and `MDViewer.app.zip.sha256`.

This project currently ships unsigned and not notarized binaries. On first run, Gatekeeper may block the app.

If needed:

```bash
xattr -dr com.apple.quarantine /Applications/MDViewer.app
```

## Quick Look behavior

Pressing `space` in Finder should render Markdown directly with the extension. The `Open with MDViewer` button is system UI and cannot be removed, but you should not need to click it for preview.

Important: Quick Look extensions are only loaded when the host app is properly code-signed. Unsigned release builds can still open files, but Finder may fallback to plain text preview.
For local development, open the Xcode project and set a team in `Signing & Capabilities` for `MDViewerApp` and `MDViewerQuickLookExtension`.

If Finder still shows plain text preview, refresh Quick Look services:

```bash
qlmanage -r
qlmanage -r cache
killall Finder
pluginkit -m -A -D -p com.apple.quicklook.preview | grep com.newuni.mdviewer.quicklook
```

## Open source

- License: MIT
- Contributions: see `CONTRIBUTING.md`
- Security policy: see `SECURITY.md`

## Roadmap

See `ROADMAP.md`.
