#!/bin/sh

ros_version=noetic

singularity build --sandbox ${ros_version}/ docker://osrf/ros:${ros_version}-desktop-full
