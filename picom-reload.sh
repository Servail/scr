#!/bin/bash

#call on saturation, sharpness #or color change -deprecated

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
conf=$path/profiles/current
tempshader=$path/shaders/universal_template.glsl
activeshader=$path/shaders/universal_active.glsl

readvar=$path/readvar.sh

cp -f "$tempshader" "$activeshader"

saturation=$("$readvar" "$conf" saturation)
sed -i "s\SATURATION_VALUE\\$saturation\g" "$activeshader"

sharpness=$("$readvar" "$conf" sharpness)
sed -i "s\SHARPNESS_VALUE\\$sharpness\g" "$activeshader"

dim=$("$readvar" "$conf" dim)
sed -i "s\DIM_VALUE\\$dim\g" "$activeshader"

dimslope=$("$readvar" "$conf" dimslope)
sed -i "s\DIMSLOPE_VALUE\\$dimslope\g" "$activeshader"

useeffects=$("$readvar" "$conf" useeffects)
sed -i "s\USEEFFECTS_VALUE\\$useeffects\g" "$activeshader"


#sed -i "s\R_VALUE\\$(~/scr/readvar.sh "$conf" r)\g" "$activeshader"

#sed -i "s\G_VALUE\\$(~/scr/readvar.sh "$conf" g)\g" "$activeshader"

#sed -i "s\B_VALUE\\$(~/scr/readvar.sh "$conf" b)\g" "$activeshader"

killall picom

picom --backend glx --no-use-damage --window-shader-fg "$activeshader"
