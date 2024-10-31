#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

$path/chvar.sh dim -0.05 0 1
$path/picom-reload.sh
