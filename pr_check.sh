#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

IMAGE_REPO="quay.io"
ORG="cloudservices"
APP="ubi-hive"
IMAGE="${IMAGE_REPO}/${ORG}/${APP}"
IMAGE_TAG="latest"

DOCKER_CONF="$PWD/.docker"
mkdir -p "$DOCKER_CONF"
docker --config="$DOCKER_CONF" build --no-cache -t ${IMAGE}:${IMAGE_TAG} -f ${SCRIPT_DIR}/Dockerfile ${SCRIPT_DIR}

