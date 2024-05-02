#!/bin/bash

#call on saturation, sharpness #or color change -deprecated

conf=~/scr/profiles/current
tempshader=~/scr/shaders/universal_template.glsl
activeshader=~/scr/shaders/universal_active.glsl

cp -f "$tempshader" "$activeshader"

saturation=$(~/scr/readvar.sh "$conf" saturation)
sed -i "s\SATURATION_VALUE\\$saturation\g" "$activeshader"

sharpness=$(~/scr/readvar.sh "$conf" sharpness)
sed -i "s\SHARPNESS_VALUE\\$sharpness\g" "$activeshader"

dim=$(~/scr/readvar.sh "$conf" dim)
sed -i "s\DIM_VALUE\\$dim\g" "$activeshader"

#sed -i "s\R_VALUE\\$(~/scr/readvar.sh "$conf" r)\g" "$activeshader"

#sed -i "s\G_VALUE\\$(~/scr/readvar.sh "$conf" g)\g" "$activeshader"

#sed -i "s\B_VALUE\\$(~/scr/readvar.sh "$conf" b)\g" "$activeshader"

killall picom

picom --backend glx --no-use-damage --window-shader-fg "$activeshader"