#!/usr/bin/env bash
set -euo pipefail

# Provides COMMON_SCRIPT_DIR and PROJECT_ROOT. Without this the get-version.sh call below is an
# unbound-variable abort, which breaks every 'task' invocation (BUILD_LDFLAGS is a top-level var).
source "$(realpath "$(dirname "$0")/environment.sh")"

# --- Git values ---
SHA=$(git rev-parse HEAD)
# A clone without an 'origin' remote is normal locally; 'git config --get' exits 1 and would abort.
REPO_URL=$(git config --get remote.origin.url || echo "")
ORG=$(echo "$REPO_URL" | sed -E 's#(git@|https://)([^/:]+)[:/]([^/]+)/.*#\3#')
REPO=$(echo "$REPO_URL" | sed -E 's#.*/([^/]+)\.git#\1#')
REPO_NAME=$(basename "$REPO_URL")

# --- Version from tags ---
if [[ -z "${VERSION:-}" ]]; then
  VERSION=$("$COMMON_SCRIPT_DIR/get-version.sh")
fi

# --- Build time ---
BUILD_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- Build JSON ---
ENCODED_BUILD_INFO=$(cat <<EOF | base64 -w0
{"branch": "refs/tags/$VERSION","org": "$ORG","product": "$REPO_NAME","repo": "$REPO","sha": "$SHA","version": "$VERSION","buildTime": "$BUILD_TIME"}
EOF
)

# Output for -ldflags
echo "-X main.BuildInfo=base64($ENCODED_BUILD_INFO)"
