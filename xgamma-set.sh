#!/bin/bash
#call on gamma change

conf=~/scr/profiles/current

gamma=$(~/scr/readvar.sh "$conf" gamma)

xgamma -gamma "$gamma"


