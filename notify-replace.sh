#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

conf=$path/profiles/current
readvar=$path/readvar.sh
writevar=$path/writevar.sh

NID=$(notify-send --urgency=low --hint=int:transient:1 -p -r $("$readvar" "$conf" notification-id) $1 $2)

if [[ ! -z "$NID" ]] #if not empty string or null
then
    "$writevar" "$conf" notification-id "$NID"
else
    "$writevar" "$conf" notification-id 167
fi
