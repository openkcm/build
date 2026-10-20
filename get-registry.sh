#!/bin/bash -eu

set -euo pipefail

# Prints the registry path for images, helm charts or OCM components.
#
# Images are published as:
#
#   <BASE_REGISTRY>/images/<repo>/<image>     normally
#   <BASE_REGISTRY>/images/<repo>             when the image is named after its repository
#
# The 'images/' namespace keeps them clearly separate from <BASE_REGISTRY>/charts (helm charts)
# and <BASE_REGISTRY>/components (OCM components).
#
# Within it, a repository publishing a single image named after itself gets a short
# 'ghcr.io/openkcm/images/registry' instead of repeating the name, while a repository publishing
# several keeps them namespaced under it ('ghcr.io/openkcm/images/cmk/cmkd'). The repository
# segment is what keeps images from different repos apart: crypto, crypto-edge and dummy-service
# all publish an image called 'tenant-manager'.
#
# '--image' takes the image name as an optional argument and prints the BASE to prepend to it, so
# that callers can keep concatenating "<base>/<image>" unchanged:
#
#   REPO_NAME=registry get-registry.sh --image registry        -> ghcr.io/openkcm/images
#   REPO_NAME=crypto   get-registry.sh --image tenant-manager  -> ghcr.io/openkcm/images/crypto
#   REPO_NAME=crypto   get-registry.sh --image                 -> ghcr.io/openkcm/images/crypto
#
# Setting IMAGE_REGISTRY explicitly overrides all of this and is used verbatim.

if [[ -z ${BASE_REGISTRY:-} ]]; then
  BASE_REGISTRY=ghcr.io/openkcm
fi

if [[ -z ${CHART_REGISTRY:-} ]]; then
  CHART_REGISTRY=$BASE_REGISTRY/charts
fi
if [[ -z ${COMPONENT_REGISTRY:-} ]]; then
  COMPONENT_REGISTRY=$BASE_REGISTRY/components
fi

mode="BASE_"
image_name=""

while [[ "$#" -gt 0 ]]; do
  case ${1:-} in
    "-i"|"--image")
      mode="IMAGE_"
      # Optional image name; anything that is not another flag belongs to --image.
      if [[ "$#" -gt 1 ]] && [[ "${2:-}" != -* ]]; then
        image_name="$2"
        shift
      fi
      ;;
    "-h"|"--helm")
      mode="CHART_"
      ;;
    "-c"|"--component")
      mode="COMPONENT_"
      ;;
    *)
      echo "invalid argument: $1" 1>&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z ${IMAGE_REGISTRY:-} ]]; then
  if [[ -n "$image_name" ]] && [[ "$image_name" == "${REPO_NAME:-}" ]]; then
    # The image is named after its repository: drop the repository segment so that the caller's
    # "<base>/<image>" concatenation yields <images>/<repo> rather than <repo>/<repo>.
    IMAGE_REGISTRY=$BASE_REGISTRY/images
  else
    IMAGE_REGISTRY=$BASE_REGISTRY/images/${REPO_NAME:-}
  fi
fi

eval echo "\$${mode}REGISTRY"
