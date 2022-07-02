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

# Getting Started

```shell
mkdir ~/ROS
cd ~/ROS
git clone https://github.com/soraxas/singularity-ros-bootstrap.git _singularity-bootstrap
make -C _singularity-bootstrap
```
