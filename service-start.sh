#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

ramdir=/run/user/$(id -u)/scr
mkdir "$ramdir"

if [ -L "$path/profiles/current" ] && [ ! -e "$path/profiles/current" ]; then
	rm "$path/profiles/current"
fi

if [ ! -f "$path"/profiles/current ]; then
  cp "$path"/profiles/backup "$path"/profiles/current
fi

cp "$path"/profiles/current "$path"/profiles/backup
mv "$path"/profiles/current "$ramdir"/current
ln -s "$ramdir"/current "$path"/profiles/current
