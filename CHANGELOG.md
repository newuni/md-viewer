# Changelog

All notable changes to this project will be documented in this file.

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
