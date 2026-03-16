#!/usr/bin/env bash

# WiFi status using networksetup (more reliable than system_profiler)
# Note: networksetup is a stable CLI tool that has been available for years

# Get current WiFi service
WIFI_SERVICE=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')

if [ -z "$WIFI_SERVICE" ]; then
  ICON="󰤭"
else
  # Check if WiFi is on
  WIFI_POWER=$(networksetup -getairportpower "$WIFI_SERVICE" 2>/dev/null | awk '{print $NF}')
  
  if [ "$WIFI_POWER" != "On" ]; then
    ICON="󰤭"
  else
    # Get WiFi SSID (connected or not)
    WIFI_SSID=$(networksetup -getairportnetwork "$WIFI_SERVICE" 2>/dev/null | sed 's/Current Wi-Fi Network: //')
    
    if [ -z "$WIFI_SSID" ] || [ "$WIFI_SSID" = "off" ]; then
      ICON="󰤭"
    else
      # Get signal strength using airport command
      RSSI=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | grep "agrCtlRSSI" | awk '{print $2}')
      
      if [ -z "$RSSI" ]; then
        ICON="󰤨"
      elif [ "$RSSI" -gt -50 ]; then
        ICON="󰤨"
      elif [ "$RSSI" -gt -60 ]; then
        ICON="󰤥"
      elif [ "$RSSI" -gt -70 ]; then
        ICON="󰤢"
      elif [ "$RSSI" -gt -80 ]; then
        ICON="󰤟"
      else
        ICON="󰤯"
      fi
    fi
  fi
fi

sketchybar --set "$NAME" icon="$ICON" label.drawing=off
