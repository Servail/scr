#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

#pgrep -f "^xcalib-set-counter.sh" | xargs -I{} kill -9 {} 
kill -9 $(pgrep -f ".*/xcalib-set-counter.sh --killtag$")
$path/xcalib-set-counter.sh --killtag &
exit 0
