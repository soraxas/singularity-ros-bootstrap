#!/bin/sh

root=~/ROS
cd_cmd=":"

export TERM=screen-256color

if [ -n "$1" ]; then
  for dir in "$root/"*$1*; do
    if [ -d "$dir" ]; then
      found_dir="$dir"
      break
    fi
  done

  if [ -n "$found_dir" ]; then
    cd_cmd="cd '$found_dir'"
  else
    echo "Given argunment '$1' but no matching directory found."
  fi
fi

cmd_to_execute="$cd_cmd && ~/ROS/run.sh"

session_name="$(basename "$found_dir")"
[ -z "$session_name" ] && session_name="ros_ws"

# attach if one already exists
if tmux has-session -t "$session_name" 2>/dev/null; then
  tmux a -t "$session_name"
else
  tmux new-session -s "$session_name" \; \
    send-keys "$cmd_to_execute" C-m C-l \; \
    split-window -v \; \
    send-keys "$cmd_to_execute" C-m C-l \; \
    split-window -h \; \
    send-keys "$cmd_to_execute" C-m C-l \; \
    ;
fi
