#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

#pgrep -f "^picom-reload-counter.sh" | xargs -I{} kill -9 {} 
kill -9 $(pgrep -f ".*/picom-reload-counter.sh --killtag$")
$path/picom-reload-counter.sh --killtag &
exit 0
