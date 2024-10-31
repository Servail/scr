#!/bin/bash

#Usage: profile-save.sh <fname> [var1] [var2] ...

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

source=$path/profiles/current
readvar=$path/readvar.sh
writevar=$path/writevar.sh

target=$1

if [ $# -eq 0 ]; then
  echo "Usage: profile-save.sh <fname> [var1] [var2] ..."
  exit 1
fi

if [ -f $target ]; then
  echo "File exists!"
  exit 1 #todo: add rewrite/merge choice
fi

#just duplicate if single argument
if [ "$#" -eq 1 ]; then
  cp $source $target
  exit 0
fi

touch "$target"

for (( i = 2; i < "$#"; i++ ))
do
  if [ ??? ]; then
    "$writevar" "$target" "$i" "$("$readvar" "$source" "$i")"
  fi 
done

