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

# Extract org and repo name
if [[ "$REPO_URL" =~ github.com[:/](.+)/(.+)\.git ]]; then
  ORG="${BASH_REMATCH[1]}"
  REPO_NAME="${BASH_REMATCH[2]}"
fi

# --- Tag commit SHA fallback ---
TAG="$VERSION"
TAG_COMMIT_SHA=""

if git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null 2>&1; then
  TAG_COMMIT_SHA=$(git rev-list -n 1 "refs/tags/$VERSION")
elif [[ -n "${GITHUB_SHA:-}" ]]; then
  TAG_COMMIT_SHA=$GITHUB_SHA
fi

# fallback to HEAD if still empty
if [[ -z "$TAG_COMMIT_SHA" ]]; then
  TAG_COMMIT_SHA=$(git rev-parse HEAD)
fi

# --- Build time ---
BUILD_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- Build JSON ---
ENCODED_BUILD_INFO=$(cat <<EOF | base64 -w0
{"branch": "$BRANCH","org": "$ORG","product": "$REPO_NAME","repo": "$REPO","sha": "$TAG_COMMIT_SHA","version": "$VERSION","buildTime": "$BUILD_TIME"}
EOF
)

# Output for -ldflags
echo "-X main.buildInfo=$ENCODED_BUILD_INFO"
