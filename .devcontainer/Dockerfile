ARG ROS_DISTRO=jazzy
FROM ros:${ROS_DISTRO}-ros-base

ARG ROS_DISTRO
ARG USERNAME=ubuntu
ARG USER_UID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST \
    WORKSPACE=/opt/workspace \
    DATASETS_DIR=/opt/workspace/datasets

RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo git bash-completion python3-pip python3-pytest \
        ros-${ROS_DISTRO}-ros2bag \
        ros-${ROS_DISTRO}-rosbag2-storage-mcap \
        ros-${ROS_DISTRO}-foxglove-bridge \
        ros-${ROS_DISTRO}-std-srvs \
    && rm -rf /var/lib/apt/lists/*

# Reuse the base image's "ubuntu" user, matching the host UID so bind-mounted files stay
# owned by the host user on Linux hosts (Docker Desktop on macOS maps ownership anyway).
RUN if [ "${USER_UID}" != "$(id -u ${USERNAME})" ]; then usermod -u ${USER_UID} ${USERNAME}; fi \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# Named volumes for build/install/log and ~/.local (pip --user) are initialised from these dirs, so they get the
# right owner on first use.
RUN mkdir -p ${WORKSPACE}/py_packages ${WORKSPACE}/datasets \
        ${WORKSPACE}/ros2_ws/src ${WORKSPACE}/ros2_ws/build \
        ${WORKSPACE}/ros2_ws/install ${WORKSPACE}/ros2_ws/log \
        /home/${USERNAME}/.local \
    && chown -R ${USERNAME} ${WORKSPACE} /home/${USERNAME}/.local

RUN printf '%s\n' \
        "source /opt/ros/${ROS_DISTRO}/setup.bash" \
        "[ -f ${WORKSPACE}/ros2_ws/install/setup.bash ] && source ${WORKSPACE}/ros2_ws/install/setup.bash" \
        "PS1='(${ROS_DISTRO}) \\w \\$ '" \
        >> /home/${USERNAME}/.bashrc

# Sources ROS + workspace overlay before running any command (entrypoint and `ros_exec ...`)
COPY --chmod=755 ros_exec.sh /usr/local/bin/ros_exec
ENTRYPOINT ["/usr/local/bin/ros_exec"]

USER ${USERNAME}
WORKDIR ${WORKSPACE}
