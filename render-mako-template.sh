#! /bin/sh

o=gcc-options-parser.sh

mako-render $o.mako --output-file $o
chmod +x $o
echo done $o
