#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

ramdir=/run/user/$(id -u)/scr

if [ ! -f "$ramdir"/current ]; then
  echo "File $ramdir/current not exists! Not started move-to-ram service?"
  exit 1 #todo: add rewrite/merge choice
fi

rm "$path"/profiles/current
mv "$ramdir"/current "$path"/profiles/current
