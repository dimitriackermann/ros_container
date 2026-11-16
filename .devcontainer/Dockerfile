# syntax=docker/dockerfile:1
# Build context: the repo root (see compose.yaml and .dockerignore).
#   dev      devcontainer / `make up`: tools + all rosdep deps; sources are bind-mounted, build in volumes
#   build    compiles the workspace and the py_packages wheels (CI and `runtime`)
#   runtime  self-contained image: install space + exec deps only, no sources or compilers
#            docker build -f .devcontainer/Dockerfile --target runtime -t ros_container:jazzy-runtime .
ARG ROS_DISTRO=jazzy
# compose.yaml passes a digest-pinned image per distro; this default is only for ad-hoc builds
ARG BASE_IMAGE=ros:${ROS_DISTRO}-ros-base
ARG RUNTIME_BASE_IMAGE=ros:${ROS_DISTRO}-ros-core

# ---------------------------------------------------------------------------------------------
# Only the package.xml files of ros2_ws/src. Copying this stage's result (not the sources) keeps
# the rosdep layers cached until a manifest changes.
FROM ${BASE_IMAGE} AS manifests
COPY ros2_ws/src /src
RUN find /src -type f ! -name package.xml -delete && find /src -depth -type d -empty -delete

# ---------------------------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS base
ARG ROS_DISTRO
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST \
    WORKSPACE=/opt/workspace \
    DATASETS_DIR=/opt/workspace/datasets
# Keep downloaded .debs in the apt cache mounts below
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
COPY --from=manifests /src /tmp/manifests
COPY --chmod=755 .devcontainer/ros_exec.sh /usr/local/bin/ros_exec
ENTRYPOINT ["/usr/local/bin/ros_exec"]

# ---------------------------------------------------------------------------------------------
FROM base AS dev
ARG ROS_DISTRO
ARG USERNAME=ubuntu
ARG USER_UID=1000

# Tools + every rosdep dependency (build, exec, test) of the workspace packages, baked into the
# image so they survive container re-creation. setup_workspace.sh only installs what is missing.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        sudo git bash-completion python3-pip python3-pytest \
    && rosdep update --rosdistro "${ROS_DISTRO}" -q \
    && rosdep install --from-paths /tmp/manifests --ignore-src -y -q --rosdistro "${ROS_DISTRO}"

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

USER ${USERNAME}
# rosdep cache for the user, so `rosdep check` in setup_workspace.sh works offline
RUN rosdep update --rosdistro "${ROS_DISTRO}" -q
WORKDIR ${WORKSPACE}

# ---------------------------------------------------------------------------------------------
FROM dev AS build
COPY --chown=ubuntu ros2_ws/src ${WORKSPACE}/ros2_ws/src
COPY --chown=ubuntu py_packages ${WORKSPACE}/py_packages
RUN cd ${WORKSPACE}/ros2_ws \
    && . /opt/ros/${ROS_DISTRO}/setup.sh \
    && colcon build --event-handlers console_direct+ --cmake-args -DCMAKE_BUILD_TYPE=Release \
    && pip wheel --no-deps -w /tmp/wheels ${WORKSPACE}/py_packages/*/

# ---------------------------------------------------------------------------------------------
# ros-core: no compilers (ros-base ships build-essential). Exec dependencies only, resolved
# with a throw-away rosdep that is purged again in the same layer.
FROM ${RUNTIME_BASE_IMAGE} AS runtime
ARG ROS_DISTRO
ENV DEBIAN_FRONTEND=noninteractive \
    ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST \
    WORKSPACE=/opt/workspace \
    DATASETS_DIR=/opt/workspace/datasets
RUN --mount=type=bind,from=manifests,source=/src,target=/tmp/manifests \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update && apt-get install -y --no-install-recommends python3-rosdep \
    && rosdep init && rosdep update --rosdistro "${ROS_DISTRO}" -q \
    && rosdep install --from-paths /tmp/manifests --ignore-src -y -q --rosdistro "${ROS_DISTRO}" \
        --dependency-types exec \
    && apt-get purge -y python3-rosdep \
    && rm -rf /etc/ros/rosdep /root/.ros
# py_packages are pure Python: unpack the wheels straight into dist-packages (no pip needed)
RUN --mount=type=bind,from=build,source=/tmp/wheels,target=/tmp/wheels \
    python3 -c "import glob, site, zipfile; [zipfile.ZipFile(w).extractall(site.getsitepackages()[0]) for w in glob.glob('/tmp/wheels/*.whl')]"
COPY --from=build ${WORKSPACE}/ros2_ws/install ${WORKSPACE}/ros2_ws/install
COPY --chmod=755 .devcontainer/ros_exec.sh /usr/local/bin/ros_exec
RUN mkdir -p ${DATASETS_DIR} && chown ubuntu ${DATASETS_DIR}
ENTRYPOINT ["/usr/local/bin/ros_exec"]
USER ubuntu
WORKDIR ${WORKSPACE}
CMD ["ros2", "launch", "num_bringup", "live.launch.py"]
