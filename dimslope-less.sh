#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

$path/chvar.sh dimslope -0.1 0.1 10 
$path/picom-reload.sh
