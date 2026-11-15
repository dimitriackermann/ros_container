# ros_container

A ROS 2 dev environment for **Jazzy** (Ubuntu 24.04) or **Lyrical** (Ubuntu 26.04). It has:
- a counter topic
- add/subtract services backed by plain Python packages
- MCAP recording and replay, started via ROS actions
- a Foxglove bridge

```
.devcontainer/            Dockerfile (ARG ROS_DISTRO), pre_build.sh, jazzy/ + lyrical/ devcontainer.json
compose.yaml              services "jazzy" and "lyrical" (same sources, separate image + build volumes)
Makefile                  host-side commands
scripts/                  setup_workspace.sh (pip + rosdep + colcon), create_submodules.sh
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
git clone --recursive https://github.com/ros-nodes/ros_container.git
```

Submodule URLs are relative (`../num_add.git`, …), so they follow the protocol of the main clone — use `git@github.com:ros-nodes/ros_container.git` to clone everything over SSH. Each package also lives in its own repo in the [ros-nodes](https://github.com/ros-nodes) organization.

## Start: VS Code

1. Install the *Dev Containers* extension.
2. Run **Dev Containers: Reopen in Container** and pick **ROS Jazzy** or **ROS Lyrical**.
3. `initializeCommand` initialises the submodules and writes `.env` with your UID. `postCreateCommand` runs `scripts/setup_workspace.sh`, which does `pip install -e py_packages/*`, `rosdep` and `colcon build --symlink-install`.
4. To change distro, run **Dev Containers: Switch Container** (or Reopen in Container again).

Run one distro at a time: both containers publish Foxglove on port 8765.

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

Foxglove: open the app → *Open connection* → *Foxglove WebSocket* → `ws://localhost:8765`.

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
