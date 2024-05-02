#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <config_file> <variable_name>"
  exit 1
fi

conf=$1
var=$2

if [ ! -f "$conf" ]; then
  echo "Config file does not exist!"
  exit 1
fi

value=$(grep "^$var=" "$conf" | cut -d '=' -f 2)

if [ -z "$value" ]; then
  echo "Variable $var not found in config file!"
  exit 1
else
  echo "$value"
  exit 0
fi

