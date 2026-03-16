#!/usr/bin/env bash
# Follow focus to the correct workspace when Cmd+Tab (or any focus change)
# lands on a window that lives on a different workspace.

CURRENT_WS=$(aerospace list-workspaces --focused 2>/dev/null)
WINDOW_WS=$(aerospace list-windows --focused --format '%{workspace}' 2>/dev/null | head -1)

[ -z "$WINDOW_WS" ] && exit 0
[ "$WINDOW_WS" = "$CURRENT_WS" ] && exit 0

aerospace workspace "$WINDOW_WS"
