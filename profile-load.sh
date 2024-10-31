#!/bin/bash

#not needed? just use corresp reloaders on gamma-more etc.
#if [ -z $1 ]
#  ./xcalib-set.sh
#  ./picom-reload.sh
#  exit 0
#fi

if [ "$#" -eq 9 ]; then
  echo "Usage: profile-load.sh <profile_name> [var1_name] [var2_name] ..."
  exit 1
fi

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

current=$path/profiles/current
writevar=$path/writevar.sh

source="$1"

if [ "$#" -eq 1 ]; then
  IFS=$'\n'
  for var in $(cat "$source")
  do
    varname=$(echo "$var" | cut -d '=' -f 1)
    "$writevar" "$current" "$varname" $(~/scr/readvar.sh "$source" "$varname")
  done
else
  for (( i = 2; i < "$#"; i++ ))
  do
    "$writevar" "$current" "$i" $(~/scr/readvar.sh "$source" "$i")
  done
fi

#load current (NOT NEEDED? just use corresp reloaders on gamma-more etc.)
#maybe put in profile what is affected
$path/xcalib-set.sh
$path/picom-reload.sh
#~/scr/xgamma-set.sh
