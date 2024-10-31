#!/bin/bash

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

conf=$path/profiles/current
readvar=$path/readvar.sh
writevar=$path/writevar.sh
notify=$path/notify-replace.sh

var=$1
adj=$2
min=$3
max=$4
mode=$5

val="$("$readvar" "$conf" "$var")"

if [[ "$adj" == +* ]] || [[ "$adj" == -* ]]
then
  val="$(echo "$val$adj" | bc -l)"
else
  val="$adj"
fi

if [[ ! -z "$min" ]] && (( $(echo "$val<$min" | bc -l) ))  #if not empty string and...
then
  if [[ -z "$mode" ]] then
    val="$min"
  elif [[ ! -z "$max" ]] && [[ "$mode" == "loop" ]] then
    val="$max"
  fi
fi

if [[ ! -z "$max" ]] && (( $(echo "$val>$max" | bc -l) ))
then
  if [[ -z "$mode" ]] then
    val="$max"
  elif [[ ! -z "$min" ]] && [[ "$mode" == "loop" ]] then
    val="$min"
  fi
fi

"$writevar" "$conf" "$var" "$val" &>1
"$notify" "$var" "$val" &>1

echo "$val"
