#!/usr/bin/env bash

# Prevent reload loop: ignore if we reloaded within the last 5 seconds
LOCK=/tmp/sketchybar_display_reload
if [ -f "$LOCK" ]; then
  AGE=$(( $(date +%s) - $(stat -f %m "$LOCK") ))
  [ "$AGE" -lt 5 ] && exit 0
fi
touch "$LOCK"

sketchybar --reload
