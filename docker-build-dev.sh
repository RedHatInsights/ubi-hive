#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_TAG=$(${SCRIPT_DIR}/get_image_tag.sh)

echo "Executing local hive-metastore docker image build..."
docker build --target build \
       -t quay.io/cloudservices/ubi-hive:latest \
       -t quay.io/cloudservices/ubi-hive:${IMAGE_TAG} \
       -f "${SCRIPT_DIR}/Dockerfile" \
       $@ \
       "${SCRIPT_DIR}"
