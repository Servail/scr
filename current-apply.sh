#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

$path/xcalib-set.sh
#~/scr/xgamma-set.sh #different behaviour between nvidia and amd
$path/picom-reload.sh
