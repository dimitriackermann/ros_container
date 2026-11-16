# Design goals

The requirements this project was built to:

- **Devcontainer** with ROS 2 **Jazzy** or **Lyrical** as the base image.
- **`py_packages/`** with two plain Python packages: adding and subtracting numbers.
- **`ros2_ws/src/`** with ROS 2 nodes:
  - a publisher sending increasing numbers on a topic, and a subscriber;
  - a service server and client that use the Python packages to add and subtract;
  - a recorder node that writes topics and services to an MCAP bag in `datasets/`;
  - a player node that replays a selected bag from `datasets/`;
  - recorder and player are triggered through ROS actions;
  - a Foxglove bridge to connect Foxglove Studio.
- `py_packages/`, `ros2_ws/src/` and `datasets/` are mounted into the container at `/opt/workspace`.
- Pre- and post-create scripts set up the Python packages and run the colcon build.
- The main project is a git repo; each package in `py_packages/` and `ros2_ws/src/` is its own repo, included as a git submodule.
- Host-side commands for live recording and offline replay.
