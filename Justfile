# Host-side commands (just equivalent of the Makefile).
# D selects the distro container (jazzy | lyrical):  just D=lyrical up   (or: D=lyrical just up)
# build/up/clean default to jazzy; the other recipes use whichever distro container is running
# unless D is given.

D := env("D", "")
distro := if D == "" { "jazzy" } else { D }

compose := "docker compose"
# Allocate a TTY only when just itself runs in a terminal (so Ctrl-C reaches ros2 in the container)
exec := compose + " exec $([ -t 0 ] || echo -T)"
# Prints the distro container to exec into (explicit D wins, otherwise the running one), or fails.
svc := quote(just_executable()) + " --justfile " + quote(justfile()) + " D=" + quote(D) + " _svc"
# Run a command in container $s with ROS and the workspace overlay sourced (see ros_exec).
ros := exec + ' "$s" ros_exec'

# List recipes
default:
    @{{just_executable()}} --justfile {{quote(justfile())}} --list

# Build the image of distro D (default jazzy)
build:
    @bash .devcontainer/pre_build.sh
    {{compose}} build {{distro}}

# Start the container of distro D (default jazzy) and build the workspace
up:
    @bash .devcontainer/pre_build.sh
    {{compose}} up -d {{distro}}
    {{exec}} {{distro}} /opt/workspace/scripts/setup_workspace.sh

# Stop all containers
down:
    {{compose}} --profile '*' down

# Open a bash shell in the running distro container
shell:
    #!/usr/bin/env bash
    set -euo pipefail
    s=$({{svc}})
    {{compose}} exec "$s" bash

# Force a full colcon rebuild of the workspace
rebuild:
    #!/usr/bin/env bash
    set -euo pipefail
    s=$({{svc}})
    {{exec}} "$s" /opt/workspace/scripts/setup_workspace.sh

# Run live.launch.py as the 'live' service (Ctrl-C stops; pass -d to run detached)
live *flags: (_launch "live" flags)

# Run offline.launch.py as the 'offline' service (pass -d to run detached)
offline *flags: (_launch "offline" flags)

# Follow the logs of detached live/offline services
logs:
    {{compose}} --profile '*' logs -f live offline

# Record into datasets/ (duration 0: Ctrl-C stops). E.g. just record run1 30 /counter /add_result
record name="run" duration="0" *topics:
    #!/usr/bin/env bash
    set -euo pipefail
    s=$({{svc}})
    t=""; for x in {{topics}}; do t+="${t:+, }'$x'"; done
    {{ros}} ros2 action send_goal --feedback /bag_recorder/record num_interfaces/action/Record \
        "{name: '{{name}}', duration: {{duration}}, topics: [$t]}"

# Replay a bag from datasets/. E.g. just replay run1 2.0 true
replay bag="" rate="1.0" loop="false":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{bag}}" ]; then echo "Usage: just replay <folder in datasets/> [rate] [loop]"; ls datasets; exit 1; fi
    s=$({{svc}})
    {{ros}} ros2 action send_goal --feedback /bag_player/replay num_interfaces/action/Replay \
        "{bag_name: '{{bag}}', rate: {{rate}}, loop: {{loop}}}"

# List recorded bags
bags:
    #!/usr/bin/env bash
    for d in datasets/*/; do [ -f "$d/metadata.yaml" ] && basename "$d"; done; true

# Run the Python and colcon tests
test:
    #!/usr/bin/env bash
    set -euo pipefail
    s=$({{svc}})
    {{ros}} python3 -m pytest -q py_packages
    {{exec}} -w /opt/workspace/ros2_ws "$s" ros_exec bash -c 'colcon test && colcon test-result --verbose'

# Remove the build/install/log/.local volumes of distro D (forces a clean colcon build on next up)
clean:
    D={{distro}} {{compose}} --profile '*' rm -sf live offline {{distro}}
    docker volume rm -f ros_container_{{distro}}_build ros_container_{{distro}}_install ros_container_{{distro}}_log ros_container_{{distro}}_local

[private]
_launch profile flags="":
    #!/usr/bin/env bash
    set -euo pipefail
    s=$({{svc}})
    D="$s" {{compose}} --profile {{profile}} up {{flags}} {{profile}}

[private]
_svc:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{D}}" ]; then echo "{{D}}"; exit 0; fi
    running=$({{compose}} ps --services --status running 2>/dev/null | grep -xE 'jazzy|lyrical' || true)
    n=$(printf '%s' "$running" | grep -c . || true)
    if [ "$n" -eq 0 ]; then echo "No container running: run 'just up' (or 'just D=lyrical up') first" >&2; exit 1; fi
    if [ "$n" -gt 1 ]; then echo "Both $(echo $running) are running: pass D=jazzy or D=lyrical" >&2; exit 1; fi
    echo "$running"
