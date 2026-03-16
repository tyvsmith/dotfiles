#!/usr/bin/env bash

LEVEL=$(memory_pressure 2>/dev/null | awk '/system memory pressure is at/{print $(NF-1)}')

case "$LEVEL" in
  CRITICAL) COLOR=0xfff7768e ;;
  WARNING)  COLOR=0xffe0af68 ;;
  *)        COLOR=0xffa9b1d6 ;;
esac

if [ "$LEVEL" = "CRITICAL" ] || [ "$LEVEL" = "WARNING" ]; then
  TOP=$(ps -A -o pmem=,comm= -m 2>/dev/null | awk '{n=split($2,a,"/"); name=a[n]; if(name!="kernel_task"&&name!=""){print name;exit}}')
  [ ${#TOP} -gt 12 ] && TOP="${TOP:0:11}…"
  sketchybar --set "$NAME" icon="󰍛" icon.color=$COLOR label="$TOP" label.drawing=on
else
  sketchybar --set "$NAME" icon="󰍛" icon.color=$COLOR label.drawing=off
fi
