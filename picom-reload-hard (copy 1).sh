#!/bin/bash

#call on saturation, sharpness, etc.

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

conf=$path/profiles/current

tempshader=$path/shaders/universal_template.glsl

activeshader=$path/shaders/universal_active.glsl

readvar=$path/readvar.sh

cp -f "$tempshader" "$activeshader"

replace() #1=target string in shader #2=var name in config
{
  tgstr="$1"
  varname="$2"
  val=$("$readvar" "$conf" "$varname")
  sed -i "s\\$tgstr\\$val\g" "$activeshader"
}

replace SATURATION_VALUE saturation

replace SHARPNESS_VALUE sharpness

replace ROUGHNESS_VALUE roughness

replace DIM_VALUE dim

replace DIMSLOPE_VALUE dimslope

replace USEEFFECTS_VALUE useeffects

replace EXPAND_BLACKS_VALUE expand-blacks
replace EXPAND_BLACKS_SLOPE_VALUE expand-blacks-slope
replace EXPAND_BLACKS_GAMMA_VALUE expand-blacks-gamma
replace EXPAND_BLACKS_SAT_VALUE expand-blacks-sat
replace EXPAND_BLACKS_SAT_SLOPE_VALUE expand-blacks-sat-slope

replace LUM_VALUE lum

replace FAKEHDR_VALUE fakehdr

replace EXPOSURE_EXPANSION_VALUE exposure-expansion
replace EXPOSURE_EXPANSION_THRESHOLD_VALUE exposure-expansion-threshold
replace EXPOSURE_EXPANSION_SLOPE_VALUE exposure-expansion-slope
replace EXPOSURE_EXPANSION_IGNORE_LEVEL_VALUE exposure-expansion-ignore-level


replace BLACK_LIGHTNESS_VALUE black-lightness
#sed -i "s\R_VALUE\\$(~/scr/readvar.sh "$conf" r)\g" "$activeshader"

#sed -i "s\G_VALUE\\$(~/scr/readvar.sh "$conf" g)\g" "$activeshader"

#sed -i "s\B_VALUE\\$(~/scr/readvar.sh "$conf" b)\g" "$activeshader"

kill $(pgrep -f "picom ")

picom --backend glx --no-use-damage --window-shader-fg "$activeshader" & disown

exit 0
