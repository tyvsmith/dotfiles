#!/usr/bin/env bash

ACTION="$1"
BLUE=0xff7aa2f7
TEXT=0xffa9b1d6

SELECTED=$(cat /tmp/sketchybar_menu_selected 2>/dev/null || echo "1")
WORKSPACES=$(cat /tmp/sketchybar_menu_workspaces 2>/dev/null || echo "1")
WS_ARRAY=($WORKSPACES)
FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null)

# Find index of current selection
CURRENT_IDX=0
for idx in "${!WS_ARRAY[@]}"; do
  [ "${WS_ARRAY[$idx]}" = "$SELECTED" ] && CURRENT_IDX=$idx && break
done

restore_color() {
  local ws="$1"
  [ "$ws" = "$FOCUSED" ] && echo $BLUE || echo $TEXT
}

case "$ACTION" in
  up|down)
    if [ "$ACTION" = "up" ]; then
      NEW_IDX=$(( (CURRENT_IDX - 1 + ${#WS_ARRAY[@]}) % ${#WS_ARRAY[@]} ))
    else
      NEW_IDX=$(( (CURRENT_IDX + 1) % ${#WS_ARRAY[@]} ))
    fi
    NEW="${WS_ARRAY[$NEW_IDX]}"
    sketchybar --set apple_menu.ws.$SELECTED background.drawing=off label.color=$(restore_color $SELECTED)
    echo "$NEW" > /tmp/sketchybar_menu_selected
    sketchybar --set apple_menu.ws.$NEW background.drawing=on label.color=0xff1a1b26
    # Reset auto-close timer on each navigation
    TIMER_ID=$$
    echo $TIMER_ID > /tmp/sketchybar_menu_timer
    (sleep 4
      [ "$(cat /tmp/sketchybar_menu_timer 2>/dev/null)" = "$TIMER_ID" ] && {
        rm -f /tmp/sketchybar_popup_open /tmp/sketchybar_menu_keyboard
        sketchybar --set apple_menu popup.drawing=off
        aerospace mode main 2>/dev/null
      }) &
    ;;
  enter)
    rm -f /tmp/sketchybar_menu_keyboard /tmp/sketchybar_popup_open
    sketchybar --set apple_menu.ws.$SELECTED background.drawing=off
    sketchybar --set apple_menu popup.drawing=off
    aerospace workspace "$SELECTED"
    sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$SELECTED"
    ;;
  esc)
    rm -f /tmp/sketchybar_menu_keyboard /tmp/sketchybar_popup_open
    sketchybar --set apple_menu.ws.$SELECTED background.drawing=off
    sketchybar --set apple_menu popup.drawing=off
    ;;
esac
