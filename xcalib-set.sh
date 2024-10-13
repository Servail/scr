#!/bin/bash
#call on contrast and brightness change
#TODO: make different modes for rgb, w(white) and rgbw(combined, now it is)

conf=~/scr/profiles/current
icc=~/scr/icc/gamma_1_0.icc

brightness=$(~/scr/readvar.sh "$conf" brightness)
contrast=$(~/scr/readvar.sh "$conf" contrast)

gamma=$(~/scr/readvar.sh "$conf" gamma) # not needed with xgamma
invgamma=$(echo "scale=2 ; 1 / $gamma" | bc) # not needed with xgamma 

var=$(~/scr/readvar.sh "$conf" rbrightness)
rbrightness=$(echo "scale=2 ; $brightness + $var" | bc)

var=$(~/scr/readvar.sh "$conf" gbrightness)
gbrightness=$(echo "scale=2 ; $brightness + $var" | bc)

var=$(~/scr/readvar.sh "$conf" bbrightness)
bbrightness=$(echo "scale=2 ; $brightness + $var" | bc)

var=$(~/scr/readvar.sh "$conf" rcontrast)
ratio=$(echo "scale=2 ; $var / 100" | bc)
rcontrast=$(echo "scale=2 ; $contrast * $ratio" | bc)

var=$(~/scr/readvar.sh "$conf" gcontrast)
ratio=$(echo "scale=2 ; $var / 100" | bc)
gcontrast=$(echo "scale=2 ; $contrast * $ratio" | bc)

var=$(~/scr/readvar.sh "$conf" bcontrast)
ratio=$(echo "scale=2 ; $var / 100" | bc)
bcontrast=$(echo "scale=2 ; $contrast * $ratio" | bc)

xcalib \
-red "$invgamma" "$rbrightness" "$rcontrast" \
-green "$invgamma" "$gbrightness" "$gcontrast" \
-blue "$invgamma" "$bbrightness" "$bcontrast" \
"$icc"



