#! /usr/bin/env sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_NUM_FILE="${SCRIPT_DIR}/image_build_num.txt"
BUILD_DESCRIPTOR_FILE="${SCRIPT_DIR}/image_build_descriptor.txt"

if [[ -s ${BUILD_NUM_FILE} ]]
then
    BUILD_NUM=$(head -1 ${BUILD_NUM_FILE} | tr -d '\n')
else
    echo "The build number file is missing or empty."
    exit -1
fi

if [[ -s ${BUILD_DESCRIPTOR_FILE} ]]
then
    BUILD_DESCRIPTOR=$(head -1 ${BUILD_DESCRIPTOR_FILE} | tr -d '\n')
else
    echo "The build descriptor file is missing or empty."
    exit -1
fi

echo "$(${SCRIPT_DIR}/get_metastore_version.sh)-${BUILD_DESCRIPTOR}-${BUILD_NUM}"
