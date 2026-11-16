#!/usr/bin/env python3
"""Run a colcon-installed ROS node in this process, so the VS Code debugger sees it.

Used by the "ROS: debug node" configuration in .vscode/launch.json, whose node picker passes
one string:  "<package> <executable> [--ros-args -p name:=value ...]"
(separate arguments work as well).
"""
import os
import runpy
import shlex
import sys

argv = shlex.split(sys.argv[1]) if len(sys.argv) == 2 else sys.argv[1:]
if len(argv) < 2:
    sys.exit(__doc__)
package, executable, *node_args = argv

install = os.path.join(os.environ.get('WORKSPACE', '/opt/workspace'), 'ros2_ws', 'install')
script = os.path.join(install, package, 'lib', package, executable)
if not os.path.isfile(script):
    sys.exit(f'{script} not found: build the workspace first (colcon build)')

# The node sees the same argv as under `ros2 run <package> <executable> <node_args>`
sys.argv = [script, *node_args]
runpy.run_path(script, run_name='__main__')
