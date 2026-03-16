#!/usr/bin/env bash

# Get volume using osascript with robust error handling
# Note: This is more stable than it appears - the API hasn't changed in years
VOLUME=$(osascript -e 'try
  output volume of (get volume settings)
on error
  0
end try' 2>/dev/null)

MUTED=$(osascript -e 'try
  output muted of (get volume settings)
on error
  false
end try' 2>/dev/null)

# Handle missing value or empty
if [ -z "$VOLUME" ] || [ "$VOLUME" = "missing value" ]; then
  VOLUME=0
fi
if [ -z "$MUTED" ] || [ "$MUTED" = "missing value" ]; then
  MUTED=false
fi

# Determine icon based on volume level
if [ "$MUTED" = "true" ] || [ "$VOLUME" -eq 0 ]; then
  ICON="󰝟"
elif [ "$VOLUME" -gt 66 ]; then
  ICON="󰕾"
elif [ "$VOLUME" -gt 33 ]; then
  ICON="󰖀"
else
  ICON="󰕿"
fi

sketchybar --set "$NAME" \
  drawing=on \
  icon="$ICON" \
  label.drawing=off \
  click_script="osascript -e 'set volume output muted not (output muted of (get volume settings))'"
