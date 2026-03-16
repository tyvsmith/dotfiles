#!/usr/bin/env bash

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

for i in {1..9}; do
  if [ "$i" = "$FOCUSED" ]; then
    sketchybar --set space.$i \
      icon.color=0xff7aa2f7 \
      background.drawing=on
  else
    sketchybar --set space.$i \
      icon.color=0xff565f89 \
      background.drawing=off
  fi
done
