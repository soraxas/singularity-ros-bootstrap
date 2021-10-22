#!/bin/sh

BASEDIR="$(realpath "$(dirname "$0")")"

cur_dir="$(pwd)"

TMP="$(mktemp -d)"

cd $TMP

wget https://github.com/dandavison/delta/releases/download/0.8.2/delta-0.8.2-x86_64-unknown-linux-gnu.tar.gz
tar xvf delta-0.8.2-x86_64-unknown-linux-gnu.tar.gz

cd delta-0.8.2-x86_64-unknown-linux-gnu

chmod +x delta
mv delta "$BASEDIR/self-contained-bin/" 

