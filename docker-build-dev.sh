#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_TAG="$(${SCRIPT_DIR}/get_image_tag.sh)"

echo "Executing local trino docker image build..."
docker build \
       -t quay.io/cloudservices/ubi-trino:latest \
       -t quay.io/cloudservices/ubi-trino:${IMAGE_TAG} \
       -f "${SCRIPT_DIR}/Dockerfile" \
       $@ \
       "${SCRIPT_DIR}"
