# MDViewer

Native macOS Markdown preview utility with Finder Quick Look support.

## Why

macOS preview support for `.md` files is inconsistent across tools and workflows. `MDViewer` provides:

- A lightweight native Markdown viewer app.
- A Quick Look extension to preview Markdown directly in Finder.
- A small CLI (`md-viewer`) for opening files or exporting HTML.

## Status

Early MVP. Initial focus is reliability and local Markdown rendering.

## Features

- Render `.md` and `.markdown` files with app-level viewing.
- Quick Look extension (`space` in Finder) for Markdown previews.
- HTML export from CLI for debugging and integrations.
- Basic HTML sanitization to strip active script content.

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
