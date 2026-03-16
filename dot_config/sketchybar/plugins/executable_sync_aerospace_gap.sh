#!/usr/bin/env bash
# Patch AeroSpace outer.top to match the sketchybar height.
# Called at sketchybar startup and by the shell reload() function before
# aerospace reload-config, ensuring correct ordering.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
CACHE_DIR="$HOME/.cache/sketchybar"
mkdir -p "$CACHE_DIR"
MBHEIGHT_BIN="$CACHE_DIR/menu_bar_height"
BAR_HEIGHT=$("$MBHEIGHT_BIN" 2>/dev/null || echo 30)

# On laptop-only (builtin display, macOS auto-hides menu bar without reserving
# space), keep a small aesthetic gap. When any external display is active, use
# the full bar height so windows don't cover sketchybar.
EXT_BIN="$CACHE_DIR/has_external_display"
EXT_SRC="$CONFIG_DIR/plugins/has_external_display.swift"
if [ ! -f "$EXT_BIN" ] || [ "$EXT_SRC" -nt "$EXT_BIN" ]; then
  swiftc "$EXT_SRC" -o "$EXT_BIN" 2>/dev/null
fi
HAS_EXTERNAL=$("$EXT_BIN" 2>/dev/null || echo 0)
echo "$HAS_EXTERNAL" > /tmp/sketchybar_has_external

GAP=8

if [ "$HAS_EXTERNAL" -eq 1 ] 2>/dev/null; then
  AEROSPACE_TOP=$(( BAR_HEIGHT + GAP ))
else
  AEROSPACE_TOP=$GAP
fi

AEROSPACE_CFG="$HOME/.config/aerospace/aerospace.toml"
# Resolve symlink so sed -i works (macOS sed refuses in-place edits on symlinks)
AEROSPACE_CFG="$(readlink -f "$AEROSPACE_CFG")"
OLD_TOP=$(grep "^outer\.top" "$AEROSPACE_CFG" | awk '{print $3}')
sed -i '' "s/^outer\.top[[:space:]]*=.*/outer.top        = $AEROSPACE_TOP/" "$AEROSPACE_CFG"
if [ "$OLD_TOP" != "$AEROSPACE_TOP" ] && command -v aerospace &>/dev/null; then
  aerospace reload-config
fi
