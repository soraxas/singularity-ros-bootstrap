#!/bin/sh

BASEDIR="$(realpath "$(dirname "$0")")"

cur_dir="$(pwd)"

TMP="$(mktemp -d)"

cd $TMP
echo "In $TMP"

###########################
# delta
if false; then
  wget https://github.com/dandavison/delta/releases/download/0.8.2/delta-0.8.2-x86_64-unknown-linux-gnu.tar.gz
  tar xvf delta-0.8.2-x86_64-unknown-linux-gnu.tar.gz
  
  cd delta-0.8.2-x86_64-unknown-linux-gnu
  
  chmod +x delta
  mv delta "$BASEDIR/self-contained-bin/" 
fi  
###########################
# micromamba
if false; then
  #wget https://github.com/mamba-org/boa-forge/releases/download/micromamba-0.15.3/micromamba-linux-64
  wget https://github.com/mamba-org/boa-forge/releases/download/micromamba-nightly-21.10.8.959/micromamba-nightly-linux-64

  mv micromamba-nightly-linux-64 "$BASEDIR/self-contained-bin/micromamba"
  chmod +x "$BASEDIR/self-contained-bin/micromamba"
fi
###########################
