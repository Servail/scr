#!/bin/bash
conf=~/.config/profiles/current
gamma=$(~/scr/chvar.sh gamma +0.05 0 4)
xgamma -gamma "$gamma"
