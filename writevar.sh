#!/bin/bash

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <config_file> <variable_name> <new_value>"
  exit 1
fi

conf="$1"
varname="$2"
newval="$3"

if [ ! -f "$conf" ]; then
  echo "Config file does not exist!"
  exit 1
fi

value=$(grep "^$varname=" "$conf" | cut -d '=' -f 2)

if [ -z "$value" ]; then
  echo "$varname=$newval" >> "$conf"
  echo "New variable $varname=$newval added to config file"
else
  sed -i "s/^$varname=.*/$varname=$newval/" "$conf"
  echo "Variable $varname changed from $value to $newval"
fi

#exit 0

