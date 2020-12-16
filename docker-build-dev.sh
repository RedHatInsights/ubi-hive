#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HIVE_VER=$(${SCRIPT_DIR}/get_hive_version.sh)

echo "Executing local presto docker image build..."
docker build \
       -t quay.io/cloudservices/ubi-hive:latest \
       -t quay.io/cloudservices/ubi-hive:${HIVE_VER} \
       -f "${SCRIPT_DIR}/Dockerfile" \
       $@ \
       "${SCRIPT_DIR}"
