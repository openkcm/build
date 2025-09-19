#!/usr/bin/env bash
set -euo pipefail

# --- Git values ---
BRANCH=$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)
SHA=$(git rev-parse HEAD)
REPO_URL=$(git config --get remote.origin.url)
ORG=$(echo "$REPO_URL" | sed -E 's#(git@|https://)([^/:]+)[:/]([^/]+)/.*#\3#')
REPO=$(echo "$REPO_URL" | sed -E 's#.*/([^/]+)\.git#\1#')
REPO_FULL="$ORG/$REPO"

# --- Version from tags ---
if [[ -z "${VERSION:-}" ]]; then
  VERSION=$("$COMMON_SCRIPT_DIR/get-version.sh")
fi

# --- Build time---
BUILD_TIME="$(date -u +"+%Y%m%d.%H%M%S")"


ENCODED_BUILD_INFO=$(cat <<EOF | base64 -w0
{"branch": "refs/tags/$VERSION","org": "$ORG","product": "$REPO","repo": "$REPO_FULL","sha": "$SHA","version": "$VERSION","buildTime": "$BUILD_TIME"}
EOF
)

echo "-ldflags \"-X main.buildInfo=$ENCODED_BUILD_INFO\""