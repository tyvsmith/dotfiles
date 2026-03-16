#!/usr/bin/env bash

HAS_EXTERNAL=$(cat /tmp/sketchybar_has_external 2>/dev/null || echo 0)
if [ "$HAS_EXTERNAL" -eq 1 ]; then
  LABEL=$(date '+%b %-d | %H:%M | %A')
else
  LABEL=$(date '+%b %-d %H:%M')
fi
sketchybar --set "$NAME" label="$LABEL"
