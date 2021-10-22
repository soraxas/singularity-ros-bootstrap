#!/usr/bin/env fish

set -l BASEDIR (dirname (readlink -f (status --current-filename)))

#if test (pwd) = $HOME
#  # cd to ROS dir if pwd is at home (i.e. default for new terminal)
#  cd ~/ROS
#end

# use appimage nvim with python support
command -q nvim.appimage
and alias vim nvim.appimage

set TERM xterm-256color

if set -q TMUX
  # setup an event-driven updates of #{pane_path} variable (with OSC 7 escape sequence)
  # so that it workaround the issue of tmux not being able to retrieve cwd
  # within the singularity container
  # see: https://github.com/arl/gitmux/issues/19#issuecomment-623955306
  function __update_tmux_pane_path --on-variable PWD
    printf "\\e]7;$PWD\\a"
  end
end

# add the binary folder with self-contained (static) binaries
set -p PATH "$BASEDIR/self-contained-bin"

set_color --bold cyan
echo ">> Bonjour from fish! Singularity shell initialised."
set_color --bold normal
