create 
- a devcontainer with either ros2 jazzy or ros2 lyrical as base image
- folder py_packages with 2 simple packages (adding numbers, subtracting numbers)
- a ros2_ws/src folder with nodes (topic send increasing numbers, and subscriber), service server and client which use the python packges for adding and subtracting numbers and a ros2 bag node for recording of the topics and services into mcap file which goes to folder datasets and a ros2 bag node which replays a selectable the mcap file from datasets folder. the recorder and replay node will be triggered via an action. make a sugestions how i can trigger the action.
- the py_packages and ros2_ws/src and datasets are mounted into containers workspace /opt/worksrpace
- the devcontainers has pre and post build script for setup of python packages and colcon build.
- this main project is a git repo, where the subdirectories of py_packgesm ros2_ws/src are also git repos which are git submodules of main project
- a foxglove brige is also in the ros2_ws in order to connect to foxglove.
- make as good sugestions how to run the live-recording, the offline-replay from the host side.   