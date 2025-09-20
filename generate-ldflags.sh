#!/usr/bin/env bash
set -euo pipefail

# --- Version from tags ---
if [[ -z "${VERSION:-}" ]]; then
  VERSION=$("$(dirname "$0")/get-version.sh")
fi

# --- Git values ---
BRANCH=$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)
REPO_URL=$(git config --get remote.origin.url)
ORG=$(echo "$REPO_URL" | sed -E 's#(git@|https://)([^/:]+)[:/]([^/]+)/.*#\3#')
REPO=$(echo "$REPO_URL" | sed -E 's#.*/([^/]+)\.git#\1#')
REPO_NAME=$(basename -s .git "$REPO_URL")

# --- Build time ---
BUILD_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- Build JSON safely with jq ---
BUILD_INFO=$(jq -n \
  --arg branch "refs/tags/$VERSION" \
  --arg org "$ORG" \
  --arg product "$REPO_NAME" \
  --arg repo "$REPO" \
  --arg sha "$TAG_COMMIT_SHA" \
  --arg version "$VERSION" \
  --arg buildTime "$BUILD_TIME" \
  '{branch, org, product, repo, sha, version, buildTime}'
)

ENCODED_BUILD_INFO=$(echo "$BUILD_INFO" | base64 -w0)

# Output for -ldflags
echo "-X main.buildInfo=$ENCODED_BUILD_INFO"