#!/usr/bin/env bash

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
CACHE_DIR="$HOME/.cache/sketchybar"
mkdir -p "$CACHE_DIR"
BIN="$CACHE_DIR/cpu_stats"
SRC="$CONFIG_DIR/plugins/cpu_stats.swift"

if [ ! -f "$BIN" ] || [ "$SRC" -nt "$BIN" ]; then
  swiftc "$SRC" -o "$BIN" 2>/dev/null
fi

CPU=$("$BIN" 2>/dev/null || echo 0)

if [ "$CPU" -gt 80 ]; then
  COLOR=0xfff7768e
  TOP=$(ps -A -o pcpu=,comm= -r 2>/dev/null | awk '{n=split($2,a,"/"); name=a[n]; if(name!="kernel_task"&&name!=""){print name;exit}}')
  [ ${#TOP} -gt 12 ] && TOP="${TOP:0:11}…"
  sketchybar --set "$NAME" icon="󰻠" icon.color=$COLOR label="$TOP" label.drawing=on
elif [ "$CPU" -gt 50 ]; then
  COLOR=0xffe0af68
  sketchybar --set "$NAME" icon="󰻠" icon.color=$COLOR label.drawing=off
else
  COLOR=0xffa9b1d6
  sketchybar --set "$NAME" icon="󰻠" icon.color=$COLOR label.drawing=off
fi
