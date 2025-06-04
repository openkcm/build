#!/bin/bash -eu

set -euo pipefail

(
  cd "$PROJECT_ROOT"

  version=$YQ '.version' Chart.yaml
  echo "$version"
)
