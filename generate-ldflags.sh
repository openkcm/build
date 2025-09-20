#!/usr/bin/env bash
set -euo pipefail

# --- Version from tags ---
if [[ -z "${VERSION:-}" ]]; then
  VERSION=$("$(dirname "$0")/get-version.sh")
fi

# --- Git values ---
SHA=$(git rev-parse HEAD)
ORG=$(echo "$REPO_URL" | sed -E 's#(git@|https://)([^/:]+)[:/]([^/]+)/.*#\3#')
REPO_NAME=$(basename "$REPO_URL")

TAG="refs/tags/$VERSION"

# Get the commit SHA for the tag
if git rev-parse -q --verify "$TAG" >/dev/null 2>&1; then
  SHA=$(git rev-list -n 1 "$TAG")
fi

# --- Build time ---
BUILD_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- Build JSON ---
ENCODED_BUILD_INFO=$(cat <<EOF | base64 -w0
{"branch": "$TAG","org": "$ORG","product": "$REPO_NAME","repo": "$REPO_URL","sha": "$SHA","version": "$VERSION","buildTime": "$BUILD_TIME"}
EOF
)

# Output for -ldflags
echo "-X main.buildInfo=$ENCODED_BUILD_INFO"
