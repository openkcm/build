#!/bin/bash -eu

set -euo pipefail

# 'helm package' names the archive after the chart's 'name' field in Chart.yaml, and 'helm push'
# publishes it under that same name. The component (directory) name is only used to locate the
# chart sources. Fall back to the component name for callers that do not pass CHART_NAME.
CHART_NAME="${CHART_NAME:-${COMPONENT}}"

while [[ "$#" -gt 0 ]]; do
  case ${1:-} in
    "-p"|"--push")
        if $HELM pull "oci://${HELM_REGISTRY}/${CHART_NAME}" --version "${CHART_VERSION}" >/dev/null 2>&1; then
          echo "Chart ${CHART_NAME}-${CHART_VERSION} version already exist, do not push again."
        else
          echo "Chart ${CHART_NAME}-${CHART_VERSION} version does not exist, continue pushing."
          $HELM push "${LOCALTMP}/${CHART_NAME}-${CHART_VERSION}.tgz" "oci://${HELM_REGISTRY}"
          rm -f "${LOCALTMP}/${CHART_NAME}-${CHART_VERSION}.tgz"
        fi
      ;;
    "-b"|"--build")
        if $HELM pull "oci://${HELM_REGISTRY}/${CHART_NAME}" --version "${CHART_VERSION}" >/dev/null 2>&1; then
          echo "Chart ${CHART_NAME}-${CHART_VERSION} version already exist, do not build again."
        else
          echo "Chart ${CHART_NAME}-${CHART_VERSION} version does not exist, continue building."
          $HELM package "${ROOT_DIR2}/charts/${COMPONENT}" -d "${LOCALTMP}" --version "${CHART_VERSION}"
        fi
      ;;

    *)
      echo "invalid argument: $1" 1>&2
      exit 1
      ;;
  esac
  shift
done
