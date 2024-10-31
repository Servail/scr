#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

conf=$path/profiles/current
useeffects=$($path/chvar.sh useeffects 1)
$path/picom-reload.sh
