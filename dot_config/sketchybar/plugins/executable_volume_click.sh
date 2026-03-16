#!/bin/bash

# Toggle mute using osascript
# Note: This uses the legacy osascript volume API which is fragile but unavoidable
# The API has been stable for years but may break with major macOS updates

if [ "$BUTTON" = "right" ]; then
  # Toggle mute
  osascript -e 'set volume output muted (not (output muted of (get volume settings)))'
else
  # Open Sound preferences
  open "x-apple.systempreferences:com.apple.preference.sound"
fi

# Refresh the volume icon
sketchybar --trigger volume_change
