#!/usr/bin/env bash

# One-shot migration for the image path change (ghcr.io/openkcm/<repo>/images/<image> ->
# ghcr.io/openkcm/images/[<repo>/]<image>).
#
# Only needed for images that one repository consumes from ANOTHER repository: a repo's own images
# are pushed before they are read within the same publish job, but a composite resolves its plugin
# images from other repos, looks up that repo's latest git tag, and fails hard if that exact tag is
# not present at the resolved path. Copying the existing images across removes the ordering
# dependency, so repos can be released in any order.
#
# 'crane copy --all-tags' retains digests, which matters: the sha256-<digest> tags are cosign
# signatures and stay valid only if the digest they refer to is preserved.
#
# Usage:
#   ./migrate-image-paths.sh              # dry run, prints what would be copied
#   ./migrate-image-paths.sh --apply      # actually copy (needs push rights: crane auth login ghcr.io)
#   ./migrate-image-paths.sh --all        # include every repo, not just cross-repo dependencies
#
# Delete this script once the migration has been done.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APPLY=false
ALL=false
for a in "$@"; do
  case "$a" in
    --apply) APPLY=true ;;
    --all)   ALL=true ;;
    *) echo "unknown argument: $a" >&2; exit 1 ;;
  esac
done

CRANE="${CRANE:-crane}"
command -v "$CRANE" >/dev/null 2>&1 || { echo "❌ crane not found; set CRANE=/path/to/crane" >&2; exit 1; }

# "<repo> <image>" pairs. These are the images consumed by another repository's composite build
# (cmk and dummy-service), which is what breaks if they are missing at the new path.
CROSS_REPO=(
  "keystore-plugins keystore-plugins"
  "identity-management-plugins identity-management-plugins"
  "dummy-plugins dummy-plugins"
)

# Everything else, for completeness. Not required to keep releases working.
OTHER=(
  "registry registry"
  "checker checker"
  "session-manager session-manager"
  "gateway-extension gateway-extension"
  "crypto-edge-operator crypto-edge-operator"
  "krypton-operator krypton-operator"
  "platform-mesh-controller platform-mesh-controller"
  "cmk-ui cmk-ui"
  "extauthz extauthz"
)

PAIRS=("${CROSS_REPO[@]}")
$ALL && PAIRS+=("${OTHER[@]}")

BASE="${BASE_REGISTRY:-ghcr.io/openkcm}"
FAIL=0

echo "crane:  $("$CRANE" version 2>/dev/null || echo unknown)"
echo "mode:   $($APPLY && echo APPLY || echo 'DRY RUN (pass --apply to copy)')"
echo

for pair in "${PAIRS[@]}"; do
  read -r repo image <<<"$pair"

  src="${BASE}/${repo}/images/${image}"
  # Destination comes from get-registry.sh so this script cannot disagree with the build.
  dst_base="$(REPO_NAME="$repo" "$SCRIPT_DIR/get-registry.sh" --image "$image")"
  dst="${dst_base}/${image}"

  n=$("$CRANE" ls "$src" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$n" == "0" ]]; then
    echo "⏭  $src — no tags readable, skipping"
    continue
  fi

  echo "📦 $src"
  echo "   -> $dst   ($n tags, including cosign signatures)"

  if $APPLY; then
    if "$CRANE" copy --all-tags "$src" "$dst"; then
      echo "   ✅ copied"
    else
      echo "   ❌ failed"
      FAIL=$((FAIL + 1))
    fi
  fi
done

echo
if $APPLY; then
  [[ "$FAIL" -eq 0 ]] && echo "✅ migration complete" || { echo "❌ $FAIL repo(s) failed"; exit 1; }
else
  echo "Dry run only. Re-run with --apply (after 'crane auth login ghcr.io') to copy."
fi
