# Host-side commands. D selects the distro container (jazzy | lyrical) for build/up;
# the other targets use whichever distro container is running (override with D=...).
D ?= jazzy
NAME ?= run
DURATION ?= 0
TOPICS ?=
BAG ?=
RATE ?= 1.0
LOOP ?= false

COMPOSE := docker compose
# Allocate a TTY only when make itself runs in a terminal (so Ctrl-C reaches ros2 in the container)
EXEC := $(COMPOSE) exec $(if $(shell [ -t 0 ] && echo tty),,-T)
RUNNING = $(shell $(COMPOSE) ps --services --status running 2>/dev/null)
# Service to exec into: explicit D on the command line wins, otherwise the running one.
SVC = $(if $(filter command line,$(origin D)),$(D),$(RUNNING))
# Run a command in the container with ROS and the workspace overlay sourced.
ROS = $(EXEC) $(SVC) bash -c 'source /opt/ros/$$ROS_DISTRO/setup.bash && \
      source ros2_ws/install/setup.bash && exec "$$0" "$$@"'

.PHONY: help build up down rebuild shell live offline record replay bags test clean check-svc

help:
	@echo "make build [D=jazzy|lyrical]   build the image"
	@echo "make up    [D=jazzy|lyrical]   start the container and build the workspace"
	@echo "make down                      stop containers"
	@echo "make live                      run live.launch.py (foreground, Ctrl-C stops)"
	@echo "make offline                   run offline.launch.py (foreground, Ctrl-C stops)"
	@echo "make record NAME=run1 [DURATION=30] [TOPICS='/counter /add_result']"
	@echo "                               record into datasets/; without DURATION: Ctrl-C stops"
	@echo "make bags                      list recorded bags"
	@echo "make replay BAG=<folder> [RATE=1.0] [LOOP=true]"
	@echo "make shell | test | rebuild | clean"

build:
	@bash .devcontainer/pre_build.sh
	$(COMPOSE) build $(D)

up:
	@bash .devcontainer/pre_build.sh
	$(COMPOSE) up -d $(D)
	$(EXEC) $(D) /opt/workspace/scripts/setup_workspace.sh

down:
	$(COMPOSE) down

check-svc:
	@test -n "$(SVC)" || { echo "No container running: run 'make up [D=jazzy|lyrical]' first"; exit 1; }
	@test $(words $(SVC)) -eq 1 || { echo "Both $(SVC) are running: pass D=jazzy or D=lyrical"; exit 1; }

shell: check-svc
	$(COMPOSE) exec $(SVC) bash

rebuild: check-svc
	$(EXEC) $(SVC) /opt/workspace/scripts/setup_workspace.sh --force

live: check-svc
	$(ROS) ros2 launch num_bringup live.launch.py

offline: check-svc
	$(ROS) ros2 launch num_bringup offline.launch.py

record: check-svc
	$(ROS) ros2 action send_goal --feedback /bag_recorder/record num_interfaces/action/Record \
		"{name: '$(NAME)', duration: $(DURATION), topics: [$(shell echo $(TOPICS) | sed "s/[^ ][^ ]*/'&'/g; s/ /, /g")]}"

replay: check-svc
	@test -n "$(BAG)" || { echo "Usage: make replay BAG=<folder in datasets/>"; ls datasets; exit 1; }
	$(ROS) ros2 action send_goal --feedback /bag_player/replay num_interfaces/action/Replay \
		"{bag_name: '$(BAG)', rate: $(RATE), loop: $(LOOP)}"

bags:
	@for d in datasets/*/; do [ -f "$$d/metadata.yaml" ] && echo "$$(basename $$d)"; done; true

test: check-svc
	$(ROS) python3 -m pytest -q py_packages
	$(EXEC) -w /opt/workspace/ros2_ws $(SVC) bash -c 'source install/setup.bash && \
		colcon test && colcon test-result --verbose'

# Remove the build/install/log volumes of distro D (forces a clean colcon build on next up)
clean:
	$(COMPOSE) rm -sf $(D)
	docker volume rm -f ros_container_$(D)_build ros_container_$(D)_install ros_container_$(D)_log
