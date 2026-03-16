#!/usr/bin/env bash

# Bluetooth status using blueutil if available, otherwise use networksetup
# Note: blueutil is more reliable than parsing plist files

if command -v blueutil &>/dev/null; then
  BT_STATUS=$(blueutil -p 2>/dev/null)
  if [ "$BT_STATUS" = "1" ]; then
    CONNECTED=$(blueutil --connected | wc -l | tr -d ' ')
    if [ "$CONNECTED" -gt 0 ]; then
      ICON="󰂱"
    else
      ICON="󰂯"
    fi
  else
    ICON="󰂲"
  fi
else
  # Fallback: use defaults (fragile - plist path/format may change)
  BT_STATUS=$(defaults read /Library/Preferences/com.apple.Bluetooth ControllerPowerState 2>/dev/null)
  if [ "$BT_STATUS" = "0" ]; then
    ICON="󰂲"
  else
    CONNECTED=$(system_profiler SPBluetoothDataType 2>/dev/null | grep -c "Connected: Yes" || echo "0")
    if [ "$CONNECTED" -gt 0 ]; then
      ICON="󰂱"
    else
      ICON="󰂯"
    fi
  fi
fi

sketchybar --set "$NAME" icon="$ICON" label.drawing=off
