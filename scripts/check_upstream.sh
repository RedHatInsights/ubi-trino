#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_TRINO_VER=$("${SCRIPT_DIR}/get_trino_version.sh")
UPSTREAM_TRINO_VER=$("${SCRIPT_DIR}/get_latest_repo_release_tag.sh")

if [ "${LOCAL_TRINO_VER}" -lt "${UPSTREAM_TRINO_VER}" ]; then
    if [ "${1:-}" != "quiet" ]; then
        echo "A newer version of trino has been released (${UPSTREAM_TRINO_VER})"
    fi
    exit 1
fi

if [ "${1:-}" != "quiet" ]; then
    echo "Up to date with trinodb/trino"
fi
