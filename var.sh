#!/bin/bash

if [ -z "$3" ]; then
  ./readvar.sh "$1" "$2"
else
  ./writevar.sh "$1" "$2" "$3"
fi

exit 0