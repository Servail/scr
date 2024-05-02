#!/bin/bash

NID=$(notify-send --urgency=low --hint=int:transient:1 -p -r $(cat ~/.config/vars/notification-id) $1 $2)

if [[ ! -z "$NID" ]] #if not empty string or null
then
    echo "$NID" > ~/.config/vars/notification-id
else
    echo "167" > ~/.config/vars/notification-id
fi