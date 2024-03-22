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

singularity build --sandbox ${CONFIG_ros_version}/ docker-daemon://osrf/ros:${CONFIG_ros_version}-desktop-full
# singularity build --sandbox ${CONFIG_ros_version}/ docker://osrf/ros:${CONFIG_ros_version}-desktop-full
