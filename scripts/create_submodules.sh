#!/usr/bin/env bash
# One-time bootstrap: turn every package folder into its own git repo and register it as a
# submodule of the main repo. Each package gets a bare "remote" in ../ros_container_repos/;
# replace those later with real remotes:  git submodule set-url <path> <url>
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
REPOS=${REPOS:-$(cd .. && pwd)/ros_container_repos}
PACKAGES=(py_packages/num_add py_packages/num_sub
          ros2_ws/src/num_interfaces ros2_ws/src/num_nodes ros2_ws/src/bag_tools ros2_ws/src/num_bringup)
TRAILER="Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"

# .git/modules may already exist (created by the compose bind mount), so check for HEAD
[ -f .git/HEAD ] || git init -b main
mkdir -p "${REPOS}"

for path in "${PACKAGES[@]}"; do
    name=$(basename "${path}")
    if git config -f .gitmodules --get "submodule.${path}.url" >/dev/null 2>&1; then
        echo "${path} is already a submodule"; continue
    fi
    echo "== ${path} -> ${REPOS}/${name}.git"
    git -C "${path}" init -q -b main
    git -C "${path}" add -A
    git -C "${path}" commit -q -m "Initial ${name} package" -m "${TRAILER}"
    git clone -q --bare "${path}" "${REPOS}/${name}.git"
    rm -rf "${path}"      # content now lives in the bare repo; re-add it as a submodule
    git -c protocol.file.allow=always submodule add -q "${REPOS}/${name}.git" "${path}"
done

git add -A
git commit -q -m "ROS 2 Jazzy/Lyrical devcontainer with package submodules" -m "${TRAILER}"
git submodule status
