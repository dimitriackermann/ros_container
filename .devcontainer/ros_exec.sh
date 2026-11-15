#!/bin/bash
# Image entrypoint, installed as /usr/local/bin/ros_exec.
# Sources ROS and (if built) the workspace overlay, then runs the given command, e.g.
#   docker compose exec jazzy ros_exec ros2 topic list
source "/opt/ros/${ROS_DISTRO}/setup.bash"
if [ -f "${WORKSPACE}/ros2_ws/install/setup.bash" ]; then
    source "${WORKSPACE}/ros2_ws/install/setup.bash"
fi
exec "$@"
