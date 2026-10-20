#!/usr/bin/env bash

# Asserts the image reference every image task produces, for the three shapes a repo can have:
#
#   A  one image named after the repo      -> ghcr.io/openkcm/<repo>
#   B  one image with a different name     -> ghcr.io/openkcm/<repo>/<image>
#   C  several images, one repo-named      -> both of the above, side by side
#
# Case C is the one that matters: 'crypto' publishes both 'crypto' and 'tenant-manager', so the
# collapse has to be decided per image, not per repository.
#
# Usage: ./test-image-paths.sh

set -uo pipefail
BUILD_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
bad(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# ---------------------------------------------------------------------- unit
echo "── get-registry.sh resolves the base per image"
u(){ # u <repo> <image> <expected full ref>
  local got; got="$(REPO_NAME="$1" "$BUILD_REPO/get-registry.sh" --image "$2")/$2"
  if [[ "$got" == "$3" ]]; then ok "$1 + $2 -> $3"; else bad "$1 + $2 -> got '$got', want '$3'"; fi
}
u registry      registry       ghcr.io/openkcm/images/registry
u checker       checker        ghcr.io/openkcm/images/checker
u crypto        crypto         ghcr.io/openkcm/images/crypto
u crypto        tenant-manager ghcr.io/openkcm/images/crypto/tenant-manager
u crypto-edge   tenant-manager ghcr.io/openkcm/images/crypto-edge/tenant-manager
u cmk           cmkd           ghcr.io/openkcm/images/cmk/cmkd
u platform-mesh-microfrontend ui ghcr.io/openkcm/images/platform-mesh-microfrontend/ui

echo "── other registries and overrides are untouched"
[[ "$(REPO_NAME=r "$BUILD_REPO/get-registry.sh" --helm)"      == "ghcr.io/openkcm/charts" ]]     && ok "--helm"      || bad "--helm"
[[ "$(REPO_NAME=r "$BUILD_REPO/get-registry.sh" --component)" == "ghcr.io/openkcm/components" ]] && ok "--component" || bad "--component"
[[ "$(REPO_NAME=r IMAGE_REGISTRY=my.reg/x "$BUILD_REPO/get-registry.sh" --image r)" == "my.reg/x" ]] \
  && ok "IMAGE_REGISTRY override wins" || bad "IMAGE_REGISTRY override ignored"
[[ "$(REPO_NAME=r BASE_REGISTRY=other.io/org "$BUILD_REPO/get-registry.sh" --image r)" == "other.io/org/images" ]] \
  && ok "BASE_REGISTRY override honoured" || bad "BASE_REGISTRY override ignored"

# ------------------------------------------------------------------ fixture
FIXTURE="$(mktemp -d)"; FIXTURE="$(cd "$FIXTURE" && pwd -P)"
trap 'rm -rf "$FIXTURE" "${FIXTURE}.origin.git" "$(dirname "$FIXTURE")/$(basename "$FIXTURE").origin.git"' EXIT

# 'crypto' is case C: an image named after the repo plus a second one that is not.
mkdir -p "$FIXTURE"/{hack,cmd/crypto,cmd/tenant-manager}
cp -R "$BUILD_REPO"/ "$FIXTURE/hack/common/"; rm -rf "$FIXTURE/hack/common/.git"
printf 'module github.com/openkcm/crypto\n\ngo 1.24\n' > "$FIXTURE/go.mod"
for c in crypto tenant-manager; do printf 'package main\nfunc main(){}\n' > "$FIXTURE/cmd/$c/main.go"; done
printf 'FROM scratch\n' > "$FIXTURE/Dockerfile"
# Short-circuits get-version.sh, which otherwise does a (fatal) 'git fetch' against a remote the
# fixture does not have.
printf 'v1.0.0' > "$FIXTURE/VERSION"
cat > "$FIXTURE/Taskfile.yaml" <<'EOF'
version: 3
includes:
  shared:
    taskfile: hack/common/Taskfile_service.yaml
    flatten: true
    vars:
      COMPONENTS: 'crypto tenant-manager'
      CODE_DIRS: '{{.ROOT_DIR}}/cmd/...'
EOF
(
  cd "$FIXTURE"
  git init -q; git config user.email t@e.com; git config user.name t
  git add -A && git commit -qm i && git tag v1.0.0
  # A real (local, bare) origin: the version scripts run 'git fetch --tags --force' unconditionally
  # and abort when it fails, so the fixture needs a reachable remote.
  git init -q --bare "$FIXTURE/../$(basename "$FIXTURE").origin.git"
  git remote add origin "$FIXTURE/../$(basename "$FIXTURE").origin.git"
  git push -q origin HEAD --tags
) >/dev/null 2>&1

cd "$FIXTURE"
export GITHUB_REPOSITORY="openkcm/crypto"
# compute-next-release-version.sh dereferences this unconditionally; '{}' takes the non-PR branch.
printf '{}' > "$FIXTURE/event.json"
export GITHUB_EVENT_PATH="$FIXTURE/event.json"

# Collect every image reference the tasks would use, from --dry output.
refs(){ task "$1" --dry 2>&1 | grep -oE 'ghcr\.io/openkcm[a-z0-9/._-]*' | sort -u; }

echo "── image references produced by the real tasks (repo 'crypto')"
all=$(for t in build:img:build-raw build:img:push-multi build:img:all; do refs "$t"; done | sort -u)
if [[ -z "$all" ]]; then bad "no image references found (tasks failed?)"; else
  while read -r r; do echo "       $r"; done <<<"$all"
fi

want_collapsed="ghcr.io/openkcm/images/crypto"
want_nested="ghcr.io/openkcm/images/crypto/tenant-manager"
grep -qx "$want_collapsed"            <<<"$all" && ok "repo-named image  -> $want_collapsed"  || bad "missing $want_collapsed"
grep -qx "$want_nested"               <<<"$all" && ok "other image       -> $want_nested"     || bad "missing $want_nested"
grep -qx "ghcr.io/openkcm/images/crypto/crypto" <<<"$all" && bad "duplicated path ghcr.io/openkcm/images/crypto/crypto still produced" \
                                                   || ok "no duplicated <repo>/<repo> path"
grep -qE "^ghcr\.io/openkcm/images/" <<<"$all" && ok "images live under the images/ namespace" \
                                                || bad "images are not under ghcr.io/openkcm/images/"

echo
echo "  passed: $PASS   failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
