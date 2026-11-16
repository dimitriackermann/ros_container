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
# The image bakes in the rosdep deps of the package.xml files it was built from. Check every time
# (fast, offline) so a dependency added since then is installed even when the build is skipped.
if [ "${FORCE}" = 1 ] || ! rosdep check --from-paths src --ignore-src -q >/dev/null 2>&1; then
    echo "installing missing rosdep dependencies (rebuild the image to bake them in)"
    sudo apt-get update -qq
    rosdep update --rosdistro "${ROS_DISTRO}" -q
    rosdep install --from-paths src --ignore-src -y -q
fi
if [ "${FORCE}" = 1 ] || [ ! -f install/setup.bash ]; then
    colcon build --symlink-install
else
    echo "install/ exists, skipping colcon build (use --force or 'colcon build' to rebuild)"
fi
