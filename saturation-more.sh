#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

$path/chvar.sh saturation +0.05 0 2
$path/picom-reload.sh
