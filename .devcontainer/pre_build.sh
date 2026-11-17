#!/usr/bin/env bash
# Runs on the host before building or starting the devcontainer.
set -euo pipefail
cd "$(dirname "$0")/.."

# Initialise missing submodules without moving existing checkouts.
if [ -f .gitmodules ]; then
    while IFS= read -r line; do
        if [[ "$line" == -* ]]; then
            path=${line#* }
            path=${path%% *}
            git submodule update --init --recursive -- "$path"
        fi
    done < <(git submodule status)
fi
mkdir -p datasets

# Preserve user configuration while updating the UID used by Compose.
tmp=$(mktemp .env.XXXXXX)
trap 'rm -f "$tmp"' EXIT
if [ -f .env ]; then
    awk '!/^[[:space:]]*(export[[:space:]]+)?USER_UID[[:space:]]*=/' .env > "$tmp"
fi
printf 'USER_UID=%s\n' "$(id -u)" >> "$tmp"
mv "$tmp" .env
