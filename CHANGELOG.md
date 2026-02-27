# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.1.6] - 2026-02-27

### Added

- Collapsible outline sidebar based on extracted heading anchors (`h1`-`h4`).
- In-document search UI with `Cmd+F`, next/previous navigation, and case-sensitive mode.
- Large-file banner with manual fast mode toggle for documents `>= 5MB`.
- `MarkdownRenderOptions` and `HeadingItem` APIs in `MarkdownRendererCore`.
- Front matter parsing at file start (`--- ... ---`) so metadata blocks are not rendered as content.
- Tests covering core GitHub-flavored Markdown constructs (tables, task lists, strikethrough).
- Autolinking of plain `http(s)` URLs outside protected tags (`code`, `pre`, and existing `a`).
- Release workflow step to sync repository About (description/homepage/topics) to each tagged release.

### Changed

- `RenderedMarkdownDocument` now includes extracted headings.
- Fast mode now disables syntax highlighting and TOC extraction while keeping anchor navigation.
- Added tests for render options (`fastMode`, TOC-disabled rendering, heading extraction).
- Front matter values now feed metadata extraction (`title`, `description`, `tags`/`keywords`) when present.

## [0.1.5] - 2026-02-27

### Added

- Lightweight syntax highlighting for fenced code blocks (Swift/JS/TS/Python/Shell/SQL).
- File watching in the app to auto-refresh preview when the Markdown file changes on disk.
- Metadata extraction (`title`, `description`, `keywords`, searchable text) in `MarkdownRendererCore`.
- New renderer APIs returning both HTML and extracted metadata.
- Additional test coverage for syntax highlighting and metadata generation.

### Changed

- Quick Look preview now uses extracted document title and includes metadata attachment.
- Extension metadata now declares support for searchable items.

## [0.1.4] - 2026-02-27

### Added

- Auto-generated heading anchors (`id`) so Markdown TOC links (`#...`) navigate correctly in app and Quick Look previews.
- Regression test coverage for heading-anchor generation and duplicate heading suffixes.

### Changed

- Increased default app document window size for better first-open readability.
- Reduced top content padding and removed top margin on first heading to show more lines initially.
- README troubleshooting now includes `pluginkit` verification command for Quick Look extension registration.

## [0.1.1] - 2026-02-27

### Added

- Generated native `AppIcon` asset set and wired it into the macOS app target.

### Fixed

- Replaced `UTType.markdown` with extension-derived UTTypes for CI/Xcode SDK compatibility.
- Tightened Quick Look type registration to prioritize Markdown preview rendering over plain text fallback.
- Regenerated all app icon assets with exact required pixel sizes to avoid fallback to generic icons.

## [0.1.0] - 2026-02-27

### Added

- Initial open source project scaffolding.
- `MarkdownRendererCore` shared renderer with HTML sanitization.
- `md-viewer` CLI with open and export commands.
- SwiftUI app target and Quick Look extension target definitions.
- GitHub Actions workflows for CI and tagged releases.
