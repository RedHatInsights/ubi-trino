#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

grep -E '^ARG TRINO_VERSION=' "${REPO_DIR}/Dockerfile" | cut -d '=' -f 2
