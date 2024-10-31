#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

$path/chvar.sh gamma 1 0 4
$path/xcalib-set.sh

