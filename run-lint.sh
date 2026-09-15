#!/bin/bash

# Runs 'go test' on all modules.
# Expects NESTED_MODULES to be set and the code directories being passed in as arguments.

set -euo pipefail
source "$(realpath "$(dirname $0)/environment.sh")"

# Resolve the linter config once.
# Passing '-c' with a path that does not exist makes golangci-lint fail hard ("can't read viper
# config", exit 3) rather than falling back to anything, and golangci-lint accepts several config
# file names, not just '.golangci.yaml'. So look for all of them, and when the repo has none, fall
# back to the shared openkcm default shipped alongside this script instead of letting golangci-lint
# drop to its own 'standard' set of five linters.
LINT_CONFIG=""
for candidate in .golangci.yaml .golangci.yml .golangci.toml .golangci.json; do
  if [[ -f "$PROJECT_ROOT/$candidate" ]]; then
    LINT_CONFIG="$PROJECT_ROOT/$candidate"
    break
  fi
done

if [[ -z "$LINT_CONFIG" ]]; then
  LINT_CONFIG="$COMMON_SCRIPT_DIR/golangci-default.yaml"
  msg="No golangci-lint config in $PROJECT_ROOT; falling back to the shared openkcm default ($LINT_CONFIG). Add a .golangci.yaml to pin this repo's own rules."
  # Surface this in the GitHub Actions UI, not just buried in the log.
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::warning title=No golangci-lint config::${msg}"
  fi
  echo "⚠️  ${msg}" >&2

  if [[ ! -f "$LINT_CONFIG" ]]; then
    echo "❌ Shared default linter config is missing: $LINT_CONFIG" >&2
    exit 1
  fi
fi

function run_lint() {
  "$LINTER" run -c "$LINT_CONFIG" "$@"
}

function check_go_mod_tidy() {
  echo "> Checking go mod tidy ..." | indent 2
  if ! go mod tidy --diff; then
    echo "❌ go.mod/go.sum not tidy. Run 'go mod tidy'." >&2
    exit 1
  fi
}

echo "> Running linter ..."

# NESTED_MODULES must be set to the list of nested go modules, e.g. 'api,nested2,nested3'
paths=("$@")
for nm in ${NESTED_MODULES//,/ }; do
  echo "> Linting $nm module ..." | indent 1
  # filter out paths that belong to the nested module by prefix matching
  module_paths=()
  non_module_paths=()
  for val in "${paths[@]}"; do
    if [[ "$val" =~ ^$PROJECT_ROOT/$nm ]] || [[ "$val" =~ ^$nm ]]; then
      module_paths+=("$val")
    else
      non_module_paths+=("$val")
    fi
  done
  paths=("${non_module_paths[@]}")
  (
    cd "$PROJECT_ROOT/$nm"
    run_lint "${module_paths[@]}"
  )
done

echo "> Linting root module ..." | indent 1
(
  cd "$PROJECT_ROOT"
  check_go_mod_tidy
  run_lint "${paths[@]}"
)
