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
    git fetch --tags --force
    latest_tag=$(git describe --tags $(git rev-list --tags --max-count=1) 2>/dev/null || echo "${VERSION}")

    # Extract version components
    major=$(echo $latest_tag | cut -d. -f1 | tr -d 'v')
    minor=$(echo $latest_tag | cut -d. -f2)
    patch=$(echo $latest_tag | cut -d. -f3)

    if jq -e '.pull_request != null' "$GITHUB_EVENT_PATH" > /dev/null; then
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
    else
      echo "❌ Skipping release, as is not done through pull request!"
      exit 1
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
