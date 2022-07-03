# Getting Started

Cloning this bootstrap repo

```shell
mkdir ~/ROS
cd ~/ROS
git clone https://github.com/soraxas/singularity-ros-bootstrap.git _singularity-bootstrap
make -C _singularity-bootstrap
```

Building the singularity container

```shell
# edit ros_version as you see fit
vim _singularity-ros-config.yaml
# clone and build the image from docker
./_build.sh
```

Entering the container (the system will be read-only)

```shell
./run.sh
```

Entering the container as root to modify system (e.g. to install packages)

```shell
# add the --writable flag
./run.sh -w
```

# Structure

This folder should be in the following structure

```sh
$ pwd
/XXX/ROS/_singularity-bootstrap
```

```sh
$ ls ../
_singularity-bootstrap/
_singularity-ros-config.yaml
noetic/
run.sh
ws_awesomestuff/
```

where `run.sh` links back to this folder

```sh
$ ls -al ../run.sh -> _singularity-bootstrap/run.sh
```

