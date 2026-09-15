#!/usr/bin/env bash

# Exercises this repository against a throwaway "consuming repo", the way a real openkcm service
# repo uses it (this repo checked out at hack/common, a Taskfile including Taskfile_service.yaml).
#
# Nothing else in this repo tests itself: every workflow here is 'workflow_call' only, so a defect
# cannot fail until it fails in a consuming repo's release. This script is that missing gate.
#
# Usage: ./self-test.sh [fixture-dir]     (default: a mktemp dir, removed on exit)

set -uo pipefail

BUILD_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="${1:-}"
if [[ -z "$FIXTURE" ]]; then
  FIXTURE="$(mktemp -d)"
  trap 'rm -rf "$FIXTURE"' EXIT
fi
mkdir -p "$FIXTURE"
# Resolve to the physical path: on macOS mktemp returns /var/folders/... which is a symlink to
# /private/var/..., and Go then treats the module root and the build target as different trees
# ("directory ... outside main module").
FIXTURE="$(cd "$FIXTURE" && pwd -P)"

PASS=0
FAIL=0

ok()   { echo "  ✅ $1"; PASS=$((PASS + 1)); }
bad()  { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
step() { echo; echo "── $1"; }

# check <description> <expected> <actual>
check() {
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi
}

# ---------------------------------------------------------------------------
step "Shell scripts parse"
for f in "$BUILD_REPO"/*.sh; do
  if bash -n "$f" 2>/dev/null; then ok "$(basename "$f")"; else bad "$(basename "$f") has a syntax error"; fi
done

# ---------------------------------------------------------------------------
step "Building fixture consuming repo at $FIXTURE"
mkdir -p "$FIXTURE"/{hack,cmd/app,cli,charts/demo}
# A real submodule is a directory, not a symlink: task resolves included taskfiles through symlinks
# and would run commands outside the module.
cp -R "$BUILD_REPO"/ "$FIXTURE/hack/common/"
rm -rf "$FIXTURE/hack/common/.git"

printf 'module github.com/openkcm/demo\n\ngo 1.24\n'                       > "$FIXTURE/go.mod"
printf 'package main\n\nfunc main() {}\n'                                  > "$FIXTURE/cmd/app/main.go"
printf 'package main\n\nimport "fmt"\n\nfunc main() { fmt.Println("x") }\n' > "$FIXTURE/cli/main.go"
printf 'Apache-2.0\n'                                                      > "$FIXTURE/LICENSE"
printf '# demo\n'                                                          > "$FIXTURE/README.md"
printf 'apiVersion: v2\nname: demo\nversion: 0.1.0\nappVersion: "0.1.0"\n' > "$FIXTURE/charts/demo/Chart.yaml"
printf 'image:\n  tag: 0.1.0\n'                                            > "$FIXTURE/charts/demo/values.yaml"

cat > "$FIXTURE/Taskfile.yaml" <<'EOF'
version: 3
includes:
  shared:
    taskfile: hack/common/Taskfile_service.yaml
    flatten: true
    vars:
      CODE_DIRS: '{{.ROOT_DIR}}/cmd/... {{.ROOT_DIR}}/cli/...'
      COMPONENTS: 'app'
      CHART_COMPONENTS: 'demo'
      CLI_COMPONENTS: './cli:democtl'
      CLI_DIST_PLATFORMS: 'linux/amd64 windows/amd64'
EOF

(
  cd "$FIXTURE"
  git init -q
  git config user.email t@example.com; git config user.name t
  git add -A && git commit -qm init
  # v1.8.0 is the highest version, but the v1.7.1 hotfix is committed LAST -- a tag lookup that
  # orders by commit date instead of version would pick v1.7.1 here.
  git tag v1.7.0
  git commit -qm second --allow-empty && git tag v1.8.0
  git checkout -q -b hotfix v1.7.0
  git commit -qm hotfix --allow-empty && git tag v1.7.1
  git checkout -q master 2>/dev/null || git checkout -q main
) >/dev/null 2>&1
ok "fixture created (tags: v1.7.0, v1.8.0, hotfix v1.7.1)"

export GITHUB_REPOSITORY="openkcm/demo"
cd "$FIXTURE"

# ---------------------------------------------------------------------------
step "task runs without GitHub Actions environment"
# Regression guard: top-level vars are evaluated before ANY task, so a var whose 'sh:' needs
# GITHUB_EVENT_PATH (or a reachable git remote) breaks every task on a developer machine.
if env -u GITHUB_EVENT_PATH task --list >/dev/null 2>&1; then ok "task --list"; else bad "task --list failed"; fi

v=$(env -u GITHUB_EVENT_PATH task version 2>/dev/null | tail -1)
check "task version resolves the HIGHEST tag, not the newest-committed one" "v1.8.0" "$v"
rm -f VERSION

# ---------------------------------------------------------------------------
step "Pinned tool download URLs resolve"
# The tools:* tasks are internal, so they cannot be invoked directly. What actually breaks is the
# URL: a tag mangled by 'trimPrefix "v"' 404s and the tool can never install. Assert the URLs the
# pinned versions produce, reading each version from tasks_tools.yaml so a version bump is covered.
pinned_version() { # pinned_version <VAR_NAME> -> e.g. v4.45.4
  sed -n "s/.*${1}: '{{ env \"${1}\" | default ( .${1} | default \"\([^\"]*\)\" ) }}'.*/\1/p" \
    "$BUILD_REPO/tasks_tools.yaml" | head -1
}
url_ok() { # url_ok <description> <url>
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 30 "$2" || echo "000")
  if [[ "$code" == "200" ]]; then ok "$1 ($code)"; else bad "$1 -> HTTP $code: $2"; fi
}

