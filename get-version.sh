#!/bin/bash -eu

set -euo pipefail
source "$(realpath "$(dirname $0)/environment.sh")"

if [[ -n "${VERSION_OVERRIDE:-}" ]]; then
  echo -n "$VERSION_OVERRIDE"
  exit 0
fi

if [ ! -f "${PROJECT_ROOT}/VERSION" ]; then
  if command -v git >/dev/null 2>&1; then
    git fetch --tags --force
    latest_tag=$(git describe --tags $(git rev-list --tags --max-count=1) 2>/dev/null || echo "v0.0.0")
    echo "$latest_tag" > $PROJECT_ROOT/VERSION
  else
    echo "v0.0.0" > $PROJECT_ROOT/VERSION
  fi
fi

VERSION="$(cat "${PROJECT_ROOT}/VERSION")"

(
  cd "$PROJECT_ROOT"

  if [[ "$VERSION" = *-dev ]] ; then
    VERSION="$VERSION-$(git rev-parse HEAD)"
  fi

  echo "$VERSION"
)
