#!/bin/bash

set -e

COMMAND="normal"


export Color_Off='\033[0m'             # Text Reset
# Regular Colors
export Color_Black='\033[1;30m'        # Bold Black
export Color_Red='\033[1;31m'          # Bold Red
export Color_Green='\033[1;32m'        # Bold Green
export Color_Yellow='\033[0;33m'       # Yellow
export Color_Blue='\033[0;34m'         # Blue
export Color_Purple='\033[1;35m'       # Bold Purple
export Color_Cyan='\033[1;36m'         # Bold Cyan
export Color_White='\033[1;37m'        # Bold White

info_echo() {
    >&2 printf "$Color_Yellow%s$Color_Off\n" "$@"
}

error_echo() {
    >&2 printf "$Color_Red%s$Color_Off\n" "$@"
}

help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  exec              Execute arbitrary command inside the container.
  -h, --help        Show this help message and exit.
  -v, --verbose     Verbose output.
  -d, --debug       Enable debug mode (set -x).
  -w, --writable    Start Singularity with --writable flag.
  --nv, --cuda      Use NVIDIA-specific options.
  --nvccli

Description:
  This script facilitates running a Singularity container with predefined configurations.

Examples:
  $(basename "$0")                   # Start Singularity container with default settings.
  $(basename "$0") -w                # Start Singularity container with --writable flag.
  $(basename "$0") exec [COMMAND]    # Execute arbitrary COMMAND inside the container.

EOF
}

#####################################################################
# retrieve options
for arg; do
    shift
    case "$arg" in
        exec)
            COMMAND="exec"
            break
        ;;
        -h|--help)
            help
            exit
        ;;
        -v|--verbose)
            verbose="true"
        ;;
        -d|--debug)
            set -x
        ;;
        -w|--writable)
            COMMAND="use_root"
        ;;
        --nv|--cuda|--nvidia)
            use_nv="true"
            CAPS="$CAPS --nv"
        ;;
        --nvccli)
            use_nv="true"
            CAPS="$CAPS --nvccli"
        ;;
        * )
            info_echo "Unknown args: '$COMMAND'"
            help
            exit 1
        ;;
    esac
done

path="$(dirname "$0" )"
CONFIG_FILE="$path"/_singularity-ros-config.yaml
if [ ! -f "$CONFIG_FILE" ]; then
    error_echo "$CONFIG_FILE does not exists."
    exit 1
fi
# source "$path"/_singularity-bootstrap/yaml_parser.bash
source "$path"/_singularity-bootstrap/yaml.sh

declare -A config
if ! create_variables "$CONFIG_FILE" CONFIG_; then
    error_echo failed to parse config file
    exit 1
fi

if [ -n "$SINGULARITY_NAME" ]; then
    error_echo "Already in a singularity container!"
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

#####################################################################



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
        info_echo ">> Not performing ros source due to unknown shell $CONFIG_target_shell"
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
for vars in "${CONFIG_variables[@]}"; do
    # replace reference to ~ with correct user home
    if [ "$COMMAND" = "use_root" ]; then
        _target_home=/root
    else
        _target_home=$HOME
    fi
    # replace the tilda
    export_pair="$(echo "$vars" | sed 's:=~/:='"$_target_home"'/:')"
    # expands any variables
    export_pair="$(eval echo "$export_pair")"
    CMDS_AFTER_ROS_SOURCE+="export "$export_pair"; "
done
CMDS_AFTER_ROS_SOURCE+=": "


INITIALISE_CMD="$CMDS_BEFORE_ROS_SOURCE ; $ROS_SOURCE ; $CMDS_AFTER_ROS_SOURCE"



#####################################################################

CMDS_BEFORE_CONTAINER=""
for cmd in "${CONFIG_cmd_to_run_before_entering_container[@]}"; do
    # the following formulation expands env variables
    eval "$cmd"
done



cmd=($SINGULARITY run)

if [ "$COMMAND" = "use_root" ]; then
    cmd+=(--writable --fakeroot)
fi

cmd+=($CAPS $BINDS $TARGET "$CONFIG_target_shell" $target_shell_init_command )
case "$CONFIG_target_shell" in
    bash)
        cmd+=(--init-file <(echo "$INITIALISE_CMD"))
    ;;
    fish)
        cmd+=(-C "$INITIALISE_CMD")
    ;;
esac

case "$COMMAND" in
    normal)
        # workaround for an error where:
        # 1. direnv had already loaded some environment file,
        # 2. but entering singularity container will enter a new shell which wipes envs
        # 3. when direnv tries to unload those non-existing envs, it enters an error state and unloads things like /usr/bin in PATH
        # work around by running `direnv exec / <CMD>` when executing singularity to unload environment
        if [ -n "$DIRENV_DIR" ]; then
            # this should not be entered on environment without direnv
            direnv_unload="direnv exec / "
        fi

        if [ -n "$verbose" ]; then
            msg="${cmd[@]}"
        else
            msg="$SINGULARITY run $CAPS [SOME_LONG_BINDS] $TARGET"
        fi
        info_echo ">> $msg"
        $direnv_unload "${cmd[@]}"
    ;;
    exec)
        cmd="$SINGULARITY run $CAPS $BINDS $TARGET"
        info_echo ">> $cmd $(printf '%s ' "$@")"
        $cmd $@
    ;;
    use_root)
        info_echo "> Starting singularity with --writable flag"
        # cmd="$SINGULARITY run -B $HOME --writable --fakeroot $TARGET $CONFIG_target_shell"
        # cmd=($SINGULARITY run  $CAPS $BINDS  $TARGET $CONFIG_target_shell -C "$INITIALISE_CMD")
        msg="${cmd[@]}"
        info_echo ">> $msg"
        "${cmd[@]}"
    ;;
esac