# Render the URL AS WRITTEN in tasks_tools.yaml rather than reconstructing it here -- otherwise a
# mangled tag in the real URL would not be caught.
render_url() { # render_url <substring identifying the curl line>
  local url var v
  # Anchor on '" --output' rather than the next '"': the URL itself contains quotes, as in
  # {{.JQ_VERSION | trimPrefix "v"}}.
  url=$(grep -m1 -- "$1" "$BUILD_REPO/tasks_tools.yaml" | sed -n 's#.*curl -sfL "\(.*\)" --output.*#\1#p')
  url=${url//\{\{.OS\}\}/linux}
  url=${url//\{\{.JQ_OS\}\}/linux}
  url=${url//\{\{.ARCH\}\}/amd64}
  for var in JQ_VERSION YQ_VERSION HELM_VERSION; do
    v=$(pinned_version "$var")
    url=${url//"{{.${var} | trimPrefix \"v\"}}"/${v#v}}
    url=${url//"{{.${var}}}"/$v}
  done
  echo "$url"
}

for tool in "jq:jqlang/jq/releases" "yq:mikefarah/yq/releases" "helm:get.helm.sh"; do
  name="${tool%%:*}"; pat="${tool#*:}"
  u=$(render_url "$pat")
  if [[ -z "$u" || "$u" == *'{{'* ]]; then
    bad "${name}: could not render the download URL from tasks_tools.yaml ('${u}')"
  else
    url_ok "${name} $(basename "$u")" "$u"
  fi
done

# ---------------------------------------------------------------------------
step "CLI release archives"
cli_out=$(env -u GITHUB_EVENT_PATH task build:bin:build_cli 2>&1)
cli_rc=$?
if [[ "$cli_rc" -ne 0 ]]; then echo "$cli_out" | tail -5 | sed 's/^/     | /'; fi
if [[ "$cli_rc" -eq 0 ]]; then
  n=$(ls -1 dist/*.tar.gz dist/*.zip 2>/dev/null | wc -l | tr -d ' ')
  check "two archives produced (linux tar.gz + windows zip)" "2" "$n"
  if unzip -Z1 dist/democtl_v1.8.0_windows_amd64.zip 2>/dev/null | grep -q 'democtl\.exe$'; then
    ok "windows archive contains democtl.exe"
  else
    bad "windows archive is missing democtl.exe"
  fi
  if [[ -s dist/checksums.txt ]]; then ok "checksums.txt written"; else bad "checksums.txt missing or empty"; fi
else
  bad "task build:bin:build_cli failed"
fi

# ---------------------------------------------------------------------------
step "Helm chart packaging"
if env -u GITHUB_EVENT_PATH task build:helm:build >/dev/null 2>&1 && ls tmp/demo-*.tgz >/dev/null 2>&1; then
  ok "chart packaged from charts/demo"
else
  bad "task build:helm:build did not package charts/demo"
fi

# ---------------------------------------------------------------------------
step "OCM component descriptor renders correctly"
# components.yaml is a spiff template; a field missing its '(( ))' wrapper silently publishes the
# literal template text into every component descriptor.
if command -v ocm >/dev/null 2>&1; then
  # '--dry-run -O -' renders the descriptor without resolving ociArtifact digests, so this needs
  # no registry credentials and no published chart/image.
  rendered=$(ocm add componentversions --dry-run -O - --file ./.selftest-cv --version v1.8.0 \
    --create --force --templater spiff "$BUILD_REPO/components.yaml" -- \
    VERSION=v1.8.0 ORG_NAME=openkcm CHART_REGISTRY=ghcr.io/openkcm/charts \
    IMG_REGISTRY=ghcr.io/openkcm/demo/images COMMIT=deadbeef \
    MODULE_NAME=github.com/openkcm/demo REPO_URL=https://github.com/openkcm/demo \
    COMPONENTS="app" CD_VERSION="" CHART_VERSION=0.1.0 IMG_VERSION=v1.8.0 \
    BP_COMPONENTS="[]" CHART_COMPONENTS="demo:0.1.0:demo" IMG_COMPONENTS="app:v1.8.0" 2>/dev/null)
  rm -rf .selftest-cv

  prov=$(awk '/^provider:/{getline; print $2; exit}' <<<"$rendered")
  check "provider is the org name, not the literal template text" "openkcm" "$prov"

  if grep -q 'imageReference: ghcr.io/openkcm/charts/demo:0.1.0' <<<"$rendered"; then
    ok "helm chart resolved to <CHART_REGISTRY>/<chart name>:<version>"
  else
    bad "helm chart imageReference is wrong"
  fi
else
  echo "  ⚠️  ocm CLI not on PATH, skipping descriptor render"
fi

# ---------------------------------------------------------------------------
echo
echo "════════════════════════════════════════"
echo "  passed: $PASS   failed: $FAIL"
echo "════════════════════════════════════════"
[[ "$FAIL" -eq 0 ]]
