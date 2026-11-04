#!/usr/bin/env bash
# Runs on the HOST before the container is built (devcontainer initializeCommand, make build/up).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .gitmodules ]; then
    git submodule update --init --recursive
fi
mkdir -p datasets

# compose.yaml reads USER_UID from .env
echo "USER_UID=$(id -u)" > .env
