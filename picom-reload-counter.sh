#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

time=6

while true;
do
	sleep 0.1
	((time--))
	if [ "$time" -le 0 ]; then
		"$path"/picom-reload-hard.sh &
		exit 0
	fi
done

exit 0
