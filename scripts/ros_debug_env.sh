#!/usr/bin/env bash
# Runs INSIDE the container (VS Code task before debugging).
# Writes the ROS + overlay environment to a file the Python debugger loads via "envFile",
# because VS Code does not source setup.bash for debugged processes.
set -eo pipefail

WS=/opt/workspace
OUT="${1:-${WS}/ros2_ws/install/debug.env}"

source "/opt/ros/${ROS_DISTRO}/setup.bash"
source "${WS}/ros2_ws/install/setup.bash"

# Import Python packages straight from ros2_ws/src (not the build/ symlinks), so breakpoints
# set in the source files always bind.
src_paths=$(find "${WS}/ros2_ws/src" -mindepth 2 -maxdepth 2 -name setup.py -printf '%h:')
export PYTHONPATH="${src_paths}${PYTHONPATH}"

env | grep -E '^(PATH|PYTHONPATH|LD_LIBRARY_PATH|AMENT_PREFIX_PATH|CMAKE_PREFIX_PATH|COLCON_PREFIX_PATH|ROS_[A-Z_]*|RMW_[A-Z_]*)=' > "${OUT}"
echo "wrote ${OUT}"
