#!/usr/bin/env bash
set -euo pipefail

# --- Version from tags ---
if [[ -z "${VERSION:-}" ]]; then
  VERSION=$("$(dirname "$0")/get-version.sh")
fi

# --- Git values ---
BRANCH=$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)
SHA=$(git rev-parse HEAD)
ORG=$(echo "$REPO_URL" | sed -E 's#(git@|https://)([^/:]+)[:/]([^/]+)/.*#\3#')
REPO_NAME=$(basename "$REPO_URL")

# --- Build time ---
BUILD_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- Build JSON ---
ENCODED_BUILD_INFO=$(cat <<EOF | base64 -w0
{"branch": "refs/tags/$VERSION","org": "$ORG","product": "$REPO_NAME","repo": "$REPO_URL","sha": "$SHA","version": "$VERSION","buildTime": "$BUILD_TIME"}
EOF
)

# Output for -ldflags
echo "-X main.buildInfo=$ENCODED_BUILD_INFO"
