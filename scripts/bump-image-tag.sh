#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_NUM_FILE="${REPO_DIR}/image_build_num.txt"

OLD_BUILD_NUM=$(head -1 "${BUILD_NUM_FILE}" | tr -d '\n')
NEW_BUILD_VALUE=$((10#${OLD_BUILD_NUM} + 1))
NEW_BUILD_NUM=$(printf "%03d" $NEW_BUILD_VALUE)
echo "$NEW_BUILD_NUM" > "${BUILD_NUM_FILE}"
git -C "${REPO_DIR}" add image_build_num.txt
