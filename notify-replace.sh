#!/bin/bash

conf=~/scr/profiles/current

NID=$(notify-send --urgency=low --hint=int:transient:1 -p -r $(cat ~/.config/vars/notification-id) $1 $2)

if [[ ! -z "$NID" ]] #if not empty string or null
then
    ~/scr/writevar.sh "$conf" notification-id "$NID"
else
    ~/scr/writevar.sh "$conf" notification-id 167
fi