#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

$path/chvar.sh contrast -5 1 99
$path/xcalib-set.sh
