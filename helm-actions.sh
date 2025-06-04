#!/bin/bash -eu

set -euo pipefail

while [[ "$#" -gt 0 ]]; do
  case ${1:-} in
    "-p"|"--push")
        if $HELM pull "oci://${HELM_REGISTRY}/${COMPONENT}" --version "${CHART_VERSION}" >/dev/null 2>&1; then
          echo "Chart using version {{.CHART_VERSION}} already exist, do not push again."
        else
          echo "Chart using version {{.CHART_VERSION}} do not exist, continue pushing."
          $HELM push "${LOCALTMP}/${CHART_NAME}-${CHART_VERSION}.tgz" "oci://${HELM_REGISTRY}"; rm -f "${LOCALTMP}/${CHART_NAME}-${CHART_VERSION}.tgz"
          rm -f "${LOCALTMP}/${CHART_NAME}-${CHART_VERSION}.tgz"
        fi
      ;;
    "-b"|"--build")
        if $HELM pull "oci://${HELM_REGISTRY}/${COMPONENT}" --version "${CHART_VERSION}" >/dev/null 2>&1; then
          echo "Chart using version ${CHART_VERSION} already exist, do not build again."
        else
          echo "Chart using version ${CHART_VERSION} do not exist, continue building."
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
