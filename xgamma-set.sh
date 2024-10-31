#!/bin/bash
#call on gamma change !(old) AMD (or mesa) ONLY!

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

conf=$path/profiles/current

gamma=$($path/readvar.sh "$conf" gamma)

xgamma -gamma "$gamma"


