#!/bin/bash

normal_label() {
  HAS_EXTERNAL=$(cat /tmp/sketchybar_has_external 2>/dev/null || echo 0)
  if [ "$HAS_EXTERNAL" -eq 1 ]; then
    date '+%b %-d | %H:%M | %A'
  else
    date '+%b %-d %H:%M'
  fi
}

STATE=$(cat /tmp/sketchybar_clock_alt 2>/dev/null || echo "normal")

if [ "$STATE" = "normal" ]; then
  echo "week" > /tmp/sketchybar_clock_alt
  sketchybar --set clock label="Week $(date '+%-V')"
  sleep 3
  sketchybar --set clock label="$(normal_label)"
  echo "normal" > /tmp/sketchybar_clock_alt
else
  sketchybar --set clock label="$(normal_label)"
  echo "normal" > /tmp/sketchybar_clock_alt
fi
