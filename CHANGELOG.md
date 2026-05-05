# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.1.26] - 2026-05-05

### Fixed

- Theme changes now refresh the native preview when only rendered attributes change and the markdown text stays the same.
- Native previews now apply the selected theme background instead of leaving the host window background visible.
- Added native regression coverage for theme-specific text color attributes.

## [0.1.25] - 2026-05-05

### Fixed

- Native renderer now preserves explicit breathing room after tables so following paragraphs do not sit against the table border.
- Added native regression coverage for table-to-paragraph spacing.

## [0.1.24] - 2026-03-12

### Added

- Mermaid fenced-code-block support rendered through the HTML/WebView path, with automatic fallback away from native attributed rendering when diagrams are present.
- Renderer regression coverage for Mermaid HTML generation and native fallback behavior.

## [0.1.23] - 2026-03-06

### Fixed

- Native renderer now enforces a blank-line break before headings (`h1-h6`) so section titles have clearer visual separation from the previous block.
- Added native regression coverage to ensure headings keep breathing room in attributed output.

## [0.1.22] - 2026-03-05

### Added

- Expanded renderer regression coverage for:
  - JavaScript-link + inline event-handler sanitization
  - Autolink punctuation edge case with wrapping parentheses
  - Existing heading-id preservation in generated TOC metadata
  - Folded front-matter description parsing and keyword extraction
  - Unreadable file-path error wrapping for file URL rendering

## [0.1.21] - 2026-03-05

### Changed

- Hardened CI/release workflows with concurrency guards and explicit job timeouts to reduce stuck/duplicated runs.
- Release workflow now validates manual tag input format before checkout to fail fast with clear errors.
- Release metadata sync is now non-blocking (`continue-on-error`) so packaging/publishing remains reliable even if repo-about sync has transient issues.

### Refactored

- Removed duplicated file-loading logic in `MarkdownRenderer` by introducing a shared `loadMarkdown(from:)` helper used by both HTML and native render paths.
- Added regression tests for file URL rendering/error paths (non-file URL rejection and non-UTF8 content handling).

## [0.1.20] - 2026-03-05

### Changed

- Release workflow now supports `workflow_dispatch` with optional `tag` input to run releases manually when automatic `push tag` triggers are not firing.
- Release job resolves and checks out the target tag explicitly and reuses that resolved tag for release publication and repository metadata sync.

## [0.1.19] - 2026-03-05

### Fixed

- Native renderer no longer displays the hidden searchable shadow text block that is injected for HTML indexing, preventing duplicated/plain-text dumps at the end of previews.
- Added regression coverage to ensure native attributed output does not expose duplicated searchable-shadow content.

## [0.1.17] - 2026-03-01

### Added

- Command Palette (`Cmd+K`) with actions for outline toggle, theme switch, fast mode toggle, Open With, HTML export, reading mode, and paste-preview.
- Ultra-clean Reading Mode (`Ctrl+Cmd+R`) that hides chrome and keeps content centered.
- Outline context action to copy a link to any heading anchor.
- Quick paste-preview flow (`Cmd+Shift+V`) to render clipboard Markdown instantly.
- Typography zoom shortcuts (`Cmd+=`, `Cmd+-`, `Cmd+0`).

### Changed

- TOC now stays in sync with scroll position and highlights the active heading in both native and HTML fallback renderers.

## [0.1.14] - 2026-03-01

### Changed

- Updated `README.md` to reflect native renderer as default path (app + Quick Look), with compatibility fallback notes.
- Expanded feature documentation for themes/appearance/typography and automatic render tiers.
- Updated `ROADMAP.md` and `roadmap.md` to include completed native-engine migration milestones.

## [0.1.13] - 2026-03-01

### Fixed

- Fixed Swift 6/Xcode 16.4 ambiguity in `NativeMarkdownTextView` by explicitly using `CGFloat.greatestFiniteMagnitude` for NSTextView sizing.

## [0.1.12] - 2026-03-01

### Fixed

- Reworked main-thread attributed conversion to use `DispatchQueue.main.sync(execute:)`, eliminating a Swift strict-concurrency capture race reported by CI while keeping native rendering test stability.

## [0.1.11] - 2026-03-01

### Fixed

- Stabilized native rendering in CI/test environments by forcing AppKit HTML-to-attributed conversion onto the main thread, preventing `nsattributedstringagent` connection errors during `swift test`.
- Marked native preview bridge (`NativeMarkdownTextView`) as main-actor isolated to satisfy Swift 6 actor isolation checks in Release builds.

## [0.1.10] - 2026-03-01

### Added

- Native render API in `MarkdownRendererCore`: `renderNativeDocument(...)` returning attributed output, metadata, and TOC headings with character offsets.
- New `NativeMarkdownTextView` (`NSTextView`-based) with in-document search and heading-offset scrolling support.
- Core tests covering native rendering output and fast-mode TOC behavior.

### Changed

- App preview now uses native text rendering as the default path.
- Quick Look now prefers native RTF previews generated from attributed markdown output.
- Existing HTML/WebView rendering remains available as a compatibility fallback when native conversion fails.

## [0.1.9] - 2026-03-01

### Fixed

- Build fix in app target: corrected fast-mode expression precedence in `MarkdownDocumentView` (`fastModeOverride ?? (tier == .large || tier == .huge)`).
- Restores GitHub release build step that was failing with Swift type-check errors.

## [0.1.8] - 2026-03-01

### Fixed

- Preserve `<body>` markup without empty class attribute to keep renderer output compatible with existing tests and consumers.
- Restore release pipeline stability after the 0.1.7 tag failed in `Swift package tests`.

## [0.1.7] - 2026-03-01

### Added

- Toolbar **Style** controls with selectable themes (System, GitHub, Solarized, Dracula).
- Appearance override options (System/Light/Dark) for deterministic preview rendering.
- User-configurable typography controls for body and code font sizes.
- Toolbar **Open With** menu to open the current markdown file in another installed app.
- Automatic file-size render tiers (`small`, `medium`, `large`, `huge`) to drive fast-mode defaults.
- Execution-plan checklist section in `ROADMAP.md` (and mirrored `roadmap.md`) for chained delivery.

### Changed

- `MarkdownRenderOptions` now includes theme, appearance, and typography preferences.
- HTML renderer now applies theme palettes and font-size CSS variables from render options.
- Large-file UX now supports manual fast-mode override with a one-click return to Auto mode.

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
