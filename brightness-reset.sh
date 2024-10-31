#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

$path/chvar.sh brightness 0
$path/xcalib-set.sh
