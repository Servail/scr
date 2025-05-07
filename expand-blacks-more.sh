#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

$path/chvar.sh expand-blacks +0.1 0 4
$path/picom-reload.sh
