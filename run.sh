#!/bin/bash

set -e
# set -x

if [ -n "$SINGULARITY_NAME" ]; then
  echo "Already in a singularity container!"
  exec fish
fi

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


TARGET="$path/$CONFIG_container_name"
SINGULARITY=singularity

BOOTSTRAP_ROOT="$path/_singularity-bootstrap"

#####################################################################
# load bindings from yaml


# join binds arrary with comma
BINDS="-B $(IFS=, ; echo "${CONFIG_bindings[*]}")"
# expand any variable in string to the actual environment variable (with the ! exclamation point)
BINDS="$(eval echo $BINDS)"

#####################################################################

# THIS allows using ptrace (e.g. gdb) in the singularity image.
# NOT too safe tho..
CAPS="--add-caps ALL"

export SHELL=/bin/bash
export SPACEFISH_DIR_SUFFIX=" [ROS_Singularity] "

_default_ros_source="$path/$CONFIG_default_ros_source"
ROS_PREP="remove_token_from_path $HOME/.pyenv/shims >/dev/null && if test -f $_default_ros_source; bass source $_default_ros_source; end"


EXTRAS=""
for cmd in "${CONFIG_cmd_to_run_inside_container[@]}"; do
    EXTRAS+="$(eval echo "$cmd") && "
done
EXTRAS+=": "

#####################################################################
# retrieve options

for arg; do
  shift
  case "$arg" in
    --help)
      show_help="true"
      exit
      ;;
    -v|--verbose)
      verbose="true"
      ;;
    --nv|--cuda|--nvidia)
      use_nv="true"
      CAPS="$CAPS --nv"
      ;;
    *)
      # set back any unused args
      set -- "$@" "$arg"
  esac
done

#####################################################################

command="$1"

case "$command" in
"")
  # workaround for an error where:
  # 1. direnv had already loaded some environment file,
  # 2. but entering singularity container will enter a new shell which wipes envs
  # 3. when direnv tries to unload those non-existing envs, it enters an error state and unloads things like /usr/bin in PATH
  # work around by running `direnv exec / <CMD>` when executing singularity to unload environment
  if [ -n "$DIRENV_DIR" ]; then
    # this should not be entered on environment without direnv
    direnv_unload="direnv exec / "
  fi

  # cd to ROS dir if pwd is at home (i.e. default for new terminal)
  #if test "$(pwd)" = "$HOME"; then
  #  DIR_TO_CD="$HOME/ROS"
  #else
  #  DIR_TO_CD="$(pwd)"
  #fi
  #unset DIRENV_DIR
  #pushd "$HOME"
  #pwd
  #direnv reload

  # set to correct TERM as singularity doesn't work well with other TERM
  case "$TERM" in
    screen-*|tmux-*|xterm-kitty)
      export TERM=xterm-256color
      ;;
  esac

  cmd="$SINGULARITY run $CAPS $BINDS $TARGET"
  if [ -n "$verbose" ]; then
    msg="$cmd"
  else
    msg=">> $SINGULARITY run $CAPS [SOME_LONG_BINDS] $TARGET"
  fi
  echo "$msg"
  # echo ">> startup cmd: $ROS_PREP && $EXTRAS"
  $direnv_unload $cmd fish -C "$ROS_PREP && $EXTRAS"
  #$cmd fish -C "$ROS_PREP && $EXTRAS && cd '$DIR_TO_CD'"
  ;;
exec)
  shift
  cmd="$SINGULARITY run $CAPS $BINDS $TARGET"
  echo ">> $cmd $@"
  # echo ">> startup cmd: $ROS_PREP && $EXTRAS"
  $cmd $@
  ;;
-w)
  echo "> Starting singularity with --writable flag"
  cmd="sudo $SINGULARITY run -B $HOME --writable $TARGET fish"
  echo ">> $cmd"
  $cmd
  ;;
* )
  echo "Run without any argunment for starting ROS"
  echo "Or run with -w flag for modifing the image"
  echo "Or run with subcommand 'exec [ARG1 ARG2...]' to execute arbitary comand inside the container"
  exit 1
  ;;
esac
