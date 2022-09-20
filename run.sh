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

if [ -n "$SINGULARITY_NAME" ]; then
  echo "Already in a singularity container!"
  exec "$CONFIG_target_shell"
fi


TARGET="$path/$CONFIG_container_name"
SINGULARITY=singularity

BOOTSTRAP_ROOT="$path/_singularity-bootstrap"

#####################################################################
# load bindings from yaml


declare -A uniq_bindings=()
for b in "${CONFIG_bindings[@]}"; do
  uniq_bindings[$b]=1
done
# collect the bindings for the list of binaries
for binary in "${CONFIG_binary_bindings[@]}"; do
  uniq_bindings[$binary]=1
  for shared_lib in $(ldd "$binary" | awk '/ => / { print $3 }'); do
    if [ ! -f "$TARGET/$shared_lib" ]; then
      uniq_bindings[$shared_lib]=1
    fi
  done
done

# join binds arrary with comma
BINDS="$(IFS=, ; echo "${!uniq_bindings[*]}")"

# expand any variable in string to the actual environment variable (with the ! exclamation point)
if [ -n "$BINDS" ]; then
  BINDS="-B $(eval echo $BINDS)"
fi

#####################################################################

# THIS allows using ptrace (e.g. gdb) in the singularity image.
# NOT too safe tho..
CAPS="--add-caps ALL"



_default_ros_source="$path/$CONFIG_default_ros_source"


CMDS_BEFORE_ROS_SOURCE=""
for cmd in "${CONFIG_cmd_to_run_inside_container_before_ros_source[@]}"; do
  # the following formulation expands env variables
  CMDS_BEFORE_ROS_SOURCE+="$(echo "$cmd") ; "
  # CMDS_BEFORE_ROS_SOURCE+="$(eval echo "$cmd") ; "
done
CMDS_BEFORE_ROS_SOURCE+=": "

case "$CONFIG_target_shell" in
  bash|zsh)
    ROS_SOURCE="if test -f $_default_ros_source; then source $_default_ros_source; fi "
    ;;
  fish)
    ROS_SOURCE="if test -f $_default_ros_source; bass source $_default_ros_source; end "
    ;;
  *)
    # unknown shell
    echo ">> Not performing ros source due to unknown shell $CONFIG_target_shell"
    ROS_SOURCE=": "
esac

CMDS_AFTER_ROS_SOURCE=""
for cmd in "${CONFIG_cmd_to_run_inside_container_after_ros_source[@]}"; do
  CMDS_AFTER_ROS_SOURCE+="$(echo "$cmd") ; "
done
for cmd in "${CONFIG_cmd_to_run_inside_container_after_ros_source_expand_vars[@]}"; do
  # the following formulation expands env variables
  CMDS_AFTER_ROS_SOURCE+="$(eval echo "$cmd") ; "
done
CMDS_AFTER_ROS_SOURCE+=": "


INITIALISE_CMD="$CMDS_BEFORE_ROS_SOURCE ; $ROS_SOURCE ; $CMDS_AFTER_ROS_SOURCE"


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
      set -x
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

CMDS_BEFORE_CONTAINER=""
for cmd in "${CONFIG_cmd_to_run_before_entering_container[@]}"; do
  # the following formulation expands env variables
  eval "$cmd"
done


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
  case "$CONFIG_target_shell" in
    bash)
      $direnv_unload $cmd "$CONFIG_target_shell" $target_shell_init_command --init-file <(echo "$INITIALISE_CMD")
      ;;
    fish)
      $direnv_unload $cmd "$CONFIG_target_shell" $target_shell_init_command -C "$INITIALISE_CMD"
      ;;
  esac
  #$cmd "$CONFIG_target_shell" -C "$ROS_PREP && $CMDS_AFTER_ROS_SOURCE && cd '$DIR_TO_CD'"
  ;;
exec)
  shift
  cmd="$SINGULARITY run $CAPS $BINDS $TARGET"
  echo ">> $cmd $@"
  $cmd $@
  ;;
-w)
  echo "> Starting singularity with --writable flag"
  cmd="$SINGULARITY run -B $HOME --writable --fakeroot $TARGET $CONFIG_target_shell"
  cmd="$SINGULARITY run  --writable --fakeroot $TARGET $CONFIG_target_shell"
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
