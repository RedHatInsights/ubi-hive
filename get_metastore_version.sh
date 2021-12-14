#! /usr/bin/env sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

grep -E '^ENV METASTORE_VERSION' ${SCRIPT_DIR}/Dockerfile | cut -d '=' -f 2
