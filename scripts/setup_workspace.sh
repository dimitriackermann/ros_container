#!/usr/bin/env bash
# Runs inside the container: devcontainer postCreateCommand and `make up`.
set -eo pipefail

WS=/opt/workspace
source "/opt/ros/${ROS_DISTRO}/setup.bash"

echo "== Python packages (${WS}/py_packages)"
for pkg_dir in "${WS}"/py_packages/*/; do
    [ -f "${pkg_dir}pyproject.toml" ] || continue
    python3 -m pip install --user --no-deps -e "${pkg_dir}"
done

echo "== ROS workspace (${WS}/ros2_ws)"
cd "${WS}/ros2_ws"
sudo apt-get update -qq
rosdep update --rosdistro "${ROS_DISTRO}" -q
rosdep install --from-paths src --ignore-src -y -q
colcon build --symlink-install
