#!/bin/bash
#call on contrast and brightness change
#TODO: make different modes for rgb, w(white) and rgbw(combined, now it is)

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

conf=$path/profiles/current
icc=$path/icc/gamma_1_0.icc

readvar=$path/readvar.sh

brightness=$("$readvar" "$conf" brightness)

contrast=$("$readvar" "$conf" contrast)

gamma=$("$readvar" "$conf" gamma) # not needed with xgamma
invgamma=$(echo "scale=2 ; 1 / $gamma" | bc) # not needed with xgamma 

var=$("$readvar" "$conf" rbrightness)
rbrightness=$(echo "scale=2 ; $brightness + $var" | bc)

var=$("$readvar" "$conf" gbrightness)
gbrightness=$(echo "scale=2 ; $brightness + $var" | bc)

var=$("$readvar" "$conf" bbrightness)
bbrightness=$(echo "scale=2 ; $brightness + $var" | bc)

var=$("$readvar" "$conf" rcontrast)
ratio=$(echo "scale=2 ; $var / 100" | bc)
rcontrast=$(echo "scale=2 ; $contrast * $ratio" | bc)

var=$("$readvar" "$conf" gcontrast)
ratio=$(echo "scale=2 ; $var / 100" | bc)
gcontrast=$(echo "scale=2 ; $contrast * $ratio" | bc)

var=$("$readvar" "$conf" bcontrast)
ratio=$(echo "scale=2 ; $var / 100" | bc)
bcontrast=$(echo "scale=2 ; $contrast * $ratio" | bc)

xcalib \
-red "$invgamma" "$rbrightness" "$rcontrast" \
-green "$invgamma" "$gbrightness" "$gcontrast" \
-blue "$invgamma" "$bbrightness" "$bcontrast" \
"$icc"



