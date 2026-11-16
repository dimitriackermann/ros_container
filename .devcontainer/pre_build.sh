#!/usr/bin/env bash
# Runs on the HOST before the container is built (devcontainer initializeCommand, make build/up).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .gitmodules ]; then
    # Initialise only submodules that are not checked out yet. A plain `git submodule update`
    # would reset already checked-out packages to the commit recorded in the main repo and
    # silently drop newer local commits from the working tree.
    git submodule status | awk '/^-/{print $2}' | while read -r path; do
        git submodule update --init --recursive -- "${path}"
    done
    # Refuse to push the main repo while it points at package commits that are not pushed yet.
    git config push.recurseSubmodules check
fi
mkdir -p datasets

# compose.yaml reads USER_UID from .env; keep any other settings (ROS_DOMAIN_ID, ports, ...)
touch .env
grep -v '^USER_UID=' .env > .env.tmp || true
echo "USER_UID=$(id -u)" >> .env.tmp
mv .env.tmp .env
