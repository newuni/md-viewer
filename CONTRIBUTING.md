# Contributing

## Setup

1. Fork and clone.
2. Install `xcodegen`.
3. Run:

```bash
./scripts/generate_xcodeproj.sh
swift test
```

## Branch and PR flow

- Create a branch per change.
- Keep PRs focused and small.
- Include tests for behavioral changes.

## Coding expectations

- Target macOS 14+.
- Keep `MarkdownRendererCore` reusable between app and extension.
- Avoid adding heavy dependencies without justification.

## Commit guidelines

Use clear commit messages. Conventional Commits are encouraged (`feat:`, `fix:`, `docs:`).
