#!/usr/bin/env bash

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
SID="${NAME#space.}"

if [ "$SID" = "$FOCUSED" ]; then
  sketchybar --set "$NAME" \
    icon.color=0xff7aa2f7 \
    background.drawing=on
else
  sketchybar --set "$NAME" \
    icon.color=0xff565f89 \
    background.drawing=off
fi
