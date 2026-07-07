#!/bin/bash

#call on saturation, sharpness, etc.

path="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

conf=$path/profiles/current

sourceshader=$path/shaders/universal_template.glsl

tempshader=/dev/shm/shader.glsl

readvar=$path/readvar.sh

#kill picom first to give it time to close
kill $(pgrep -f "picom ")

#copy shader template to RAM to avoid disk writes
#tempshader="$(cat $path/shaders/universal_template.glsl)"
cp -f "$sourceshader" "$tempshader"

#replaces definition values with new values
redefine() #1=target define in shader, #2=new value #3=target shader file
{
  tgstr="$1"
  newval="$2"
  tgshader="$3"
  #if [[ $# -ne 1 ]]; then
  if [[ -z  "$tgshader" ]]; then
    tgshader="$tempshader"
  fi
  #sed -E -i "s/^#define[[:space:]]+$tgstr\\b.*/#define $tgstr $newval/" "$tgshader"
  sed -E -i "s/^(#define[[:space:]]+${tgstr}[[:space:]]+)\w+(\s*.*)/#define ${tgstr} ${newval}\2/" "$tgshader"
}

#replaces definition values with values readen from config (by var name)
cfgredf() #1=target define in shader #2=var name in config
{
  tgstr="$1"
  varname="$2"
  val=$("$readvar" "$conf" "$varname")
  redefine "$tgstr" "$val" "$tempshader"
}

cfg()
{
	echo $("$readvar" "$conf" "$1")
}

#simple string replacement
replace_string() #1=target string #2=new string #3=target file
{
  tgstr="$1"
  newstr="$2"
  tgfile="$3"
  sed -i "s\\$tgstr\\$newstr\g" "$tgfile"
}

#redefine template shader parameters
cfgredf Gamma gamma
cfgredf Contrast contrast
cfgredf Brightness brightness
cfgredf Saturation saturation
cfgredf Sharpness sharpness
cfgredf Roughness roughness
cfgredf Dim dim
cfgredf DimSlope dimslope
cfgredf UseEffects useeffects

cfgredf ExpandBlacks expand-blacks
cfgredf ExpandBlacksSlope expand-blacks-slope
cfgredf ExpandBlacksGamma expand-blacks-gamma
cfgredf ExpandBlacksSat expand-blacks-sat
cfgredf ExpandBlacksSatSlope expand-blacks-sat-slope

cfgredf Lum lum

cfgredf FakeHdr fakehdr

cfgredf ExposureExpansion exposure-expansion
cfgredf ExposureExpansionThreshold exposure-expansion-threshold
cfgredf ExposureExpansionSlope exposure-expansion-slope
cfgredf ExposureExpansionIgnoreLevel exposure-expansion-ignore-level


cfgredf BlackLightness black-lightness

cfgredf AutoBalance autobalance

#sed -i "s\R_VALUE\\$(~/scr/readvar.sh "$conf" r)\g" "$tempshader"

#sed -i "s\G_VALUE\\$(~/scr/readvar.sh "$conf" g)\g" "$tempshader"

#sed -i "s\B_VALUE\\$(~/scr/readvar.sh "$conf" b)\g" "$tempshader"

#kill $(pgrep -f "picom ")

#picom --backend glx --no-use-damage --window-shader-fg-rule "$tempshader":'_NET_WM_STATE@[*] *?= "MAXIMIZED" || _NET_WM_STATE@[*] *?= "FULLSCREEN"' & disown
#picom --backend glx --no-use-damage --window-shader-fg-rule $fullscreenshader:'focused=1' --window-shader-fg-rule $windowshader:'focused=0' & disown

fullscreenshader=/dev/shm/fullscreen_shader.glsl
windowshader=/dev/shm/window_shader.glsl
maximizedshader=/dev/shm/maximized_shader.glsl

cp -f "$tempshader" "$fullscreenshader"
cp -f "$tempshader" "$windowshader"
cp -f "$tempshader" "$maximizedshader"

redefine CURRENT_FXSTACK FXStack_Fullscreen "$fullscreenshader"
redefine CURRENT_FXSTACK FXStack_Windowed "$windowshader"
redefine CURRENT_FXSTACK FXStack_Maximized "$maximizedshader"

picom --backend glx --no-vsync --no-use-damage \
	--window-shader-fg $windowshader \
	--window-shader-fg-rule "$maximizedshader":'_NET_WM_STATE@[*] *?= "MAXIMIZED"' \
	--window-shader-fg-rule "$fullscreenshader":'_NET_WM_STATE@[*] *?= "FULLSCREEN"'  \
	& disown
	#"$fullscreenshader":'_NET_WM_STATE@[*] *?= "MAXIMIZED"
	#|| _NET_WM_STATE@[*] *?= "FULLSCREEN"' \
	#& disown

#_NET_WM_STATE rule for fullscreen detection not applied immediately after reload, the workaround is to remaximize or refocus the window after picom finishes loading TODO: FIX THIS, try by size and coords
sleep 0.5

active_win=$(xdotool getactivewindow)
another_win=$(xdotool search --onlyvisible "xfce4-panel")
xdotool windowactivate $another_win
# for win in $(xdotool search --onlyvisible "xfce4-panel"); do
# 	xdotool windowactivate $win
# #	sleep 0.05
# done
sleep 0.05
xdotool windowactivate $active_win

# if [[ ! -z "$(xprop | grep _NET_WM_STATE_FULLSCREEN)" ]]; then
# 	wmctrl -r :ACTIVE: -b remove,fullscreen
# 	wmctrl -r :ACTIVE: -b add,fullscreen
# else
# 	wmctrl -r :ACTIVE: -b toggle,maximized_vert,maximized_horz
# 	wmctrl -r :ACTIVE: -b toggle,maximized_vert,maximized_horz
# fi

#picom --backend glx --no-use-damage \
#	--window-shader-fg $windowshader \
#	--window-shader-fg-rule "$fullscreenshader":'fullscreen' \
#	& disown

exit 0
