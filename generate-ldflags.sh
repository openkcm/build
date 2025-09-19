#!/usr/bin/env bash
set -euo pipefail

# --- Git values ---
BRANCH=$(git symbolic-ref -q --short HEAD || git describe --tags --exact-match)
SHA=$(git rev-parse HEAD)
REPO_URL=$(git config --get remote.origin.url)
ORG=$(echo "$REPO_URL" | sed -E 's#(git@|https://)([^/:]+)[:/]([^/]+)/.*#\3#')
REPO=$(echo "$REPO_URL" | sed -E 's#.*/([^/]+)\.git#\1#')
REPO_NAME=$(basename -s .git "$REPO_URL")
COMMIT_MSG=$(git log -1 --pretty=%s)
COMMIT_AUTHOR=$(git log -1 --pretty="%an <%ae>")
COMMIT_DATE=$(git log -1 --pretty=%cI)

# --- Version from tags ---
if [[ -z "${VERSION:-}" ]]; then
  VERSION=$("$COMMON_SCRIPT_DIR/get-version.sh")
fi

# --- Build time---
BUILD_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ)"


ENCODED_BUILD_INFO=$(cat <<EOF | base64 -w0
json({
  "branch": "refs/tags/$VERSION",
  "org": "$ORG",
  "product": "$REPO_NAME",
  "repo": "$REPO",
  "sha": "$SHA",
  "version": "$VERSION",
  "buildTime": "$BUILD_TIME",
  "commitMessage": "$COMMIT_MSG",
  "commitAuthor": "$COMMIT_AUTHOR",
  "commitDate": "$COMMIT_DATE"
})
EOF
)

echo "-ldflags \"-X main.buildInfo=base64($ENCODED_BUILD_INFO)\""