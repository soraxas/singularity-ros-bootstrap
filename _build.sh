#!/bin/bash

set -e

path="$(dirname "$0" )"
CONFIG_FILE="$path"/_singularity-ros-config.yaml
if [ ! -f "$CONFIG_FILE" ]; then
  echo "$CONFIG_FILE does not exists."
  exit 1
fi
# source "$path"/_singularity-bootstrap/yaml_parser.bash
source "$path"/_singularity-bootstrap/yaml.sh

declare -A config
if ! create_variables "$CONFIG_FILE" CONFIG_; then
  echo failed to parse config file
  exit 1
fi

if [ -z "$CONFIG_ros_version" ]; then
  echo "ros version not set!"
fi

# ROS1
# singularity build --sandbox ${CONFIG_ros_version}/ docker-daemon://osrf/ros:${CONFIG_ros_version}-desktop-full

# ROS2
singularity build --sandbox ${CONFIG_ros_version}/ docker-daemon://ros2base:latest

