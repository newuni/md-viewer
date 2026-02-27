#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${REPO_METADATA_TOKEN:-}" ]]; then
  echo "Skipping About sync: REPO_METADATA_TOKEN secret is not configured."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI is required to sync repository About."
  exit 1
fi

repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
tag="${GITHUB_REF_NAME:?GITHUB_REF_NAME is required}"

description="${REPO_ABOUT_DESCRIPTION:-Native macOS Markdown viewer with Finder Quick Look extension, live preview, and CLI export.}"
homepage="https://github.com/${repo}/releases/tag/${tag}"
topics_csv="${REPO_ABOUT_TOPICS:-cli,finder,macos,markdown,quicklook,swift}"

export GH_TOKEN="${REPO_METADATA_TOKEN}"

gh api -X PATCH "repos/${repo}" \
  -f "description=${description}" \
  -f "homepage=${homepage}" >/dev/null

topic_args=()
IFS=',' read -r -a raw_topics <<< "${topics_csv}"
for topic in "${raw_topics[@]}"; do
  trimmed="$(echo "${topic}" | xargs)"
  if [[ -n "${trimmed}" ]]; then
    topic_args+=(-f "names[]=${trimmed}")
  fi
done

if [[ ${#topic_args[@]} -gt 0 ]]; then
  gh api -X PUT "repos/${repo}/topics" \
    -H "Accept: application/vnd.github+json" \
    "${topic_args[@]}" >/dev/null
fi

echo "Repository About synced for ${repo} (${tag})."
