# ros_container

A ROS 2 dev environment for **Jazzy** (Ubuntu 24.04) or **Lyrical** (Ubuntu 26.04). It has:
- a counter topic
- add/subtract services backed by plain Python packages
- MCAP recording and replay, started via ROS actions
- a Foxglove bridge

[![CI](https://github.com/dimitriackermann/ros_container/actions/workflows/ci.yml/badge.svg)](https://github.com/dimitriackermann/ros_container/actions/workflows/ci.yml)

```
.devcontainer/            Dockerfile (targets dev / build / runtime), compose.ros.yaml (service template),
                          pre_build.sh, jazzy/ + lyrical/ devcontainer.json
compose.yaml              services "jazzy" and "lyrical" (same sources, separate image + build volumes),
                          profiles live / offline / runtime
Makefile                  host-side commands
scripts/                  setup_workspace.sh (pip + rosdep + colcon), ros_debug_env.sh + debug_node.py (VS Code debugging)
.github/workflows/ci.yml  builds both distros, runs pytest + colcon test, builds the runtime image
docs/design.md            original requirements
py_packages/num_add       submodule – add(a, b)
py_packages/num_sub       submodule – subtract(a, b)
ros2_ws/src/num_interfaces  submodule – Compute.srv, Record.action, Replay.action
ros2_ws/src/num_nodes       submodule – counter_pub/sub, calc_server/client
ros2_ws/src/bag_tools       submodule – bag_recorder / bag_player action servers
ros2_ws/src/num_bringup     submodule – live / offline launch files, Foxglove bridge
datasets/                 recorded bags (gitignored)
```

Inside the container:

| Host path | Container path |
|---|---|
| `py_packages/` | `/opt/workspace/py_packages` |
| `ros2_ws/src/` | `/opt/workspace/ros2_ws/src` |
| `datasets/` | `/opt/workspace/datasets` |

`ros2_ws/{build,install,log}` are per-distro Docker volumes (`ros_container_jazzy_build`, …). Switching distro never mixes build outputs, and switching back needs no rebuild.

## Clone

```bash
git clone --recursive https://github.com/dimitriackermann/ros_container.git
```

Submodule URLs are relative (`../num_add.git`, …), so they follow the protocol of the main clone — use `git@github.com:dimitriackermann/ros_container.git` to clone everything over SSH. Each package also lives in its own repo under the same account.

## Start: VS Code

1. Install the *Dev Containers* extension.
2. Run **Dev Containers: Reopen in Container** and pick **ROS Jazzy** or **ROS Lyrical**.
3. `initializeCommand` (`pre_build.sh`) initialises submodules that are not checked out yet (checked-out ones are left alone, so local package commits are never reset) and writes your UID to `.env`. `postCreateCommand` runs `scripts/setup_workspace.sh`: `pip install -e py_packages/*`, a `rosdep check` (installs only deps missing from the image) and `colcon build --symlink-install`.
4. To change distro, run **Dev Containers: Switch Container** (or Reopen in Container again).

Both distros can run at the same time: Foxglove is published on `localhost:8765` (Jazzy) and `localhost:8766` (Lyrical).

Git works inside the container for the submodules, because `.git/modules` is mounted. Run git commands for the main repo on the host.

## Start: host only (Makefile)

```bash
make up                 # or: make up D=lyrical  (builds the image on first run)
make shell              # bash with ROS + overlay sourced
```

## Live recording

```bash
# terminal 1 – producers, recorder/player action servers, Foxglove bridge
make live

# terminal 2 – record 30 s of all topics + service calls
make record NAME=run1 DURATION=30
# … or record until Ctrl-C (Ctrl-C cancels the goal, the MCAP is finalised cleanly)
make record NAME=run1
# … or only selected topics
make record NAME=counter_only TOPICS='/counter /add_result'
```

Bags are written to `datasets/<NAME>_<distro>_<YYYYmmdd-HHMMSS>/`.

Foxglove: open the app → *Open connection* → *Foxglove WebSocket* → `ws://localhost:8765` (Lyrical: `8766`).

## Offline replay

```bash
# terminal 1 – stop live (Ctrl-C), then start only player + subscriber + Foxglove bridge
make offline

# terminal 2
make bags                                   # list bags
make replay BAG=run1_jazzy_20261104-231500  # RATE=2.0 LOOP=true optional; Ctrl-C stops
```

Bags are shared between distros. A Jazzy bag replays on Lyrical. A bag recorded on Lyrical may be too new for Jazzy's rosbag2; the player then aborts the goal and the reason is in the launch log.

## Triggering the actions in other ways

The action servers are plain ROS 2 actions:

| Action | Type |
|---|---|
| `/bag_recorder/record` | `num_interfaces/action/Record` |
| `/bag_player/replay` | `num_interfaces/action/Replay` |

Ways to call them:
- **Inside the container:**
  ```bash
  ros2 action send_goal --feedback /bag_recorder/record num_interfaces/action/Record "{name: test, duration: 10.0}"
  ros2 service call /bag_player/list_bags std_srvs/srv/Trigger
  ```
- **From the host without make:**
  ```bash
  docker compose exec jazzy bash -ic 'ros2 action send_goal …'
  ```
- **Not implemented, possible extensions:**
  - Foxglove's *Service Call* panel. foxglove_bridge exposes services but not actions, so this needs a small service wrapper.
  - A Python CLI built on `rclpy.action.ActionClient`.
  - A button in your own UI.

## Development

```bash
make test       # pytest for py_packages + colcon test
make rebuild    # force pip reinstall + colcon build
make clean      # drop build/install/log volumes of D (default jazzy)
```

`num_add` and `num_sub` are editable installs, and colcon uses `--symlink-install`, so most Python edits take effect without rebuilding. Restart the launch file to pick them up.

**New ROS dependency?** Add it to the package's `package.xml`. `make up` / `make rebuild` install it right away; `make build` bakes it into the image so it survives container re-creation.

**Packages are submodules.** Commit and push inside the package first, then commit the new pointer in the main repo. `pre_build.sh` sets `push.recurseSubmodules=check`, so pushing the main repo fails while it points at an unpushed package commit.

## Settings

Put these in `.env` (next to `USER_UID`) or set them in the shell:

| Variable | Default | Purpose |
|---|---|---|
| `ROS_DOMAIN_ID` | `0` | separate ROS graphs on a shared network |
| `ROS_AUTOMATIC_DISCOVERY_RANGE` | `LOCALHOST` | `SUBNET` to discover nodes on other machines |
| `JAZZY_FOXGLOVE_PORT` / `LYRICAL_FOXGLOVE_PORT` / `RUNTIME_FOXGLOVE_PORT` | `8765` / `8766` / `8767` | host port of the Foxglove bridge |

The base images are pinned by digest in `compose.yaml`. To update, run `docker buildx imagetools inspect ros:jazzy-ros-base`, paste the new digest, and run `make build`.

## Runtime image

The `runtime` target of the Dockerfile is a self-contained image: the colcon install space, the `py_packages` wheels and the exec dependencies, without sources, compilers or test tools. It runs the live launch by default.

```bash
make runtime              # build ros_container:jazzy-runtime   (D=lyrical for Lyrical)
make runtime-up           # run it; Foxglove on ws://localhost:8767, bags go to datasets/
docker run --rm ros_container:jazzy-runtime ros2 launch num_bringup offline.launch.py
```
