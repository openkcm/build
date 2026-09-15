#!/bin/bash -eu

set -euo pipefail
source "$(realpath "$(dirname $0)/environment.sh")"

if [[ -n "${VERSION_OVERRIDE:-}" ]]; then
  echo -n "$VERSION_OVERRIDE"
  exit 0
fi

if [ ! -f "${PROJECT_ROOT}/VERSION" ]; then
  # Best effort: CI already checks out with fetch-tags, and locally the remote may be absent or
  # unreachable. A failed fetch must not abort every 'task' invocation -- fall back to local tags.
  git fetch --tags --force >/dev/null 2>&1 || true
  # Highest version tag, NOT the most recently committed one: 'git rev-list --tags --max-count=1'
  # orders by commit date, so a hotfix (e.g. v1.7.1 cut from v1.7.0 after v1.8.0 shipped) would win.
  # 'for-each-ref --count=1' avoids a 'head -n1' pipe, which would trip 'pipefail' via SIGPIPE.
  latest_tag=$(git for-each-ref --sort=-v:refname --format='%(refname:short)' --count=1 refs/tags 2>/dev/null || true)
  latest_tag="${latest_tag:-v0.0.0}"
  echo "$latest_tag" > $PROJECT_ROOT/VERSION
fi

VERSION="$(cat "${PROJECT_ROOT}/VERSION")"

(
  cd "$PROJECT_ROOT"

  if [[ "$VERSION" = *-dev ]] ; then
    VERSION="$VERSION-$(git rev-parse HEAD)"
  fi

  if [[ -n "${VERSION_PREFIX:-}" ]]; then
    VERSION="${VERSION_PREFIX}${VERSION}"
  fi

  echo "$VERSION"
)
