#!/usr/bin/env sh
set -eu

# Only numeric release tags are Trino server versions; ignore CLI and annotated tag refs.
TAGS=$(git ls-remote --tags https://github.com/trinodb/trino)
LATEST_TAG=$(printf '%s\n' "${TAGS}" | sed -nE 's|.*refs/tags/([0-9]+)$|\1|p' | sort -un | tail -1)
if [ -z "${LATEST_TAG}" ]; then
    echo "No numeric Trino release tags were found." >&2
    exit 1
fi
echo "${LATEST_TAG}"
