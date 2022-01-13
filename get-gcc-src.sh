#! /bin/sh

[ -e gcc ] && { echo error: gcc exists; exit 1; }

git clone --depth 1 https://github.com/gcc-mirror/gcc
