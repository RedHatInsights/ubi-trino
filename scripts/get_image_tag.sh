#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_NUM_FILE="${REPO_DIR}/image_build_num.txt"

if [ -s "${BUILD_NUM_FILE}" ]
then
    BUILD_NUM=$(head -1 "${BUILD_NUM_FILE}" | tr -d '\n')
else
    echo "The build number file is missing or empty." >&2
    exit 1
fi

TRINO_VERSION=$("${SCRIPT_DIR}/get_trino_version.sh")
echo "${TRINO_VERSION}-${BUILD_NUM}"
