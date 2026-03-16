#!/usr/bin/env bash

BLUE=0xff7aa2f7
TEXT=0xffa9b1d6
MODE="${1:-mouse}"

# Mouse toggle: close if already open
if [ "$MODE" = "mouse" ] && [ -f /tmp/sketchybar_popup_open ]; then
  rm -f /tmp/sketchybar_popup_open
  sketchybar --set apple_menu popup.drawing=off
  aerospace mode main 2>/dev/null
  exit 0
fi

FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null)

# Single query for all windows, parsed into per-workspace summaries
WS_SUMMARY=$(aerospace list-windows --all --format "%{workspace} %{app-name}" 2>/dev/null | \
  sort | awk '
    {
      ws = $1; app = substr($0, length(ws) + 2)
      if (!(ws SUBSEP app in seen)) {
        seen[ws SUBSEP app] = 1; count[ws]++
        if (count[ws] <= 2) label[ws] = (label[ws] ? label[ws] ", " app : app)
      }
    }
    END {
      for (ws in count) {
        extra = count[ws] > 2 ? " +" (count[ws] - 2) : ""
        print ws "|" label[ws] extra
      }
    }
  ' | sort)

# Hide all rows, then show occupied ones — all in one sketchybar call
ARGS=(--set apple_menu.ws.1 drawing=off --set apple_menu.ws.2 drawing=off
      --set apple_menu.ws.3 drawing=off --set apple_menu.ws.4 drawing=off
      --set apple_menu.ws.5 drawing=off --set apple_menu.ws.6 drawing=off
      --set apple_menu.ws.7 drawing=off --set apple_menu.ws.8 drawing=off
      --set apple_menu.ws.9 drawing=off)
VISIBLE=""
while IFS='|' read -r ws apps; do
  [ -z "$ws" ] && continue
  COLOR=$TEXT
  [ "$ws" = "$FOCUSED" ] && COLOR=$BLUE
  ARGS+=(--set "apple_menu.ws.$ws" drawing=on "label=$ws  $apps" "label.color=$COLOR" background.drawing=off)
  VISIBLE="$VISIBLE $ws"
done <<< "$WS_SUMMARY"
VISIBLE="${VISIBLE# }"
sketchybar "${ARGS[@]}"

auto_close() {
  local id="$1" delay="$2"
  (sleep "$delay"
    [ "$(cat /tmp/sketchybar_menu_timer 2>/dev/null)" = "$id" ] && {
      rm -f /tmp/sketchybar_popup_open /tmp/sketchybar_menu_keyboard
      sketchybar --set apple_menu popup.drawing=off
      aerospace mode main 2>/dev/null
    }) &
}

TIMER_ID=$$
echo $TIMER_ID > /tmp/sketchybar_menu_timer

if [ "$MODE" = "keyboard" ]; then
  echo "$VISIBLE" > /tmp/sketchybar_menu_workspaces

  SELECTED="$FOCUSED"
  if ! echo "$VISIBLE" | grep -qw "$FOCUSED"; then
    SELECTED=$(echo "$VISIBLE" | awk '{print $1}')
  fi
  echo "$SELECTED" > /tmp/sketchybar_menu_selected
  touch /tmp/sketchybar_menu_keyboard

  sketchybar --set apple_menu.ws.$SELECTED background.drawing=on label.color=0xff1a1b26
  sketchybar --set apple_menu popup.drawing=on
  auto_close "$TIMER_ID" 4
else
  touch /tmp/sketchybar_popup_open
  sketchybar --set apple_menu popup.drawing=on
  aerospace mode workspace_menu 2>/dev/null
  auto_close "$TIMER_ID" 2
fi
