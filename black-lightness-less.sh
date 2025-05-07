#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

$path/chvar.sh black-lightness -0.01 0 0.5
$path/picom-reload.sh
