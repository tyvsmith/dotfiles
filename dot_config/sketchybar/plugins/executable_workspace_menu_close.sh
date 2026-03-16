#!/usr/bin/env bash

rm -f /tmp/sketchybar_popup_open /tmp/sketchybar_menu_keyboard

# Clear any keyboard selection highlight
SELECTED=$(cat /tmp/sketchybar_menu_selected 2>/dev/null)
[ -n "$SELECTED" ] && sketchybar --set apple_menu.ws.$SELECTED background.drawing=off

sketchybar --set apple_menu popup.drawing=off
aerospace mode main 2>/dev/null
