#!/bin/bash
#call on gamma change

conf=~/.config/profiles/current

gamma=$(~/scr/readvar.sh "$conf" gamma)

xgamma -gamma "$gamma"


