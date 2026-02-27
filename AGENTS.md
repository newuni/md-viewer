# AGENTS

## Release Discipline

These rules are mandatory for this repository:

1. Every significant change must be committed with **Conventional Commits**.
2. After each significant change commit, push to `origin/main` immediately.
3. After each pushed significant change, create and publish a **consecutive minor release**.

## Commit Rules

1. Use Conventional Commit format: `<type>(<scope>): <subject>`.
2. Prefer explicit scopes, for example: `renderer`, `app`, `quicklook`, `workflow`, `docs`.
3. Examples:
   - `feat(renderer): add front matter parsing and metadata mapping`
   - `fix(app): stabilize find navigation in web preview`
   - `chore(workflow): sync repository about on tagged releases`

## Versioning Rules

1. For each significant merged change, bump the **minor** version sequentially:
   - `v0.1.5` -> `v0.1.6` -> `v0.1.7` ...
2. Do not skip numbers.
3. Keep `CHANGELOG.md` updated before tagging.

## Release Sequence

For significant changes, always follow this order:

1. `swift test`
2. `git add ...`
3. `git commit -m "<conventional-commit>"`
4. `git push origin main`
5. Update changelog/version notes
6. `git tag vX.Y.Z`
7. `git push origin vX.Y.Z`
8. Verify GitHub release workflow completed successfully
