#!/bin/bash

var=$1
adj=$2
min=$3
max=$4
mode=$5
conf=~/scr/profiles/current

val="$(~/scr/readvar.sh "$conf" "$var")"

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

~/scr/writevar.sh "$conf" "$var" "$val" &>1
~/scr/notify-replace.sh "$var" "$val" &>1

echo "$val"
