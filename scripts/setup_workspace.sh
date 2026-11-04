#!/usr/bin/env bash
# Runs INSIDE the container: devcontainer postCreateCommand and `make up`.
# Idempotent: only installs/builds what is missing. Pass --force to redo everything.
set -eo pipefail

WS=/opt/workspace
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

source "/opt/ros/${ROS_DISTRO}/setup.bash"

echo "== Python packages (${WS}/py_packages)"
for pkg_dir in "${WS}"/py_packages/*/; do
    [ -f "${pkg_dir}pyproject.toml" ] || continue
    name=$(basename "${pkg_dir}")
    if [ "${FORCE}" = 1 ] || ! python3 -c "import ${name}" 2>/dev/null; then
        pip install --user --no-deps -e "${pkg_dir}"
    else
        echo "${name} already installed"
    fi
done

echo "== ROS workspace (${WS}/ros2_ws)"
cd "${WS}/ros2_ws"
if [ "${FORCE}" = 1 ] || [ ! -f install/setup.bash ]; then
    sudo apt-get update -qq
    rosdep update --rosdistro "${ROS_DISTRO}" -q
    rosdep install --from-paths src --ignore-src -y -q
    colcon build --symlink-install
else
    echo "install/ exists, skipping colcon build (use --force or 'colcon build' to rebuild)"
fi
