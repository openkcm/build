#!/usr/bin/env bash
set -euo pipefail


# --- Version from tags ---
if [[ -z "${VERSION:-}" ]]; then
  VERSION=$("$COMMON_SCRIPT_DIR/get-version.sh")
fi

# --- Git values ---
BRANCH=$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)
SHA=$(git rev-parse HEAD)
REPO_URL=$(git config --get remote.origin.url)
ORG=$(echo "$REPO_URL" | sed -E 's#(git@|https://)([^/:]+)[:/]([^/]+)/.*#\3#')
REPO=$(echo "$REPO_URL" | sed -E 's#.*/([^/]+)\.git#\1#')
REPO_NAME=$(basename -s .git "$REPO_URL")



TAG="refs/tags/$VERSION"

# Get the commit hash for the tag
TAG_COMMIT_SHA=$(git rev-list -n 1 "$TAG")

# Extract commit metadata from the tag commit
COMMIT_MSG=$(git log -1 --pretty=%s "$TAG_COMMIT_SHA")
COMMIT_AUTHOR=$(git log -1 --pretty="%an <%ae>" "$TAG_COMMIT_SHA")
COMMIT_DATE=$(git log -1 --pretty=%cI "$TAG_COMMIT_SHA")


# --- Build time---
BUILD_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ)"


ENCODED_BUILD_INFO=$(cat <<EOF | base64 -w0
{
  "branch": "$TAG",
  "org": "$ORG",
  "product": "$REPO_NAME",
  "repo": "$REPO",
  "sha": "$SHA",
  "version": "$VERSION",
  "buildTime": "$BUILD_TIME",
  "commitMessage": "$COMMIT_MSG",
  "commitAuthor": "$COMMIT_AUTHOR",
  "commitDate": "$COMMIT_DATE"
}
EOF
)

echo "-ldflags \"-X main.buildInfo=base64($ENCODED_BUILD_INFO)\""