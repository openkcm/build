#!/bin/bash

set -euo pipefail
source "$(realpath "$(dirname $0)/environment.sh")"

if [[ -z "${VERSION:-}" ]]; then
  VERSION=$("$COMMON_SCRIPT_DIR/get-version.sh")
fi

semver=${1:-"minor"}

major=${VERSION%%.*}
major=${major#v}
minor=${VERSION#*.}
minor=${minor%%.*}
patch=${VERSION##*.}
patch=${patch%%-*}

case "$semver" in
  ("git-tags")
    # Best effort -- see get-version.sh for why a failed fetch must not be fatal.
    git fetch --tags --force >/dev/null 2>&1 || true
    # Highest version tag, NOT the most recently committed one -- see get-version.sh for why.
    latest_tag=$(git for-each-ref --sort=-v:refname --format='%(refname:short)' --count=1 refs/tags 2>/dev/null || true)
    latest_tag="${latest_tag:-v0.0.0}"

    # Extract version components
    major=$(echo $latest_tag | cut -d. -f1 | tr -d 'v')
    minor=$(echo $latest_tag | cut -d. -f2)
    patch=$(echo $latest_tag | cut -d. -f3)

    # GITHUB_EVENT_PATH only exists inside GitHub Actions; guard it so 'set -u' does not abort
    # every local 'task' invocation. In Actions the variable and the file are always present,
    # so the short-circuit is always true there and CI behaviour is unchanged.
    if [[ -n "${GITHUB_EVENT_PATH:-}" ]] && [[ -f "$GITHUB_EVENT_PATH" ]] && jq -e '.pull_request != null' "$GITHUB_EVENT_PATH" > /dev/null; then
       labels=$(jq -r '.pull_request.labels // [] | .[].name' "$GITHUB_EVENT_PATH")
       if echo "$labels" | grep -q "major"; then
         major=$((major + 1))
         minor=0
         patch=0
       elif echo "$labels" | grep -q "minor"; then
         minor=$((minor + 1))
         patch=0
       else
         patch=$((patch + 1))
       fi
    fi
    ;;
  ("major")
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  ("minor")
    minor=$((minor + 1))
    patch=0
    ;;
  ("patch")
    patch=$((patch + 1))
    ;;
  (*)
    echo "invalid argument: $semver"
    exit 1
    ;;
esac

echo -n "v$major.$minor.$patch"
