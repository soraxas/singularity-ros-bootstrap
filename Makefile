
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
THIS_DIR_NAME:="$(notdir $(ROOT_DIR))"


all: ../_build.sh ../run.sh ../_singularity-ros-config.yaml

../%.sh:
	ln -s ./$(THIS_DIR_NAME)/$(notdir $@) ../$(notdir $@)

# ../run.sh:
# 	ln -s ./$(THIS_DIR_NAME)/run.sh ..

../_singularity-ros-config.yaml: _singularity-ros-config.yaml.example
	cp $< ../$(notdir $@)

