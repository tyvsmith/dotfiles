#!/usr/bin/env bash

BATT=$(pmset -g batt)
PERCENTAGE=$(echo "$BATT" | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(echo "$BATT" | grep 'AC Power')
TIME_REMAINING=$(echo "$BATT" | grep -Eo '[0-9]+:[0-9]+ remaining' | grep -Eo '[0-9]+:[0-9]+')

[ -z "$PERCENTAGE" ] && exit 0

if [ "$PERCENTAGE" -ge 80 ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

if [ -n "$CHARGING" ]; then
  case "$PERCENTAGE" in
    100)    ICON="󰂅" ;;
    9[0-9]) ICON="󰂋" ;;
    8[0-9]) ICON="󰂊" ;;
    7[0-9]) ICON="󰢞" ;;
    6[0-9]) ICON="󰂉" ;;
    5[0-9]) ICON="󰢝" ;;
    4[0-9]) ICON="󰂈" ;;
    3[0-9]) ICON="󰂇" ;;
    2[0-9]) ICON="󰂆" ;;
    *)      ICON="󰢜" ;;
  esac
  sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color=0xffa9b1d6 label.drawing=off
  exit 0
fi

if [ "$PERCENTAGE" -gt 80 ]; then
  ICON="󰁹"
elif [ "$PERCENTAGE" -gt 60 ]; then
  ICON="󰂀"
elif [ "$PERCENTAGE" -gt 40 ]; then
  ICON="󰁾"
elif [ "$PERCENTAGE" -gt 20 ]; then
  ICON="󰁼"
else
  ICON="󰁺"
fi

if [ "$PERCENTAGE" -le 10 ]; then
  COLOR=0xfff7768e
elif [ "$PERCENTAGE" -le 20 ]; then
  COLOR=0xffe0af68
else
  COLOR=0xffa9b1d6
fi

if [ "$PERCENTAGE" -le 20 ]; then
  if [ -z "$CHARGING" ] && [ -n "$TIME_REMAINING" ]; then
    LABEL="$TIME_REMAINING"
  else
    LABEL="${PERCENTAGE}%"
  fi
  sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color=$COLOR label="$LABEL" label.color=$COLOR label.drawing=on
else
  sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color=$COLOR label.drawing=off
fi
